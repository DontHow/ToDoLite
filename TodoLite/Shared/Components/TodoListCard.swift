import SwiftUI

struct TodoListCard: View {
    let todo: TodoItem
    var isDraggable: Bool = false

    @State private var store = TodoStore.shared
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(destination: CreateTodoView(todo: todo)) {
                TodoRowView(todo: todo)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle())

            if showsActionBar {
                Divider()
                    .padding(.horizontal, 16)

                actionBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
        )
        .draggable(isDraggable ? todo.id : "")
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            regularActionBar

            HStack {
                Spacer(minLength: 0)
                compactActionMenu
            }
        }
    }

    private var regularActionBar: some View {
        HStack(spacing: 12) {
            completionButton

            Spacer(minLength: 8)

            if canReschedule {
                rescheduleMenu
            }
        }
    }

    private var compactActionMenu: some View {
        Menu {
            Button {
                toggleCompletion()
            } label: {
                Label(
                    todo.status == .done ? "重新打开" : "标记完成",
                    systemImage: todo.status == .done ? "arrow.uturn.backward" : "checkmark"
                )
            }

            if canReschedule {
                Divider()
                ForEach(TodoReschedulePreset.allCases) { preset in
                    Button {
                        reschedule(to: preset)
                    } label: {
                        Label("重新排期至\(preset.title)", systemImage: "calendar.badge.plus")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "ellipsis.circle")
                Text("操作")
            }
            .appFont(.caption, weight: .medium)
            .foregroundStyle(Color.labelSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.chipBackground)
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("操作\(todo.title)")
    }

    private var completionButton: some View {
        Button {
            toggleCompletion()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: todo.status == .done ? "arrow.uturn.backward" : "checkmark")
                Text(todo.status == .done ? "重新打开" : "标记完成")
            }
            .appFont(.caption, weight: .medium)
            .foregroundStyle(SectionTheme.done.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SectionTheme.done.softBackground)
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.status == .done ? "重新打开\(todo.title)" : "标记\(todo.title)为完成")
    }

    private var rescheduleMenu: some View {
        Menu {
            ForEach(TodoReschedulePreset.allCases) { preset in
                Button {
                    reschedule(to: preset)
                } label: {
                    Label(preset.title, systemImage: "calendar.badge.plus")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                Text("重新排期")
            }
            .appFont(.caption, weight: .medium)
            .foregroundStyle(SectionTheme.upcoming.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(SectionTheme.upcoming.softBackground)
            .clipShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("重新排期\(todo.title)")
    }

    private var canReschedule: Bool {
        todo.status != .done && todo.status != .archived
    }

    private var showsActionBar: Bool {
        todo.status != .archived
    }

    private func toggleCompletion() {
        Task {
            do {
                try await store.toggleComplete(id: todo.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reschedule(to preset: TodoReschedulePreset) {
        guard let dueDate = preset.dueDate() else { return }
        var updated = todo
        updated.dueAt = dueDate

        Task {
            do {
                try await store.updateTodo(updated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
