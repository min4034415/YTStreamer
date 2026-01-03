import Foundation
import Combine

/// Coordinates downloading, converting, and serving audio
class StreamManager: ObservableObject {

    static let shared = StreamManager()

    // MARK: - Published Properties
    @Published var currentTrack: Track?
    @Published var status: StreamStatus = .idle
    @Published var downloadProgress: Double = 0
    @Published var streamURL: String?
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let downloader = YouTubeDownloader.shared
    private let converter = AudioConverter.shared
    private let server = HTTPServer()
    private let networkInfo = NetworkInfo.shared
    private let queue = TrackQueue.shared

    private var currentProcess: Process?

    enum StreamStatus: String {
        case idle = "Ready"
        case fetchingMetadata = "Fetching info..."
        case downloading = "Downloading..."
        case converting = "Converting..."
        case serving = "Streaming"
        case error = "Error"
    }

    private init() {}

    // MARK: - Public Methods

    /// Add a YouTube URL to the queue and start processing
    func addAndPlay(url: String) {
        var track = Track(youtubeURL: url)
        queue.add(track)

        status = .fetchingMetadata
        errorMessage = nil

        // Fetch metadata first
        downloader.fetchMetadata(for: url) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let metadata):
                track.title = metadata.title
                track.artist = metadata.artist
                track.thumbnailURL = metadata.thumbnailURL
                track.duration = metadata.duration
                self.queue.update(track)
                self.currentTrack = track
                self.startDownload(track: track)

            case .failure(let error):
                self.status = .error
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Stop streaming and clean up
    func stopServer() {
        currentProcess?.terminate()
        currentProcess = nil
        server.stop()
        status = .idle
        streamURL = nil
    }

    /// Play next track in queue
    func playNext() {
        guard let next = queue.next() else { return }
        startDownload(track: next)
    }

    /// Play previous track in queue
    func playPrevious() {
        guard let prev = queue.previous() else { return }
        startDownload(track: prev)
    }

    // MARK: - Private Methods

    private func startDownload(track: Track) {
        status = .downloading
        downloadProgress = 0

        var updatedTrack = track
        updatedTrack.status = .downloading

        currentProcess = downloader.download(
            url: track.youtubeURL,
            onProgress: { [weak self] progress in
                self?.downloadProgress = progress / 100.0
            },
            completion: { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let filePath):
                    updatedTrack.localFilePath = filePath
                    updatedTrack.status = .converting
                    self.queue.update(updatedTrack)
                    self.currentTrack = updatedTrack
                    self.startConversion(track: updatedTrack, inputPath: filePath)

                case .failure(let error):
                    updatedTrack.status = .failed
                    self.queue.update(updatedTrack)
                    self.status = .error
                    self.errorMessage = error.localizedDescription
                }
            }
        )
    }

    private func startConversion(track: Track, inputPath: String) {
        status = .converting

        var updatedTrack = track

        currentProcess = converter.convertToMP3(
            inputPath: inputPath,
            onProgress: { _ in
                // Could show conversion progress
            },
            completion: { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let mp3Path):
                    updatedTrack.localFilePath = mp3Path
                    updatedTrack.status = .ready
                    self.queue.update(updatedTrack)
                    self.currentTrack = updatedTrack
                    self.startServer(filePath: mp3Path)

                case .failure(let error):
                    updatedTrack.status = .failed
                    self.queue.update(updatedTrack)
                    self.status = .error
                    self.errorMessage = error.localizedDescription
                }
            }
        )
    }

    private func startServer(filePath: String) {
        // Stop existing server if running
        server.stop()

        server.start(servingFile: filePath, port: 8000) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                self.status = .serving
                self.streamURL = self.networkInfo.streamURL()

                // Update track status
                if var track = self.currentTrack {
                    track.status = .playing
                    self.queue.update(track)
                    self.currentTrack = track
                }

            case .failure(let error):
                self.status = .error
                self.errorMessage = "Failed to start server: \(error.localizedDescription)"
            }
        }
    }
}
