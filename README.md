# Colorpicker — Native macOS (Swift)

A native Swift/AppKit+SwiftUI rewrite of the Electron [Colorpicker](https://github.com/toinane/colorpicker) app.
No Electron, no Node, no robotjs — a single ~.app bundle of a few hundred KB.

- **Website**: <https://ikoshura.github.io/colorpicker-macos> (source in [`website/`](website), built with [Zola](https://www.getzola.org))
- **Original app by [Toinane](https://github.com/toinane)** — the native macOS port is by [ikoshura](https://github.com/ikoshura).

## Build

```bash
brew install xcodegen   # once
./build.sh              # generates Colorpicker.xcodeproj and builds
open build/Build/Products/Release/Colorpicker.app
```

Or open `Colorpicker.xcodeproj` in Xcode and hit Run.

Requires macOS 14+ to run (Xcode 15.2+ to build).

## Website

The project website lives in [`website/`](website) and is built with [Zola](https://www.getzola.org).

```bash
brew install zola        # once
cd website && zola build # output in website/public
```

It is deployed automatically to GitHub Pages by
`.github/workflows/deploy-website.yml` on every push to `main` that touches
`website/`.

## What's implemented (feature parity with the Electron app)

- **Main color window** (frameless-ish, native traffic lights, transparent title bar)
  - RGBA sliders + numeric fields + hex field (same track/thumb styling as the original CSS)
  - A copy button next to the hex field (copies the hex code; its context menu offers
    the RGB/RGBA variants)
  - Background is the current color; text/controls switch light/dark like the original
  - Window becomes see-through when alpha < 1
  - Shading header with **tints / naturals / shades** — the exact same 3×22 swatches
    as the Electron app (`ColorTools.swift` is a 1:1 port of `color.class.js`,
    validated: 264/264 generated colors identical)
  - Tools toolbar (configurable): pin to foreground, picker, colorsbook, shading,
    random, focus mode, clipboard, settings
  - Context menu with all original actions + a "Recent Colors" submenu (history)
  - Window size/position, last color and history are persisted (debounced 300 ms,
    like the original)
- **Screen picker** (`⌘P`): borderless loupe that follows the mouse, shows the pixel
  color under the cursor with a hex label, picks on click, cancels on right-click or
  `Esc`. Realtime preview into the main window (optional). Uses ScreenCaptureKit
  (`SCScreenshotManager`, macOS 15.2+) with a CoreGraphics fallback.
- **Colorsbook**: categories + colors, add/delete via popups and context menus,
  click previews in the main window, persisted.
- **Settings**: toolset selection, "hide alpha slider" toggle, optional toolbar
  separator, picker realtime toggle, colorsbook JSON export, reset to defaults,
  about + update check against the GitHub Releases API of
  [`ikoshura/colorpicker-macos`](https://github.com/ikoshura/colorpicker-macos/releases).
- **Menu bar** with the exact same shortcuts as the Electron app
  (`⇧⌘A`, `⌘,`, `⇧⌘C`, `⇧⌘B`, `⌘S`, `⌘W`, `⇧⌘W`, `⌘N`, `⌘F`, `⌘P`, `⇧⌘V`, `⌘T`, `⌘M`).
- **Data migration**: on first launch, settings/colors/history are imported
  automatically from the Electron app's
  `~/Library/Application Support/colorpicker/storage/colorpicker.json`.

## Deliberate differences

- **Native window controls.** The Windows/Linux "fake buttons" option is gone —
  a native macOS app uses real traffic lights. The Electron app's "colorfull app"
  setting (which tinted those buttons with complementary colors) was removed too.
- **Focus mode** keeps only the color and the focus-mode button (same as original).
- **"Get Clipboard's Colors"** is actually implemented (in the Electron repo the
  handler was referenced but never defined); it parses `#RGB`, `#RRGGBB`, `rgb()`
  and `rgba()` from the clipboard.
- **Touch Bar support** from the Electron version is not ported.
- The macOS 14 fallback for pixel sampling uses the deprecated
  `CGWindowListCreateImage`; on macOS 15.2+ ScreenCaptureKit is used.
- The first time you use the picker you'll be asked for the **Screen Recording**
  permission (System Settings → Privacy & Security → Screen Recording), exactly
  like the Electron version needed it for robotjs.

## Layout

```
native-macos/
├── project.yml                  # XcodeGen project definition
├── build.sh                     # generate + build
└── Colorpicker/
    ├── main.swift               # AppKit entry point
    ├── AppDelegate.swift        # menu + lifecycle (ex-src/main.js)
    ├── Models/
    │   ├── ColorTools.swift     # ex-src/views/js/color.class.js
    │   ├── AppColor.swift
    │   └── StoredState.swift    # ex-src/storage.js (+ Electron migration)
    ├── State/
    │   └── AppState.swift       # ex-src/events/colorpicker.js
    ├── Windows/                 # ex-src/browsers/*.js + events/picker.js
    │   ├── MainColorpickerWindowController.swift
    │   ├── ColorsbookWindowController.swift
    │   ├── SettingsWindowController.swift
    │   ├── PickerWindowController.swift
    │   ├── PickerLoupe.swift
    │   └── PixelSampler.swift
    ├── Views/                   # ex-src/views/*.html + js
    │   ├── ColorpickerView.swift
    │   ├── ColorsbookView.swift
    │   ├── SettingsView.swift
    │   └── Components.swift
    └── Update/
        └── UpdateChecker.swift  # ex-src/checkUpdate.js
```
