import Foundation
import Combine

enum StreamQuality: String, CaseIterable, Identifiable, Codable {
    case low, medium, high
    var id: String { rawValue }
    var itagPreference: [Int] {
        switch self {
        case .low: return [139, 140, 251]
        case .medium: return [140, 251, 139]
        case .high: return [251, 140, 139]
        }
    }
    func title(_ arabic: Bool) -> String {
        switch self {
        case .low: return arabic ? "منخفضة (48kbps)" : "Low (48kbps)"
        case .medium: return arabic ? "متوسطة (128kbps)" : "Medium (128kbps)"
        case .high: return arabic ? "عالية (160kbps)" : "High (160kbps)"
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case m4a, mp3
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var isArabic: Bool { didSet { store(.isArabic, isArabic) } }
    @Published var darkMode: Bool { didSet { store(.darkMode, darkMode) } }
    @Published var streamQuality: StreamQuality { didSet { store(.streamQuality, streamQuality.rawValue) } }
    @Published var downloadQuality: StreamQuality { didSet { store(.downloadQuality, downloadQuality.rawValue) } }
    @Published var exportFormat: ExportFormat { didSet { store(.exportFormat, exportFormat.rawValue) } }
    @Published var wifiOnlyDownloads: Bool { didSet { store(.wifiOnly, wifiOnlyDownloads) } }
    @Published var autoPlayNext: Bool { didSet { store(.autoPlayNext, autoPlayNext) } }

    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        isArabic = d.object(forKey: Key.isArabic.rawValue) as? Bool ?? true
        darkMode = d.object(forKey: Key.darkMode.rawValue) as? Bool ?? true
        streamQuality = StreamQuality(rawValue: d.string(forKey: Key.streamQuality.rawValue) ?? "") ?? .high
        downloadQuality = StreamQuality(rawValue: d.string(forKey: Key.downloadQuality.rawValue) ?? "") ?? .high
        exportFormat = ExportFormat(rawValue: d.string(forKey: Key.exportFormat.rawValue) ?? "") ?? .m4a
        wifiOnlyDownloads = d.object(forKey: Key.wifiOnly.rawValue) as? Bool ?? false
        autoPlayNext = d.object(forKey: Key.autoPlayNext.rawValue) as? Bool ?? true
    }

    private enum Key: String {
        case isArabic, darkMode, streamQuality, downloadQuality, exportFormat, wifiOnly, autoPlayNext
    }

    private func store(_ key: Key, _ value: Any) {
        defaults.set(value, forKey: key.rawValue)
    }

    func clearCache() throws {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let caches, let items = try? fm.contentsOfDirectory(at: caches, includingPropertiesForKeys: nil) {
            for item in items { try? fm.removeItem(at: item) }
        }
    }
}
