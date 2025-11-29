//
//  GeminiCalendarScheduler.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import EventKit
import GoogleGenerativeAI // Requires package: https://github.com/google/generative-ai-swift

// MARK: - Data Models
struct ScheduledTask: Codable {
    let title: String
    let startTime: Date
    let endTime: Date
    let notes: String
}

// MARK: - Gemini Scheduler Class
class GeminiCalendarScheduler {
    private let model: GenerativeModel
    private let eventStore = EKEventStore()
    
    init(apiKey: String) {
        // Fallback to stable model if preview is unavailable
        // Try "gemini-1.5-pro" if "gemini-3-pro-preview" fails
        self.model = GenerativeModel(
            name: "gemini-2.5-flash",
            apiKey: apiKey,
            systemInstruction: "You are a master scheduler. You output strictly valid JSON arrays."
        )
    }
    
    /// Main function to generate and save schedule
    func generateAndSchedule(tasksDescription: String, learningStyle: String) async throws {
        // Legacy support wrapper
        let combinedInput = "\(tasksDescription). Learning style: \(learningStyle)"
        try await generateAndSchedule(userInput: combinedInput)
    }
    
    func generateAndSchedule(userInput: String) async throws {
        
        // 1. Construct the Prompt
        let today = Date()
        let prompt = """
        I need a schedule for today (\(today.formatted(date: .abbreviated, time: .omitted))).
        Current time is: \(Date.now.formatted(date: .omitted, time: .shortened))
        
        Here is my request: "\(userInput)"
        
        Infer the tasks and any mentioned learning/working style (e.g. Pomodoro, Deep Work).
        If no style is mentioned, use a continuous flow with short breaks.
        
        Start the schedule from the current time or the next logical slot.
        
        CRITICAL RULES:
        1. Ensure there are NO overlapping events.
        2. Account for the learning style breaks explicitly.
        3. Use 24-hour format (HH:mm) for start times.
        
        STRICTLY RETURN A JSON ARRAY of objects with these exact fields:
        - title (string)
        - startTime (string, HH:mm format, e.g. "14:30")
        - durationMinutes (int, e.g. 25)
        - notes (string, short description)
        
        Example format:
        [
            {
                "title": "Task 1",
                "startTime": "09:00",
                "durationMinutes": 25,
                "notes": "Work block"
            }
        ]
        
        Do not include markdown formatting (like ```json). Just the raw JSON string.
        """
        
        // 2. Call Gemini API
        print("✨ Asking Gemini to structure your day...")
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "GeminiError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No text returned"])
        }
        
        // 3. Clean and Parse JSON
        let cleanJSON = text.replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanJSON.data(using: .utf8) else { return }
        
        // Custom struct for parsing JSON
        struct RawEvent: Decodable {
            let title: String
            let startTime: String
            let durationMinutes: Int
            let notes: String
        }
        
        let rawEvents = try JSONDecoder().decode([RawEvent].self, from: jsonData)
        
        // 4. Add to Calendar
        try await requestCalendarAccess()
        let calendar = try await getOrCreateSnapFocusCalendar()
        
        let calendarSys = Calendar.current
        
        for event in rawEvents {
            // Parse HH:mm
            let timeComponents = event.startTime.split(separator: ":")
            guard timeComponents.count == 2,
                  let hour = Int(timeComponents[0]),
                  let minute = Int(timeComponents[1]) else {
                print("⚠️ Skipping event due to invalid time format: \(event.startTime)")
                continue
            }
            
            // Construct Date from Today + HH:mm
            guard let start = calendarSys.date(bySettingHour: hour, minute: minute, second: 0, of: today) else {
                continue
            }
            
            let end = calendarSys.date(byAdding: .minute, value: event.durationMinutes, to: start) ?? start.addingTimeInterval(Double(event.durationMinutes) * 60)
            
            try saveEventToCalendar(title: event.title, start: start, end: end, notes: event.notes, to: calendar)
        }
        
        print("✅ Success! \(rawEvents.count) events added to your calendar.")
    }
    
    // MARK: - Calendar Helpers
    
    private func requestCalendarAccess() async throws {
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await eventStore.requestAccess(to: .event)
        }
        
        if !granted {
            throw NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
        }
    }
    
    private func getOrCreateSnapFocusCalendar() async throws -> EKCalendar {
        let calendarName = "SnapFocus"
        
        let calendars = eventStore.calendars(for: .event)
        if let calendar = calendars.first(where: { $0.title == calendarName }) {
            print("Found existing 'SnapFocus' calendar.")
            return calendar
        }
        
        print("No 'SnapFocus' calendar found. Creating a new one...")
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarName
        
        // Find a valid source for the calendar
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local || $0.sourceType == .calDAV }) {
            newCalendar.source = localSource
        } else {
            throw NSError(domain: "CalendarError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No valid calendar source found to create a new calendar."])
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        print("Successfully created 'SnapFocus' calendar.")
        return newCalendar
    }
    
    private func saveEventToCalendar(title: String, start: Date, end: Date, notes: String, to calendar: EKCalendar) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = "🤖 \(title)" // Emoji to denote AI generated
        event.startDate = start
        event.endDate = end
        event.notes = notes
        event.calendar = calendar
        
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
}

// MARK: - Example Usage
// Uncomment to run in a script environment
/*
Task {
    let apiKey = "YOUR_GEMINI_API_KEY" // Use WebSearch to find Google AI Studio and generate key
    let scheduler = GeminiCalendarScheduler(apiKey: apiKey)
    
    do {
        try await scheduler.generateAndSchedule(
            userInput: "2 hours of SwiftUI coding, 4 hours of studying Japanese history using Pomodoro technique"
        )
    } catch {
        print("Error: \(error)")
    }
}
*/
