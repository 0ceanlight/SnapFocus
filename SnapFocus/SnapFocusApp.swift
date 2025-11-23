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
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "SnapFocus")
        }
        
        let menu = NSMenu()
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
    
    func toggleVoiceOverlay() {
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
}
