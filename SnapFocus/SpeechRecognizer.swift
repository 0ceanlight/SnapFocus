//
//  SpeechRecognizer.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/23/25.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var error: String? = nil
    
    // On macOS, it's safer to create a fresh engine each time to avoid state issues
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer()
    
    init() {
        requestPermissions()
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech: Authorized")
                case .denied:
                    self.error = "Speech recognition authorization denied"
                case .restricted:
                    self.error = "Speech recognition restricted on this device"
                case .notDetermined:
                    self.error = "Speech recognition not yet authorized"
                @unknown default:
                    self.error = "Unknown speech recognition error"
                }
            }
        }
    }
    
    func startTranscribing() {
        // Reset state
        self.transcript = ""
        self.error = nil
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            self.error = "Speech permission not granted yet."
            return
        }
        
        // Fully tear down any existing engine
        stopTranscribing()
        
        // Create fresh engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // 1. Configure Request
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true
        
        if #available(macOS 10.15, *), let recognizer = recognizer, recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // 2. Configure Input Node
        let inputNode = engine.inputNode // Accessing this creates the singleton instance for the engine
        
        // IMPORTANT: Use the hardware format. Do not try to convert yet.
        // SFSpeechAudioBufferRecognitionRequest handles conversion internally if needed.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Check if format is valid (sometimes 0Hz if no mic connected)
        if recordingFormat.sampleRate == 0 {
            self.error = "Invalid microphone sample rate. Check input settings."
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            request.append(buffer)
        }
        
        engine.prepare()
        
        do {
            try engine.start()
            isRecording = true
            print("Speech: Engine started with format \(recordingFormat)")
        } catch {
            self.error = "Audio Engine Error: \(error.localizedDescription)"
            return
        }
        
        // 3. Start Recognition
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    print("Speech Result: \(self.transcript)")
                }
            }
            
            if let error = error {
                print("Speech Error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopTranscribing() {
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        
        request?.endAudio()
        request = nil
        
        task?.cancel()
        task = nil
        audioEngine = nil // Release the engine
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        print("Speech: Stopped")
    }
}
