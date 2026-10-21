# Colorpicker for macOS

<img src="https://github.com/user-attachments/assets/69456df7-fc1c-4bbe-a745-fab9e63884e5" width="400" alt="Colorpicker screenshot" />

A small, native macOS color picker. It's a Swift rewrite of the Electron app [Colorpicker](https://github.com/toinane/colorpicker) by [Toinane](https://github.com/toinane), with no Electron or Node, just a tiny `.app`.

Website: <https://ikoshura.github.io/colorpicker-macos>

## Features

- **Tiny:** only 618 KB, compared to 96.6 MB for the original [Toinane/colorpicker](https://github.com/toinane/colorpicker)
- Pick any color on screen with `⌘P`
- Adjust color with RGBA sliders, number fields, or a hex field
- Copy as hex, RGB, or RGBA
- Tints, naturals, and shades of the current color
- Colorsbook to save colors in categories
- Color history, window position, and settings are remembered
- Pin the window on top, focus mode, random color, read colors from the clipboard
- Imports your data from the Electron version on first launch

## Requirements

- macOS 14 or later
- Xcode 15.2 or later (to build)

## Install / Build

```bash
brew install xcodegen   # once
./build.sh
open build/Build/Products/Release/Colorpicker.app
```

You can also open `Colorpicker.xcodeproj` in Xcode and press Run.

On first use, the picker asks for **Screen Recording** permission. Enable it in System Settings → Privacy & Security → Screen Recording.

## Differences from the Electron version

- Uses native macOS window controls
- "Get Clipboard's Colors" now works (it was never finished in the original)
- Touch Bar support isn't included

## Website

The site lives in [`website/`](website) and is built with [Zola](https://www.getzola.org):

```bash
brew install zola
cd website && zola build
```

It deploys to GitHub Pages automatically when `website/` changes on `main`.

## Credits

Original app by [Toinane](https://github.com/toinane). macOS port by [ikoshura](https://github.com/ikoshura).
