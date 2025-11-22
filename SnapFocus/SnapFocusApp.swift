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
    @Environment(\.openURL) var openURL

    var body: some Scene {
        // Main window for the Agentic Scheduler
        WindowGroup("Agentic Scheduler", id: "agentic-scheduler") {
            AgenticSchedulerView()
                .environmentObject(appDelegate.calendarManager)
        }
        .handlesExternalEvents(matching: ["snapfocus://scheduler"])

        // This is a bit of a hack to remove the default "new window" command
        // that shows up when you have a WindowGroup.
        Settings {
            EmptyView().frame(width: 0, height: 0)
        }
        
        // Command menu for showing the window
        .commands {
            CommandGroup(replacing: .newItem) {
                // This replaces the "New Item" menu, effectively hiding it.
            }
            CommandMenu("Window") {
                Button("Show Agentic Scheduler") {
                    openURL(URL(string: "snapfocus://scheduler")!)
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
        }
    }
    
    func openScheduler() {
        openURL(URL(string: "snapfocus://scheduler")!)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let calendarManager = CalendarManager(calendarName: "SnapFocus")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            // First, await the setup and permission request.
            await calendarManager.start()
            
            // Now that permissions are handled, set up the UI on the main thread.
            await MainActor.run {
                // Keep your existing HUD window creation
                let ruler = RulerView(cal: calendarManager)
                window = createFloatingWindow(rootView: ruler)
                
                // Open the new scheduler window on launch
                (NSApp.delegate as? SnapFocusApp)?.openScheduler()
            }
        }
    }
}
