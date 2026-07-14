import SwiftUI

extension CreateTodoView {
    var attributesPanel: some View {
        VStack(spacing: 16) {
            statusSelector
            projectSelector
            tagSelector()

            if todo != nil {
                actionCard
            }
        }
    }

    var statusSelector: some View {
        OptionRow(icon: "list.bullet.rectangle", iconColor: .indigo, label: "状态") {
            VStack(spacing: 8) {
                ForEach(TodoStatus.allCases.filter { $0 != .archived }, id: \.self) { status in
                    statusRow(status)
                }
            }
        }
    }

    var projectSelector: some View {
        OptionRow(icon: "folder.fill", iconColor: .blue, label: "项目") {
            VStack(spacing: 10) {
                searchField(text: $projectQuery, placeholder: "搜索项目")

                ScrollView {
                    VStack(spacing: 6) {
                        if let pendingProjectName {
                            pendingProjectRow(pendingProjectName)
                        }
                        projectRow(nil)
                        ForEach(filteredProjects) { project in
                            projectRow(project)
                        }
                    }
                }
                .frame(
                    minHeight: usesWideDetailLayout && todo == nil ? 200 : nil,
                    maxHeight: usesWideDetailLayout && todo == nil ? .infinity : 240
                )
            }
        }
        .frame(maxHeight: usesWideDetailLayout && todo == nil ? .infinity : nil, alignment: .top)
    }

    @ViewBuilder
    func tagSelector(scrollsList: Bool = true) -> some View {
        OptionRow(icon: "tag.fill", iconColor: .purple, label: "标签") {
            VStack(spacing: 10) {
                searchField(text: $tagQuery, placeholder: "搜索标签")

                if scrollsList {
                    ScrollView {
                        tagRows
                    }
                    .frame(maxHeight: 200)
                } else {
                    tagRows
                }
            }
        }
    }

    var tagRows: some View {
        VStack(spacing: 6) {
            ForEach(pendingTagNames, id: \.self) { name in
                pendingTagRow(name)
            }
            ForEach(filteredTags) { tag in
                tagRow(tag)
            }

            if store.tags.isEmpty && pendingTagNames.isEmpty {
                emptySelectorText("暂无标签")
            } else if filteredTags.isEmpty {
                emptySelectorText("无匹配标签")
            }
        }
    }

    var filteredProjects: [Project] {
        guard !projectQuery.isEmpty else { return store.projects }
        return store.projects.filter { $0.name.localizedCaseInsensitiveContains(projectQuery) }
    }

    var filteredTags: [TagItem] {
        guard !tagQuery.isEmpty else { return store.tags }
        return store.tags.filter { $0.name.localizedCaseInsensitiveContains(tagQuery) }
    }

    func statusRow(_ status: TodoStatus) -> some View {
        let isSelected = edited.status == status
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                edited.status = status
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? status.theme.background : Color.labelSecondary)
                Text(status.displayName)
                    .appFont(.subheadline, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? status.theme.softBackground : Color.clear)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func projectRow(_ project: Project?) -> some View {
        let isSelected = edited.projectId == project?.id && (project != nil || pendingProjectName == nil)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                edited.projectId = project?.id
                pendingProjectName = nil
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "folder.fill")
                    .foregroundStyle(isSelected ? .blue : Color.labelSecondary)
                    .symbolRenderingMode(.hierarchical)
                Text(project?.name ?? "无项目")
                    .appFont(.subheadline, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color.blue.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func pendingProjectRow(_ name: String) -> some View {
        Button {
            pendingProjectName = nil
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text("将创建：\(name)")
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "xmark")
                    .foregroundStyle(Color.labelSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.blue.opacity(0.14))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func tagRow(_ tag: TagItem) -> some View {
        let isSelected = edited.tagIds.contains(tag.id)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if isSelected {
                    edited.tagIds.removeAll { $0 == tag.id }
                } else {
                    edited.tagIds.append(tag.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "tag.fill")
                    .foregroundStyle(isSelected ? Color(hex: tag.colorHex) : Color.labelSecondary)
                    .symbolRenderingMode(.hierarchical)
                Text(tag.name)
                    .appFont(.subheadline, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color(hex: tag.colorHex).opacity(0.16) : Color.clear)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    func pendingTagRow(_ name: String) -> some View {
        Button {
            pendingTagNames.removeAll { $0 == name }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.purple)
                Text("将创建：\(name)")
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "xmark")
                    .foregroundStyle(Color.labelSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.purple.opacity(0.14))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
