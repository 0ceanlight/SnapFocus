//
//  AgenticSchedulerView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import SwiftUI

struct AgenticSchedulerView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @AppStorage("gemini_api_key") private var geminiAPIKey: String = ""
    
    // State for the Gemini Scheduler
    @State private var tasksDescription: String = ""
    @State private var learningStyle: String = "Pomodoro (25min work, 5min break)"
    @State private var geminiStatus: String = "Idle"
    
    // State for Bulk Time Shift
    @State private var timeShiftInput: String = ""
    @State private var shiftStatus: String = ""
    
    // An instance of the scheduler
    @State private var scheduler: GeminiCalendarScheduler?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agentic Scheduler")
                .font(.largeTitle)
                .bold()

            GroupBox("Schedule Generation (with Gemini)") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Enter your tasks for the day...", text: $tasksDescription, axis: .vertical)
                        .lineLimit(3...)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)

                    TextField("Working Style", text: $learningStyle)
                        .textFieldStyle(.roundedBorder)

                    // Removed SecureField for API Key, now managed in Preferences
                    Text("Gemini API Key is managed in Preferences (Cmd+,)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: generateSchedule) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Schedule")
                        }
                    }
                    .disabled(geminiAPIKey.isEmpty || tasksDescription.isEmpty)
                }
                .padding(.vertical, 8)
            }
            
            GroupBox("Bulk Time Shift") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("e.g., +15m, -1h", text: $timeShiftInput)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: shiftEvents) {
                        HStack {
                            Image(systemName: "hourglass.tophalf.fill")
                            Text("Shift All Today's Events")
                        }
                    }
                    .disabled(timeShiftInput.isEmpty)
                }
                .padding(.vertical, 8)
            }

            GroupBox("Window Management (with Rectangle)") {
                HStack {
                    Button("Left Half") { RectangleManager.execute(.leftHalf) }
                    Button("Right Half") { RectangleManager.execute(.rightHalf) }
                    Button("Maximize") { RectangleManager.execute(.maximize) }
                    Button("Center") { RectangleManager.execute(.center) }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Text("Gemini Status: \(geminiStatus)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !shiftStatus.isEmpty {
                Text("Shift Status: \(shiftStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }

    private func generateSchedule() {
        guard !geminiAPIKey.isEmpty else {
            geminiStatus = "Error: Gemini API Key is missing. Set it in Preferences (Cmd+,)."
            return
        }

        scheduler = GeminiCalendarScheduler(apiKey: geminiAPIKey)
        geminiStatus = "Generating schedule..."

        Task {
            do {
                try await scheduler?.generateAndSchedule(
                    tasksDescription: tasksDescription,
                    learningStyle: learningStyle
                )
                geminiStatus = "✅ Successfully generated schedule! Check your calendar."
            } catch {
                geminiStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func shiftEvents() {
        shiftStatus = "Parsing time shift..."
        guard let timeInterval = parseTimeShiftInput(timeShiftInput) else {
            shiftStatus = "Error: Invalid time format. Use e.g., +15m, -1h."
            return
        }
        
        shiftStatus = "Shifting events..."
        Task { @MainActor in // <-- Added @MainActor here
            do {
                try await calendarManager.shiftEventsInScope(by: timeInterval)
                shiftStatus = "✅ Successfully shifted events!"
            } catch {
                shiftStatus = "Error shifting events: \(error.localizedDescription)"
            }
        }
    }
    
    private func parseTimeShiftInput(_ input: String) -> TimeInterval? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let pattern = #"^([\+\-]?\d+)\s*(m|min|minute|h|hr|hour)?s?$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        guard let match = regex?.firstMatch(in: trimmedInput, options: [], range: NSRange(location: 0, length: trimmedInput.utf16.count)) else {
            return nil
        }
        
        guard let valueRange = Range(match.range(at: 1), in: trimmedInput),
              let value = Double(trimmedInput[valueRange]) else {
            return nil
        }
        
        var unit: String?
        if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: trimmedInput) {
            unit = String(trimmedInput[unitRange])
        }
        
        var multiplier: Double = 1.0 // default to minutes
        if let u = unit {
            if u.hasPrefix("h") { // h, hr, hour, hours
                multiplier = 60.0
            }
        }
        
        return value * multiplier * 60.0 // Convert to seconds
    }
}

#Preview {
    AgenticSchedulerView()
        .environmentObject(CalendarManager()) // Provide a dummy for preview
}
