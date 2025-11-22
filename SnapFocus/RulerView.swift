//
//  RulerView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//


import SwiftUI

struct RulerView: View {
    @ObservedObject var cal: CalendarManager

    // layout config
    let rulerWidth: CGFloat = 48
    let pixelsPerMinute: CGFloat = 2.0    // tweak: 2 px per minute => 120 px per hour
    let whiteLineRatio: CGFloat = 0.30    // 30% down the screen
    let labelInset: CGFloat = 8

    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // popover state
    @State private var selectedBlock: EventBlock? = nil
    @State private var showPopover: Bool = false
    @State private var popoverAnchorFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear

                // background canvas: ticks and event blocks
                Canvas { context, size in
                    let height = size.height
                    let anchorNow = now
                    let whiteY = height * whiteLineRatio

                    // visible time window in seconds for clipping
                    let visibleTopSeconds = TimeInterval(-(whiteY / pixelsPerMinute) * 60.0)
                    let visibleBottomSeconds = TimeInterval(((height - whiteY) / pixelsPerMinute) * 60.0)

                    // draw event backgrounds
                    for block in cal.blocks {
                        let sSec = block.start.timeIntervalSince(anchorNow)
                        let eSec = block.end.timeIntervalSince(anchorNow)

                        // quick clip (if block entirely outside visible range, skip)
                        if eSec < visibleTopSeconds || sSec > visibleBottomSeconds { continue }

                        let yStart = whiteY + CGFloat(sSec / 60.0) * pixelsPerMinute
                        let yEnd   = whiteY + CGFloat(eSec / 60.0) * pixelsPerMinute
                        let rect = CGRect(x: 0, y: yStart, width: rulerWidth, height: max(1, yEnd - yStart))

                        context.fill(Path(rect), with: .color(block.color.opacity(0.18)))
                        // faint border
                        context.stroke(Path(rect), with: .color(block.color.opacity(0.35)), lineWidth: 1.0)
                    }

                    // ticks: aligned to nearest 15-min mark covering visible range
                    let stepSeconds = 15 * 60
                    // compute visibleStart and visibleEnd absolute Dates
                    let visibleStart = anchorNow.addingTimeInterval(visibleTopSeconds)
                    let visibleEnd   = anchorNow.addingTimeInterval(visibleBottomSeconds)

                    // find first tick at or before visibleStart that is a multiple of 15 minutes
                    let calComp = Calendar.current
                    let comps = calComp.dateComponents([.year, .month, .day, .hour, .minute], from: visibleStart)
                    var minute = comps.minute ?? 0
                    minute = (minute / 15) * 15 // floor to nearest 15
                    var firstTick = calComp.date(bySettingHour: comps.hour ?? 0, minute: minute, second: 0, of: visibleStart) ?? visibleStart

                    // if firstTick is still > visibleStart, step back one
                    if firstTick > visibleStart {
                        firstTick = firstTick.addingTimeInterval(TimeInterval(-stepSeconds))
                    }

                    var tickTime = firstTick
                    while tickTime <= visibleEnd {
                        let y = whiteY + CGFloat(tickTime.timeIntervalSince(anchorNow) / 60.0) * pixelsPerMinute

                        // is full hour?
                        let tickComps = calComp.dateComponents([.minute], from: tickTime)
                        let isHour = (tickComps.minute ?? 0) == 0

                        let tickWidth: CGFloat = isHour ? rulerWidth * 0.60 : rulerWidth * 0.30
                        let tickX: CGFloat = 6

                        // tick color: if event covers that moment, show event color; else gray
                        var tickColor = Color.gray.opacity(0.7)
                        if let ev = cal.blocks.first(where: { $0.start <= tickTime && $0.end > tickTime }) {
                            tickColor = ev.color
                        }

                        var tickPath = Path()
                        tickPath.move(to: CGPoint(x: tickX, y: y))
                        tickPath.addLine(to: CGPoint(x: tickX + tickWidth, y: y))
                        context.stroke(tickPath, with: .color(tickColor), lineWidth: isHour ? 2.0 : 1.0)

                        // hour label
                        if isHour {
                            let hourFormatter = DateFormatter()
                            hourFormatter.dateFormat = "HH:mm"
                            let label = hourFormatter.string(from: tickTime)
                            let text = Text(label).font(.caption2).bold().foregroundColor(.white)
                            context.draw(text, at: CGPoint(x: tickX + tickWidth + 8, y: y - 8), anchor: .leading)
                        }

                        tickTime = tickTime.addingTimeInterval(TimeInterval(stepSeconds))
                    }

                    // gray base when no events exist (subtle)
                    if cal.blocks.isEmpty {
                        context.fill(Path(CGRect(x: 0, y: 0, width: rulerWidth, height: height)), with: .color(Color.gray.opacity(0.06)))
                    }

                    // right edge shadow
                    var edgePath = Path(CGRect(x: rulerWidth - 1, y: 0, width: 1, height: height))
                    context.fill(edgePath, with: .color(Color.black.opacity(0.07)))
                }
                .frame(width: rulerWidth)

                // clickable labels: placed in view coordinates using offsets
                ForEach(cal.blocks) { block in
                    // compute position and size
                    let sSec = block.start.timeIntervalSince(now)
                    let eSec = block.end.timeIntervalSince(now)
                    let yStart = geo.size.height * whiteLineRatio + CGFloat(sSec / 60.0) * pixelsPerMinute
                    let heightPx = max(18, CGFloat((eSec - sSec) / 60.0) * pixelsPerMinute)

                    // skip if outside view
                    if yStart + heightPx < 0 || yStart > geo.size.height {
                        EmptyView()
                    } else {
                        Button(action: {
                            selectedBlock = block
                            showPopover = true
                        }) {
                            HStack(alignment: .center, spacing: 8) {
                                // short colored tick indicator
                                Rectangle()
                                    .fill(block.color)
                                    .frame(width: 6, height: min(18, heightPx))
                                    .cornerRadius(2)

                                // title text (trimmed)
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

                // Current time white line and label (always at 30% down)
                VStack(spacing: 4) {
                    Spacer().frame(height: geo.size.height * whiteLineRatio)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: rulerWidth, height: 2)
                            .shadow(color: Color.white.opacity(0.9), radius: 2)

                        Text(shortTimeString(now))
                            .font(.caption2).bold()
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            } // ZStack
        } // GeometryReader
        .frame(width: 300) // overall width including labels; the left ruler is fixed width
        .onReceive(timer) { t in
            // update "now" frequently to keep white line in place
            self.now = t
        }
    }

    private func shortTimeString(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
}

// Simple event detail view shown in popover
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
            Button("Jump to start") {
                // Optional: implement action to center the ruler on the event start
                // you can add an action/closure to RulerView or call a published value in CalendarManager
            }
            Spacer()
        }
        .padding()
    }
}
