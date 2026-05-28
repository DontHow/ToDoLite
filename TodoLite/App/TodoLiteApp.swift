import SwiftUI

#if os(macOS)
import AppKit

class TodoLiteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApplication.shared.windows {
            window.minSize = NSSize(width: 1000, height: 500)
        }
    }
}
#endif

@main
struct TodoLiteApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(TodoLiteAppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    try? await FileSystemManager.shared.setupDirectories()
                    try? await TodoStore.shared.loadAll()
                    iCloudSyncManager.shared.startMonitoring()
                }
        }
        .defaultSize(width: 1200, height: 800)

        #if os(macOS)
        MenuBarExtra("TodoLite", systemImage: "checklist") {
            MenuBarView()
        }
        #endif
    }
}
