import SwiftUI

extension CreateTodoView {
    var quickEntryArea: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)

                if edited.title.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入任务...")
                            .foregroundStyle(.tertiary)
                            .appFont(.title3)
                        Text("@项目 #标签 ^日期")
                            .foregroundStyle(.quaternary)
                            .appFont(.callout)
                    }
                    .padding(20)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $edited.title)
                    .appFont(.title3)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 120)
                    .focused($quickEntryFocused)
            }
            .frame(minHeight: 120)
            .onChange(of: edited.title) { _, newValue in
                parsedDraft = TodoParser.parse(newValue)
                llmError = nil
            }

            aiParseButton

            suggestionPanel

            if let draft = parsedDraft, !draft.title.isEmpty {
                quickPreviewCard(draft)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                quickEntryFocused = true
            }
        }
    }

    var aiParseButton: some View {
        HStack(spacing: 12) {
            Button {
                Task { await parseWithLLM() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .appFont(.subheadline)
                    if isParsingLLM {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("AI 解析")
                            .appFont(.subheadline, weight: .medium)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(edited.title.isEmpty ? Color.gray : Color.purple)
                .clipShape(Capsule())
            }
            .disabled(edited.title.isEmpty || isParsingLLM)
            .buttonStyle(.plain)

            if let error = llmError {
                Text(error)
                    .appFont(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    func parseWithLLM() async {
        guard !edited.title.isEmpty else { return }
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else {
            llmError = "请先配置 LLM"
            return
        }

        isParsingLLM = true
        llmError = nil

        do {
            let draft = try await LLMParser.shared.parse(
                edited.title,
                projects: store.projects,
                tags: store.tags,
                config: config
            )
            parsedDraft = draft
        } catch {
            llmError = "解析失败"
        }

        isParsingLLM = false
    }

    var suggestionPanel: some View {
        Group {
            if let token = activeToken {
                VStack(alignment: .leading, spacing: 10) {
                    switch token.prefix {
                    case "@":
                        projectSuggestions(query: token.query)
                    case "#":
                        tagSuggestions(query: token.query)
                    case "^":
                        dateSuggestions()
                    default:
                        EmptyView()
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    var activeToken: (prefix: Character, query: String)? {
        let components = edited.title.split(separator: " ", omittingEmptySubsequences: false)
        guard let last = components.last, !last.isEmpty else { return nil }
        let lastStr = String(last)
        guard let first = lastStr.first, ["@", "#", "^"].contains(first) else { return nil }
        return (first, String(lastStr.dropFirst()))
    }

    func insertSuggestion(_ text: String) {
        let components = edited.title.split(separator: " ", omittingEmptySubsequences: false)
        if components.count > 1 {
            let allButLast = components.dropLast().joined(separator: " ")
            edited.title = allButLast + " " + text
        } else {
            edited.title = text
        }
    }

    func projectSuggestions(query: String) -> some View {
        let filtered = query.isEmpty
            ? store.projects
            : store.projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return suggestionRow(title: "项目", icon: "folder.fill", color: .blue) {
            ForEach(filtered) { project in
                suggestionChip(text: project.name) {
                    insertSuggestion("@" + project.name)
                }
            }
            if filtered.isEmpty {
                Text("无匹配项目")
                    .appFont(.caption)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.vertical, 4)
            }
        }
    }

    func tagSuggestions(query: String) -> some View {
        let filtered = query.isEmpty
            ? store.tags
            : store.tags.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return suggestionRow(title: "标签", icon: "tag.fill", color: .purple) {
            ForEach(filtered) { tag in
                suggestionChip(text: tag.name) {
                    insertSuggestion("#" + tag.name)
                }
            }
            if filtered.isEmpty {
                Text("无匹配标签")
                    .appFont(.caption)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.vertical, 4)
            }
        }
    }

    func dateSuggestions() -> some View {
        let options: [(display: String, value: String)] = [
            ("今天", "today"), ("明天", "tomorrow"), ("下周", "next week"),
            ("周末", "weekend"), ("周一", "mon"), ("周二", "tue"),
            ("周三", "wed"), ("周四", "thu"), ("周五", "fri")
        ]
        return suggestionRow(title: "日期", icon: "calendar", color: .green) {
            ForEach(options, id: \.value) { option in
                suggestionChip(text: option.display) {
                    insertSuggestion("^" + option.value)
                }
            }
        }
    }

    func suggestionRow<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .appFont(.caption)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(Color.labelSecondary)
            }
            FlowLayout(spacing: 8) {
                content()
            }
        }
    }

    func suggestionChip(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .appFont(.subheadline, weight: .medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func quickPreviewCard(_ draft: TodoDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.title)
                .appFont(.headline)
                .foregroundStyle(.primary)

            FlowLayout(spacing: 8) {
                if let project = draft.projectName {
                    TagChip(
                        icon: "folder.fill",
                        text: project,
                        color: .blue
                    )
                }

                if let date = draft.dueAt {
                    TagChip(
                        icon: "calendar",
                        text: date.formatted(.dateTime.month().day()),
                        color: .green
                    )
                }

                ForEach(draft.tagNames, id: \.self) { tag in
                    TagChip(
                        icon: "tag.fill",
                        text: tag,
                        color: .purple
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackgroundTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
