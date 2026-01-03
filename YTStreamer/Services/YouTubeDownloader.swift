import Foundation

/// Downloads audio from YouTube using yt-dlp
class YouTubeDownloader {

    static let shared = YouTubeDownloader()
    private let tools = BundledTools.shared

    private init() {}

    /// Fetch video metadata (title, artist, thumbnail, duration)
    func fetchMetadata(for url: String, completion: @escaping (Result<TrackMetadata, Error>) -> Void) {
        let arguments = [
            "--dump-json",
            "--no-playlist",
            "--extractor-args", "youtube:player_client=ios",
            url
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ProcessRunner.run(self.tools.ytdlpPath, arguments: arguments)

            if result.exitCode != 0 {
                DispatchQueue.main.async {
                    completion(.failure(DownloadError.metadataFailed(result.error)))
                }
                return
            }

            guard let data = result.output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(DownloadError.parseError))
                }
                return
            }

            let metadata = TrackMetadata(
                title: json["title"] as? String ?? "Unknown",
                artist: json["uploader"] as? String ?? json["channel"] as? String,
                thumbnailURL: json["thumbnail"] as? String,
                duration: json["duration"] as? TimeInterval,
                videoURL: url
            )

            DispatchQueue.main.async {
                completion(.success(metadata))
            }
        }
    }
    
    /// Fetch all videos from a playlist
    func fetchPlaylistMetadata(for url: String, completion: @escaping (Result<[TrackMetadata], Error>) -> Void) {
        let arguments = [
            "--flat-playlist",
            "--dump-json",
            "--extractor-args", "youtube:player_client=ios",
            url
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ProcessRunner.run(self.tools.ytdlpPath, arguments: arguments)

            if result.exitCode != 0 {
                DispatchQueue.main.async {
                    completion(.failure(DownloadError.metadataFailed(result.error)))
                }
                return
            }

            // Each line is a JSON object for one video
            let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
            var tracks: [TrackMetadata] = []
            
            for line in lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                let videoId = json["id"] as? String ?? ""
                let videoURL = "https://www.youtube.com/watch?v=\(videoId)"
                
                let metadata = TrackMetadata(
                    title: json["title"] as? String ?? "Unknown",
                    artist: json["uploader"] as? String ?? json["channel"] as? String,
                    thumbnailURL: json["thumbnail"] as? String,
                    duration: json["duration"] as? TimeInterval,
                    videoURL: videoURL
                )
                tracks.append(metadata)
            }

            DispatchQueue.main.async {
                if tracks.isEmpty {
                    completion(.failure(DownloadError.parseError))
                } else {
                    print("📋 Found \(tracks.count) videos in playlist")
                    completion(.success(tracks))
                }
            }
        }
    }

    /// Download audio from YouTube URL
    func download(
        url: String,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> Process? {
        let outputPath = tools.tempDirectory.appendingPathComponent("audio_\(UUID().uuidString).aac").path

        let arguments = [
            "-f", "bestaudio",
            "--extractor-args", "youtube:player_client=ios",
            "--no-playlist",
            "-o", outputPath,
            url
        ]

        let process = ProcessRunner.runAsync(
            tools.ytdlpPath,
            arguments: arguments,
            onOutput: { output in
                // Parse progress from output (e.g., "[download]  50.0% of ~3.00MiB")
                if let progress = self.parseProgress(from: output) {
                    onProgress(progress)
                }
            },
            onError: { error in
                print("yt-dlp error: \(error)")
            },
            completion: { exitCode in
                if exitCode == 0 {
                    completion(.success(outputPath))
                } else {
                    completion(.failure(DownloadError.downloadFailed))
                }
            }
        )

        return process
    }

    private func parseProgress(from output: String) -> Double? {
        // Match patterns like "[download]  50.0% of"
        let pattern = "\\[download\\]\\s+(\\d+\\.?\\d*)%"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return Double(output[range])
    }
}

// MARK: - Supporting Types

struct TrackMetadata {
    let title: String
    let artist: String?
    let thumbnailURL: String?
    let duration: TimeInterval?
    let videoURL: String?
}

enum DownloadError: LocalizedError {
    case metadataFailed(String)
    case parseError
    case downloadFailed
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .metadataFailed(let msg): return "Failed to fetch metadata: \(msg)"
        case .parseError: return "Failed to parse video information"
        case .downloadFailed: return "Download failed"
        case .conversionFailed: return "Audio conversion failed"
        }
    }
}
