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
    private let trackQueue = TrackQueue.shared
    
    var queue: [Track] { trackQueue.tracks }

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
        print("📥 addAndPlay called with URL: \(url)")
        
        // Check if it's a playlist
        if url.contains("list=") {
            addPlaylist(url: url)
            return
        }
        
        addSingleVideo(url: url)
    }
    
    /// Add a single video to the queue
    private func addSingleVideo(url: String) {
        var track = Track(youtubeURL: url)
        trackQueue.add(track)

        DispatchQueue.main.async {
            self.status = .fetchingMetadata
            self.errorMessage = nil
            print("📥 Status set to fetchingMetadata")
        }

        // Fetch metadata first
        downloader.fetchMetadata(for: url) { [weak self] result in
            guard let self = self else { return }
            
            print("📥 Metadata fetch completed")

            switch result {
            case .success(let metadata):
                print("📥 Metadata success: \(metadata.title)")
                track.title = metadata.title
                track.artist = metadata.artist
                track.thumbnailURL = metadata.thumbnailURL
                track.duration = metadata.duration
                self.trackQueue.update(track)
                
                DispatchQueue.main.async {
                    self.currentTrack = track
                    self.objectWillChange.send()
                }
                
                self.startDownload(track: track)

            case .failure(let error):
                print("📥 Metadata error: \(error)")
                DispatchQueue.main.async {
                    self.status = .error
                    self.errorMessage = error.localizedDescription
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    /// Add all videos from a playlist to the queue
    private func addPlaylist(url: String) {
        DispatchQueue.main.async {
            self.status = .fetchingMetadata
            self.errorMessage = nil
            print("📋 Fetching playlist...")
        }
        
        downloader.fetchPlaylistMetadata(for: url) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let metadataList):
                print("📋 Adding \(metadataList.count) videos to queue")
                
                // Add all tracks to queue
                for (index, metadata) in metadataList.enumerated() {
                    guard let videoURL = metadata.videoURL else { continue }
                    
                    var track = Track(youtubeURL: videoURL)
                    track.title = metadata.title
                    track.artist = metadata.artist
                    track.thumbnailURL = metadata.thumbnailURL
                    track.duration = metadata.duration
                    self.trackQueue.add(track)
                    
                    // Start playing the first track
                    if index == 0 {
                        DispatchQueue.main.async {
                            self.currentTrack = track
                            self.objectWillChange.send()
                        }
                        self.startDownload(track: track)
                    }
                }
                
            case .failure(let error):
                print("📋 Playlist error: \(error)")
                DispatchQueue.main.async {
                    self.status = .error
                    self.errorMessage = "Failed to load playlist: \(error.localizedDescription)"
                    self.objectWillChange.send()
                }
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
        guard let next = trackQueue.next() else { return }
        startDownload(track: next)
    }

    /// Play previous track in queue
    func playPrevious() {
        guard let prev = trackQueue.previous() else { return }
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
                    self.trackQueue.update(updatedTrack)
                    self.currentTrack = updatedTrack
                    self.startConversion(track: updatedTrack, inputPath: filePath)

                case .failure(let error):
                    updatedTrack.status = .failed
                    self.trackQueue.update(updatedTrack)
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
                    self.trackQueue.update(updatedTrack)
                    self.currentTrack = updatedTrack
                    self.startServer(filePath: mp3Path)

                case .failure(let error):
                    updatedTrack.status = .failed
                    self.trackQueue.update(updatedTrack)
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
                DispatchQueue.main.async {
                    self.status = .serving
                    self.streamURL = self.networkInfo.streamURL(port: self.server.port)
                    self.objectWillChange.send()

                    // Update track status
                    if var track = self.currentTrack {
                        track.status = .playing
                        self.trackQueue.update(track)
                        self.currentTrack = track
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self.status = .error
                    self.errorMessage = "Failed to start server: \(error.localizedDescription)"
                    self.objectWillChange.send()
                }
            }
        }
    }
}
