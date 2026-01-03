import Cocoa
import Combine

/// Main window controller for full app interface
class MainWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "YT Streamer"
        window.center()
        window.contentViewController = MainViewController()

        self.init(window: window)
    }
}

/// Main view controller with sidebar and content
class MainViewController: NSViewController {

    private let streamManager = StreamManager.shared
    private let queue = TrackQueue.shared
    private var cancellables = Set<AnyCancellable>()

    // UI Elements
    private let splitView = NSSplitView()
    private let sidebarView = NSView()
    private let contentView = NSView()
    private let queueTableView = NSTableView()

    // Content UI
    private let thumbnailImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "No track playing")
    private let artistLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let streamURLLabel = NSTextField(labelWithString: "")
    private let urlTextField = NSTextField()
    private let addButton = NSButton()
    private let progressIndicator = NSProgressIndicator()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindToStreamManager()
    }

    private func setupUI() {
        // Split view
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        setupSidebar()
        setupContent()

        splitView.addArrangedSubview(sidebarView)
        splitView.addArrangedSubview(contentView)

        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
    }

    private func setupSidebar() {
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let label = NSTextField(labelWithString: "Queue")
        label.font = .boldSystemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(label)

        // Table view for queue
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = queueTableView

        queueTableView.headerView = nil
        queueTableView.dataSource = self
        queueTableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.title = "Track"
        queueTableView.addTableColumn(column)

        sidebarView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 12),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor)
        ])
    }

    private func setupContent() {
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        // Thumbnail
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        thumbnailImageView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        // Title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        // Artist
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.alignment = .center

        // Status
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .tertiaryLabelColor

        // Progress
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.isHidden = true

        // Stream URL
        streamURLLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        streamURLLabel.textColor = .systemBlue
        streamURLLabel.isSelectable = true
        streamURLLabel.alignment = .center

        // URL Input
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.spacing = 8

        urlTextField.placeholderString = "Paste YouTube URL..."
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.widthAnchor.constraint(equalToConstant: 300).isActive = true

        addButton.title = "Add & Play"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addTrack)

        inputStack.addArrangedSubview(urlTextField)
        inputStack.addArrangedSubview(addButton)

        stack.addArrangedSubview(thumbnailImageView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(artistLabel)
        stack.addArrangedSubview(progressIndicator)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(streamURLLabel)
        stack.addArrangedSubview(inputStack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            progressIndicator.widthAnchor.constraint(equalToConstant: 300)
        ])
    }

    private func bindToStreamManager() {
        streamManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.titleLabel.stringValue = track?.title ?? "No track playing"
                self?.artistLabel.stringValue = track?.artist ?? ""

                // Load thumbnail
                if let urlString = track?.thumbnailURL,
                   let url = URL(string: urlString) {
                    self?.loadThumbnail(from: url)
                } else {
                    self?.thumbnailImageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
                }

                self?.queueTableView.reloadData()
            }
            .store(in: &cancellables)

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

        streamManager.$streamURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.streamURLLabel.stringValue = url ?? ""
            }
            .store(in: &cancellables)
    }

    private func loadThumbnail(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = image
            }
        }.resume()
    }

    @objc private func addTrack() {
        let url = urlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        streamManager.addAndPlay(url: url)
        urlTextField.stringValue = ""
    }
}

// MARK: - NSTableViewDataSource & Delegate
extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return queue.tracks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let track = queue.tracks[row]

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: track.title)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        // Highlight current track
        if row == queue.currentIndex {
            textField.font = .boldSystemFont(ofSize: 13)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
}
