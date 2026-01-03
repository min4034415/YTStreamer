import Cocoa
import Combine

/// Menu bar popover view controller
class MenuBarViewController: NSViewController {

    // MARK: - UI Elements
    private let urlTextField = NSTextField()
    private let addButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let progressIndicator = NSProgressIndicator()
    private let trackTitleLabel = NSTextField(labelWithString: "No track")
    private let trackArtistLabel = NSTextField(labelWithString: "")
    private let streamURLField = NSTextField()
    private let copyButton = NSButton()
    private let stopButton = NSButton()
    private let openWindowButton = NSButton()
    private let quitButton = NSButton()

    private let streamManager = StreamManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindToStreamManager()
    }

    // MARK: - UI Setup
    private func setupUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        // Title
        let titleLabel = NSTextField(labelWithString: "YT Streamer")
        titleLabel.font = .boldSystemFont(ofSize: 16)

        // URL Input
        urlTextField.placeholderString = "Paste YouTube URL..."
        urlTextField.translatesAutoresizingMaskIntoConstraints = false

        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addTrack)

        let inputStack = NSStackView(views: [urlTextField, addButton])
        inputStack.orientation = .horizontal
        inputStack.spacing = 8

        // Progress
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.isHidden = true

        // Status
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        // Now Playing
        let nowPlayingLabel = NSTextField(labelWithString: "Now Playing")
        nowPlayingLabel.font = .boldSystemFont(ofSize: 12)
        nowPlayingLabel.textColor = .secondaryLabelColor

        trackTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        trackTitleLabel.lineBreakMode = .byTruncatingTail

        trackArtistLabel.font = .systemFont(ofSize: 12)
        trackArtistLabel.textColor = .secondaryLabelColor

        // Stream URL
        let streamLabel = NSTextField(labelWithString: "Stream URL")
        streamLabel.font = .boldSystemFont(ofSize: 12)
        streamLabel.textColor = .secondaryLabelColor

        streamURLField.isEditable = false
        streamURLField.isSelectable = true
        streamURLField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        streamURLField.stringValue = "Not streaming"

        copyButton.title = "Copy"
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyStreamURL)

        let urlStack = NSStackView(views: [streamURLField, copyButton])
        urlStack.orientation = .horizontal
        urlStack.spacing = 8

        // Controls
        stopButton.title = "Stop Streaming"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopStreaming)

        openWindowButton.title = "Open Full Window"
        openWindowButton.bezelStyle = .rounded
        openWindowButton.target = self
        openWindowButton.action = #selector(openMainWindow)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator

        // Quit
        quitButton.title = "Quit"
        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitApp)

        // Add all to stack
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(inputStack)
        stack.addArrangedSubview(progressIndicator)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(makeSpacer(height: 8))
        stack.addArrangedSubview(nowPlayingLabel)
        stack.addArrangedSubview(trackTitleLabel)
        stack.addArrangedSubview(trackArtistLabel)
        stack.addArrangedSubview(makeSpacer(height: 8))
        stack.addArrangedSubview(streamLabel)
        stack.addArrangedSubview(urlStack)
        stack.addArrangedSubview(makeSpacer(height: 8))
        stack.addArrangedSubview(stopButton)
        stack.addArrangedSubview(openWindowButton)
        stack.addArrangedSubview(separator)
        stack.addArrangedSubview(quitButton)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            urlTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            streamURLField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
        ])
    }

    private func makeSpacer(height: CGFloat) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    // MARK: - Bindings
    private func bindToStreamManager() {
        streamManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.statusLabel.stringValue = status.rawValue
                self?.progressIndicator.isHidden = (status != .downloading)
            }
            .store(in: &cancellables)

        streamManager.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progressIndicator.doubleValue = progress
            }
            .store(in: &cancellables)

        streamManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.trackTitleLabel.stringValue = track?.title ?? "No track"
                self?.trackArtistLabel.stringValue = track?.artist ?? ""
            }
            .store(in: &cancellables)

        streamManager.$streamURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.streamURLField.stringValue = url ?? "Not streaming"
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    @objc private func addTrack() {
        let url = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        streamManager.addAndPlay(url: url)
        urlTextField.stringValue = ""
    }

    @objc private func copyStreamURL() {
        guard let url = streamManager.streamURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)

        // Visual feedback
        copyButton.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.copyButton.title = "Copy"
        }
    }

    @objc private func stopStreaming() {
        streamManager.stopServer()
    }

    @objc private func openMainWindow() {
        (NSApp.delegate as? AppDelegate)?.showMainWindow()
        (NSApp.delegate as? AppDelegate)?.closePopover()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
