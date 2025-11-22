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
        
        // 1. Construct the Prompt
        let today = Date()
        let prompt = """
        I need a schedule for today (\(today.formatted())).
        
        Here is what I need to work on: "\(tasksDescription)"
        My learning/working style is: "\(learningStyle)" (e.g., if Pomodoro, insert 5m breaks; if Deep Work, do 90m blocks).
        
        Start the schedule from now (\(Date.now.formatted(date: .omitted, time: .shortened))) or the next logical hour.
        
        CRITICAL RULES:
        1. Ensure there are NO overlapping events. Each event must strictly start after the previous one ends.
        2. Account for the learning style breaks explicitly.
        
        STRICTLY RETURN A JSON ARRAY of objects with these exact fields:
        - title (string)
        - startISO (string, ISO8601 date-time)
        - endISO (string, ISO8601 date-time)
        - notes (string, short description)
        
        Example format:
        [
            {
                "title": "Task 1",
                "startISO": "2023-10-27T09:00:00Z",
                "endISO": "2023-10-27T09:25:00Z",
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
        
        // Custom struct for parsing JSON strings before converting to real Date objects
        struct RawEvent: Decodable {
            let title: String
            let startISO: String
            let endISO: String
            let notes: String
        }
        
        let rawEvents = try JSONDecoder().decode([RawEvent].self, from: jsonData)
        
        // 4. Add to Calendar
        try await requestCalendarAccess()
        let calendar = try await getOrCreateSnapFocusCalendar()

        // Standard ISO8601 formatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Fallback formatter without fractional seconds
        let simpleIsoFormatter = ISO8601DateFormatter()
        simpleIsoFormatter.formatOptions = [.withInternetDateTime]
        
        for event in rawEvents {
            // Flexible date parsing strategy
            var start: Date? = isoFormatter.date(from: event.startISO)
            if start == nil {
                start = simpleIsoFormatter.date(from: event.startISO)
            }
            
            var end: Date? = isoFormatter.date(from: event.endISO)
            if end == nil {
                end = simpleIsoFormatter.date(from: event.endISO)
            }
            
            guard let validStart = start, let validEnd = end else {
                print("⚠️ Skipping event due to date format error: \(event.title) (Start: \(event.startISO), End: \(event.endISO))")
                continue
            }
            
            try saveEventToCalendar(title: event.title, start: validStart, end: validEnd, notes: event.notes, to: calendar)
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
            tasksDescription: "2 hours of SwiftUI coding, 4 hours of studying Japanese history",
            learningStyle: "Pomodoro (25m work, 5m break)"
        )
    } catch {
        print("Error: \(error)")
    }
}
*/
