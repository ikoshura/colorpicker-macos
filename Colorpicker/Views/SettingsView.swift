//
//  SettingsView.swift
//  Colorpicker
//
//  Native counterpart of views/settings.html + js/settings.js.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var state = AppState.shared

    enum Tab: String, CaseIterable, Identifiable {
        case general, colorpicker, picker, colorsbook, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .colorpicker: return "Colorpicker"
            case .picker: return "Picker"
            case .colorsbook: return "Colorsbook"
            case .about: return "About"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .colorpicker: return "paintpalette"
            case .picker: return "eyedropper"
            case .colorsbook: return "book"
            case .about: return "info.circle"
            }
        }
    }

    @State private var tab: Tab = .general

    var body: some View {
        HStack(spacing: 0) {
            tabBar
            Divider()
            panel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
        }
        .frame(minWidth: 460, minHeight: 340)
    }

    private var tabBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                        Text(item.title)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tab == item ? Color.accentColor.opacity(0.2) : .clear))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: 160)
        .padding(10)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private var panel: some View {
        switch tab {
        case .general: generalPanel
        case .colorpicker: colorpickerPanel
        case .picker: pickerPanel
        case .colorsbook: colorsbookPanel
        case .about: aboutPanel
        }
    }

    // MARK: - General

    private var generalPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Colorpicker Tools").font(.headline)
                Text("Choose the tools shown in the toolbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(ToolItem.all) { tool in
                    Toggle(isOn: toolBinding(tool.id)) {
                        Label(tool.title, systemImage: tool.icon)
                    }
                }
                Divider()
                Text("Preferences").font(.headline)
                Button("Reset Colorpicker") { resetPreferences() }
                    .foregroundStyle(.red)
            }
        }
    }

    private func toolBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { state.tools.contains(id) },
            set: { enabled in
                if enabled {
                    if !state.tools.contains(id) {
                        let order = ToolItem.all.map(\.id)
                        state.tools = (state.tools + [id]).sorted {
                            (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0)
                        }
                    }
                } else {
                    state.tools.removeAll { $0 == id }
                }
                state.persistSoon()
            })
    }

    private func resetPreferences() {
        let alert = NSAlert()
        alert.messageText = "Are you sure to reset your preferences?"
        alert.informativeText = "It will remove ALL your colors!"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Oh no!")
        alert.addButton(withTitle: "Reset it!")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            state.resetToDefaults()
            relaunchApp()
        }
    }

    private func relaunchApp() {
        let configuration = Process()
        configuration.launchPath = "/usr/bin/open"
        configuration.arguments = ["-n", Bundle.main.bundlePath]
        try? configuration.run()
        NSApp.terminate(nil)
    }

    // MARK: - Colorpicker

    private var colorpickerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appearance").font(.headline)
            Toggle("Show complementary colors in OSX Icons", isOn: $state.colorfullApp)
            Text("""
            Tints the close, minimize and zoom buttons with colors \
            complementary to the current color.
            """)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Picker

    private var pickerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Options").font(.headline)
            Toggle("Show color in realtime", isOn: $state.pickerRealtime)
            Text("While picking, the main window previews the color under the cursor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Colorsbook

    private var colorsbookPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Colorsbook").font(.headline)
            Text("Export your colors as JSON.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Export…") { exportColorsbook() }
            Spacer()
        }
    }

    private func exportColorsbook() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "colorsbook.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            let colors = Dictionary(
                uniqueKeysWithValues: state.categories.map { ($0.id, $0.colors) })
            if let data = try? JSONSerialization.data(
                withJSONObject: colors, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - About

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Update").font(.headline)
            HStack(spacing: 8) {
                if updateState == nil {
                    ProgressView().controlSize(.small)
                    Text("Fetching..").foregroundStyle(.secondary)
                } else if let state = updateState, state.hasUpdate {
                    Image(systemName: "exclamationtriangle").foregroundStyle(.orange)
                    Text("New update available (\(state.latest))")
                    Button("Show Update") {
                        NSWorkspace.shared.open(URL(
                            string: "https://github.com/Toinane/colorpicker/releases")!)
                    }
                } else {
                    Image(systemName: "checkmark.circle").foregroundStyle(.green)
                    Text("You're up to date!")
                }
            }
            .font(.system(size: 13))

            Divider()

            Text("About").font(.headline)
            Text("Colorpicker - version \(UpdateChecker.currentVersion)")
            Text("-")
            HStack(spacing: 4) {
                Text("Colorpicker is developed by Toinane with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            Button("Website") {
                NSWorkspace.shared.open(URL(string: "https://colorpicker.fr")!)
            }
            Spacer()
        }
        .task {
            updateState = await UpdateChecker.check()
        }
    }

    @State private var updateState: UpdateChecker.Result?

}
