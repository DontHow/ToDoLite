import SwiftUI

@main
struct TodoLiteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? await FileSystemManager.shared.setupDirectories()
                    try? await TodoStore.shared.loadAll()
                    iCloudSyncManager.shared.startMonitoring()
                }
        }

        #if os(macOS)
        MenuBarExtra("TodoLite", systemImage: "checklist") {
            MenuBarView()
        }
        #endif
    }
}
