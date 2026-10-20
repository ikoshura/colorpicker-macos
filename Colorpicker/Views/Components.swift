//
//  Components.swift
//  Colorpicker
//
//  Shared building blocks for the main window: the RGBA channel sliders
//  (styled after colorpicker.css) and the tool buttons.
//

import SwiftUI

// MARK: - Channel slider

/// Custom slider matching the original track/thumb styling:
/// 10px rounded track, colored fill, 22px white thumb.
struct ColorChannelSlider: View {
    @Binding var value: Double
    var fill: Color
    var isDark: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clamped = min(max(value, 0), 255)
            let fraction = width > 0 ? CGFloat(clamped / 255) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.35))
                    .frame(height: 10)
                Capsule()
                    .fill(fill)
                    .frame(width: max(10, fraction * width), height: 10)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .overlay(
                        Capsule()
                            .fill(Color(hex: "#F3F3F3"))
                            .frame(width: 14, height: 2)
                            .offset(y: 9)
                            .clipShape(Circle())
                    )
                    .offset(x: min(max(fraction * width - 11, 0), max(0, width - 22)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let ratio = min(max(gesture.location.x / max(width, 1), 0), 1)
                        value = ratio * 255
                    }
            )
        }
        .frame(height: 22)
    }
}

// MARK: - Tools

struct ToolItem: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String

    /// Same catalogue as `allTools` in colorpicker.events.js.
    static let all: [ToolItem] = [
        ToolItem(id: "top", title: "Pin to Foreground", icon: "pin"),
        ToolItem(id: "picker", title: "Pick Color", icon: "eyedropper"),
        ToolItem(id: "tags", title: "Open Colorsbook", icon: "book"),
        ToolItem(id: "shade", title: "Toggle Shading", icon: "drop"),
        ToolItem(id: "random", title: "Set Random Color", icon: "dice"),
        ToolItem(id: "clean", title: "Focus Mode", icon: "circle.lefthalf.filled"),
        ToolItem(id: "apply", title: "Get Clipboard's Colors", icon: "doc.on.clipboard"),
        ToolItem(id: "settings", title: "Open Settings", icon: "gearshape"),
    ]

    static func named(_ id: String) -> ToolItem? {
        all.first { $0.id == id }
    }
}

struct ToolButton: View {
    let tool: ToolItem
    var isActive = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        isActive
                            ? Color.primary.opacity(0.25)
                            : (hovering ? Color.primary.opacity(0.12) : .clear)))
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .onHover { hovering = $0 }
    }
}


extension Color {
    init(hex: String) {
        self = Color(nsColor: AppColor(hex: hex).nsColor)
    }
}
