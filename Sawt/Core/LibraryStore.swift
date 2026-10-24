import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Songs

    func addSong(from item: DownloadTaskItem, localFileName: String, fileSize: Int64, format: String) -> Song {
        if let existing = song(videoId: item.videoId) {
            existing.localFileName = localFileName
            existing.fileSizeBytes = fileSize
            existing.format = format
            try? context.save()
            return existing
        }
        let song = Song(
            videoId: item.videoId,
            title: item.title,
            author: item.author,
            durationSeconds: item.durationSeconds,
            thumbnailURL: item.thumbnailURL,
            localFileName: localFileName,
            format: format,
            fileSizeBytes: fileSize
        )
        context.insert(song)
        try? context.save()
        return song
    }

    func song(videoId: String) -> Song? {
        let descriptor = FetchDescriptor(predicate: #Predicate({ $0.videoId == videoId }))
        return try? context.fetch(descriptor).first
    }

    func songs() -> [Song] {
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\\Song.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func toggleFavorite(_ song: Song) {
        song.isFavorite.toggle()
        try? context.save()
    }

    func delete(_ song: Song) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SawtDownloads")
        let url = dir.appendingPathComponent(song.localFileName)
        try? FileManager.default.removeItem(at: url)
        context.delete(song)
        try? context.save()
    }

    func recordPlay(song: Song?, videoId: String, title: String, author: String, thumbnail: String?, position: Double, duration: Int) {
        song?.lastPlayedAt = Date()
        song?.lastPositionSeconds = position
        let descriptor = FetchDescriptor(predicate: #Predicate({
            $0.videoId == videoId }),
            sortBy: [SortDescriptor(\\HistoryEntry.playedAt, order: .reverse)]
        )
        let existing = try? context.fetch(descriptor).first
        if let existing {
            existing.playedAt = Date()
            existing.positionSeconds = position
            existing.durationSeconds = duration
        } else {
            let entry = HistoryEntry(videoId: videoId, title: title, author: author, thumbnailURL: thumbnail, positionSeconds: position, durationSeconds: duration)
            context.insert(entry)
        }
        try? context.save()
    }

    func deleteHistory(_ entry: HistoryEntry) {
        context.delete(entry)
        try? context.save()
    }

    func clearHistory() {
        try? context.delete(model: HistoryEntry.self)
        try? context.save()
    }

    // MARK: - Playlists

    func createPlaylist(name: String) -> Playlist {
        let pl = Playlist(name: name)
        context.insert(pl)
        try? context.save()
        return pl
    }

    func deletePlaylist(_ pl: Playlist) {
        context.delete(pl)
        try? context.save()
    }

    func addToPlaylist(_ song: Song, playlist: Playlist) {
        if !playlist.songs.contains(where: { $0.videoId == song.videoId }) {
            playlist.songs.append(song)
            try? context.save()
        }
    }

    // MARK: - Storage

    var totalStorageBytes: Int64 {
        songs().reduce(0) { $0 + $1.fileSizeBytes }
    }
}
