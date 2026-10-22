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
        #if os(macOS)
        Window("办它", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands { TodoCommands() }
        MenuBarExtra("办他", systemImage: "checklist") {
            MenuBarView()
        }
        #else
        WindowGroup { ContentView() }
        #endif
    }
}
