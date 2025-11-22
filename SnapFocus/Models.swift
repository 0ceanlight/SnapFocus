//
//  Models.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import SwiftUI
import EventKit

struct EventBlock: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: Color
    let calendarTitle: String
}

fileprivate let defaultColors: [Color] = [
    Color.orange.opacity(0.85),
    Color.blue.opacity(0.85),
    Color.green.opacity(0.85),
    Color.purple.opacity(0.85),
    Color.red.opacity(0.85)
]

// Choose from palette but keep base non-transparent for tick lines
fileprivate let lineColors: [Color] = [
    Color.orange,
    Color.blue,
    Color.green,
    Color.purple,
    Color.red
]

extension EventBlock {
    static func assignColorsOrdered(events: [EKEvent]) -> [EventBlock] {
        let sorted = events
            .compactMap { e -> EKEvent? in
                guard let s = e.startDate, let en = e.endDate else { return nil }
                return s < en ? e : nil
            }
            .sorted(by: { $0.startDate! < $1.startDate! })

        var blocks: [EventBlock] = []
        var prevIndex: Int? = nil

        for (i, ev) in sorted.enumerated() {
            // pick color index - simple round-robin but avoid matching previous index
            var idx = i % defaultColors.count
            if let p = prevIndex, idx == p {
                idx = (idx + 1) % defaultColors.count
            }
            prevIndex = idx

            let color = defaultColors[idx]
            let id = ev.eventIdentifier ?? UUID().uuidString
            blocks.append(.init(
                id: id,
                title: ev.title ?? "(untitled)",
                start: ev.startDate!,
                end: ev.endDate!,
                color: color,
                calendarTitle: ev.calendar.title
            ))
        }
        return blocks
    }

    // helper to calculate minutes between dates
    func minutes(from anchor: Date) -> (startMin: Double, endMin: Double) {
        let startMin = start.timeIntervalSince(anchor) / 60.0
        let endMin   = end.timeIntervalSince(anchor) / 60.0
        return (startMin, endMin)
    }
}
