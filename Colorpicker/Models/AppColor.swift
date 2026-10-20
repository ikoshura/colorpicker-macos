//
//  AppColor.swift
//  Colorpicker
//

import AppKit
import SwiftUI

/// A color with an alpha channel, in the same spirit as the JS `Color` class.
struct AppColor: Equatable {
    var red: Int
    var green: Int
    var blue: Int
    var alpha: Double = 1.0

    init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
        self.red = min(255, max(0, red))
        self.green = min(255, max(0, green))
        self.blue = min(255, max(0, blue))
        self.alpha = min(1, max(0, alpha))
    }

    init(hex: String) {
        let rgb = ColorTools.rgb(fromHex: hex)
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    var rgb: ColorTools.RGB { (red, green, blue) }
    var hex: String { ColorTools.hex(from: rgb) }
    var isDark: Bool { ColorTools.isDark(rgb) }

    /// CSS-style `rgb(r, g, b)` string, like `getCSSFromRGB`.
    var cssRGB: String { "rgb(\(red), \(green), \(blue))" }

    /// CSS-style `rgba(r, g, b, a.a)` string, like `getCSSFromRGBA`.
    var cssRGBA: String { "rgba(\(red), \(green), \(blue), \(String(format: "%.2f", alpha)))" }

    var nsColor: NSColor { NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha)) }
    var swiftUIColor: Color { Color(nsColor: nsColor) }

    var foreground: Color { isDark ? .white : .black }
}
