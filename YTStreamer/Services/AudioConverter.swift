import Foundation

/// Converts audio files to MP3 using ffmpeg
class AudioConverter {

    static let shared = AudioConverter()
    private let tools = BundledTools.shared

    private init() {}

    /// Convert audio file to MP3 with embedded metadata
    func convertToMP3(
        inputPath: String,
        title: String? = nil,
        artist: String? = nil,
        thumbnailURL: String? = nil,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> Process? {
        let outputPath = tools.tempDirectory.appendingPathComponent("stream.mp3").path
        let thumbnailPath = tools.tempDirectory.appendingPathComponent("thumbnail.jpg").path

        // Remove existing file if present
        try? FileManager.default.removeItem(atPath: outputPath)

        // Download thumbnail if available
        var hasThumbnail = false
        if let urlString = thumbnailURL, let url = URL(string: urlString) {
            if let data = try? Data(contentsOf: url) {
                try? data.write(to: URL(fileURLWithPath: thumbnailPath))
                hasThumbnail = true
            }
        }

        var arguments = [
            "-y",                    // Overwrite output
            "-i", inputPath          // Input file
        ]
        
        // Add thumbnail as second input if available
        if hasThumbnail {
            arguments += ["-i", thumbnailPath]
        }

        arguments += [
            "-vn",                   // No video from first input
            "-acodec", "mp3",        // MP3 codec
            "-ab", "128k",           // 128 kbps bitrate
            "-ar", "44100"           // 44.1 kHz sample rate
        ]
        
        // Add metadata
        if let title = title {
            arguments += ["-metadata", "title=\(title)"]
        }
        if let artist = artist {
            arguments += ["-metadata", "artist=\(artist)"]
        }
        
        // Embed thumbnail as album art
        if hasThumbnail {
            arguments += [
                "-map", "0:a",           // Audio from first input
                "-map", "1:v",           // Video (image) from second input
                "-c:v", "copy",          // Copy the image as-is
                "-id3v2_version", "3",   // Use ID3v2.3 for compatibility
                "-metadata:s:v", "title=Album cover",
                "-metadata:s:v", "comment=Cover (front)"
            ]
        }
        
        arguments += [outputPath]

        let process = ProcessRunner.runAsync(
            tools.ffmpegPath,
            arguments: arguments,
            onOutput: { output in
                // ffmpeg outputs progress to stderr, not stdout
            },
            onError: { error in
                // Parse progress from ffmpeg output
                if let progress = self.parseProgress(from: error) {
                    onProgress(progress)
                }
            },
            completion: { exitCode in
                // Clean up input file and thumbnail
                try? FileManager.default.removeItem(atPath: inputPath)
                try? FileManager.default.removeItem(atPath: thumbnailPath)

                if exitCode == 0 && FileManager.default.fileExists(atPath: outputPath) {
                    completion(.success(outputPath))
                } else {
                    completion(.failure(DownloadError.conversionFailed))
                }
            }
        )

        return process
    }

    private func parseProgress(from output: String) -> Double? {
        // This is simplified - would need duration to calculate actual progress
        if output.contains("time=") {
            return nil
        }
        return nil
    }
}

