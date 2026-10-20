//
//  Components.swift
//  Colorpicker
//
//  Shared building blocks for the main window: the RGBA channel sliders
//  (styled after colorpicker.css) and the tool buttons.
//

import SwiftUI

// MARK: - Layout metrics

/// Vertical metrics for the main window.
///
/// The window has two density profiles:
///
/// - With the alpha slider visible there are four rows of controls, so
///   the layout stays compact to keep the panel short.
/// - Without it there are only three rows, and the layout relaxes into
///   the roomier, more comfortable spacing of the original app.
struct LayoutMetrics {
    let showAlpha: Bool
    /// Whether the hairline under the toolbar is drawn. It changes how
    /// much air sits between the toolbar band and the controls.
    let showSeparator: Bool

    /// Number of slider/field rows (RGB + optional alpha).
    var rowCount: Int { showAlpha ? 4 : 3 }
    /// Height of a single slider or value field. The slider thumb is a
    /// circle that is taller than the track, so the row is sized to it.
    var rowHeight: CGFloat { showAlpha ? 20 : 24 }
    /// Vertical gap between rows.
    var rowSpacing: CGFloat { showAlpha ? 5 : 9 }
    /// Height of the toolbar band: the system traffic lights and the tool
    /// buttons sit inline in it.
    var toolbarHeight: CGFloat { showAlpha ? 32 : 30 }
    /// Space reserved above the controls for the toolbar row. It always
    /// clears the toolbar band first.
    ///
    /// With the separator on, the hairline needs room of its own, so a
    /// little air is left between it and the controls. Without it there is
    /// no divider to space out from, so the controls move up and the view
    /// stays tight instead of showing a band of dead space.
    var topPadding: CGFloat {
        let gap: CGFloat
        if showSeparator {
            gap = showAlpha ? 6 : 8
        } else {
            gap = 0
        }
        return toolbarHeight + gap
    }
    /// Space below the controls.
    var bottomPadding: CGFloat { showAlpha ? 6 : 6 }
    /// Horizontal padding around the whole control block.
    var horizontalPadding: CGFloat { 18 }
    /// Gap between the sliders and the value fields.
    var sliderFieldSpacing: CGFloat { showAlpha ? 10 : 16 }
    /// Gap between the value fields and the hex field.
    var fieldHexSpacing: CGFloat { showAlpha ? 10 : 12 }
    /// Width of a numeric value field.
    var fieldWidth: CGFloat { showAlpha ? 44 : 52 }
    /// Font size of the numeric value fields.
    var fieldFontSize: CGFloat { showAlpha ? 12 : 14 }
    /// Width of the hex field + copy button.
    var hexWidth: CGFloat { showAlpha ? 104 : 118 }
    /// Font size of the hex text.
    var hexFontSize: CGFloat { showAlpha ? 13 : 15 }
    /// Diameter of the slider thumb circle.
    var thumbSize: CGFloat { showAlpha ? 20 : 24 }
    /// Height of the rounded slider track.
    var trackHeight: CGFloat { 10 }

    /// Height of the controls block on its own.
    var contentHeight: CGFloat {
        CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * rowSpacing
    }

    /// The smallest height the window may take.
    var minimumHeight: CGFloat { topPadding + contentHeight + bottomPadding }
}

// MARK: - Channel slider

/// Custom slider matching the original track/thumb styling:
/// 10px rounded track, colored fill, 22px white thumb.
struct ColorChannelSlider: View {
    @Binding var value: Double
    /// The colored portion of the track (the channel's own color).
    var fill: Color
    /// The unfilled portion of the track, tinted towards the background.
    var track: Color
    /// The thumb color, tinted so it never glares.
    var thumb: Color
    /// Thumb diameter; the row height follows it.
    var thumbSize: CGFloat = 20
    /// Height of the rounded track. The thumb is a bigger circle that
    /// sits on top of it.
    var trackHeight: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let clamped = min(max(value, 0), 255)
            let fraction = width > 0 ? CGFloat(clamped / 255) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .frame(height: trackHeight)
                Capsule()
                    .fill(fill)
                    .frame(width: max(trackHeight, fraction * width), height: trackHeight)
                Circle()
                    .fill(thumb)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .overlay(
                        Capsule()
                            .fill(Color(hex: "#F3F3F3"))
                            .frame(width: thumbSize * 0.64, height: 2)
                            .offset(y: thumbSize * 0.41)
                            .clipShape(Circle())
                    )
                    .offset(x: min(max(fraction * width - thumbSize / 2, 0), max(0, width - thumbSize)))
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
        .frame(height: thumbSize)
    }
}

// MARK: - Tools

struct ToolItem: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String

    /// Same catalogue as `allTools` in colorpicker.events.js.
    static let all: [ToolItem] = [
        ToolItem(id: "top", title: "Pin to Foreground", icon: "pin.fill"),
        ToolItem(id: "picker", title: "Pick Color", icon: "eyedropper.halffull"),
        ToolItem(id: "tags", title: "Open Colorsbook", icon: "book.fill"),
        ToolItem(id: "shade", title: "Toggle Shading", icon: "drop.fill"),
        ToolItem(id: "random", title: "Set Random Color", icon: "dice.fill"),
        ToolItem(id: "clean", title: "Focus Mode", icon: "circle.lefthalf.filled"),
        ToolItem(id: "apply", title: "Get Clipboard's Colors", icon: "doc.on.clipboard.fill"),
        ToolItem(id: "settings", title: "Open Settings", icon: "gearshape.fill"),
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
