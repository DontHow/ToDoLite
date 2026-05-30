#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @State private var store = TodoStore.shared

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
            openApp()
        }
        .keyboardShortcut("n", modifiers: .command)

        Divider()

        Button("打开 办他") {
            openApp()
        }

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
#endif
