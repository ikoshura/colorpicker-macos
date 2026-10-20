//
//  PickerLoupe.swift
//  Colorpicker
//
//  The magnifier window used while picking a color from the screen.
//

import AppKit
import SwiftUI

final class LoupeModel: ObservableObject {
    @Published var hex: String = "#000000"
    @Published var color: AppColor = AppColor(hex: "#000000")
}

struct LoupeView: View {
    @ObservedObject var model: LoupeModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: model.color.nsColor), lineWidth: 8)
                .frame(width: 96, height: 96)
            Text(model.hex)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(.ultraThinMaterial))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(width: 110, height: 132, alignment: .top)
        .padding(.top, 7)
        // Let every click fall through to the window itself so it can
        // decide between picking and cancelling.
        .allowsHitTesting(false)
    }
}

final class PickerWindow: NSWindow {
    var onPick: (() -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseUp(with event: NSEvent) {
        if event.type == .leftMouseUp {
            onPick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
