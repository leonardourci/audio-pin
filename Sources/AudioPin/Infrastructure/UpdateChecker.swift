import Foundation
import Observation

@Observable
@MainActor
final class UpdateChecker {
    private(set) var latestVersion: String?
    private(set) var releaseURL: URL?
    private(set) var lastCheckedAt: Date?

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        if let dismissed = defaults.string(forKey: Self.dismissedVersionKey), dismissed == latest {
            return false
        }
        return Self.compareSemver(latest, currentVersion) == .orderedDescending
    }

    private static let log = AppLog.logger("UpdateChecker")
    private static let endpoint = URL(string: "https://api.github.com/repos/leonardourci/audio-pin/releases/latest")!
    private static let lastCheckedAtKey = "UpdateChecker.lastCheckedAt"
    private static let dismissedVersionKey = "UpdateChecker.dismissedVersion"
    private static let pollInterval: Duration = .seconds(24 * 60 * 60)

    private let defaults: UserDefaults
    private let currentVersion: String
    private var periodicTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentVersion = Self.readBundleVersion()
        self.lastCheckedAt = defaults.object(forKey: Self.lastCheckedAtKey) as? Date
    }

    func startPeriodicChecks() {
        guard periodicTask == nil else { return }
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkNow()
                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        periodicTask?.cancel()
        periodicTask = nil
    }

    func checkNow() async {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 10)
        request.setValue("AudioPin/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                Self.log.debug("update check non-2xx response")
                return
            }
            let payload = try JSONDecoder().decode(ReleasePayload.self, from: data)
            let parsed = Self.stripLeadingV(payload.tag_name)
            let url = URL(string: payload.html_url)

            self.latestVersion = parsed
            self.releaseURL = url
            let now = Date()
            self.lastCheckedAt = now
            defaults.set(now, forKey: Self.lastCheckedAtKey)
        } catch {
            Self.log.debug("update check failed: \(String(describing: error), privacy: .public)")
        }
    }

    func dismiss() {
        guard let latest = latestVersion else { return }
        defaults.set(latest, forKey: Self.dismissedVersionKey)
    }

    // MARK: - Helpers

    private static func readBundleVersion() -> String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return v
        }
        return "0.0.0"
    }

    private static func stripLeadingV(_ tag: String) -> String {
        if tag.hasPrefix("v") || tag.hasPrefix("V") {
            return String(tag.dropFirst())
        }
        return tag
    }

    // Numeric semver compare on dot-separated components. Non-numeric segments
    // sort as 0. Extra components on either side are treated as 0.
    static func compareSemver(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private struct ReleasePayload: Decodable {
        let tag_name: String
        let html_url: String
    }
}
