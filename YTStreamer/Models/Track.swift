import Foundation
import Combine

/// Represents a YouTube track
struct Track: Codable, Identifiable, Equatable {
    let id: UUID
    let youtubeURL: String
    let videoID: String
    var title: String
    var artist: String?
    var thumbnailURL: String?
    var duration: TimeInterval?
    var localFilePath: String?
    var downloadProgress: Double
    var status: TrackStatus

    enum TrackStatus: String, Codable {
        case queued
        case downloading
        case converting
        case ready
        case playing
        case failed
    }

    init(youtubeURL: String) {
        self.id = UUID()
        self.youtubeURL = youtubeURL
        self.videoID = Track.extractVideoID(from: youtubeURL) ?? "unknown"
        self.title = "Loading..."
        self.downloadProgress = 0
        self.status = .queued
    }

    /// Extract video ID from YouTube URL
    static func extractVideoID(from url: String) -> String? {
        // Handle various YouTube URL formats
        let patterns = [
            "v=([a-zA-Z0-9_-]{11})",           // youtube.com/watch?v=
            "youtu\\.be/([a-zA-Z0-9_-]{11})",  // youtu.be/
            "embed/([a-zA-Z0-9_-]{11})",       // youtube.com/embed/
            "/v/([a-zA-Z0-9_-]{11})"           // youtube.com/v/
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        return nil
    }
}

/// Queue of tracks to play
class TrackQueue: ObservableObject {
    static let shared = TrackQueue()

    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = 0

    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    func add(_ track: Track) {
        tracks.append(track)
    }

    func remove(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        if currentIndex >= tracks.count {
            currentIndex = max(0, tracks.count - 1)
        }
    }

    func next() -> Track? {
        guard currentIndex + 1 < tracks.count else { return nil }
        currentIndex += 1
        return currentTrack
    }

    func previous() -> Track? {
        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return currentTrack
    }

    func update(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index] = track
        }
    }
}
