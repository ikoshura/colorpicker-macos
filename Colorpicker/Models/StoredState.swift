//
//  StoredState.swift
//  Colorpicker
//
//  Mirrors the JSON written by the Electron app's `electron-json-storage`
//  (src/storage.js) so existing user data can be migrated 1:1.
//

import Foundation

struct StoredState: Codable {
    struct ColorpickerSection: Codable {
        struct Size: Codable {
            var width: Int
            var height: Int
        }
        struct Pos: Codable {
            var x: Int
            var y: Int
        }

        var tools: [String]
        var size: Size
        var pos: Pos?
        var buttonsPosition: String
        var buttonsType: String
        var lastColor: String
        var history: [String]
        /// Replaces the old `colorfullApp` flag (complementary traffic-light
        /// tinting), which was removed. Decoding stays lenient so existing
        /// storage files keep working.
        var showAlphaSlider: Bool
        /// Draws a hairline under the toolbar row, separating it from the
        /// controls. Off by default.
        var showToolbarSeparator: Bool
        var updateIgnore: String?

        enum CodingKeys: String, CodingKey {
            case tools, size, pos, buttonsPosition, buttonsType, lastColor, history
            case showAlphaSlider
            case showToolbarSeparator
            case updateIgnore = "update:ignore"
        }
    }

    struct ColorsbookSection: Codable {
        var colors: [String: [String]]
    }

    struct PickerSection: Codable {
        var realtime: Bool

        enum CodingKeys: String, CodingKey {
            case realtime, realTime
        }

        init(realtime: Bool = false) {
            self.realtime = realtime
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // The Electron app writes both `realTime` (default) and `realtime`
            // (read path); accept either when migrating.
            if let value = try container.decodeIfPresent(Bool.self, forKey: .realtime) {
                realtime = value
            } else if let value = try container.decodeIfPresent(Bool.self, forKey: .realTime) {
                realtime = value
            } else {
                realtime = false
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(realtime, forKey: .realtime)
        }
    }

    var colorpicker: ColorpickerSection
    var colorsbook: ColorsbookSection
    var picker: PickerSection

    // MARK: - Defaults (same values as `defaultStorage` in storage.js)

    static let defaultTools = ["top", "picker", "tags", "shade", "settings"]
    static let defaultColors: [String: [String]] = [
        "flat": [
            "#2196F3", "#00BCD4", "#4CAF50", "#8BC34A", "#FFEB3B", "#FF9800",
            "#FF5722", "#F44336", "#673AB7", "#3F51B5", "#607D8B",
        ],
        "pastel": [
            "#7E93C8", "#8FC1E2", "#AFBBE3", "#EFCAC4", "#E19494", "#F8AF85",
            "#F9C48C", "#C2BB9B", "#B0D9CD", "#6B8790", "#AC94C9",
        ],
    ]

    static func makeDefault() -> StoredState {
        StoredState(
            colorpicker: .init(
                tools: defaultTools,
                size: .init(width: 440, height: 150),
                pos: nil,
                buttonsPosition: "left",
                buttonsType: "osx",
                lastColor: "#00AEEF",
                history: [],
                showAlphaSlider: false,
                showToolbarSeparator: false,
                updateIgnore: nil
            ),
            colorsbook: .init(colors: defaultColors),
            picker: .init()
        )
    }
}

// MARK: - Lenient decoding (fills missing keys with defaults, like storage.js)

extension StoredState {
    private enum CodingKeys: String, CodingKey {
        case colorpicker, colorsbook, picker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colorpicker = try container.decodeIfPresent(ColorpickerSection.self, forKey: .colorpicker)
            ?? Self.makeDefault().colorpicker
        colorsbook = try container.decodeIfPresent(ColorsbookSection.self, forKey: .colorsbook)
            ?? Self.makeDefault().colorsbook
        picker = try container.decodeIfPresent(PickerSection.self, forKey: .picker)
            ?? Self.makeDefault().picker
    }
}

extension StoredState.ColorpickerSection {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = StoredState.makeDefault().colorpicker
        tools = try container.decodeIfPresent([String].self, forKey: .tools) ?? defaults.tools
        size = try container.decodeIfPresent(Size.self, forKey: .size) ?? defaults.size
        pos = try container.decodeIfPresent(Pos.self, forKey: .pos)
        buttonsPosition = try container.decodeIfPresent(String.self, forKey: .buttonsPosition)
            ?? defaults.buttonsPosition
        buttonsType = try container.decodeIfPresent(String.self, forKey: .buttonsType)
            ?? defaults.buttonsType
        lastColor = try container.decodeIfPresent(String.self, forKey: .lastColor)
            ?? defaults.lastColor
        history = try container.decodeIfPresent([String].self, forKey: .history) ?? []
        showAlphaSlider = try container.decodeIfPresent(Bool.self, forKey: .showAlphaSlider) ?? false
        showToolbarSeparator = try container.decodeIfPresent(Bool.self, forKey: .showToolbarSeparator) ?? false
        updateIgnore = try container.decodeIfPresent(String.self, forKey: .updateIgnore)
    }
}

// MARK: - Persistence

enum PersistenceStore {
    /// Native app storage: ~/Library/Application Support/Colorpicker/colorpicker.json
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Colorpicker", isDirectory: true)
            .appendingPathComponent("colorpicker.json")
    }

    /// Electron app storage (electron-json-storage writes to a `storage/`
    /// subdirectory of the Electron userData folder):
    /// ~/Library/Application Support/colorpicker/storage/colorpicker.json
    static var electronFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("colorpicker", isDirectory: true)
            .appendingPathComponent("storage", isDirectory: true)
            .appendingPathComponent("colorpicker.json")
    }

    static func load() -> StoredState {
        let decoder = JSONDecoder()

        if let data = try? Data(contentsOf: fileURL),
           let state = try? decoder.decode(StoredState.self, from: data) {
            return state
        }

        // Migrate data written by the Electron version, if present.
        if let data = try? Data(contentsOf: electronFileURL),
           let state = try? decoder.decode(StoredState.self, from: data) {
            save(state)
            return state
        }

        let fresh = StoredState.makeDefault()
        save(fresh)
        return fresh
    }

    static func save(_ state: StoredState) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Colorpicker: failed to save storage: \(error)")
        }
    }

    static func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

}
