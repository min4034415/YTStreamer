import Foundation

/// Converts audio files to MP3 using ffmpeg
class AudioConverter {

    static let shared = AudioConverter()
    private let tools = BundledTools.shared

    private init() {}

    /// Convert audio file to MP3
    func convertToMP3(
        inputPath: String,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> Process? {
        let outputPath = tools.tempDirectory.appendingPathComponent("stream.mp3").path

        // Remove existing file if present
        try? FileManager.default.removeItem(atPath: outputPath)

        let arguments = [
            "-y",                    // Overwrite output
            "-i", inputPath,         // Input file
            "-vn",                   // No video
            "-acodec", "mp3",        // MP3 codec
            "-ab", "128k",           // 128 kbps bitrate
            "-ar", "44100",          // 44.1 kHz sample rate
            outputPath
        ]

        let process = ProcessRunner.runAsync(
            tools.ffmpegPath,
            arguments: arguments,
            onOutput: { output in
                // ffmpeg outputs progress to stderr, not stdout
            },
            onError: { error in
                // Parse progress from ffmpeg output
                // Format: "time=00:01:30.50"
                if let progress = self.parseProgress(from: error) {
                    onProgress(progress)
                }
            },
            completion: { exitCode in
                // Clean up input file
                try? FileManager.default.removeItem(atPath: inputPath)

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
        // For now, just check if we see time updates
        if output.contains("time=") {
            return nil // Would calculate based on duration
        }
        return nil
    }
}
