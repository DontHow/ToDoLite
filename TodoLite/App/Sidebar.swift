import SwiftUI

#if os(macOS)
struct Sidebar: View {
    @Binding var selection: ContentView.Tab

    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: ContentView.Tab.today) {
                Label("今日", systemImage: "sun.max.fill")
            }
            NavigationLink(value: ContentView.Tab.inbox) {
                Label("收件箱", systemImage: "tray.fill")
            }
            NavigationLink(value: ContentView.Tab.overdue) {
                Label("逾期", systemImage: "exclamationmark.triangle")
            }
            NavigationLink(value: ContentView.Tab.upcoming) {
                Label("即将到来", systemImage: "calendar")
            }
            NavigationLink(value: ContentView.Tab.board) {
                Label("看板", systemImage: "rectangle.3.group.fill")
            }
            NavigationLink(value: ContentView.Tab.projects) {
                Label("项目", systemImage: "folder")
            }
            NavigationLink(value: ContentView.Tab.tags) {
                Label("标签", systemImage: "tag")
            }
            NavigationLink(value: ContentView.Tab.search) {
                Label("搜索", systemImage: "magnifyingglass")
            }

            Section("历史") {
                NavigationLink(value: ContentView.Tab.done) {
                    Label("已完成", systemImage: "checkmark.circle")
                }
                NavigationLink(value: ContentView.Tab.archive) {
                    Label("已归档", systemImage: "archivebox")
                }
            }

            Section("设置") {
                NavigationLink(value: ContentView.Tab.settings) {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
#endif
