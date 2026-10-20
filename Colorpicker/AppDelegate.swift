//
//  AppDelegate.swift
//  Colorpicker
//
//  Port of src/main.js: application menu with the same shortcuts and
//  window lifecycle (main window closed → quit).
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        MainColorpickerWindowController.shared.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let version = UpdateChecker.currentVersion

        // Colorpicker menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Colorpicker")
        appItem.submenu = appMenu

        let about = NSMenuItem(
            title: "About Colorpicker", action: #selector(showSettings), keyEquivalent: "a")
        about.keyEquivalentModifierMask = [.shift, .command]
        appMenu.addItem(about)
        let versionItem = NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        appMenu.addItem(versionItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Preferences", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide Colorpicker",
            action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Colorpicker",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu (role="editMenu" in the original)
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // View menu
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        let showPicker = NSMenuItem(
            title: "Show Colorpicker", action: #selector(showColorpicker), keyEquivalent: "c")
        showPicker.keyEquivalentModifierMask = [.shift, .command]
        viewMenu.addItem(showPicker)
        let showBook = NSMenuItem(
            title: "Show ColorsBook", action: #selector(showColorsbook), keyEquivalent: "b")
        showBook.keyEquivalentModifierMask = [.shift, .command]
        viewMenu.addItem(showBook)
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Save Color", action: #selector(saveColor), keyEquivalent: "s")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Copy Hex Color", action: #selector(copyHex), keyEquivalent: "w")
        let copyRGBItem = NSMenuItem(
            title: "Copy RGB(a) Color", action: #selector(copyRGB), keyEquivalent: "w")
        copyRGBItem.keyEquivalentModifierMask = [.shift, .command]
        viewMenu.addItem(copyRGBItem)
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            withTitle: "set Negative Color", action: #selector(negativeColor), keyEquivalent: "n")

        // Tools menu
        let toolsItem = NSMenuItem()
        mainMenu.addItem(toolsItem)
        let toolsMenu = NSMenu(title: "Tools")
        toolsItem.submenu = toolsMenu
        toolsMenu.addItem(
            withTitle: "Pin to Foreground", action: #selector(togglePin), keyEquivalent: "f")
        toolsMenu.addItem(.separator())
        toolsMenu.addItem(withTitle: "Pick Color", action: #selector(startPicker), keyEquivalent: "p")
        let applyItem = NSMenuItem(
            title: "Get Clipboard's Colors", action: #selector(applyClipboard), keyEquivalent: "v")
        applyItem.keyEquivalentModifierMask = [.shift, .command]
        toolsMenu.addItem(applyItem)
        toolsMenu.addItem(
            withTitle: "Toggle Shading", action: #selector(toggleShading), keyEquivalent: "t")
        toolsMenu.addItem(
            withTitle: "Set Random Color", action: #selector(randomColor), keyEquivalent: "m")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func showColorpicker() { MainColorpickerWindowController.shared.show() }
    @objc private func showColorsbook() { ColorsbookWindowController.shared.show() }
    @objc private func showSettings() { SettingsWindowController.shared.show() }
    @objc private func startPicker() { PickerWindowController.start() }
    @objc private func saveColor() { AppState.shared.saveCurrentToColorsbook() }
    @objc private func copyHex() { AppState.shared.copyHex() }
    @objc private func copyRGB() { AppState.shared.copyRGB() }
    @objc private func negativeColor() { AppState.shared.setNegativeColor() }
    @objc private func togglePin() { AppState.shared.togglePin() }
    @objc private func toggleShading() { AppState.shared.toggleShading() }
    @objc private func randomColor() { AppState.shared.setRandomColor() }
    @objc private func applyClipboard() { AppState.shared.applyFromClipboard() }
}
