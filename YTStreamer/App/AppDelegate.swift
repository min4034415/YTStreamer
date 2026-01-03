import SwiftUI

@main
struct YTStreamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 700, height: 500)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let streamManager = StreamManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force app to be a regular app (show in Dock) for Xcode debugging
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        streamManager.stopServer()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "music.note.house", accessibilityDescription: "YT Streamer") {
                button.image = image
            } else {
                button.title = "♪"
            }
            button.action = #selector(menuBarClicked)
            button.target = self
        }
    }
    
    @objc private func menuBarClicked() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func closePopover() {
        // No longer using popover in SwiftUI version
    }
}
