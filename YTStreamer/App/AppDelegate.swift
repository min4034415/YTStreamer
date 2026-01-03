import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var mainWindow: NSWindow!
    private let streamManager = StreamManager.shared

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched!")
        
        setupMenuBar()
        setupPopover()
        createAndShowMainWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        streamManager.stopServer()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // MARK: - Window Setup
    private func createAndShowMainWindow() {
        print("Creating main window...")
        
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = "YT Streamer"
        mainWindow.isReleasedWhenClosed = false
        mainWindow.setFrameAutosaveName("")  // Disable state restoration
        mainWindow.contentViewController = MainViewController()
        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.orderFrontRegardless()  // Force to front even if app isn't active
        
        NSApp.activate(ignoringOtherApps: true)
        
        print("Window should be visible now!")
    }

    // MARK: - Menu Bar Setup
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "music.note.house", accessibilityDescription: "YT Streamer") {
                button.image = image
            } else {
                button.title = "♪"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = MenuBarViewController()
    }

    // MARK: - Actions
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
