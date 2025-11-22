//
//  SnapFocusApp.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import SwiftUI

@main
struct SnapFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() } // or any other small window
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let calendarManager = CalendarManager(calendarName: "SnapFocus")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep your existing HUD window creation; replace rootView with RulerView
        let ruler = RulerView(cal: calendarManager)
        window = createFloatingWindow(rootView: ruler)
        // calendarManager.start() is already called in its init; if you prefer explicit:
        // calendarManager.start()
    }
}
