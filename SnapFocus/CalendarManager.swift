//
//  CalendarManager.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import EventKit
import Combine
import SwiftUI

final class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    private var timer: Timer?
    private var notificationObserver: Any?

    @Published private(set) var blocks: [EventBlock] = []

    /// The calendar name to import from (SnapFocus)
    let calendarName: String

    init(calendarName: String = "SnapFocus") {
        self.calendarName = calendarName
        start()
    }

    deinit {
        stopTimers()
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func start() {
        requestAccess { granted in
            guard granted else {
                print("SnapFocus: Calendar access denied.")
                DispatchQueue.main.async {
                    self.blocks = []
                }
                return
            }
            self.fetchAndPublishToday()
            self.setupEventStoreListener()
            self.setupPeriodicPoll()
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Permissions (Sonoma-friendly)
    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                if let error = error {
                    print("Calendar access error:", error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("Calendar access error (legacy):", error.localizedDescription)
                }
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    // MARK: - Watch for external calendar changes
    private func setupEventStoreListener() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.fetchAndPublishToday()
        }
    }

    // fallback poll every 10s
    private func setupPeriodicPoll() {
        stopTimers()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.fetchAndPublishToday()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: - Fetch only today's events
    // TODO: fetch others also?
    func fetchAndPublishToday() {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return
        }

        // find calendars with matching title
        let calendars = store.calendars(for: .event).filter { $0.title == calendarName }
        guard !calendars.isEmpty else {
            DispatchQueue.main.async { self.blocks = [] }
            return
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = store.events(matching: predicate)

        let newBlocks = EventBlock.assignColorsOrdered(events: events)

        DispatchQueue.main.async {
            self.blocks = newBlocks
        }
    }
}
