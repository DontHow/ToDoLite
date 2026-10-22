import Foundation
import SQLite3

enum AIActivitySource: String, CaseIterable, Identifiable, Sendable {
    case claude, codex, cursor
    var id: String { rawValue }
    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }
}

/// 仅读取明确选择的来源和日期范围。可注入目录供测试，不访问真实用户会话。
enum AIActivityReader {
    static func summaryAsync(week: ReportWeek, sources: Set<AIActivitySource>,
                             homeDirectory: URL? = nil) async -> String {
        let task = Task.detached(priority: .utility) {
            summary(week: week, sources: sources, homeDirectory: homeDirectory)
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func summary(week: ReportWeek, sources: Set<AIActivitySource>,
                        homeDirectory: URL? = nil) -> String {
        guard !sources.isEmpty else { return "" }
        let root: URL
        if let homeDirectory {
            root = homeDirectory
        } else {
            #if os(macOS)
            root = FileManager.default.homeDirectoryForCurrentUser
            #else
            return ""
            #endif
        }
        var sections: [String] = []
        for source in AIActivitySource.allCases where sources.contains(source) {
            guard !Task.isCancelled else { return "" }
            let text: String
            switch source {
            case .claude:
                text = sessionSummary(at: root.appendingPathComponent(".claude/projects"), source: source, week: week)
            case .codex:
                // 按消息时间筛选，包含在所选周之前创建、该周仍有活动的长会话。
                text = sessionSummary(at: root.appendingPathComponent(".codex/sessions"), source: source, week: week)
            case .cursor:
                text = cursorSummary(at: root.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb"), week: week)
            }
            if !text.isEmpty { sections.append(source.title + " 会话：\n" + text) }
        }
        return String(sections.joined(separator: "\n\n").prefix(6000))
    }

    private static func sessionSummary(at directory: URL, source: AIActivitySource, week: ReportWeek) -> String {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys,
                                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return "" }
        var candidates: [(url: URL, date: Date)] = []
        for case let file as URL in files {
            guard !Task.isCancelled else { return "" }
            guard file.pathExtension == "jsonl", let values = try? file.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, let modified = values.contentModificationDate, modified >= week.start else { continue }
            candidates.append((file, modified))
        }
        candidates.sort { $0.date > $1.date }
        var results: [String] = []
        let dates = ActivityDates()
        for candidate in candidates.prefix(128) {
            guard !Task.isCancelled else { return "" }
            guard let text = readSessionFile(candidate.url) else { continue }
            var project = candidate.url.deletingLastPathComponent().lastPathComponent
            var messages: [String] = []
            for line in text.split(separator: "\n") {
                guard !Task.isCancelled else { return "" }
                guard let object = jsonObject(line) else { continue }
                if source == .codex, object["type"] as? String == "session_meta",
                   let payload = object["payload"] as? [String: Any], let cwd = payload["cwd"] as? String {
                    project = URL(fileURLWithPath: cwd).lastPathComponent
                }
                if source == .claude, let cwd = object["cwd"] as? String { project = URL(fileURLWithPath: cwd).lastPathComponent }
                guard let date = dates.resolve(object["timestamp"]), week.contains(date) else { continue }
                let content: String?
                if source == .claude, object["type"] as? String == "user",
                   let message = object["message"] as? [String: Any] {
                    content = message["content"] as? String ?? (message["content"] as? [[String: Any]])?.compactMap {
                        $0["type"] as? String == "text" ? $0["text"] as? String : nil
                    }.joined(separator: " ")
                } else if source == .codex, object["type"] as? String == "response_item",
                          let payload = object["payload"] as? [String: Any], payload["type"] as? String == "message",
                          payload["role"] as? String == "user", let blocks = payload["content"] as? [[String: Any]] {
                    content = blocks.compactMap { $0["type"] as? String == "input_text" ? $0["text"] as? String : nil }.joined(separator: " ")
                } else { content = nil }
                if let content = clean(content) { messages.append(content) }
                if messages.count >= 5 { break }
            }
            if !messages.isEmpty {
                results.append("- 项目 " + project + "：\n" + messages.map { "  · " + $0 }.joined(separator: "\n"))
            }
            if results.count >= 8 { break }
        }
        return results.joined(separator: "\n")
    }

    private static func cursorSummary(at url: URL, week: ReportWeek) -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            return ""
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = 'workbench.panel.aichat.view.aichat.chatdata' AND length(value) <= 4000000"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return "" }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0) else { return "" }
        let data = Data(String(cString: raw).utf8)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tabs = root["tabs"] as? [[String: Any]] else { return "" }
        var results: [String] = []
        let dates = ActivityDates()
        for tab in tabs {
            guard !Task.isCancelled else { return "" }
            let bubbles = tab["bubbles"] as? [[String: Any]] ?? []
            let messages = bubbles.compactMap { bubble -> String? in
                guard bubble["type"] as? String == "user", let date = dates.resolve(bubble["timestamp"] ?? bubble["createdAt"]),
                      week.contains(date) else { return nil }
                return clean(bubble["text"] as? String)
            }.prefix(3)
            if !messages.isEmpty {
                results.append("- " + (tab["title"] as? String ?? "会话") + "：\n" + messages.map { "  · " + $0 }.joined(separator: "\n"))
            }
            if results.count >= 8 { break }
        }
        return results.joined(separator: "\n")
    }

    private struct ActivityDates {
        let fractional: ISO8601DateFormatter
        let plain: ISO8601DateFormatter

        init() {
            fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
        }

        func resolve(_ value: Any?) -> Date? {
            if let text = value as? String { return fractional.date(from: text) ?? plain.date(from: text) }
            if let number = value as? NSNumber {
                let time = number.doubleValue
                guard time.isFinite, time > 0 else { return nil }
                return Date(timeIntervalSince1970: time > 100_000_000_000 ? time / 1000 : time)
            }
            return nil
        }
    }

    private static func readSessionFile(_ url: URL) -> String? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        do {
            let size = try file.seekToEnd()
            let headSize = 256_000
            let tailSize = 4_000_000
            try file.seek(toOffset: 0)
            if size <= UInt64(headSize + tailSize) {
                return String(decoding: try file.readToEnd() ?? Data(), as: UTF8.self)
            }
            let head = String(decoding: try file.read(upToCount: headSize) ?? Data(), as: UTF8.self)
            try file.seek(toOffset: size - UInt64(tailSize))
            var tail = String(decoding: try file.readToEnd() ?? Data(), as: UTF8.self)
            if let newline = tail.firstIndex(of: "\n") { tail = String(tail[tail.index(after: newline)...]) }
            return head + "\n" + tail
        } catch { return nil }
    }

    private static func jsonObject(_ line: Substring) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    }

    private static func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["<command-name>", "<command-message", "<local-command", "<system-reminder>", "Caveat:",
                        "# AGENTS.md", "<environment_context", "<user_instructions", "<recommended_plugins",
                        "## Context", "Base directory for this skill:", "<bash-input", "<bash-stdout", "[Image", "[Request interrupted"]
        guard !content.isEmpty, !prefixes.contains(where: { content.hasPrefix($0) }) else { return nil }
        return String(content.prefix(150))
    }
}
