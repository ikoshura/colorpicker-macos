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

    // MARK: - Tinted foregrounds

    /// Text and symbols are never pure black or pure white: they are tinted
    /// towards the current color so the controls sit in the same palette as
    /// the background instead of punching a hole in it. The result is a
    /// gentler, lower-contrast read on both light and dark colors.
    var foreground: Color {
        isDark
            ? Color(nsColor: Self.blend(.white, nsColor, 0.32))
            : Color(nsColor: Self.blend(.black, nsColor, 0.42))
    }

    /// The fill behind the value fields and the hex pill.
    var fieldFill: Color {
        isDark
            ? Color(nsColor: Self.blend(.white, nsColor, 0.35)).opacity(0.22)
            : Color(nsColor: Self.blend(.black, nsColor, 0.40)).opacity(0.14)
    }

    /// The unfilled part of a channel slider's track.
    var sliderTrack: Color {
        isDark
            ? Color(nsColor: Self.blend(.white, nsColor, 0.40)).opacity(0.35)
            : Color(nsColor: Self.blend(.black, nsColor, 0.30)).opacity(0.40)
    }

    /// The alpha slider's track: tinted, and kept visible on dark colors.
    var alphaTrack: Color {
        isDark
            ? Color(nsColor: Self.blend(.white, nsColor, 0.40)).opacity(0.30)
            : Color(nsColor: Self.blend(.black, nsColor, 0.35)).opacity(0.50)
    }

    /// The accent color used for the text caret, the text selection
    /// highlight and other focus rings.
    ///
    /// It follows the current color, but is pushed towards the opposite
    /// end of the value range so it always stays readable: on a light
    /// color it darkens, on a dark color it lightens.
    var accent: Color {
        Color(nsColor: accentNSColor)
    }

    /// The accent as an AppKit color, ready to hand to `NSApp`.
    var accentNSColor: NSColor {
        if isDark {
            return Self.blend(nsColor, .white, 0.55)
        } else {
            return Self.blend(nsColor, .black, 0.30)
        }
    }

    /// The slider thumb: near-white, but pulled slightly towards the
    /// current color so it does not glare against the background.
    var thumbFill: Color {
        Color(nsColor: Self.blend(.white, nsColor, 0.22))
    }

    /// Linearly blends two colors in sRGB; `t` is the share of `b`.
    ///
    /// The components are read through `usingColorSpace(.sRGB)`: the system
    /// `.white` / `.black` colors live in a generic gray space whose
    /// `redComponent` raises an exception if you ask for it directly.
    private static func blend(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let aRGB = a.usingColorSpace(.sRGB) ?? NSColor.white
        let bRGB = b.usingColorSpace(.sRGB) ?? NSColor.black
        func channel(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return NSColor(
            srgbRed: channel(aRGB.redComponent, bRGB.redComponent),
            green: channel(aRGB.greenComponent, bRGB.greenComponent),
            blue: channel(aRGB.blueComponent, bRGB.blueComponent),
            alpha: 1)
    }
}
