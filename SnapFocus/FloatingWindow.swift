//
//  FloatingWindow.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import Cocoa
import SwiftUI

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

func createFloatingWindow<Content: View>(rootView: Content) -> NSWindow {
    let hosting = NSHostingController(rootView: rootView)
    let window = FloatingWindow(
        contentRect: NSRect(x: 0, y: 0, width: 40, height: NSScreen.main?.frame.height ?? 600),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )

    window.contentView = hosting.view

    // Always on top
    window.level = .screenSaver    // stronger than .floating

    // Transparent background
    window.isOpaque = false
    window.backgroundColor = .clear

    // Allow interaction but no title bar
    window.ignoresMouseEvents = false
    window.collectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary  // stays visible in fullscreen apps
    ]

    window.isMovable = false
    window.makeKeyAndOrderFront(nil)

    return window
}

