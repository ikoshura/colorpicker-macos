//
//  PixelSampler.swift
//  Colorpicker
//
//  Reads the color of a single screen pixel. Uses ScreenCaptureKit on
//  macOS 14.3+ (the modern, non-deprecated path) and falls back to
//  CoreGraphics on older systems. Requires the Screen Recording permission,
//  exactly like the Electron version required it for robotjs.
//

import AppKit
import CoreGraphics
import ScreenCaptureKit

enum PixelSampler {
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Samples the 1x1 rect and returns "#RRGGBB", or nil on failure.
    ///
    /// The loupe window is transparent at its center (the sampled point), so
    /// including it in the capture is harmless.
    static func sampleHex(at rect: CGRect) async -> String? {
        var image: CGImage?

        if #available(macOS 15.2, *) {
            image = await withCheckedContinuation { continuation in
                SCScreenshotManager.captureImage(in: rect) { captured, _ in
                    continuation.resume(returning: captured)
                }
            }
        }

        if image == nil {
            // Deprecated since macOS 14 but still the only path below 15.2.
            image = CGWindowListCreateImage(
                rect, .optionOnScreenOnly, kCGNullWindowID, [.nominalResolution, .bestResolution])
        }

        guard let image else { return nil }
        return hex(from: image)
    }

    /// Extracts the (single) pixel of a small CGImage into "#RRGGBB".
    static func hex(from image: CGImage) -> String? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])
    }

    /// Converts an AppKit bottom-left-origin point to the top-left-origin
    /// global space used by CG/SCK capture APIs.
    @MainActor
    static func cgRect(forScreenPoint point: NSPoint) -> CGRect {
        let topEdge = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        return CGRect(x: point.x, y: topEdge - point.y, width: 1, height: 1)
    }
}
