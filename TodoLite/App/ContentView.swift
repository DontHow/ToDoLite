import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .today
    @State private var store = TodoStore.shared
    @State private var automaticUpdateResult: UpdateChecker.Result?
    @State private var showAutomaticUpdateAlert = false

    enum Tab: Hashable {
        case today, inbox, board, search, settings, done, archive, projects, tags
    }

    private var detailView: some View {
        Group {
            switch selectedTab {
            case .today: TodayView()
            case .inbox: InboxView()
            case .board: BoardView()
            case .search: SearchView()
            case .settings: SettingsView()
            case .done: NavigationStack { DoneView() }
            case .archive: NavigationStack { ArchiveView() }
            case .projects: ProjectListView()
            case .tags: TagListView()
            }
        }
    }

    var body: some View {
        let fontSizeOption = FontSizeOption(level: store.fontSizeLevel) ?? .standard
        Group {
        #if os(macOS)
        NavigationSplitView {
            Sidebar(selection: $selectedTab)
        } detail: {
            detailView
        }
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
        #endif
        }
        .disabled(store.loadState != .loaded)
        .overlay {
            if store.loadState != .loaded {
                VStack(spacing: 16) {
                    if case .failed(let message) = store.loadState {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("数据加载失败").font(.headline)
                        Text(message).foregroundStyle(.secondary)
                        Button("重试") { Task { await initializeStore() } }
                    } else {
                        ProgressView("正在加载任务…")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.cardBackground)
            }
        }
        .alert("操作提示", isPresented: Binding(
            get: { store.operationError != nil },
            set: { if !$0 { store.operationError = nil } }
        )) {
            Button("确定", role: .cancel) { store.operationError = nil }
        } message: {
            Text(store.operationError ?? "")
        }
        .appFontPreference(followsSystem: store.followsSystemFont, option: fontSizeOption)
        .sheet(isPresented: $store.showingCreateTodo) { CreateTodoView() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.loadState == .loaded else { return }
            Task {
                await store.refreshFocusIfNeeded()
                await checkForUpdatesAutomatically()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            guard store.loadState == .loaded else { return }
            Task { await store.refreshFocusIfNeeded() }
        }
        .task {
            await initializeStore()
            await checkForUpdatesAutomatically()
        }
        .alert("发现新版本", isPresented: $showAutomaticUpdateAlert) {
            Button("前往下载") { openAutomaticUpdateURL() }
            Button("稍后", role: .cancel) { }
        } message: {
            if let result = automaticUpdateResult {
                Text("当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)")
            }
        }
    }

    private func initializeStore() async {
        await store.initialize()
        if store.loadState == .loaded {
            await iCloudSyncManager.shared.startMonitoring()
        }
    }

    private func checkForUpdatesAutomatically() async {
        guard let result = await UpdateChecker.shared.checkAutomaticallyIfNeeded(), result.hasUpdate else {
            return
        }
        automaticUpdateResult = result
        showAutomaticUpdateAlert = true
    }

    private func openAutomaticUpdateURL() {
        guard let url = automaticUpdateResult?.downloadURL else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
