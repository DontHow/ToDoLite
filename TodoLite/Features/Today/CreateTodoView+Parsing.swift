import SwiftUI

struct DateRuleSuggestion: Identifiable {
    let syntax: String
    let label: String
    let date: Date

    var id: String { syntax }
}

extension CreateTodoView {
    @ViewBuilder
    var ruleSuggestions: some View {
        if detailTitleFocused {
            if let token = activeProjectToken(in: edited.title) {
                projectMentionSuggestions(for: token)
            } else if let token = activeTagToken(in: edited.title) {
                tagMentionSuggestions(for: token)
            } else if let token = activeDateToken(in: edited.title) {
                dateRuleSuggestions(for: token)
            }
        }
    }

    @ViewBuilder
    func projectMentionSuggestions(for token: (range: Range<String.Index>, query: String)) -> some View {
            let candidates = projectMentionCandidates(for: token.query)
            let hasExactMatch = candidates.contains {
                $0.name.localizedCaseInsensitiveCompare(token.query) == .orderedSame
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "at")
                        .foregroundStyle(.blue)
                    Text(token.query.isEmpty ? "选择项目" : "匹配项目")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(Color.labelSecondary)
                    Spacer()
                }
                .padding(.horizontal, 6)

                ForEach(Array(candidates.prefix(5))) { project in
                    projectMentionRow(project, tokenRange: token.range)
                }

