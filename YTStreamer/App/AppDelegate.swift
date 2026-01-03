import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var mainWindowController: MainWindowController?
    private let streamManager = StreamManager.shared

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()

        // Show in dock for visibility (can hide again later if needed)
        // NSApp.setActivationPolicy(.accessory)
        
        // Auto-show main window on first launch for better visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        streamManager.stopServer()
    }

    // MARK: - Menu Bar Setup
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Try SF Symbol first, fallback to text
            if let image = NSImage(systemSymbolName: "music.note.house", accessibilityDescription: "YT Streamer") {
                button.image = image
            } else {
                // Fallback for older macOS versions
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
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
