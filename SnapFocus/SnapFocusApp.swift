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
        WindowGroup {
            Text("SnapFocus HUD Running…")
                .frame(width: 300, height: 100)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    
    let calendarManager = CalendarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = createFloatingWindow(rootView: RulerView())

        calendarManager.requestAccess { granted in
            if granted {
                print("SnapFocus: Calendar access granted.")
                self.calendarManager.fetchEvents()   // fetch & print
            } else {
                print("SnapFocus: Calendar access denied.")
            }
        }
    }
}
