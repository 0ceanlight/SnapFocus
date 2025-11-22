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
        // DO NOT start() here anymore. AppDelegate will call it.
    }

    deinit {
        stopTimers()
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    @MainActor
    func start() async {
        let granted = await requestAccess()
        guard granted else {
            print("SnapFocus: Calendar access denied.")
            self.blocks = []
            return
        }
        await fetchAndPublishToday()
        setupEventStoreListener()
        setupPeriodicPoll()
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Permissions (Sonoma-friendly)
    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted
            } catch {
                print("Calendar access error:", error.localizedDescription)
                return false
            }
        } else {
            do {
                let granted = try await store.requestAccess(to: .event)
                return granted
            } catch {
                print("Calendar access error (legacy):", error.localizedDescription)
                return false
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
            Task {
                await self?.fetchAndPublishToday()
            }
        }
    }

    // fallback poll every 10s
    private func setupPeriodicPoll() {
        stopTimers()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchAndPublishToday()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: - Fetch only today's events
    @MainActor
    func fetchAndPublishToday() async {
        // Prevent overwriting local changes if user is currently interacting
        if shiftSession != nil {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            return
        }

        // find calendars with matching title
        let calendars = store.calendars(for: .event).filter { $0.title == calendarName }
        guard !calendars.isEmpty else {
            self.blocks = []
            return
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = store.events(matching: predicate)

        let newBlocks = EventBlock.assignColorsOrdered(events: events)
        self.blocks = newBlocks
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
                
                Task {
                    await self.fetchAndPublishToday()
                }
            } catch {
                print("Error saving nudged events: \(error.localizedDescription)")
                Task {
                    await self.fetchAndPublishToday()
                }
            }
        }
    }

    /// Shifts all current events by the specified number of minutes.
    @MainActor
    func shiftTodaysEvents(by timeInterval: TimeInterval) async throws {
        // Prevent accidental overwrites if a shift session is active
        if shiftSession != nil {
            throw NSError(domain: "CalendarManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot bulk shift while an active task is being nudged."])
        }
        
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            throw NSError(domain: "CalendarManagerError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not determine end of day."])
        }

        let calendars = store.calendars(for: .event).filter { $0.title == calendarName }
        guard let snapFocusCalendar = calendars.first else {
            throw NSError(domain: "CalendarManagerError", code: 5, userInfo: [NSLocalizedDescriptionKey: "SnapFocus calendar not found. Please create it first."])
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: [snapFocusCalendar])
        let events = store.events(matching: predicate)
        
        var eventsToSave: [EKEvent] = []
        for event in events {
            guard event.isDetached == false else { continue } // Skip detached occurrences of recurring events
            
            event.startDate = event.startDate.addingTimeInterval(timeInterval)
            event.endDate = event.endDate.addingTimeInterval(timeInterval)
            eventsToSave.append(event)
        }
        
        // Save all changes in a single commit for efficiency and atomicity
        for event in eventsToSave {
            try store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
        
        print("Successfully shifted \(eventsToSave.count) events by \(timeInterval / 60.0) minutes.")
        
        // Refresh the UI
        await fetchAndPublishToday()
    }
}
