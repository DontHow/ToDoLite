import SwiftUI

struct CreateTodoView: View {
    let todo: TodoItem?

    @State var store = TodoStore.shared
    @State var edited: TodoItem
    @State var useQuickEntry = true
    @State var parsedDraft: TodoDraft?
    @State var isParsingLLM = false
    @State var llmError: String?
    @State var errorMessage: String?
    @State var projectQuery = ""
    @State var tagQuery = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FocusState var quickEntryFocused: Bool
    @FocusState var detailTitleFocused: Bool

    init(todo: TodoItem? = nil) {
        self.todo = todo
        if let todo = todo {
            _edited = State(initialValue: todo)
            _useQuickEntry = State(initialValue: false)
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
                    VStack(spacing: 10) {
                        if todo == nil && useQuickEntry {
                            modeToggle
                        }

                        if todo == nil && useQuickEntry {
                            quickEntryArea
                        } else {
                            detailForm
                        }
                    }
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
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 10) {
                            if todo == nil && useQuickEntry {
                                modeToggle
                            }

                            if todo == nil && useQuickEntry {
                                quickEntryArea
                            } else {
                                detailForm
                            }

                            Spacer().frame(height: todo == nil ? 100 : 24)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    if todo == nil {
                        saveButtonBar
                    }
                }
                #endif
            }
            .navigationTitle(todo == nil ? "新建任务" : "编辑任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
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
        .frame(minWidth: 900)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    var canSave: Bool {
        if todo == nil && useQuickEntry {
            !(parsedDraft?.title.isEmpty ?? true)
        } else {
            !edited.title.isEmpty
        }
    }

    func save() async {
        if todo != nil {
            do {
                try await store.updateTodo(edited)
                dismiss()
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
        } else if useQuickEntry, let draft = parsedDraft {
            try? await store.createTodoWithParsed(
                title: draft.title,
                description: draft.description,
                status: .inbox,
                projectName: draft.projectName,
                tagNames: draft.tagNames,
                dueAt: draft.dueAt ?? defaultDueDate()
            )
            dismiss()
        } else {
            try? await store.createTodo(
                title: edited.title,
                description: edited.description,
                status: edited.status,
                projectId: edited.projectId,
                tagIds: edited.tagIds,
                dueAt: edited.dueAt
            )
            dismiss()
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
