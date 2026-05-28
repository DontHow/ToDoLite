import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .today
    @State private var store = TodoStore.shared

    enum Tab: Hashable {
        case today, inbox, board, search, settings, done, archive, projects, tags
    }

    var body: some View {
        let fontSize = FontSizeOption(level: store.fontSizeLevel)?.dynamicTypeSize ?? .medium
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
            case .done: DoneView()
            case .archive: ArchiveView()
            case .projects: ProjectListView()
            case .tags: TagListView()
            }
        }
        .dynamicTypeSize(fontSize)
        .onKeyPress(characters: .init(charactersIn: "1")) { press in
            guard press.modifiers == .command else { return .ignored }
            selectedTab = .today
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "2")) { press in
            guard press.modifiers == .command else { return .ignored }
            selectedTab = .inbox
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "3")) { press in
            guard press.modifiers == .command else { return .ignored }
            selectedTab = .board
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "k")) { press in
            guard press.modifiers == .command else { return .ignored }
            selectedTab = .search
            return .handled
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
                .tabItem { Label("看板", systemImage: "rectangle.3.group.fill") }
                .tag(Tab.board)

            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .dynamicTypeSize(fontSize)
        #endif
    }
}
