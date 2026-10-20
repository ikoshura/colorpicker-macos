//
//  MainColorpickerWindowController.swift
//  Colorpicker
//
//  Native counterpart of `src/browsers/colorpicker.js`.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class MainColorpickerWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainColorpickerWindowController()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let state = AppState.shared
        var frame = NSRect(x: 0, y: 0, width: 440, height: 150)
        if let stored = state.storedFrame {
            frame.size = stored.size
            let onScreen = NSScreen.screens.contains {
                NSMouseInRect(stored.origin, $0.frame, false)
            }
            if onScreen {
                frame.origin = stored.origin
            } else if let screen = NSScreen.main {
                // Fall back to a sensible on-screen origin.
                frame.origin = NSPoint(
                    x: screen.frame.midX - frame.width / 2,
                    y: screen.frame.midY - frame.height / 2)
            }
        }

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)

        window.title = "Colorpicker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentMinSize = NSSize(width: 440, height: 150)
        // Frame-based minimum as well: this one is enforced by AppKit during
        // interactive resizing no matter what the content view does.
        window.minSize = NSSize(width: 440, height: 150)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        state.mainWindow = window
        // NOTE: keep the hosting controller's default sizingOptions — disabling
        // preferred-size propagation stops SwiftUI from re-laying out smoothly
        // during window resizes (visible as toolbar flicker). The end-of-
        // animation snap is instead prevented by animating the content's
        // idealHeight together with the window frame (see ColorpickerView).
        window.contentViewController = NSHostingController(rootView: ColorpickerView())

        observeForTrafficLights()
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
        AppState.shared.updateShadingConstraintsIfNeeded()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        // Same behaviour as the Electron app: closing the main window quits.
        Task { @MainActor in
            NSApp.terminate(nil)
        }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in AppState.shared.updateStoredFrame() }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in AppState.shared.updateStoredFrame() }
    }

    /// Hard clamp consulted by AppKit on *every* resize (interactive drags
    /// included): the window can never go below the current content minimum.
    nonisolated func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        // AppKit delegate callbacks always run on the main thread.
        MainActor.assumeIsolated {
            let floor: CGFloat = AppState.shared.shadingActive ? 220 : 150
            return NSSize(
                width: max(frameSize.width, 440),
                height: max(frameSize.height, floor))
        }
    }

    // MARK: - "colorfull app" traffic lights

    private func observeForTrafficLights() {
        AppState.shared.$color
            .combineLatest(AppState.shared.$colorfullApp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] color, colorfull in
                self?.tintTrafficLights(color: color, colorfull: colorfull)
            }
            .store(in: &cancellables)
    }

    private func tintTrafficLights(color: AppColor, colorfull: Bool) {
        guard let window else { return }
        let delta = color.isDark ? 20 : -20
        let targets: [(NSWindow.ButtonType, (ColorTools.RGB) -> ColorTools.RGB)] = [
            (.closeButton, ColorTools.redComplementary),
            (.miniaturizeButton, ColorTools.greenComplementary),
            (.zoomButton, ColorTools.blueComplementary),
        ]
        for (type, transform) in targets {
            guard let button = window.standardWindowButton(type) else { continue }
            if colorfull {
                let rgb = ColorTools.lightness(delta, from: transform(color.rgb))
                button.contentTintColor = NSColor(
                    srgbRed: CGFloat(rgb.r) / 255,
                    green: CGFloat(rgb.g) / 255,
                    blue: CGFloat(rgb.b) / 255,
                    alpha: 1)
            } else {
                button.contentTintColor = nil
            }
        }
    }
}
