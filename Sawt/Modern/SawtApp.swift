import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Observation

@main
struct SawtApp: App {
    @State private var library = MusicLibrary()
    @State private var player = LocalPlayer()

    var body: some Scene {
        WindowGroup {
            RootView(library: library, player: player)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .tint(SawtTheme.accent)
        }
    }
}

enum SawtTheme {
    static let accent = Color(red: 1, green: 0.18, blue: 0.33)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let card = Color.white.opacity(0.09)
}

struct Track: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var fileURL: URL
    var addedAt: Date
    var isFavorite: Bool

    init(id: UUID = UUID(), title: String, artist: String = "ملف محلي", fileURL: URL, addedAt: Date = .now, isFavorite: Bool = false) {
        self.id = id; self.title = title; self.artist = artist; self.fileURL = fileURL; self.addedAt = addedAt; self.isFavorite = isFavorite
    }
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    init(id: UUID = UUID(), name: String, trackIDs: [UUID] = []) { self.id = id; self.name = name; self.trackIDs = trackIDs }
}

@MainActor @Observable
final class MusicLibrary {
    private(set) var tracks: [Track] = []
    private(set) var playlists: [Playlist] = []
    var error: String?

    init() { load() }
    var favorites: [Track] { tracks.filter(\.isFavorite) }

    func importFiles(_ urls: [URL]) {
        for original in urls {
            let accessed = original.startAccessingSecurityScopedResource()
            defer { if accessed { original.stopAccessingSecurityScopedResource() } }
            do {
                let folder = try filesDirectory()
                let destination = folder.appendingPathComponent("\(UUID().uuidString)-\(original.lastPathComponent)")
                try FileManager.default.copyItem(at: original, to: destination)
                tracks.append(Track(title: original.deletingPathExtension().lastPathComponent, fileURL: destination))
            } catch { self.error = "تعذر استيراد الملف الصوتي. حاول مرة أخرى." }
        }
        save()
    }

    func toggleFavorite(_ track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[index].isFavorite.toggle(); save()
    }

    func remove(_ track: Track) {
        try? FileManager.default.removeItem(at: track.fileURL)
        tracks.removeAll { $0.id == track.id }
        playlists.indices.forEach { playlists[$0].trackIDs.removeAll { $0 == track.id } }
        save()
    }

    func createPlaylist(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        playlists.append(Playlist(name: clean)); save()
    }

    func add(_ track: Track, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }), !playlists[index].trackIDs.contains(track.id) else { return }
        playlists[index].trackIDs.append(track.id); save()
    }

    func tracks(in playlist: Playlist) -> [Track] { tracks.filter { playlist.trackIDs.contains($0.id) } }

    private func filesDirectory() throws -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SawtAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private var archiveURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("sawt-library.json") }
    private func save() { if let data = try? JSONEncoder().encode(LibraryArchive(tracks: tracks, playlists: playlists)) { try? data.write(to: archiveURL, options: .atomic) } }
    private func load() { guard let data = try? Data(contentsOf: archiveURL), let archive = try? JSONDecoder().decode(LibraryArchive.self, from: data) else { return }; tracks = archive.tracks.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }; playlists = archive.playlists }
}
private struct LibraryArchive: Codable { var tracks: [Track]; var playlists: [Playlist] }

@MainActor @Observable
final class LocalPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    var currentTrack: Track?
    var isPlaying = false
    var progress: Double = 0
    var duration: Double = 0
    var error: String?
    private var timer: Timer?

    func play(_ track: Track) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let audio = try AVAudioPlayer(contentsOf: track.fileURL)
            audio.delegate = self; audio.prepareToPlay(); audio.play()
            audioPlayer = audio; currentTrack = track; duration = audio.duration; progress = 0; isPlaying = true
            startTimer()
        } catch { error = "تعذر تشغيل هذا الملف. تأكد من أن صيغة الصوت مدعومة."; isPlaying = false }
    }
    func toggle() { guard let currentTrack else { return }; isPlaying ? pause() : (audioPlayer == nil ? play(currentTrack) : resume()) }
    func pause() { audioPlayer?.pause(); isPlaying = false; timer?.invalidate() }
    private func resume() { audioPlayer?.play(); isPlaying = true; startTimer() }
    func seek(_ value: Double) { audioPlayer?.currentTime = value; progress = value }
    func stop() { audioPlayer?.stop(); timer?.invalidate(); isPlaying = false; progress = 0 }
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) { stop() }
    private func startTimer() { timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in guard let self else { return }; self.progress = self.audioPlayer?.currentTime ?? 0 } }
}

