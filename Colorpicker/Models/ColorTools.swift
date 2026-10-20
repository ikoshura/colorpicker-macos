//
//  ColorTools.swift
//  Colorpicker
//
//  Direct port of the Electron app's `src/views/js/color.class.js` so the
//  generated tints / naturals / shades are pixel-identical to the original app.
//

import Foundation

enum ColorTools {
    typealias RGB = (r: Int, g: Int, b: Int)
    typealias HSL = (h: Int, s: Int, l: Int)
    typealias HSV = (h: Int, s: Int, v: Int)

    // MARK: - Hex <-> RGB

    static func hex(from rgb: RGB) -> String {
        let parts = [rgb.r, rgb.g, rgb.b].map { String(format: "%02X", clamp255($0)) }
        return "#" + parts.joined()
    }

    static func rgb(fromHex hex: String) -> RGB {
        var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if h.count == 3 {
            h = h.map { "\($0)\($0)" }.joined()
        }
        guard h.count == 6, let num = UInt32(h, radix: 16) else { return (0, 0, 0) }
        return (Int((num >> 16) & 0xFF), Int((num >> 8) & 0xFF), Int(num & 0xFF))
    }

    // MARK: - RGB <-> HSL

    static func hsl(from rgb: RGB) -> HSL {
        let r = Double(rgb.r) / 255
        let g = Double(rgb.g) / 255
        let b = Double(rgb.b) / 255
        let minV = min(r, g, b)
        let maxV = max(r, g, b)
        let delta = maxV - minV

        var h: Double = 0
        if maxV != minV {
            if r == maxV { h = (g - b) / delta }
            else if g == maxV { h = 2 + (b - r) / delta }
            else { h = 4 + (r - g) / delta }
        }
        h = min(h * 60, 360)
        if h < 0 { h += 360 }

        let l = (minV + maxV) / 2
        var s: Double = 0
        if maxV != minV {
            if l <= 0.5 { s = delta / (maxV + minV) }
            else { s = delta / (2 - maxV - minV) }
        }
        return (Int(h.rounded()), Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    static func rgb(from hsl: HSL) -> RGB {
        let h = Double(hsl.h) / 360
        let s = Double(hsl.s) / 100
        let l = Double(hsl.l) / 100

        if s == 0 {
            let val = Int((l * 255).rounded())
            return (val, val, val)
        }
        let t2 = l < 0.5 ? l * (1 + s) : (l + s - l * s)
        let t1 = 2 * l - t2

        var out = [0, 0, 0]
        for i in 0..<3 {
            var t3 = h - Double(i - 1) / 3
            if t3 < 0 { t3 += 1 }
            if t3 > 1 { t3 -= 1 }
            let val: Double
            if 6 * t3 < 1 { val = t1 + (t2 - t1) * 6 * t3 }
            else if 2 * t3 < 1 { val = t2 }
            else if 3 * t3 < 2 { val = t1 + (t2 - t1) * (2.0 / 3.0 - t3) * 6 }
            else { val = t1 }
            out[i] = Int((val * 255).rounded())
        }
        return (clamp255(out[0]), clamp255(out[1]), clamp255(out[2]))
    }

    // MARK: - RGB <-> HSV

    static func hsv(from rgb: RGB) -> HSV {
        let result = hsvDouble(from: rgb)
        return (Int(result.h.rounded()), Int(result.s.rounded()), Int(result.v.rounded()))
    }

    private static func hsvDouble(from rgb: RGB) -> (h: Double, s: Double, v: Double) {
        let r = Double(rgb.r), g = Double(rgb.g), b = Double(rgb.b)
        let minV = min(r, g, b), maxV = max(r, g, b)
        let delta = maxV - minV

        var h: Double = 0
        if maxV != minV {
            if r == maxV { h = (g - b) / delta }
            else if g == maxV { h = 2 + (b - r) / delta }
            else { h = 4 + (r - g) / delta }
        }
        h = min(h * 60, 360)
        if h < 0 { h += 360 }

        let s = maxV == 0 ? 0 : (delta / maxV) * 100
        let v = (maxV / 255) * 100
        return (h, s, v)
    }

    static func rgb(from hsv: HSV) -> RGB {
        rgb(h: Double(hsv.h), s: Double(hsv.s), v: Double(hsv.v))
    }

    /// HSV in the same units as `getHSVFromRGB` / `getRGBFromHSV` in color.class.js
    /// (h: 0...360, s/v: 0...100). Unrounded inputs are allowed, like in JavaScript.
    static func rgb(h: Double, s: Double, v: Double) -> RGB {
        let hNorm = h / 60
        let sNorm = s / 100
        let vNorm = v / 100

        let hi = Int(floor(hNorm)) % 6
        let f = hNorm - floor(hNorm)
        let p = 255 * vNorm * (1 - sNorm)
        let q = 255 * vNorm * (1 - sNorm * f)
        let t = 255 * vNorm * (1 - sNorm * (1 - f))
        let vFull = 255 * vNorm

        switch hi {
        case 0: return (rnd(vFull), rnd(t), rnd(p))
        case 1: return (rnd(q), rnd(vFull), rnd(p))
        case 2: return (rnd(p), rnd(vFull), rnd(t))
        case 3: return (rnd(p), rnd(q), rnd(vFull))
        case 4: return (rnd(t), rnd(p), rnd(vFull))
        default: return (rnd(vFull), rnd(p), rnd(q))
        }
    }

    // MARK: - Color operations

    static func negative(_ rgb: RGB) -> RGB {
        (255 - rgb.r, 255 - rgb.g, 255 - rgb.b)
    }

    static func grayscale(_ rgb: RGB) -> RGB {
        let gray = Int(Double(rgb.r) * 0.3 + Double(rgb.g) * 0.59 + Double(rgb.b) * 0.11)
        let clamped = min(255, max(0, gray))
        return (clamped, clamped, clamped)
    }

    static func lightness(_ delta: Int, from rgb: RGB) -> RGB {
        let base = hsl(from: rgb)
        let shifted: HSL = (base.h, base.s, base.l + delta)
        return ColorTools.rgb(from: shifted)
    }

    static func lightness(_ delta: Int, fromHex hex: String) -> String {
        ColorTools.hex(from: lightness(delta, from: rgb(fromHex: hex)))
    }

    static func changeHue(_ degrees: Int, from rgb: RGB) -> RGB {
        var base = hsl(from: rgb)
        var h = base.h + degrees
        if h > 360 { h -= 360 } else if h < 0 { h += 360 }
        base.h = h
        return ColorTools.rgb(from: base)
    }

    static func changeHue(_ degrees: Int, fromHex hex: String) -> String {
        ColorTools.hex(from: changeHue(degrees, from: rgb(fromHex: hex)))
    }

    /// Port of `getNaturalFromRGB` (keeps the original's quirk where both
    /// branches of the saturation test perform the same operation).
    static func natural(_ percent: Int, from rgb: RGB) -> RGB {
        let base = hsv(from: rgb)
        let p = Double(percent)

        var h = Double(base.h) + 0.8 * p
        if h > 360 { h -= 360 } else if h < 0 { h += 360 }
        var s = Double(base.s)
        var v = Double(base.v)

        if base.h > 240 || base.h < 60 {
            s -= 0.7 * p
            s = min(100, max(0, s))
            v += (p < 0 ? 0.4 : 0.3) * p
            v = min(100, max(0, v))
        } else {
            s += 0.7 * p
            s = min(100, max(0, s))
            v -= (p < 0 ? 0.4 : 0.3) * p
            v = min(100, max(0, v))
        }
        return ColorTools.rgb(h: h, s: s, v: v)
    }

    static func natural(_ percent: Int, fromHex hex: String) -> String {
        ColorTools.hex(from: natural(percent, from: rgb(fromHex: hex)))
    }

    // MARK: - Brightness

    /// Port of `isDarkColor` — weighted luminance, dark when <= 140.
    static func isDark(_ rgb: RGB) -> Bool {
        let luminance = (Double(rgb.r) * 299 + Double(rgb.g) * 587 + Double(rgb.b) * 114) / 1000
        return Int(luminance.rounded()) <= 140
    }

    // MARK: - Shading strips

    struct ShadingSets: Equatable {
        let tints: [String]
        let naturals: [String]
        let shades: [String]
    }

    /// Port of `Colorpicker.changeShading`: 22 swatches per strip.
    static func shading(forHex hex: String) -> ShadingSets {
        var shades: [String] = []
        shades.reserveCapacity(22)
        var light = -25
        for _ in 0..<22 {
            shades.append(lightness(light, fromHex: hex))
            light += 2
        }

        var tints: [String] = []
        tints.reserveCapacity(22)
        var degrees = -100
        for _ in 0..<22 {
            tints.append(changeHue(degrees, fromHex: hex))
            degrees += 10
        }

        var naturals: [String] = []
        naturals.reserveCapacity(22)
        var percent = -84
        for _ in 0..<22 {
            naturals.append(natural(percent, fromHex: hex))
            percent += 8
        }
        return ShadingSets(tints: tints, naturals: naturals, shades: shades)
    }

    // MARK: - Helpers

    private static func clamp255(_ value: Int) -> Int { min(255, max(0, value)) }
    private static func rnd(_ value: Double) -> Int { Int(value.rounded()) }

}
