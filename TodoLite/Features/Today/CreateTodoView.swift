import SwiftUI

struct CreateTodoView: View {
    let todo: TodoItem?

    @State var store = TodoStore.shared
    @State var edited: TodoItem
    @State var errorMessage: String?
    @State var parseMessage: String?
    @State var parseError: String?
    @State var isParsingLLM = false
    @State var isSaving = false
    @State var llmParsingTask: Task<Void, Never>?
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
            .disabled(isSaving)
            .navigationTitle(todo == nil ? "新建任务" : "编辑任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                if todo != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }.disabled(isSaving)
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(isSaving)
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
        .interactiveDismissDisabled(isSaving)
        .onDisappear { llmParsingTask?.cancel() }
        #if os(macOS)
        .frame(minWidth: 1160, idealWidth: 1240, minHeight: 580, idealHeight: 640)
        #endif
    }

    var canSave: Bool {
        !edited.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving && !isParsingLLM
    }

    @MainActor
    func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveDraft(edited, creating: todo == nil,
                                      projectName: pendingProjectName, tagNames: pendingTagNames)
            dismiss()
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
