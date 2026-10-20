//
//  AppState.swift
//  Colorpicker
//
//  Central observable state — the Swift counterpart of storage.js +
//  events/colorpicker.js. A single shared instance so menu actions,
//  window controllers and SwiftUI views all drive the same state.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var color: AppColor {
        didSet {
            updateShadingConstraintsIfNeeded()
            syncAccentColor()
        }
    }
    /// The accent color used for the text caret and the selection
    /// highlight. It follows the current color, so AppKit has to be told
    /// when it changes.
    @Published private(set) var accentColor: NSColor = .controlAccentColor
    @Published private(set) var history: [String]
    @Published var shadingActive = false {
        didSet { updateShadingConstraintsIfNeeded() }
    }
    @Published var pinned = false {
        didSet { mainWindow?.level = pinned ? .floating : .normal }
    }
    @Published var focusMode = false

    // Settings (colorpicker section)
    @Published var tools: [String]
    /// When false the alpha slider and the alpha value field are hidden in
    /// the main window. Persisted so the choice survives a relaunch.
    @Published var showAlphaSlider: Bool {
        didSet {
            guard showAlphaSlider != oldValue else { return }
            persistSoon()
            updateMinimumHeight()
        }
    }
    /// When true a hairline is drawn under the toolbar row, separating it
    /// from the controls. Off by default.
    @Published var showToolbarSeparator: Bool {
        didSet {
            guard showToolbarSeparator != oldValue else { return }
            persistSoon()
            // The separator changes the space above the controls, so the
            // window's height floor moves with it.
            updateMinimumHeight()
        }
    }
    // Settings (picker section)
    @Published var pickerRealtime: Bool {
        didSet { persistSoon() }
    }
    // Colorsbook: ordered categories
    @Published var categories: [Category]

    struct Category: Identifiable, Equatable {
        let id: String
        var name: String { id }
        var colors: [String]

        init(name: String, colors: [String]) {
            id = name
            self.colors = colors
        }
    }

    weak var mainWindow: NSWindow?

    private var state: StoredState
    private var persistTimer: Timer?
    private var colorSaveTimer: Timer?
    /// Window size captured when shading was activated, restored on deactivation.
    private var sizeBeforeShading: NSSize?

    private init() {
        let loaded = PersistenceStore.load()
        state = loaded
        color = AppColor(hex: loaded.colorpicker.lastColor)
        history = Array(loaded.colorpicker.history.prefix(10))
        tools = loaded.colorpicker.tools
        showAlphaSlider = loaded.colorpicker.showAlphaSlider
        showToolbarSeparator = loaded.colorpicker.showToolbarSeparator
        pickerRealtime = loaded.picker.realtime
        categories = loaded.colorsbook.colors.map { Category(name: $0.key, colors: $0.value) }
        if categories.isEmpty {
            categories = StoredState.defaultColors.map { Category(name: $0.key, colors: $0.value) }
        }
        syncAccentColor()
    }

    // MARK: - Color actions (port of Colorpicker class + events)

    /// Pushes the color-derived accent into AppKit, so the text caret and
    /// the selection highlight follow the current color.
    private func syncAccentColor() {
        accentColor = color.accentNSColor
    }

    /// Port of `setNewColor(hex, dontSaveIt)`.
    func setColor(hex: String, persist: Bool = true) {
        let normalized = normalizeHex(hex)
        if normalized == color.hex && color.alpha == 1 { return }

        if persist {
            colorSaveTimer?.invalidate()
            let target = normalized
            colorSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.saveColorToHistory(target) }
            }
        }
        var newColor = AppColor(hex: normalized)
        newColor.alpha = color.alpha
        color = newColor
    }

    func setRGB(_ rgb: ColorTools.RGB, persist: Bool = true) {
        setColor(hex: ColorTools.hex(from: rgb), persist: persist)
    }

    func setAlpha(_ alpha: Double) {
        var newColor = color
        newColor.alpha = min(1, max(0, alpha))
        color = newColor
    }

    func setNegativeColor() {
        setRGB(ColorTools.negative(color.rgb))
    }

    func setRandomColor() {
        setRGB((Int.random(in: 0...255), Int.random(in: 0...255), Int.random(in: 0...255)))
    }

    // MARK: - Clipboard

    func copyHex() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(color.hex, forType: .string)
    }

    func copyRGB() {
        NSPasteboard.general.clearContents()
        let text = color.alpha < 1 ? color.cssRGBA : color.cssRGB
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyRGBA() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(color.cssRGBA, forType: .string)
    }

    /// "Get Clipboard's Colors" — parses #RGB/#RRGGBB/rgb()/rgba() from the
    /// clipboard (the original app referenced but never implemented this).
    func applyFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        if let hex = AppState.firstHexColor(in: text) {
            setColor(hex: hex)
        }
    }

    static func firstHexColor(in text: String) -> String? {
        let hexPattern = "#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range(at: 1), in: text) {
                return "#" + String(text[swiftRange]).uppercased()
            }
        }
        let rgbPattern = "rgba?\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)"
        if let regex = try? NSRegularExpression(pattern: rgbPattern) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let rRange = Range(match.range(at: 1), in: text),
               let gRange = Range(match.range(at: 2), in: text),
               let bRange = Range(match.range(at: 3), in: text) {
                let rgb = (Int(text[rRange]) ?? 0, Int(text[gRange]) ?? 0, Int(text[bRange]) ?? 0)
                return ColorTools.hex(from: rgb)
            }
        }
        return nil
    }

    // MARK: - History & colorsbook

    /// Port of `saveColor`: keep the latest 10 colors.
    private func saveColorToHistory(_ hex: String) {
        var newHistory = [hex]
        newHistory.append(contentsOf: history.filter { $0 != hex }.prefix(9))
        history = newHistory
        state.colorpicker.lastColor = hex
        state.colorpicker.history = newHistory
        persistSoon()
    }

    func saveCurrentToColorsbook() {
        guard !categories.isEmpty else { return }
        categories[categories.count - 1].colors.append(color.hex)
        persistSoon()
    }

    func deleteColor(category: String, hex: String) {
        guard let index = categories.firstIndex(where: { $0.id == category }) else { return }
        categories[index].colors.removeAll { $0 == hex }
        persistSoon()
    }

    func addColor(category: String, hex: String) {
        guard let index = categories.firstIndex(where: { $0.id == category }) else { return }
        categories[index].colors.append(normalizeHex(hex))
        persistSoon()
    }

    func addCategory(name: String) {
        guard !name.isEmpty, !categories.contains(where: { $0.id == name }) else { return }
        categories.append(Category(name: name, colors: []))
        persistSoon()
    }

    func deleteCategory(name: String) {
        categories.removeAll { $0.id == name }
        persistSoon()
    }

    // MARK: - Window integration

    func togglePin() {
        pinned.toggle()
    }

    func toggleShading() {
        shadingActive.toggle()
    }

    func toggleRandom() {
        setRandomColor()
    }

    /// Grows the window when shading is activated — and restores the exact
    /// size it had before when shading is deactivated again.
    ///
    /// On activation the window only ever GROWS to fit the header, so a window
    /// you already made taller is never forced smaller. On deactivation the
    /// height it had before the toggle is restored, so the header's space is
    /// given back. The width is never touched — it stays freely resizable.
    func updateShadingConstraintsIfNeeded() {
        guard let window = mainWindow else { return }

        // The height floor follows the content: hiding the alpha slider
        // removes a row, and the shading strip adds its own band. The
        // metrics already account for the strip, so the floor is just the
        // minimum height for the current state.
        let floor = minimumHeight

        if shadingActive {
            // Remember the height BEFORE the header appears.
            sizeBeforeShading = window.frame.size
            window.styleMask.remove(.resizable)
            let height = max(window.frame.height, floor)
            setWindowHeight(window, height)
            window.contentMinSize = NSSize(width: 440, height: height)
            window.minSize = NSSize(width: 440, height: height)
        } else {
            // Give the header's space back: restore the height from before the
            // toggle. The width stays as-is (the user may have resized it).
            let previous = sizeBeforeShading
            sizeBeforeShading = nil
            window.styleMask.insert(.resizable)
            window.contentMinSize = NSSize(width: 440, height: floor)
            window.minSize = NSSize(width: 440, height: floor)
            if let previous {
                setWindowHeight(window, max(previous.height, floor))
            }
        }
    }

    /// Re-applies the window's height floor after the content changed
    /// (e.g. the alpha slider was hidden). The window shrinks or grows to
    /// the new minimum. The metrics already include the shading strip's
    /// band when it is showing.
    func updateMinimumHeight() {
        guard let window = mainWindow else { return }
        let target = minimumHeight
        window.contentMinSize = NSSize(width: 440, height: target)
        window.minSize = NSSize(width: 440, height: target)
        // The controls have a fixed height, so any extra window height is
        // just empty space — pull the window back to a snug fit.
        setWindowHeight(window, target)
    }

    /// Sets the window's height while keeping the top edge fixed.
    private func setWindowHeight(_ window: NSWindow, _ height: CGFloat) {
        guard window.frame.height != height else { return }
        var frame = window.frame
        frame.origin.y -= height - frame.height
        frame.size.height = height
        window.setFrame(frame, display: true)
    }

    // MARK: - Persistence (debounced, like the Electron app)

    func persistSoon() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.persistNow() }
        }
    }

    func persistNow() {
        persistTimer?.invalidate()
        persistTimer = nil
        state.colorpicker.tools = tools
        state.colorpicker.showAlphaSlider = showAlphaSlider
        state.colorpicker.showToolbarSeparator = showToolbarSeparator
        state.colorpicker.lastColor = color.hex
        state.colorpicker.history = history
        state.picker.realtime = pickerRealtime
        state.colorsbook.colors = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0.colors) })
        if let window = mainWindow {
            state.colorpicker.size = .init(
                width: Int(window.frame.width), height: Int(window.frame.height))
            state.colorpicker.pos = .init(
                x: Int(window.frame.minX), y: Int(window.frame.minY))
        }
        PersistenceStore.save(state)
    }

    func updateStoredFrame() {
        persistSoon()
    }

    func resetToDefaults() {
        PersistenceStore.reset()
    }

    // MARK: - Helpers

    private func normalizeHex(_ hex: String) -> String {
        var body = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if body.count == 3 {
            body = body.map { "\($0)\($0)" }.joined()
        }
        guard body.count == 6, body.allSatisfy({ $0.isHexDigit }) else { return color.hex }
        return "#" + body.uppercased()
    }

    // MARK: - Window sizing

    /// Height of the shading strip (tints / naturals / shades).
    /// Total height the shading header adds to the window: the tint/shade
    /// strip plus the air around it.
    var shadingHeaderHeight: CGFloat {
        LayoutMetrics(
            showAlpha: showAlphaSlider,
            showSeparator: showToolbarSeparator).shadingHeaderHeight
    }

    /// Layout metrics for the current window settings.
    private var layoutMetrics: LayoutMetrics {
        LayoutMetrics(
            showAlpha: showAlphaSlider,
            showSeparator: showToolbarSeparator,
            showShading: shadingActive)
    }

    /// Smallest height the main window may take, based on the current
    /// alpha-visibility and shading settings.
    var minimumHeight: CGFloat { layoutMetrics.minimumHeight }

    var storedFrame: NSRect? {
        guard let pos = state.colorpicker.pos else {
            return NSRect(
                x: 0, y: 0,
                width: state.colorpicker.size.width,
                height: state.colorpicker.size.height)
        }
        return NSRect(
            x: pos.x, y: pos.y,
            width: state.colorpicker.size.width,
            height: state.colorpicker.size.height)
    }

}
