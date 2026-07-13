import SwiftUI

extension CreateTodoView {
    var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    do {
                        try await store.archiveTodo(id: edited.id)
                        dismiss()
                    } catch {
                        errorMessage = "归档失败: \(error.localizedDescription)"
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox.fill")
                        .appFont(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("归档任务")
                        .appFont(.body, weight: .medium)
                    Spacer()
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                Task {
                    do {
                        try await store.deleteTodo(id: edited.id)
                        dismiss()
                    } catch {
                        errorMessage = "删除失败: \(error.localizedDescription)"
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .appFont(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("删除任务")
                        .appFont(.body, weight: .medium)
                    Spacer()
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
    }

    var primarySaveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: todo == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .appFont(.title3)
                Text(todo == nil ? "创建任务" : "保存")
                    .appFont(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSave ? Color.accentColor : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canSave)
        .buttonStyle(.plain)
    }

    var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()

            primarySaveButton
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}
