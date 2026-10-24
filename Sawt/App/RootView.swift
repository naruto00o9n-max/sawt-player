import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case home, search, library, history, settings
    var id: String { rawValue }

    func title(_ar ar: Bool) -> String {
        switch self {
        case .home: return ar ? "الرئيسية" : "Home"
        case .search: return ar ? "بحث" : "Search"
        case .library: return ar ? "المكتبة" : "Library"
        case .history: return ar ? "السجل" : "History"
        case .settings: return ar ? "الإعدادات" : "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingmglass"
        case .library: return "square.stack.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var player: PlayerService
    @State private var tab: AppTab = .home
    @State private var showPlayer = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .bottom) {
            SawtTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if !network.isConnected {
                    OfflineBanner(isArabic: settings.isArabic)
                }

                Group {
                    switch tab {
                    case .home: HomeView(onOpenSearch: { tab = .search }, onOpenPlayer: { showPlayer = true })
                    case .search: SearchView(onOpenPlayer: { showPlayer = true })
                    case .library: LibraryView(onOpenPlayer: { showPlayer = true })
                    case .history: HistoryView(openPlayer: { showPlayer = true })
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if player.currentVideoId != nil {
                    MiniPlayerBar(onExpand: { showPlayer = true })
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }

                TabBar(selection: $tab, isArabic: settings.isArabic)
            }
        }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView()
                .environmentObject(player)
                .environmentObject(settings)
        }
        .onAppear {
            player.setQueue([], startAt: 0)
        }
    }
}

struct TabBar: View {
    @Binding var selection: AppTab
    let isArabic: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button {
                    selection = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: .semibold))
                        Text(item.title(isArabic))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == item ? SawtTheme.accentSoft : SawtTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title(isArabic))
                .accessibilityAddTraits(selection == item ? [.isSelected] : [])
            }
        }
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }
}

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var settings: AppSettings
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                CoverImage(url: player.thumbnailURL, size: 44, corner: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTitle.isEmpty ? "—" : player.currentTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SawtTheme.textPrimary)
                        .lineLimit(1)
                    Text(player.currentAuthor)
                        .font(.system(size: 11))
                        .foregroundStyle(SawtTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(SawtTheme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? (settings.isArabic ? "إيقاف مؤقتت" : "Pause") : (settings.isArabic ? "تشغيل" : "Play"))
            }
            .padding(10)
            .background(SawtTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct OfflineBanner: View {
    let isArabic: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(isArabic ? "لا يوجد اتصال بالإنترنت Ҕ 2زموان غير ملتصلآ" : "No internet connection — offline mode")
                .font(.system(size: 12, weight: .medium))
            Spacer()
        }
        .foregroundStyle(Color.black.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(SawtTheme.warning)
        .accessibilityElement(children: .combine)
    }
}
