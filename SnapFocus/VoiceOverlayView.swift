//
//  VoiceOverlayView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/23/25.
//

import SwiftUI

struct VoiceOverlayView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject var calendarManager: CalendarManager
    
    // We'll inject the Gemini Scheduler or create one
    // For now, let's create one locally but we need the API Key from prefs
    @AppStorage("gemini_api_key") private var geminiAPIKey: String = ""
    
    @State private var processingState: ProcessingState = .idle
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    @State private var rotation: Double = 0.0
    
    enum ProcessingState: Equatable {
        case idle
        case listening
        case processing
        case success
        case error(String)
    }
    
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Dark dimming background (optional, maybe just the orb)
            Color.black.opacity(0.01) // Nearly transparent to catch clicks if needed
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    closeOverlay()
                }
            
            VStack(spacing: 20) {
                // The Orb
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(orbColor.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .scaleEffect(processingState == .listening ? 1.2 : 1.0)
                        .blur(radius: 20)
                        .animation(processingState == .listening ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: processingState)
                    
                    // Core
                    Circle()
                        .fill(
                            LinearGradient(gradient: Gradient(colors: [orbColor, orbColor.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: orbColor.opacity(0.5), radius: 10, x: 0, y: 0)
                        .scaleEffect(scale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                scale = 1.1
                            }
                        }
                    
                    // Icon / State indicator
                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                        .rotationEffect(.degrees(rotation))
                }
                .onTapGesture {
                    if processingState == .idle {
                        startListening()
                    } else if processingState == .listening {
                        stopAndProcess()
                    }
                }
                
                // Status Text
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding(.horizontal)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                
                // Transcript Preview
                if !speechRecognizer.transcript.isEmpty && processingState == .listening {
                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: 400)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                }
            }
        }
        .onAppear {
            // Auto-start listening when view appears
            startListening()
        }
        .onChange(of: speechRecognizer.error) { newError in
             if let err = newError {
                 processingState = .error(err)
             }
        }
    }
    
    // MARK: - Helpers
    
    private var orbColor: Color {
        switch processingState {
        case .idle: return .blue
        case .listening: return .cyan
        case .processing: return .purple
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var iconName: String {
        switch processingState {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .processing: return "sparkles"
        case .success: return "checkmark"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private var statusText: String {
        switch processingState {
        case .idle: return "Tap to speak"
        case .listening: return "Tap orb to finish" // Clear instruction
        case .processing: return "Generating schedule..."
        case .success: return "Done!"
        case .error(let msg): return msg
        }
    }
    
    private func startListening() {
        processingState = .listening
        speechRecognizer.startTranscribing()
    }
    
    private func stopAndProcess() {
        speechRecognizer.stopTranscribing()
        
        // Short delay to ensure final transcript capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let transcript = speechRecognizer.transcript
            if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                processingState = .error("No speech detected")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    closeOverlay()
                }
                return
            }
            
            processingState = .processing
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            processWithGemini(transcript: transcript)
        }
    }
    
    private func processWithGemini(transcript: String) {
        guard !geminiAPIKey.isEmpty else {
            processingState = .error("Missing API Key")
            return
        }
        
        Task {
            let scheduler = GeminiCalendarScheduler(apiKey: geminiAPIKey)
            do {
                // We just pass the raw transcript
                try await scheduler.generateAndSchedule(userInput: transcript)
                
                await MainActor.run {
                    processingState = .success
                    rotation = 0
                    // Refresh calendar
                    Task { await calendarManager.fetchAndPublishToday() }
                    
                    // Close after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        closeOverlay()
                    }
                }
            } catch {
                await MainActor.run {
                    processingState = .error(error.localizedDescription)
                    rotation = 0
                }
            }
        }
    }
    
    private func closeOverlay() {
        // Reset state
        processingState = .idle
        speechRecognizer.stopTranscribing()
        onClose()
    }
}
