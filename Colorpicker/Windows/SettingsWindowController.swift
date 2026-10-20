//
//  SettingsWindowController.swift
//  Colorpicker
//
//  Native counterpart of `src/browsers/settings.js`.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)

        window.title = "Preferences"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        // The content is short: the window must never shrink below the size
        // that fits everything, otherwise the detail panel starts scrolling.
        window.contentMinSize = NSSize(width: 520, height: 380)
        window.setContentSize(NSSize(width: 540, height: 400))
        window.isReleasedWhenClosed = false
        // Not fullscreenable, like the Electron version.
        window.collectionBehavior.remove(.fullScreenPrimary)

        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
