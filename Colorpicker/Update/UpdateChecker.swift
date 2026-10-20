//
//  UpdateChecker.swift
//  Colorpicker
//
//  Port of src/checkUpdate.js — queries colorpicker.fr/release.json.
//

import Foundation

enum UpdateChecker {
    struct Result {
        let latest: String
        let hasUpdate: Bool
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.3.0"
    }

    static func check() async -> Result? {
        guard let url = URL(string: "https://colorpicker.fr/release.json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("colorpicker-\(currentVersion)", forHTTPHeaderField: "user-agent")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let release = json["release"] as? String else {
            return nil
        }
        return Result(latest: release, hasUpdate: compareVersions(release, currentVersion) == .orderedDescending)
    }

    /// Minimal semver-ish comparison: "2.3.0" < "2.10.0".
    static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, bParts.count)
        for index in 0..<count {
            let l = index < lhs.count ? lhs[index] : 0
            let r = index < bParts.count ? bParts[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
