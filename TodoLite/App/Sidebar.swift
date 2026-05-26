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
            NavigationLink(value: ContentView.Tab.board) {
                Label("看板", systemImage: "columns")
            }
            NavigationLink(value: ContentView.Tab.search) {
                Label("搜索", systemImage: "magnifyingglass")
            }
            NavigationLink(value: ContentView.Tab.settings) {
                Label("设置", systemImage: "gearshape.fill")
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
#endif
