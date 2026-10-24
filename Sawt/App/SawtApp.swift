import SwiftUI
import SwiftData

@main
struct SawtApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var network = NetworkMonitor()
    @StateObject private var player = PlayerService()
    @StateObject private var downloads = DownloadManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(network)
                .environmentObject(player)
                .environmentObject(downloads)
                .environment(\.layoutDirection, settings.isArabic ? .rightToLeft : .leftToRight)
                .preferredColorScheme(settings.darkMode ? .dark : nil)
                .tint(SawtTheme.accent)
        }
        .modelContainer(for: [Song.self, Playlist.self, HistoryEntry.self])
    }
}
