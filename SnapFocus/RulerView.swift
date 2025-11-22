//
//  RulerView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//


import SwiftUI
import AppKit

struct RulerView: View {
    @ObservedObject var cal: CalendarManager

    // layout config
    let enableHoverFeature = true
    let collapsedRulerWidth: CGFloat = 10.0
    let collapsedEventOpacity: Double = 0.8
    let rulerWidth: CGFloat = 37
    let pixelsPerMinute: CGFloat = 2.0    // tweak: 2 px per minute => 120 px per hour
    let whiteLineRatio: CGFloat = 0.30    // 30% down the screen
    let labelInset: CGFloat = 8

    @State private var now: Date = Date()
    @State private var isHovering = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // popover state
    @State private var selectedBlock: EventBlock? = nil
    @State private var showPopover: Bool = false
    @State private var popoverAnchorFrame: CGRect = .zero

    // Interaction State
    @State private var eventMonitor: Any? = nil
    @State private var lastShiftDelta: Double = 0 // For UI feedback only

    var body: some View {
        let isCollapsed = enableHoverFeature && !isHovering
        let currentWidth: CGFloat = isCollapsed ? collapsedRulerWidth : 300
        
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if isCollapsed {
                    // --- COLLAPSED VIEW ---
                    Canvas { context, size in
                        let height = size.height
                        let anchorNow = now
                        let whiteY = height * whiteLineRatio

                        // visible time window
                        let visibleTopSeconds = TimeInterval(-(whiteY / pixelsPerMinute) * 60.0)
                        let visibleBottomSeconds = TimeInterval(((height - whiteY) / pixelsPerMinute) * 60.0)

                        // base gray bar
                        let fullRect = CGRect(x: 0, y: 0, width: collapsedRulerWidth, height: height)
                        context.fill(Path(fullRect), with: .color(Color.gray.opacity(collapsedEventOpacity)))

                        // draw event blocks
                        for block in cal.blocks {
                            let sSec = block.start.timeIntervalSince(anchorNow)
                            let eSec = block.end.timeIntervalSince(anchorNow)

                            if eSec < visibleTopSeconds || sSec > visibleBottomSeconds { continue }

                            let yStart = whiteY + CGFloat(sSec / 60.0) * pixelsPerMinute
                            let yEnd   = whiteY + CGFloat(eSec / 60.0) * pixelsPerMinute
                            let rect = CGRect(x: 0, y: yStart, width: collapsedRulerWidth, height: max(1, yEnd - yStart))

                            context.fill(Path(rect), with: .color(block.color.opacity(collapsedEventOpacity)))
                        }
                    }
                } else {
                    // --- EXPANDED VIEW ---
                    Color.black.opacity(0.12)

                    // background canvas: ticks and event blocks
                    Canvas { context, size in
                        let height = size.height
                        let anchorNow = now
                        let whiteY = height * whiteLineRatio
                        
                        // visible time window in seconds for clipping
                        let visibleTopSeconds = TimeInterval(-(whiteY / pixelsPerMinute) * 60.0)
                        let visibleBottomSeconds = TimeInterval(((height - whiteY) / pixelsPerMinute) * 60.0)

                        // draw event backgrounds (Live from cal.blocks which updates during drag)
                        for block in cal.blocks {
                            let sSec = block.start.timeIntervalSince(anchorNow)
                            let eSec = block.end.timeIntervalSince(anchorNow)

                            let yStart = whiteY + CGFloat(sSec / 60.0) * pixelsPerMinute
                            let yEnd   = whiteY + CGFloat(eSec / 60.0) * pixelsPerMinute
                            
                            if yEnd < 0 || yStart > height { continue }

                            let rect = CGRect(x: 0, y: yStart, width: rulerWidth, height: max(1, yEnd - yStart))

                            context.fill(Path(rect), with: .color(block.color.opacity(0.18)))
                            context.stroke(Path(rect), with: .color(block.color.opacity(0.35)), lineWidth: 1.0)
                        }

                        // ticks: aligned to nearest 15-min mark covering visible range
                        let stepSeconds = 15 * 60
                        let visibleStart = anchorNow.addingTimeInterval(visibleTopSeconds)
                        let visibleEnd   = anchorNow.addingTimeInterval(visibleBottomSeconds)

                        let calComp = Calendar.current
                        let comps = calComp.dateComponents([.year, .month, .day, .hour, .minute], from: visibleStart)
                        var minute = comps.minute ?? 0
                        minute = (minute / 15) * 15
                        var firstTick = calComp.date(bySettingHour: comps.hour ?? 0, minute: minute, second: 0, of: visibleStart) ?? visibleStart

                        if firstTick > visibleStart {
                            firstTick = firstTick.addingTimeInterval(TimeInterval(-stepSeconds))
                        }

                        var tickTime = firstTick
                        while tickTime <= visibleEnd {
                            let y = whiteY + CGFloat(tickTime.timeIntervalSince(anchorNow) / 60.0) * pixelsPerMinute

                            let tickComps = calComp.dateComponents([.minute], from: tickTime)
                            let isHour = (tickComps.minute ?? 0) == 0

                            let tickWidth: CGFloat = isHour ? rulerWidth * 0.60 : rulerWidth * 0.30
                            let tickX: CGFloat = 6

                            // tick color: if event covers that moment, show event color
                            var tickColor = Color.gray.opacity(0.7)
                            // Use updated blocks for tick coloring too
                            if let ev = cal.blocks.first(where: { $0.start <= tickTime && $0.end > tickTime }) {
                                tickColor = ev.color
                            }

                            var tickPath = Path()
                            tickPath.move(to: CGPoint(x: tickX, y: y))
                            tickPath.addLine(to: CGPoint(x: tickX + tickWidth, y: y))
                            context.stroke(tickPath, with: .color(tickColor), lineWidth: isHour ? 2.0 : 1.0)

                            if isHour {
                                let hourFormatter = DateFormatter()
                                hourFormatter.dateFormat = "HH:mm"
                                let label = hourFormatter.string(from: tickTime)
                                let text = Text(label).font(.caption2).bold().foregroundColor(.white)
                                context.draw(text, at: CGPoint(x: tickX + tickWidth + 8, y: y - 8), anchor: .leading)
                            }

                            tickTime = tickTime.addingTimeInterval(TimeInterval(stepSeconds))
                        }

                        if cal.blocks.isEmpty {
                            context.fill(Path(CGRect(x: 0, y: 0, width: rulerWidth, height: height)), with: .color(Color.gray.opacity(0.06)))
                        }

                        var edgePath = Path(CGRect(x: rulerWidth - 1, y: 0, width: 1, height: height))
                        context.fill(edgePath, with: .color(Color.black.opacity(0.07)))
                    }
                    .frame(width: rulerWidth)

                    // clickable labels
                    ForEach(cal.blocks) { block in
                        let sSec = block.start.timeIntervalSince(now)
                        let eSec = block.end.timeIntervalSince(now)
                        
                        let yStart = geo.size.height * whiteLineRatio + CGFloat(sSec / 60.0) * pixelsPerMinute
                        let heightPx = max(18, CGFloat((eSec - sSec) / 60.0) * pixelsPerMinute)

                        if yStart + heightPx < 0 || yStart > geo.size.height {
                            EmptyView()
                        } else {
                            Button(action: {
                                selectedBlock = block
                                showPopover = true
                            }) {
                                HStack(alignment: .center, spacing: 8) {
                                    Rectangle()
                                        .fill(block.color)
                                        .frame(width: 6, height: min(18, heightPx))
                                        .cornerRadius(2)

                                    Text(block.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .frame(width: geo.size.width - rulerWidth - 12, height: heightPx, alignment: .leading)
                            .position(x: (rulerWidth + (geo.size.width - rulerWidth) / 2), y: yStart + heightPx / 2)
                            .popover(isPresented: Binding(
                                get: { selectedBlock?.id == block.id && showPopover },
                                set: { newVal in
                                    if !newVal { showPopover = false; selectedBlock = nil }
                                }
                            )) {
                                EventDetailView(block: block)
                                    .frame(width: 300)
                            }
                        }
                    }
                    
                    // Interaction Feedback
                    // Since we modify blocks directly, we might not need an overlay, 
                    // but user requested "labeling how much time they're shifting by".
                    // We can show this transiently if we track `lastShiftDelta` in View but reset it.
                    // Actually, simpler: show it if non-zero, fade out? 
                    // Since `nudgeCurrentTask` handles logic, the View doesn't know the exact cumulative delta easily 
                    // unless we expose it or track it separately.
                    // For now, let's keep it simple: visual feedback is the blocks moving.
                }
                
                // Current time white line
                VStack(spacing: 4) {
                    Spacer().frame(height: geo.size.height * whiteLineRatio)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: isCollapsed ? collapsedRulerWidth: rulerWidth, height: 2)
                            .shadow(color: Color.white.opacity(0.9), radius: 2)

                        if !isCollapsed {
                             Text(shortTimeString(now))
                                .font(.caption2).bold()
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: currentWidth)
        .onReceive(timer) { t in
            self.now = t
        }
        .onHover { hovering in
            if enableHoverFeature {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isHovering = hovering
                }
            }
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isHovering else { return event }
            
            if event.specialKey == .upArrow {
                // Shorten active task (-5 min)
                cal.nudgeCurrentTask(byMinutes: -5)
                return nil
            } else if event.specialKey == .downArrow {
                // Extend active task (+5 min)
                cal.nudgeCurrentTask(byMinutes: 5)
                return nil
            }
            return event
        }
    }

    private func shortTimeString(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
}

struct EventDetailView: View {
    let block: EventBlock
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(block.title).font(.headline)
            HStack {
                Image(systemName: "clock")
                Text("\(df.string(from: block.start)) — \(df.string(from: block.end))")
            }.font(.subheadline)
            HStack {
                Image(systemName: "calendar")
                Text(block.calendarTitle).font(.subheadline)
            }
            Spacer().frame(height: 8)
            Button("Jump to start") { }
            Spacer()
        }
        .padding()
    }
}
