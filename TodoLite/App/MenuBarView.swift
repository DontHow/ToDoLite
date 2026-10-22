#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @State private var store = TodoStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.focusTodos.isEmpty {
            Text("今天没有任务")
                .foregroundStyle(Color.labelSecondary)
        } else {
            ForEach(store.focusTodos.prefix(5)) { todo in
                Button(todo.title) {
                    openApp()
                }
            }
        }

        if store.focusTodos.count > 5 {
            Text("还有 \(store.focusTodos.count - 5) 个任务...")
                .foregroundStyle(Color.labelSecondary)
        }

        Divider()

        Button("新建任务...") {
            store.showingCreateTodo = true
            openApp()
        }
        .disabled(store.loadState != .loaded)

        Divider()

        Button("打开 办他") {
            openApp()
        }

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openApp() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

struct TodoCommands: Commands {
    @State private var store = TodoStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建任务") {
                store.showingCreateTodo = true
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(store.loadState != .loaded)
        }
    }
}
#endif
