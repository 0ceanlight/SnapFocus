//
//  CalendarManager.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var events: [EKEvent] = []

    /// Ask user for calendar access
    func requestAccess(completion: @escaping (Bool) -> Void) {

        // macOS Sonoma (14) and newer
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { (granted, error) in
                // IMPORTANT: UI updates must be done on the main thread
                DispatchQueue.main.async {
                    if granted {
                        print("Calendar access granted.")
                    } else {
                        print("Calendar access denied or error: \(String(describing: error))")
                    }
                    completion(granted)
                }
            }
        } else {
            // Fallback for older macOS
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("Calendar access error (legacy API):", error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
    
    
    /// Fetch events from all calendars in the given date range
    func fetchEvents(
        start: Date = Date().addingTimeInterval(-86400),
        end: Date = Date().addingTimeInterval(86400 * 7)
    ) {
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        let results = eventStore.events(matching: predicate)
            .sorted(by: { $0.startDate < $1.startDate })

        DispatchQueue.main.async {
            self.events = results
            self.printEvents(results)
        }
    }


    /// Utility function to print events to console
    private func printEvents(_ events: [EKEvent]) {
        print("\n--- SnapFocus — Found \(events.count) calendar events ---")

        for event in events {
            let start = event.startDate?.description ?? "N/A"
            let end   = event.endDate?.description ?? "N/A"
            
            print("""
                \(event.title ?? "(untitled)")
                • Start: \(start)
                • End:   \(end)
                • Calendar: \(event.calendar.title)
                • Location: \(event.location ?? "(none)")
                --------------------------------------
                """)
        }
    }
}