struct RootView: View {
    let library: MusicLibrary
    let player: LocalPlayer
    @State private var tab = AppTab.library
    @State private var showingImporter = false
    @State private var showingNowPlaying = false
    @State private var newPlaylistName = ""

    var body: some View {
        TabView(selection: $tab) {
            LibraryView(library: library, player: player, showingImporter: $showingImporter, newPlaylistName: $newPlaylistName).tabItem { Label("المكتبة", systemImage: "square.stack.fill") }.tag(AppTab.library)
            SearchView(library: library, player: player).tabItem { Label("بحث", systemImage: "magnifyingglass") }.tag(AppTab.search)
            YouTubeView().tabItem { Label("YouTube", systemImage: "play.rectangle.fill") }.tag(AppTab.youtube)
        }
        .overlay(alignment: .bottom) { if player.currentTrack != nil { MiniPlayer(player: player) { showingNowPlaying = true }.padding(.horizontal, 12).padding(.bottom, 56) } }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in if case .success(let urls) = result { library.importFiles(urls) } }
        .sheet(isPresented: $showingNowPlaying) { NowPlayingView(player: player) }
        .alert("Sawt", isPresented: Binding(get: { library.error != nil || player.error != nil }, set: { if !$0 { library.error = nil; player.error = nil } })) { Button("حسناً", role: .cancel) {} } message: { Text(library.error ?? player.error ?? "") }
    }
}
private enum AppTab { case library, search, youtube }

struct LibraryView: View {
    let library: MusicLibrary; let player: LocalPlayer
    @Binding var showingImporter: Bool; @Binding var newPlaylistName: String
    @State private var playlistSheet = false
    var body: some View {
        NavigationStack {
            List {
                Section { Button { showingImporter = true } label: { Label("استيراد ملفات صوتية", systemImage: "plus.circle.fill") }.foregroundStyle(SawtTheme.accent) } footer: { Text("استورد الملفات التي تملك حق استخدامها فقط.") }
                if library.tracks.isEmpty { ContentUnavailableView("مكتبتك فارغة", systemImage: "music.note.list", description: Text("استورد ملفاً صوتياً للبدء.")) }
                if !library.tracks.isEmpty { Section("الأغاني") { ForEach(library.tracks) { track in TrackRow(track: track, player: player, library: library) } } }
                Section("قوائم التشغيل") { ForEach(library.playlists) { playlist in NavigationLink(playlist.name) { PlaylistView(playlist: playlist, library: library, player: player) } }; Button("قائمة تشغيل جديدة") { playlistSheet = true }.foregroundStyle(SawtTheme.accent) }
            }.navigationTitle("المكتبة")
        }.alert("قائمة تشغيل جديدة", isPresented: $playlistSheet) { TextField("الاسم", text: $newPlaylistName); Button("إضافة") { library.createPlaylist(name: newPlaylistName); newPlaylistName = "" }; Button("إلغاء", role: .cancel) {} }
    }
}
struct TrackRow: View {
    let track: Track; let player: LocalPlayer; let library: MusicLibrary
    var body: some View { HStack { Button { player.play(track) } label: { Image(systemName: player.currentTrack?.id == track.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.title2).foregroundStyle(SawtTheme.accent) }.accessibilityLabel("تشغيل \(track.title)"); VStack(alignment: .leading) { Text(track.title).lineLimit(1); Text(track.artist).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { library.toggleFavorite(track) } label: { Image(systemName: track.isFavorite ? "heart.fill" : "heart") }.tint(SawtTheme.accent) }.swipeActions { Button(role: .destructive) { library.remove(track) } label: { Label("حذف", systemImage: "trash") } } }
}
struct PlaylistView: View { let playlist: Playlist; let library: MusicLibrary; let player: LocalPlayer; var body: some View { List(library.tracks(in: playlist)) { TrackRow(track: $0, player: player, library: library) }.navigationTitle(playlist.name) } }

struct SearchView: View { let library: MusicLibrary; let player: LocalPlayer; @State private var query = ""; var results: [Track] { query.isEmpty ? library.tracks : library.tracks.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query) } }; var body: some View { NavigationStack { List { if results.isEmpty { ContentUnavailableView(query.isEmpty ? "ابحث في مكتبتك" : "لا توجد نتائج", systemImage: "magnifyingglass", description: Text(query.isEmpty ? "استخدم حقل البحث للعثور على أغانيك." : "جرّب كلمات أخرى.")) } else { ForEach(results) { TrackRow(track: $0, player: player, library: library) } } }.searchable(text: $query, prompt: "أغنية أو فنان").navigationTitle("بحث") } } }

