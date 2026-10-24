import Foundation
import SwiftData

// MARK: - Remote models (decoded from YouTube JSON)

struct AudioFormat: Identifiable, Hashable, Codable {
    let itag: Int
    let url: String
    let mimeType: String
    let bitrateKbps: Int
    let channels: Int?
    let contentLength: Int64?

    var id: Int { itag }
    var isM4A: Bool { mimeType.contains("mp4a") }
    var qualityLabel: String {
        let kind = mimeType.contains("opus") ? "Opus" : (isM4A ? "AAC" : "Audio")
        return "\(kind) · \(bitrateKbps) kbps"
    }
}

struct VideoInfo: Identifiable, Hashable, Codable {
    let videoId: String
    let title: String
    let author: String
    let durationSeconds: Int
    let thumbnailURL: String?
    let viewCount: Int64?
    let audioFormats: [AudioFormat]
    let streamingBaseURL: String

    var id: String { videoId }
    var youtubeURL: String { "https://www.youtube.com/watch?v=\(videoId)" }
    var durationText: String { Self.format(durationSeconds) }

    static func format(_ seconds: Int) -> String {
        guard seconds > 0 else { return "--:--" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

struct SearchResult: Identifiable, Hashable, Codable {
    let videoId: String
    let title: String
    let author: String
    let durationSeconds: Int
    let thumbnailURL: String?

    var id: String { videoId }
    var durationText: String { VideoInfo.format(durationSeconds) }
}

// MARK: - Persisted models (SwiftData)

@Model
final class Song {
    @Attribute(.unique) var videoId: String
    var title: String
    var author: String
    var durationSeconds: Int
    var thumbnailURL: String?
    var localFileName: String
    var addedAt: Date
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var lastPositionSeconds: Double
    var fileSizeBytes: Int64
    var format: String

    init(videoId: String,
         title: String,
         author: String,
         durationSeconds: Int,
         thumbnailURL: String?,
         localFileName: String,
         format: String,
         fileSizeBytes: Int64 = 0) {
        self.videoId = videoId
        self.title = title
        self.author = author
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.localFileName = localFileName
        self.addedAt = Date()
        self.isFavorite = false
        self.lastPlayedAt = nil
        self.lastPositionSeconds = 0
        self.fileSizeBytes = fileSizeBytes
        self.format = format
    }

    var durationText: String { VideoInfo.format(durationSeconds) }
    var sizeText: String {
        let mb = Double(fileSizeBytes) / 1_048_576.0
        return mb >= 1 ? String(format: "%.1 MB", mb) : String(format: "%.0 KB", Double(fileSizeBytes) / 1024.0)
    }
}

@Model
final class Playlist {
    @Attribute(.unique) var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var songs: [Song]

    init(name: String, songs: [Song] = []) {
        self.name = name
        self.createdAt = Date()
        self.songs = songs
    }
}

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var videoId: String
    var title: String
    var author: String
    var thumbnailURL: String?
    var playedAt: Date
    var positionSeconds: Double
    var durationSeconds: Int

    init(videoId: String, title: String, author: String, thumbnailURL: String?, positionSeconds: Double, durationSeconds: Int) {
        self.id = UUID
()
        self.videoId = videoId
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.playedAt = Date()
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
    }
}
