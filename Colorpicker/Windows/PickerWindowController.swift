//
//  PickerWindowController.swift
//  Colorpicker
//
//  Native counterpart of `src/browsers/picker.js` + `src/events/picker.js`:
//  a borderless loupe that follows the mouse, shows the pixel color under
//  the cursor, picks on left-click and cancels on right-click / Escape.
//

import AppKit
import SwiftUI

@MainActor
final class PickerWindowController: NSObject, NSWindowDelegate {
    static var current: PickerWindowController?

    /// Distance from the window's bottom-left origin to the ring center.
    private static let ringCenter = NSPoint(x: 55, y: 77)
    private static let windowSize = NSSize(width: 110, height: 132)
    private static let sampleInterval: TimeInterval = 0.025

    private let model = LoupeModel()
    private var window: PickerWindow?
    private var timer: Timer?
    private var lastSampleDate = Date.distantPast
    private var sampleTask: Task<Void, Never>?
    private var lastHex = "#000000"
    private var finished = false

    static func start() {
        guard PixelSampler.hasScreenRecordingPermission() else {
            PixelSampler.requestScreenRecordingPermission()
            let alert = NSAlert()
            alert.messageText = "Screen Recording permission required"
            alert.informativeText = """
            Colorpicker needs the Screen Recording permission to read screen pixels. \
            Enable it in System Settings → Privacy & Security → Screen Recording, \
            then launch the picker again (⌘P).
            """
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        current?.finish(pick: false)
        let controller = PickerWindowController()
        current = controller
        controller.begin()
    }

    private func begin() {
        let window = PickerWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentViewController = NSHostingController(rootView: LoupeView(model: model))
        window.onPick = { [weak self] in
            Task { @MainActor in self?.finish(pick: true) }
        }
        window.onCancel = { [weak self] in
            Task { @MainActor in self?.finish(pick: false) }
        }
        window.delegate = self
        self.window = window

        reposition(around: NSEvent.mouseLocation)
        window.makeKeyAndOrderFront(nil)
        sample(at: NSEvent.mouseLocation, force: true)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard !finished else { return }
        let mouse = NSEvent.mouseLocation
        reposition(around: mouse)
        sample(at: mouse, force: false)
    }

    private func reposition(around point: NSPoint) {
        guard let window else { return }
        let origin = NSPoint(x: point.x - Self.ringCenter.x, y: point.y - Self.ringCenter.y)
        if window.frame.origin != origin {
            window.setFrameOrigin(origin)
        }
    }

    private func sample(at point: NSPoint, force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastSampleDate) > Self.sampleInterval else { return }
        lastSampleDate = now

        let rect = PixelSampler.cgRect(forScreenPoint: point)
        sampleTask?.cancel()
        sampleTask = Task { [weak self] in
            guard let hex = await PixelSampler.sampleHex(at: rect) else {
                return
            }
            guard !Task.isCancelled else { return }
            self?.applySample(hex)
        }
    }

    private func applySample(_ hex: String) {
        guard !finished else { return }
        lastHex = hex
        model.hex = hex
        model.color = AppColor(hex: hex)
        if AppState.shared.pickerRealtime {
            AppState.shared.setColor(hex: hex, persist: false)
        }
    }

    private func finish(pick: Bool) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        timer = nil
        sampleTask?.cancel()

        if pick {
            AppState.shared.setColor(hex: lastHex, persist: true)
        }
        window?.close()
        window = nil
        Self.current = nil
        MainColorpickerWindowController.shared.show()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            // The user clicked away or switched apps: cancel, like the
            // original app cancelled on losing the picker interaction.
            self.finish(pick: false)
        }
    }
}
