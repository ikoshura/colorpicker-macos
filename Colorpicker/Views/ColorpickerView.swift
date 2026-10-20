//
//  ColorpickerView.swift
//  Colorpicker
//
//  Native counterpart of views/colorpicker.html + colorpicker.class.js +
//  colorpicker.events.js.
//

import AppKit
import SwiftUI

struct ColorpickerView: View {
    @ObservedObject private var state = AppState.shared

    @State private var hexText = ""
    @State private var redText = "0"
    @State private var greenText = "0"
    @State private var blueText = "0"
    @State private var alphaText = "1.00"
    /// Flashes a checkmark for a moment after a successful copy.
    @State private var didCopy = false

    @FocusState private var focusedField: Field?
    enum Field: Hashable { case hex, red, green, blue, alpha }

    private var fg: Color { state.color.foreground }

    /// Layout metrics for the current alpha-visibility setting.
    private var metrics: LayoutMetrics {
        LayoutMetrics(
            showAlpha: state.showAlphaSlider,
            showSeparator: state.showToolbarSeparator)
    }

    var body: some View {
        ZStack(alignment: .top) {
            state.color.swiftUIColor
                .ignoresSafeArea()
                // Honor the window's rounded corners even while the frame is
                // being animated, so the fill never bleeds square past the mask.
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                // Clicking anywhere on the background drops the text cursor,
                // so the focused field can always be dismissed. The controls
                // sit above this layer and keep their own hit-testing.
                .onTapGesture { dismissFieldFocus() }

            if state.focusMode {
                // Focus mode hides everything but the color itself.
                Color.clear
            } else {
                VStack(spacing: 0) {
                    // No animation anywhere: the header is either here
                    // at full height or not here at all, like the
                    // original Electron app.
                    if state.shadingActive {
                        shadingHeader
                            .frame(height: 64)
                    }
                    Spacer(minLength: 0)
                    mainRow
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.bottom, metrics.bottomPadding)
                    // Any extra window height is shared above and below the
                    // controls so they stay near the toolbar.
                    Spacer(minLength: 0)
                }
                // Starts below the toolbar row, which sits one layer above
                // as a ZStack sibling — always inline with the traffic lights.
                .padding(.top, metrics.topPadding)
            }

            toolsRow

            // An optional hairline that separates the toolbar band from
            // the controls.
            if state.showToolbarSeparator {
                toolbarSeparator
            }
        }
        // Exact fit — the window sizes itself to the content:
        //   toolbar row + (optional) shading header + controls + padding.
        // Toggles are instant (no animation). The window only ever GROWS to
        // fit the header; it never shrinks. While shaded its height is
        // locked; the width stays freely resizable at all times.
        .frame(minWidth: 440, minHeight: metrics.minimumHeight)
        // The caret and the selection highlight follow the current color.
        .tint(state.color.accent)
        // The titlebar is transparent + full-size content: position everything
        // from the real window top so the tools row can sit inline with the
        // system traffic lights.
        .ignoresSafeArea()
        .onAppear { syncTexts(from: state.color) }
        .onChange(of: state.color) { _, newColor in
            if let focusedField {
                syncUnfocusedFields(from: newColor, excluding: focusedField)
            } else {
                syncTexts(from: newColor)
            }
        }
        .contextMenu { contextMenu }
        // Escape also leaves the focused field.
        .onExitCommand { dismissFieldFocus() }
    }

    /// Removes the text cursor from whichever field has it and re-syncs
    /// every field with the current color, so a half-typed value is
    /// resolved instead of being left dangling.
    private func dismissFieldFocus() {
        guard focusedField != nil else { return }
        focusedField = nil
        syncTexts(from: state.color)
    }

    // MARK: - Field syncing & parsing (port of the oninput handlers)

    private func syncTexts(from color: AppColor) {
        hexText = color.hex
        redText = String(color.red)
        greenText = String(color.green)
        blueText = String(color.blue)
        alphaText = String(format: "%.2f", color.alpha)
    }

    private func syncUnfocusedFields(from color: AppColor, excluding field: Field) {
        if field != .hex { hexText = color.hex }
        if field != .red { redText = String(color.red) }
        if field != .green { greenText = String(color.green) }
        if field != .blue { blueText = String(color.blue) }
        if field != .alpha { alphaText = String(format: "%.2f", color.alpha) }
    }

    private func parseChannel(_ text: String, channel: Int) {
        guard let value = Int(text), (0...255).contains(value) else { return }
        var rgb = state.color.rgb
        switch channel {
        case 0: rgb.r = value
        case 1: rgb.g = value
        default: rgb.b = value
        }
        state.setRGB(rgb)
    }

    private func parseHex(_ text: String) {
        let body = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard body.count == 6, body.allSatisfy({ $0.isHexDigit }) else { return }
        state.setColor(hex: "#" + body)
    }

    private func parseAlpha(_ text: String) {
        if text == "0." || text == "1." { return }
        guard let value = Double(text) else { return }
        state.setAlpha(min(1, max(0, value)))
    }

    private func adjustAllChannels(by delta: Int) {
        func clamp(_ value: Int) -> Int { min(255, max(0, value + delta)) }
        let rgb = state.color.rgb
        state.setRGB((clamp(rgb.r), clamp(rgb.g), clamp(rgb.b)))
    }

    // MARK: - Bindings

    private func channelBinding(_ channel: Int) -> Binding<Double> {
        Binding(
            get: {
                Double([state.color.red, state.color.green, state.color.blue][channel])
            },
            set: { newValue in
                let value = Int(newValue.rounded())
                var rgb = state.color.rgb
                switch channel {
                case 0: rgb.r = value
                case 1: rgb.g = value
                default: rgb.b = value
                }
                state.setRGB(rgb)
            })
    }

    private var alphaBinding: Binding<Double> {
        Binding(
            get: { state.color.alpha * 255 },
            set: { state.setAlpha($0 / 255) })
    }

    /// The hairline drawn under the toolbar row. It uses the same
    /// color-derived foreground as the rest of the UI, so it stays
    /// consistent in both light and dark mode.
    private var toolbarSeparator: some View {
        Rectangle()
            .fill(fg.opacity(0.18))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .offset(y: metrics.toolbarHeight)
            .allowsHitTesting(false)
    }

    // MARK: - Main row (sliders + fields + hex)

    /// OG-style single row: wide, flexible sliders, then the number fields,
    /// then the hex field inline on the last row — no dead space on the right.
    private var mainRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                ColorChannelSlider(
                    value: channelBinding(0),
                    fill: Color(nsColor: NSColor(srgbRed: 1.0, green: 87 / 255, blue: 57 / 255, alpha: 1)),
                    track: state.color.sliderTrack,
                    thumb: state.color.thumbFill,
                    thumbSize: metrics.thumbSize,
                    trackHeight: metrics.trackHeight)
                ColorChannelSlider(
                    value: channelBinding(1),
                    fill: Color(nsColor: NSColor(srgbRed: 105 / 255, green: 195 / 255, blue: 59 / 255, alpha: 1)),
                    track: state.color.sliderTrack,
                    thumb: state.color.thumbFill,
                    thumbSize: metrics.thumbSize,
                    trackHeight: metrics.trackHeight)
                ColorChannelSlider(
                    value: channelBinding(2),
                    fill: Color(nsColor: NSColor(srgbRed: 65 / 255, green: 165 / 255, blue: 225 / 255, alpha: 1)),
                    track: state.color.sliderTrack,
                    thumb: state.color.thumbFill,
                    thumbSize: metrics.thumbSize,
                    trackHeight: metrics.trackHeight)
                if state.showAlphaSlider {
                    ColorChannelSlider(
                        value: alphaBinding,
                        fill: state.color.alphaTrack,
                        track: state.color.sliderTrack,
                        thumb: state.color.thumbFill,
                        thumbSize: metrics.thumbSize,
                        trackHeight: metrics.trackHeight)
                }
            }
            // Sliders take whatever room is left, like the original.
            .frame(maxWidth: .infinity)

            // A clear gap separates the sliders from the value fields.
            .padding(.trailing, metrics.sliderFieldSpacing)

            VStack(alignment: .trailing, spacing: metrics.rowSpacing) {
                styledField($redText, field: .red, width: metrics.fieldWidth, fontSize: metrics.fieldFontSize)
                    .onChange(of: redText) { _, value in
                        let filtered = String(value.filter { $0.isNumber }.prefix(3))
                        if filtered != value { redText = filtered }
                        parseChannel(filtered, channel: 0)
                    }
                styledField($greenText, field: .green, width: metrics.fieldWidth, fontSize: metrics.fieldFontSize)
                    .onChange(of: greenText) { _, value in
                        let filtered = String(value.filter { $0.isNumber }.prefix(3))
                        if filtered != value { greenText = filtered }
                        parseChannel(filtered, channel: 1)
                    }
                styledField($blueText, field: .blue, width: metrics.fieldWidth, fontSize: metrics.fieldFontSize)
                    .onChange(of: blueText) { _, value in
                        let filtered = String(value.filter { $0.isNumber }.prefix(3))
                        if filtered != value { blueText = filtered }
                        parseChannel(filtered, channel: 2)
                    }
                if state.showAlphaSlider {
                    styledField($alphaText, field: .alpha, width: metrics.fieldWidth, fontSize: metrics.fieldFontSize)
                        .onChange(of: alphaText) { _, value in
                            parseAlpha(value)
                        }
                        .onSubmit {
                            focusedField = nil
                            alphaText = String(format: "%.2f", state.color.alpha)
                        }
                }
            }

            hexField
                .padding(.leading, metrics.fieldHexSpacing)
        }
    }

    /// Hex entry and the copy action share one capsule: the field takes
    /// most of the width, the copy button sits in the right-hand end
    /// separated by a hairline divider.
    private var hexField: some View {
        HStack(spacing: 0) {
            TextField("", text: $hexText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: metrics.hexFontSize, weight: .semibold))
                .foregroundStyle(fg)
                .focused($focusedField, equals: .hex)
                .frame(maxWidth: .infinity)
                .onChange(of: hexText) { _, value in
                    let body = value.filter { $0 != "#" }
                    let filtered = "#" + String(body.uppercased().prefix(6))
                    if filtered != value { hexText = filtered }
                    parseHex(filtered)
                }
                .onSubmit { focusedField = nil }
                .onKeyPress(.upArrow) {
                    adjustAllChannels(by: 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    adjustAllChannels(by: -1)
                    return .handled
                }

            Rectangle()
                .fill(fg.opacity(0.25))
                .frame(width: 1, height: 12)

            Button {
                state.copyHex()
                flashCopied()
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 22, height: metrics.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy hex code")
        }
        .frame(width: metrics.hexWidth, height: metrics.rowHeight)
        .background(
            Capsule().fill(state.color.fieldFill))
        .contextMenu { copyMenu }
    }

    /// Copy actions shared by the copy button and the hex field.
    private var copyMenu: some View {
        Group {
            Button("Copy Hex Code") {
                state.copyHex()
                flashCopied()
            }
            Button("Copy RGB Code") { state.copyRGB() }
            Button("Copy RGBA Code") { state.copyRGBA() }
        }
    }

    /// Briefly swaps the copy icon for a checkmark.
    private func flashCopied() {
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopy = false
        }
    }

    private func styledField(
        _ text: Binding<String>, field: Field, width: CGFloat,
        fontSize: CGFloat? = nil
    ) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            // Same weight as the hex field so every number reads the same.
            .font(.system(size: fontSize ?? metrics.fieldFontSize, weight: .semibold))
            .foregroundStyle(fg)
            .focused($focusedField, equals: field)
            .frame(width: width, height: metrics.rowHeight)
            .background(
                Capsule().fill(state.color.fieldFill))
    }

    // MARK: - Shading header (tints / naturals / shades)

    private var shadingHeader: some View {
        let sets = ColorTools.shading(forHex: state.color.hex)
        return HStack(spacing: 0) {
            shadingStrip(sets.tints)
            shadingStrip(sets.naturals)
            shadingStrip(sets.shades)
        }
        // Height is driven by the caller so it can animate.
    }

    private func shadingStrip(_ hexes: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(hexes.enumerated()), id: \.offset) { _, hex in
                Color(hex: hex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { state.setColor(hex: hex) }
            }
        }
    }

    // MARK: - Tools

    // The toolbar row: traffic lights are drawn by the system to its
    // left, so this row is always inline with them.
    private var toolsRow: some View {
        let visibleTools = (state.focusMode ? ["clean"] : state.tools)
            .compactMap { ToolItem.named($0) }
        return HStack(spacing: 2) {
            ForEach(visibleTools) { tool in
                ToolButton(tool: tool, isActive: isToolActive(tool)) {
                    runTool(tool)
                }
                .foregroundStyle(fg.opacity(0.85))
            }
        }
        // 26pt buttons starting 6pt from the top centers them at ~19pt,
        // which lines up with the traffic lights. Without the alpha slider
        // the band is a touch shorter, so the buttons start 2pt higher.
        .padding(.top, metrics.showAlpha ? 6 : 4)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

    private func isToolActive(_ tool: ToolItem) -> Bool {
        switch tool.id {
        case "top": return state.pinned
        case "shade": return state.shadingActive
        case "clean": return state.focusMode
        default: return false
        }
    }

    private func runTool(_ tool: ToolItem) {
        switch tool.id {
        case "top": state.togglePin()
        case "picker": PickerWindowController.start()
        case "tags": ColorsbookWindowController.shared.show()
        case "shade": state.toggleShading()
        case "random": state.setRandomColor()
        case "clean": state.focusMode.toggle()
        case "apply": state.applyFromClipboard()
        case "settings": SettingsWindowController.shared.show()
        default: break
        }
    }

    // MARK: - Context menu (port of the colorpickerMenu)

    @ViewBuilder
    private var contextMenu: some View {
        Button("Pin to Foreground") { state.togglePin() }
        Divider()
        Button("Save Color") { state.saveCurrentToColorsbook() }
        Button("Copy Hex Code") { state.copyHex() }
        Button("Copy RGB Code") { state.copyRGB() }
        Button("Copy RGBA Code") { state.copyRGBA() }
        Divider()
        Button("Pick Color") { PickerWindowController.start() }
        Button("Toggle Shading") { state.toggleShading() }
        Divider()
        Button("Set Random Color") { state.setRandomColor() }
        Button("set Negative Color") { state.setNegativeColor() }
        Divider()
        if !state.history.isEmpty {
            Menu("Recent Colors") {
                ForEach(state.history, id: \.self) { hex in
                    Button(hex) { state.setColor(hex: hex) }
                }
            }
        }
        Divider()
        Button("Preferences…") { SettingsWindowController.shared.show() }
            .keyboardShortcut(",", modifiers: .command)
    }


}
