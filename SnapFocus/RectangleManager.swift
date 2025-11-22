//
//  RectangleManager.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Cocoa

/// A helper to control the Rectangle window management app via Swift.
/// Requires Rectangle to be installed and running.
enum RectangleManager {
    
    enum Action: String {
        case leftHalf = "left-half"
        case rightHalf = "right-half"
        case topHalf = "top-half"
        case bottomHalf = "bottom-half"
        case maximize = "maximize"
        case center = "center"
        case restore = "restore"
        case nextDisplay = "next-display"
        case previousDisplay = "previous-display"
        // Add others supported by Rectangle as needed
    }
    
    /// Executes a window layout command using Rectangle
    static func execute(_ action: Action) {
        guard let url = URL(string: "rectangle://execute-action?name=\(action.rawValue)") else {
            print("Invalid Rectangle URL")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    /// Chains multiple actions (e.g., move to next display then maximize)
    static func executeSequence(_ actions: [Action], delay: TimeInterval = 0.1) {
        Task { @MainActor in
            for action in actions {
                execute(action)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}

// MARK: - Example Usage

/*
// 1. Snap current window to the left half
RectangleManager.execute(.leftHalf)

// 2. Snap current window to the right half
RectangleManager.execute(.rightHalf)

// 3. Move to next monitor and maximize
RectangleManager.executeSequence([.nextDisplay, .maximize])
*/

