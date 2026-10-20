//
//  ColorsbookWindowController.swift
//  Colorpicker
//
//  Native counterpart of `src/browsers/colorsbook.js`.
//

import AppKit
import SwiftUI

@MainActor
final class ColorsbookWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ColorsbookWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 365, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)

        window.title = "Colorsbook"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 360, height: 285)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: ColorsbookView())
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
