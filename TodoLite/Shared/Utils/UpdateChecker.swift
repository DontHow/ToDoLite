import Foundation

actor UpdateChecker {
    static let shared = UpdateChecker()
    static let automaticChecksEnabledKey = "automaticUpdateChecksEnabled"
    static let lastAutomaticCheckKey = "lastAutomaticUpdateCheck"
    static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    struct Result {
        let hasUpdate: Bool
        let currentVersion: String
        let latestVersion: String
        let downloadURL: URL?
        let releaseNotes: String?
    }

    func check() async -> Result {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        guard let latest = await fetchLatestRelease() else {
            return Result(hasUpdate: false, currentVersion: current, latestVersion: current, downloadURL: nil, releaseNotes: nil)
        }
        let hasUpdate = isNewer(latest.version, than: current)
        return Result(
            hasUpdate: hasUpdate,
            currentVersion: current,
            latestVersion: latest.version,
            downloadURL: latest.htmlURL,
            releaseNotes: latest.body
        )
    }

    func checkAutomaticallyIfNeeded(now: Date = Date()) async -> Result? {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(forKey: Self.automaticChecksEnabledKey) == nil
            ? true
            : defaults.bool(forKey: Self.automaticChecksEnabledKey)
        let lastCheck = defaults.object(forKey: Self.lastAutomaticCheckKey) as? Date
        guard Self.shouldCheckAutomatically(isEnabled: isEnabled, lastCheck: lastCheck, now: now) else {
            return nil
        }

        defaults.set(now, forKey: Self.lastAutomaticCheckKey)
        return await check()
    }

    nonisolated static func shouldCheckAutomatically(
        isEnabled: Bool,
        lastCheck: Date?,
        now: Date = Date()
    ) -> Bool {
        guard isEnabled else { return false }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= automaticCheckInterval
    }

    private struct LatestRelease: Sendable {
        let version: String
        let htmlURL: URL?
        let body: String?
    }

    private func fetchLatestRelease() async -> LatestRelease? {
        let url = URL(string: "https://api.github.com/repos/DontHow/ToDoLite/releases/latest")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let tagName = json?["tag_name"] as? String else { return nil }
            let version = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let htmlURL = (json?["html_url"] as? String).flatMap(URL.init(string:))
            let body = json?["body"] as? String
            return LatestRelease(version: version, htmlURL: htmlURL, body: body)
        } catch {
            return nil
        }
    }

    private func isNewer(_ latest: String, than current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }
}