                if !token.query.isEmpty && !hasExactMatch {
                    Button {
                        selectPendingProjectMention(token.query, tokenRange: token.range)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("新建项目“\(token.query)”")
                                .appFont(.subheadline, weight: .medium)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if candidates.isEmpty && token.query.isEmpty {
                    Text("继续输入项目名称")
                        .appFont(.caption)
                        .foregroundStyle(Color.labelSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.22), lineWidth: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    func tagMentionSuggestions(for token: (range: Range<String.Index>, query: String)) -> some View {
        let candidates = tagMentionCandidates(for: token.query)
        let hasExactMatch = candidates.contains {
            $0.name.localizedCaseInsensitiveCompare(token.query) == .orderedSame
        }

        VStack(alignment: .leading, spacing: 6) {
            suggestionHeader(
                icon: "number",
                color: .purple,
                title: token.query.isEmpty ? "选择标签" : "匹配标签"
            )

            ForEach(Array(candidates.prefix(5))) { tag in
                Button {
                    if !edited.tagIds.contains(tag.id) {
                        edited.tagIds.append(tag.id)
                    }
                    pendingTagNames.removeAll { $0 == tag.name }
                    removeRuleToken(token.range, message: "已添加标签")
                } label: {
                    suggestionRow(
                        icon: "tag.fill",
                        color: Color(hex: tag.colorHex),
                        title: tag.name
                    )
                }
                .buttonStyle(.plain)
            }

            if !token.query.isEmpty && !hasExactMatch {
                Button {
                    if !pendingTagNames.contains(token.query) {
                        pendingTagNames.append(token.query)
                    }
                    removeRuleToken(token.range, message: "已添加待创建标签")
                } label: {
                    suggestionRow(
                        icon: "plus.circle.fill",
                        color: .purple,
                        title: "新建标签“\(token.query)”"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .suggestionPanel(tint: .purple)
    }

    @ViewBuilder
    func dateRuleSuggestions(for token: (range: Range<String.Index>, query: String)) -> some View {
        let candidates = dateRuleCandidates(for: token.query)

        VStack(alignment: .leading, spacing: 6) {
            suggestionHeader(
                icon: "calendar",
                color: .orange,
                title: token.query.isEmpty ? "选择截止日期" : "匹配日期"
            )

            ForEach(Array(candidates.prefix(5))) { candidate in
                Button {
                    edited.dueAt = candidate.date
                    removeRuleToken(token.range, message: "已设置截止日期")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.circle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.label)
                                .appFont(.subheadline, weight: .medium)
                            Text("^\(candidate.syntax) · \(dateSuggestionText(candidate.date))")
                                .appFont(.caption)
                                .foregroundStyle(Color.labelSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.08))
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if candidates.isEmpty && !token.query.isEmpty {
                Text("可输入日期，例如 ^7/20")
                    .appFont(.caption)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
        .suggestionPanel(tint: .orange)
    }

    var parsingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await applyLLMParsing() }
                } label: {
                    HStack(spacing: 6) {
                        if isParsingLLM {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("AI 解析")
                            .appFont(.subheadline, weight: .medium)
                    }
                }
                .disabled(parsingInput.isEmpty || isParsingLLM)

                Spacer()
            }
            .buttonStyle(.bordered)

            if let parseError {
                Text(parseError)
                    .appFont(.caption)
                    .foregroundStyle(.red)
            } else if let parseMessage {
                Text(parseMessage)
                    .appFont(.caption)
                    .foregroundStyle(Color.labelSecondary)
            }
        }
    }

    var parsingInput: String {
        [edited.title, edited.description]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    func automaticallyApplyRuleParsing(to input: String) async {
        guard input.range(of: #"[@#^]\S+"#, options: .regularExpression) != nil else { return }

        if let token = activeProjectToken(in: input) {
            let candidates = projectMentionCandidates(for: token.query)
            let hasExactMatch = candidates.contains {
                $0.name.localizedCaseInsensitiveCompare(token.query) == .orderedSame
            }
            if !candidates.isEmpty && !hasExactMatch {
                return
            }
        }
        if let token = activeTagToken(in: input) {
            let candidates = tagMentionCandidates(for: token.query)
            let hasExactMatch = candidates.contains {
                $0.name.localizedCaseInsensitiveCompare(token.query) == .orderedSame
            }
            if !candidates.isEmpty && !hasExactMatch {
                return
            }
        }
        if let token = activeDateToken(in: input) {
            let candidates = dateRuleCandidates(for: token.query)
            let hasExactSyntax = candidates.contains {
                $0.syntax.localizedCaseInsensitiveCompare(token.query) == .orderedSame
            }
            if !candidates.isEmpty && !hasExactSyntax {
                return
            }
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled, edited.title == input else { return }

        let draft = TodoParser.parse(input)
        let recognizedMetadata = draft.projectName != nil || !draft.tagNames.isEmpty || draft.dueAt != nil
        guard recognizedMetadata else { return }

        applyParsedDraft(draft)
        parseMessage = "已自动将规则解析结果填入表单"
        parseError = nil
    }

    func activeProjectToken(in input: String) -> (range: Range<String.Index>, query: String)? {
        activeRuleToken(in: input, symbol: "@")
    }

    func activeTagToken(in input: String) -> (range: Range<String.Index>, query: String)? {
        activeRuleToken(in: input, symbol: "#")
    }

    func activeDateToken(in input: String) -> (range: Range<String.Index>, query: String)? {
        activeRuleToken(in: input, symbol: "^")
    }

    func activeRuleToken(in input: String, symbol: Character) -> (range: Range<String.Index>, query: String)? {
        guard let tokenIndex = input.lastIndex(where: { "@#^".contains($0) }),
              input[tokenIndex] == symbol else { return nil }

        if tokenIndex != input.startIndex {
            let previousIndex = input.index(before: tokenIndex)
            guard input[previousIndex].isWhitespace else { return nil }
        }

        let queryStart = input.index(after: tokenIndex)
        let query = String(input[queryStart...])
        guard !query.contains(where: \Character.isWhitespace) else { return nil }

        return (tokenIndex..<input.endIndex, query)
    }

    func projectMentionCandidates(for query: String) -> [Project] {
        let availableProjects = store.projects.filter { !$0.isArchived }
        guard !query.isEmpty else { return availableProjects }
        return availableProjects.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func tagMentionCandidates(for query: String) -> [TagItem] {
        guard !query.isEmpty else { return store.tags }
        return store.tags.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func dateRuleCandidates(for query: String) -> [DateRuleSuggestion] {
        let definitions = [
            ("today", "今天"),
            ("tomorrow", "明天"),
            ("weekend", "本周末"),
            ("nextweek", "下周"),
            ("monday", "下周一"),
            ("friday", "下周五"),
        ]
        let candidates = definitions.compactMap { syntax, label -> DateRuleSuggestion? in
            guard let date = DateResolver.resolve(syntax) else { return nil }
            return DateRuleSuggestion(syntax: syntax, label: label, date: date)
        }
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.syntax.localizedCaseInsensitiveContains(query)
                || $0.label.localizedCaseInsensitiveContains(query)
        }
    }

    func dateSuggestionText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: date)
    }

    func projectMentionRow(_ project: Project, tokenRange: Range<String.Index>) -> some View {
        Button {
            edited.projectId = project.id
            pendingProjectName = nil
            removeProjectMention(tokenRange)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
                Text(project.name)
                    .appFont(.subheadline, weight: .medium)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.08))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    func selectPendingProjectMention(_ name: String, tokenRange: Range<String.Index>) {
        edited.projectId = nil
        pendingProjectName = name
        removeProjectMention(tokenRange)
    }

    func removeProjectMention(_ range: Range<String.Index>) {
        removeRuleToken(range, message: "已选择项目")
    }

    func removeRuleToken(_ range: Range<String.Index>, message: String) {
        edited.title.removeSubrange(range)
        edited.title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        parseMessage = message
        parseError = nil
        detailTitleFocused = true
    }

    func suggestionHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(Color.labelSecondary)
            Spacer()
        }
        .padding(.horizontal, 6)
    }

    func suggestionRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .appFont(.subheadline, weight: .medium)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func applyLLMParsing() async {
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else {
            parseError = "请先在设置中配置 LLM"
            parseMessage = nil
            return
        }

        isParsingLLM = true
        parseError = nil
        parseMessage = nil
        defer { isParsingLLM = false }

        do {
            let draft = try await LLMParser.shared.parse(
                parsingInput,
                projects: store.projects,
                tags: store.tags,
                config: config
            )
            applyParsedDraft(draft)
            parseMessage = "已将 AI 解析结果填入表单"
        } catch {
            parseError = "AI 解析失败，请稍后重试"
        }
    }

    func applyParsedDraft(_ draft: TodoDraft) {
        if !draft.title.isEmpty {
            edited.title = draft.title
        }
        if !draft.description.isEmpty {
            edited.description = draft.description
        }
        if let dueAt = draft.dueAt {
            edited.dueAt = dueAt
        }

        if let projectName = draft.projectName {
            if let project = store.projects.first(where: { $0.name == projectName }) {
                edited.projectId = project.id
                pendingProjectName = nil
            } else {
                edited.projectId = nil
                pendingProjectName = projectName
            }
        }

        for name in draft.tagNames {
            if let tag = store.tags.first(where: { $0.name == name }) {
                if !edited.tagIds.contains(tag.id) {
                    edited.tagIds.append(tag.id)
                }
            } else if !pendingTagNames.contains(name) {
                pendingTagNames.append(name)
            }
        }
    }

    func resolvePendingMetadata(in todo: TodoItem) async throws -> TodoItem {
        var resolved = todo

        if let name = pendingProjectName {
            if let project = store.projects.first(where: { $0.name == name }) {
                resolved.projectId = project.id
            } else {
                try await store.createProject(name: name)
                resolved.projectId = store.projects.first(where: { $0.name == name })?.id
            }
        }

        for name in pendingTagNames {
            let tag: TagItem
            if let existing = store.tags.first(where: { $0.name == name }) {
                tag = existing
            } else {
                try await store.createTag(name: name)
                guard let created = store.tags.first(where: { $0.name == name }) else { continue }
                tag = created
            }
            if !resolved.tagIds.contains(tag.id) {
                resolved.tagIds.append(tag.id)
            }
        }

        return resolved
    }
}

private extension View {
    func suggestionPanel(tint: Color) -> some View {
        self
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
