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

    // --- State for "Current Task" shifting ---
    private struct ShiftSession {
        let originalBlocks: [EventBlock]
        let activeBlockId: String
        let connectedBlockIds: Set<String>
        var currentDeltaMinutes: Double
    }
    private var shiftSession: ShiftSession?
    private var shiftCommitTask: Task<Void, Never>?
    // -----------------------------------------

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
    func fetchAndPublishToday(completion: (() -> Void)? = nil) {
        // Prevent overwriting local changes if user is currently interacting
        if shiftSession != nil {
            completion?()
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            completion?()
            return
        }

        // find calendars with matching title
        let calendars = store.calendars(for: .event).filter { $0.title == calendarName }
        guard !calendars.isEmpty else {
            DispatchQueue.main.async {
                self.blocks = []
                completion?()
            }
            return
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = store.events(matching: predicate)

        let newBlocks = EventBlock.assignColorsOrdered(events: events)

        DispatchQueue.main.async {
            self.blocks = newBlocks
            completion?()
        }
    }

    // MARK: - Time Shift Logic

    /// Shifts the current active task (under `now`) by modifying its end time.
    /// Future tasks are shifted only if they are contiguously connected.
    func nudgeCurrentTask(byMinutes minutes: Double) {
        // Cancel any pending commit
        shiftCommitTask?.cancel()
        
        let now = Date()
        
        // 1. Initialize session if needed
        if shiftSession == nil {
            // Check active blocks
            // If multiple, pick the one that ends latest (most likely the 'main' container if nested)
            // or starts latest? Let's just pick the first valid one.
            guard let activeBlock = blocks.first(where: { $0.start <= now && $0.end > now }) else {
                print("No active block to shift.")
                return
            }
            
            // Find connected chain (future blocks with start ~ end of previous)
            // We use a small tolerance (e.g. 1 second) for "connected"
            let sortedFuture = blocks.filter { $0.start >= activeBlock.end }.sorted { $0.start < $1.start }
            var chainIds: Set<String> = []
            var lastEnd = activeBlock.end
            
            for block in sortedFuture {
                if abs(block.start.timeIntervalSince(lastEnd)) < 5 { // Tighter tolerance
                    chainIds.insert(block.id)
                    lastEnd = block.end
                } else {
                    break // chain broken
                }
            }
            
            shiftSession = ShiftSession(
                originalBlocks: self.blocks,
                activeBlockId: activeBlock.id,
                connectedBlockIds: chainIds,
                currentDeltaMinutes: 0
            )
        }
        
        // 2. Update delta
        shiftSession?.currentDeltaMinutes += minutes
        
        guard let session = shiftSession else { return }
        
        // 3. Apply preview to `blocks`
        let deltaSec = session.currentDeltaMinutes * 60.0
        
        self.blocks = session.originalBlocks.map { original in
            if original.id == session.activeBlockId {
                // Active block: extend/shorten END only. START is fixed.
                // Prevent end < start + 1 min (min duration)
                var newEnd = original.end.addingTimeInterval(deltaSec)
                if newEnd <= original.start.addingTimeInterval(60) {
                    newEnd = original.start.addingTimeInterval(60)
                }
                
                return EventBlock(
                    id: original.id,
                    title: original.title,
                    start: original.start, // FIXED
                    end: newEnd,
                    color: original.color,
                    calendarTitle: original.calendarTitle
                )
            } else if session.connectedBlockIds.contains(original.id) {
                // Connected blocks: shift entire block to maintain connection
                // New Start = Old Start + Delta
                let newStart = original.start.addingTimeInterval(deltaSec)
                let newEnd = original.end.addingTimeInterval(deltaSec)
                
                return EventBlock(
                    id: original.id,
                    title: original.title,
                    start: newStart,
                    end: newEnd,
                    color: original.color,
                    calendarTitle: original.calendarTitle
                )
            } else {
                // Unconnected blocks: Untouched
                return original
            }
        }
        
        // 4. Schedule Commit
        shiftCommitTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            if !Task.isCancelled {
                await commitShift()
            }
        }
    }
    
    @MainActor
    private func commitShift() {
        guard let session = shiftSession else { return }
        let deltaSec = session.currentDeltaMinutes * 60.0
        let activeId = session.activeBlockId
        let connectedIds = session.connectedBlockIds
        
        // Clear session so next interaction starts fresh
        self.shiftSession = nil
        
        if deltaSec == 0 { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var eventsToSave: [EKEvent] = []
            
            // Fetch and modify Active Event
            if let activeEvent = self.store.event(withIdentifier: activeId) {
                 activeEvent.endDate = activeEvent.endDate.addingTimeInterval(deltaSec)
                 eventsToSave.append(activeEvent)
            }
            
            // Fetch and modify Chain Events
            for id in connectedIds {
                if let event = self.store.event(withIdentifier: id) {
                    event.startDate = event.startDate.addingTimeInterval(deltaSec)
                    event.endDate = event.endDate.addingTimeInterval(deltaSec)
                    eventsToSave.append(event)
                }
            }
            
            do {
                for event in eventsToSave {
                    try self.store.save(event, span: .thisEvent, commit: false)
                }
                try self.store.commit()
                print("Successfully nudged active task and \(connectedIds.count) future tasks by \(session.currentDeltaMinutes) min.")
                
                self.fetchAndPublishToday()
            } catch {
                print("Error saving nudged events: \(error.localizedDescription)")
                self.fetchAndPublishToday()
            }
        }
    }

    /// Shifts all current events by the specified number of minutes.
}
