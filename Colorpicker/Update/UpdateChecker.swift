//
//  UpdateChecker.swift
//  Colorpicker
//
//  Port of src/checkUpdate.js — queries the GitHub Releases API of the
//  macOS port repository (ikoshura/colorpicker-macos).
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

    /// The GitHub repository that hosts the releases of the macOS port.
    static let repository = "ikoshura/colorpicker-macos"

    /// Where the "Show Update" button takes the user.
    static var releasesURL: URL {
        URL(string: "https://github.com/\(repository)/releases")!
    }

    /// Checks the GitHub Releases API for a version newer than the running one.
    static func check() async -> Result? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("colorpicker-macos/\(currentVersion)", forHTTPHeaderField: "user-agent")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return nil
        }

        // 404 means the repository has no published release yet, which is
        // not an error: the installed version is simply the latest one.
        if http.statusCode == 404 {
            return Result(latest: currentVersion, hasUpdate: false)
        }

        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            return nil
        }
        // Tags look like "v2.3.0" — strip any leading "v".
        let release = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
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