struct YouTubeView: View { @State private var urlText = ""; @State private var invalid = false; var body: some View { NavigationStack { Form { Section("فتح رابط رسمي") { TextField("https://youtube.com/watch…", text: $urlText).textInputAutocapitalization(.never).keyboardType(.URL); Button("فتح في YouTube") { invalid = !YouTubeLink.isOfficial(urlText); if !invalid, let url = URL(string: urlText) { UIApplication.shared.open(url) } }.disabled(urlText.isEmpty) } Section { Text("Sawt لا يستخرج أو ينزّل محتوى YouTube. استخدم الزر لفتح الرابط في YouTube أو المتصفح.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("YouTube") }.alert("رابط غير صالح", isPresented: $invalid) { Button("حسناً", role: .cancel) {} } message: { Text("أدخل رابط youtube.com أو youtu.be رسمياً.") } } }

struct MiniPlayer: View { let player: LocalPlayer; let open: () -> Void; var body: some View { Button(action: open) { HStack { Image(systemName: "music.note").frame(width: 38, height: 38).background(SawtTheme.card).clipShape(RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading) { Text(player.currentTrack?.title ?? "").lineLimit(1); Text(player.currentTrack?.artist ?? "").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3) }.buttonStyle(.plain) }.padding(10).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain) } }
struct NowPlayingView: View { let player: LocalPlayer; var body: some View { VStack(spacing: 28) { Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top); Spacer(); Image(systemName: "music.note").resizable().scaledToFit().frame(width: 180, height: 180).padding(54).background(SawtTheme.card).clipShape(RoundedRectangle(cornerRadius: 28)); VStack { Text(player.currentTrack?.title ?? "").font(.title2.bold()); Text(player.currentTrack?.artist ?? "").foregroundStyle(.secondary) }; Slider(value: Binding(get: { player.progress }, set: player.seek), in: 0...max(player.duration, 1)); HStack { Text(time(player.progress)); Spacer(); Text(time(player.duration)) }.font(.caption).foregroundStyle(.secondary); HStack(spacing: 46) { Button { player.seek(max(0, player.progress - 15)) } label: { Image(systemName: "gobackward.15") }; Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64)) }; Button { player.seek(min(player.duration, player.progress + 15)) } label: { Image(systemName: "goforward.15") } }.font(.title).tint(.white); Spacer() }.padding().background(SawtTheme.surface.ignoresSafeArea()) }
    private func time(_ value: Double) -> String { let seconds = Int(value); return String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

enum YouTubeLink { static func isOfficial(_ value: String) -> Bool { guard let host = URL(string: value)?.host?.lowercased() else { return false }; return host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be" } }
