import SwiftUI

#if os(macOS)
struct Sidebar: View {
    @Binding var selection: ContentView.Tab

    var body: some View {
        List(selection: $selection) {
            Label("今日", systemImage: "sun.max.fill").tag(ContentView.Tab.today)
            Label("收件箱", systemImage: "tray.fill").tag(ContentView.Tab.inbox)
            Label("逾期", systemImage: "exclamationmark.triangle").tag(ContentView.Tab.overdue)
            Label("即将到来", systemImage: "calendar").tag(ContentView.Tab.upcoming)
            Label("看板", systemImage: "rectangle.3.group.fill").tag(ContentView.Tab.board)
            Label("项目", systemImage: "folder").tag(ContentView.Tab.projects)
            Label("标签", systemImage: "tag").tag(ContentView.Tab.tags)
            Label("搜索", systemImage: "magnifyingglass").tag(ContentView.Tab.search)

            Section("历史") {
                Label("已完成", systemImage: "checkmark.circle").tag(ContentView.Tab.done)
                Label("已归档", systemImage: "archivebox").tag(ContentView.Tab.archive)
            }

            Section("设置") {
                Label("设置", systemImage: "gearshape.fill").tag(ContentView.Tab.settings)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
#endif
