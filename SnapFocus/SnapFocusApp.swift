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
        Settings {
            PreferencesView()
        }
    }
}

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var rulerWindow: NSWindow?
    var voiceOverlayWindow: NSWindow?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow? // Keep a reference
    
    let calendarManager = CalendarManager(calendarName: "SnapFocus")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Menu Bar
        setupMenuBar()
        
        // Setup Hotkey
        HotkeyManager.shared.onTrigger = { [weak self] in
            self?.toggleVoiceOverlay()
        }
        HotkeyManager.shared.startMonitoring()
        
        // Attempt to load API Key from file (if present)
        loadAPIKeyFromFile()
        
        Task {
            // Start Calendar Manager
            await calendarManager.start()
            
            await MainActor.run {
                // Create Ruler HUD (Always visible)
                let ruler = RulerView(cal: calendarManager)
                rulerWindow = createFloatingWindow(rootView: ruler)
            }
        }
    }
    
    private func loadAPIKeyFromFile() {
        // Check if GeminiKey.txt exists in the bundle
        if let fileURL = Bundle.main.url(forResource: "GeminiKey", withExtension: "txt") {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let key = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    // Save to UserDefaults so AppStorage picks it up
                    UserDefaults.standard.set(key, forKey: "gemini_api_key")
                    print("Loaded Gemini API Key from file.")
                }
            } catch {
                print("Failed to load Gemini API Key from file: \(error)")
            }
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "SnapFocus")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Agentic Scheduler", action: #selector(toggleVoiceOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SnapFocus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openPreferences() {
        // Manually create the settings window since standard "Settings" scene
        // can be tricky to activate from a background (LSUIElement) app
        
        if settingsWindow == nil {
            let settingsView = PreferencesView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Preferences"
            window.contentView = NSHostingView(rootView: settingsView)
            window.isReleasedWhenClosed = false // Keep the window instance alive
            settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func toggleVoiceOverlay() {
        if let window = voiceOverlayWindow, window.isVisible {
            closeVoiceOverlay()
        } else {
            showVoiceOverlay()
        }
    }
    
    func showVoiceOverlay() {
        // Create if needed
        if voiceOverlayWindow == nil {
            let overlayView = VoiceOverlayView(onClose: { [weak self] in
                self?.closeVoiceOverlay()
            })
            .environmentObject(calendarManager) // Pass manager
            
            // Create a centered floating window
            // IMPORTANT: Use NSPanel or override canBecomeKey to allow keyboard input in borderless window
            let window = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.center()
            window.contentView = NSHostingView(rootView: overlayView)
            
            voiceOverlayWindow = window
        }
        
        voiceOverlayWindow?.center()
        voiceOverlayWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeVoiceOverlay() {
        voiceOverlayWindow?.orderOut(nil)
        voiceOverlayWindow = nil // Destroy it to reset state? Or keep it? 
        // Destroying ensures fresh state next time (like "Listening..." prompt)
    }

    // MARK: - URL Handling
    func application(_ app: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        print("Received URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }

        switch host {
        case "rectangle":
            handleRectangleAction(from: components)
        case "execute-action":
            handleExecuteAction(from: components)
        default:
            print("Unknown URL host: \(host)")
        }
    }

    private func handleRectangleAction(from components: URLComponents) {
        guard let actionQueryItem = components.queryItems?.first(where: { $0.name == "action" }),
              let actionName = actionQueryItem.value else {
            print("Missing 'action' parameter for rectangle host")
            return
        }
        
        guard let action = RectangleManager.Action(rawValue: actionName) else {
            print("Unknown rectangle action: \(actionName)")
            return
        }
        
        print("Executing Rectangle action: \(action)")
        RectangleManager.execute(action)
    }

    private func handleExecuteAction(from components: URLComponents) {
        guard let nameQueryItem = components.queryItems?.first(where: { $0.name == "name" }),
              let actionName = nameQueryItem.value else {
            print("Missing 'name' parameter for execute-action host")
            return
        }

        switch actionName {
        case "toggle-scheduler": // Toggles the visibility of the Voice Overlay (aka 'Agentic Scheduler')
            toggleVoiceOverlay()
            print("Toggling Voice Overlay via URL.")
        case "less-time": // Nudges the current task by -5 minutes (shorten)
            Task { @MainActor in
                calendarManager.nudgeCurrentTask(byMinutes: -5)
                print("Nudged current task by -5 minutes via URL.")
            }
        case "more-time": // Nudges the current task by +5 minutes (extend)
            Task { @MainActor in
                calendarManager.nudgeCurrentTask(byMinutes: 5)
                print("Nudged current task by +5 minutes via URL.")
            }
        default:
            print("Unknown execute-action name: \(actionName)")
        }
    }
}
