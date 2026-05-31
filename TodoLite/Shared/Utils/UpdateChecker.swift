import Foundation

actor UpdateChecker {
    static let shared = UpdateChecker()

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
