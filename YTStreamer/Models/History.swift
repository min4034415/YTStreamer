import Foundation
import Combine

/// Manages playback history
class HistoryManager: ObservableObject {

    static let shared = HistoryManager()

    @Published var items: [HistoryItem] = []

    private let historyFile: URL
    private let maxItems = 100

    private init() {
        historyFile = BundledTools.shared.appSupportDirectory.appendingPathComponent("history.json")
        load()
    }

    /// Add a track to history
    func add(_ track: Track) {
        let item = HistoryItem(
            id: UUID(),
            youtubeURL: track.youtubeURL,
            videoID: track.videoID,
            title: track.title,
            artist: track.artist,
            thumbnailURL: track.thumbnailURL,
            playedAt: Date()
        )

        // Remove duplicate if exists
        items.removeAll { $0.videoID == item.videoID }

        // Add to beginning
        items.insert(item, at: 0)

        // Trim to max items
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    /// Clear all history
    func clear() {
        items.removeAll()
        save()
    }

    /// Remove specific item
    func remove(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyFile)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }

        do {
            let data = try Data(contentsOf: historyFile)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}

/// A single history entry
struct HistoryItem: Codable, Identifiable {
    let id: UUID
    let youtubeURL: String
    let videoID: String
    let title: String
    let artist: String?
    let thumbnailURL: String?
    let playedAt: Date

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: playedAt, relativeTo: Date())
    }
}
