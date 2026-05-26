import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today, inbox, board, search, settings
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            Sidebar(selection: $selectedTab)
        } detail: {
            switch selectedTab {
            case .today: TodayView()
            case .inbox: InboxView()
            case .board: BoardView()
            case .search: SearchView()
            case .settings: SettingsView()
            }
        }
        #else
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("今日", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            InboxView()
                .tabItem { Label("收件箱", systemImage: "tray.fill") }
                .tag(Tab.inbox)

            BoardView()
                .tabItem { Label("看板", systemImage: "columns") }
                .tag(Tab.board)

            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        #endif
    }
}
