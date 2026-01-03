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
    @Published var activePort: UInt16?
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let downloader = YouTubeDownloader.shared
    private let converter = AudioConverter.shared
    private let server = HTTPServer()
    private let networkInfo = NetworkInfo.shared
    private let trackQueue = TrackQueue.shared
    
    var queue: [Track] { trackQueue.tracks }

    private var currentProcess: Process?
    private var autoPlayTimer: Timer?

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
    /// Stop streaming and clean up
    func stopServer() {
        // Cancel streaming thread
        streamingWorkItem?.cancel()
        streamingWorkItem = nil
        
        currentProcess?.terminate()
        currentProcess = nil
        server.stop()
        status = .idle
        streamURL = nil
        activePort = nil
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
        // Cleanup existing state
        autoPlayTimer?.invalidate()
        currentProcess?.terminate()
        currentProcess = nil
        
        status = .downloading
        downloadProgress = 0

        var updatedTrack = track
        updatedTrack.status = .downloading
        
        // Update server metadata immediately so web UI shows "Loading..." or new track
        server.trackTitle = track.title
        server.trackArtist = track.artist ?? "Loading..."
        server.thumbnailURL = track.thumbnailURL
        
        // Update UI immediately with new track info
        DispatchQueue.main.async {
            self.currentTrack = updatedTrack
            self.objectWillChange.send()
        }

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
            title: track.title,
            artist: track.artist,
            thumbnailURL: track.thumbnailURL,
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
        // If server is not running, start it
        if !server.isRunning {
             // Connect remote control callbacks
            server.onSkip = { [weak self] in
                print("⏭ Remote Skip command received")
                self?.playNext()
            }
            
            server.onStop = { [weak self] in
                print("⏹ Remote Stop command received")
                self?.stopServer()
            }
            
            // Note: Empty filePath initially, we will stream data manually
            server.start(servingFile: "", port: 8000) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.status = .serving
                        self.activePort = self.server.port
                        self.streamURL = self.networkInfo.streamURL(port: self.server.port)
                        self.objectWillChange.send()
                        
                        // Start piping the file
                        self.streamAudioFile(at: filePath)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.status = .error
                        self.errorMessage = "Server error: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Server already running, just start piping new file
            DispatchQueue.main.async {
                 self.status = .serving
                 // Update metadata on running server
                 if let track = self.currentTrack {
                     self.server.trackTitle = track.title
                     self.server.trackArtist = track.artist ?? ""
                     self.server.thumbnailURL = track.thumbnailURL
                 }
                 self.streamAudioFile(at: filePath)
            }
        }
    }
    
    // Pipe audio file to server broadcast
    private var streamingWorkItem: DispatchWorkItem?

    private func streamAudioFile(at path: String) {
        // Cancel existing streaming work
        streamingWorkItem?.cancel()
        
        // Cancel existing timer
        autoPlayTimer?.invalidate()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            guard let fileData = FileManager.default.contents(atPath: path) else {
                print("❌ Failed to read audio file")
                return
            }
            
            print("📡 Broadcasting \(fileData.count) bytes...")
            
            // Chunk size for streaming (64KB)
            let chunkSize = 65536
            var offset = 0
            
            while offset < fileData.count {
                if self.streamingWorkItem?.isCancelled == true {
                    print("🛑 Streaming cancelled")
                    return
                }
                
                let length = min(chunkSize, fileData.count - offset)
                let chunk = fileData.subdata(in: offset..<offset + length)
                self.server.broadcast(chunk)
                offset += length
                
                // Throttle slightly to simulate real-time stream 
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            print("✅ Broadcast complete")
            
            // Schedule next song with short buffer
             DispatchQueue.main.async {
                 let duration = 2.0 
                 print("⏲ Check next track in \(duration)s")
                 self.autoPlayTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                     self?.playNext()
                 }
             }
        }
        
        streamingWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

}
