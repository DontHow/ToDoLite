import SwiftUI

struct CreateTodoView: View {
    let todo: TodoItem?

    @State var store = TodoStore.shared
    @State var edited: TodoItem
    @State var errorMessage: String?
    @State var parseMessage: String?
    @State var parseError: String?
    @State var isParsingLLM = false
    @State var pendingProjectName: String?
    @State var pendingTagNames: [String] = []
    @State var projectQuery = ""
    @State var tagQuery = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FocusState var detailTitleFocused: Bool

    init(todo: TodoItem? = nil) {
        self.todo = todo
        if let todo = todo {
            _edited = State(initialValue: todo)
        } else {
            var newTodo = TodoItem(title: "")
            newTodo.dueAt = defaultDueDate()
            _edited = State(initialValue: newTodo)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(iOS)
                ScrollView {
                    detailForm
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if todo == nil {
                        saveButtonBar
                    }
                }
                #else
                if todo == nil && usesWideDetailLayout {
                    VStack(spacing: 0) {
                        wideDetailForm
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                        saveButtonBar
                    }
                } else {
                    ScrollView {
                        detailForm
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if todo == nil {
                            saveButtonBar
                        }
                    }
                }
                #endif
            }
            .navigationTitle(todo == nil ? "新建任务" : "编辑任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                if todo != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                #endif
                if todo != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .alert("错误", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 1160, idealWidth: 1240, minHeight: 580, idealHeight: 640)
        #endif
    }

    var canSave: Bool {
        !edited.title.isEmpty
    }

    func save() async {
        do {
            let resolved = try await resolvePendingMetadata(in: edited)
            if todo != nil {
                try await store.updateTodo(resolved)
                dismiss()
            } else {
                try await store.createTodo(
                    title: resolved.title,
                    description: resolved.description,
                    status: resolved.status,
                    projectId: resolved.projectId,
                    tagIds: resolved.tagIds,
                    scheduledAt: resolved.scheduledAt,
                    dueAt: resolved.dueAt
                )
                dismiss()
            }
        } catch {
            if todo != nil {
                errorMessage = "保存失败: \(error.localizedDescription)"
            } else {
                errorMessage = "创建失败: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CreateTodoView()
}

#Preview("编辑任务") {
    let todo = TodoItem(title: "示例任务")
    return CreateTodoView(todo: todo)
}
