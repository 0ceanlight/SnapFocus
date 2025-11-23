//
//  HotkeyManager.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/23/25.
//

import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventMonitor: Any?
    var onTrigger: (() -> Void)?
    
    // Command + Shift + S
    // Carbon virtual key code for 'S' is 1
    // Command = cmdKey, Shift = shiftKey
    
    func startMonitoring() {
        // We use addGlobalMonitorForEvents for a simple global listen.
        // Note: This requires the app to be trusted in System Settings > Privacy > Accessibility 
        // to reliably receive global key events from other apps.
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
        
        // Also monitor local events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        // Check modifiers: Cmd + Shift
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command, .shift] && event.keyCode == 1 { // 1 is 'S'
            print("Global Hotkey Triggered!")
            DispatchQueue.main.async {
                self.onTrigger?()
            }
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

