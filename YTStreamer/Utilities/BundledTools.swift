import Foundation

/// Access bundled yt-dlp and ffmpeg binaries
class BundledTools {

    static let shared = BundledTools()

    private init() {}

    /// Path to bundled yt-dlp
    var ytdlpPath: String {
        if let path = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            return path
        }
        // Fallback to system installation
        return "/opt/homebrew/bin/yt-dlp"
    }

    /// Path to bundled ffmpeg
    var ffmpegPath: String {
        if let path = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            return path
        }
        // Fallback to system installation
        return "/opt/homebrew/bin/ffmpeg"
    }

    /// Path to bundled ffplay (for local playback)
    var ffplayPath: String {
        if let path = Bundle.main.path(forResource: "ffplay", ofType: nil) {
            return path
        }
        return "/opt/homebrew/bin/ffplay"
    }

    /// Temporary directory for downloads
    var tempDirectory: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("YTStreamer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Application Support directory for persistent data
    var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("YTStreamer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Check if bundled tools exist
    func validateTools() -> (ytdlp: Bool, ffmpeg: Bool) {
        let ytdlpExists = FileManager.default.fileExists(atPath: ytdlpPath)
        let ffmpegExists = FileManager.default.fileExists(atPath: ffmpegPath)
        return (ytdlpExists, ffmpegExists)
    }
}
