import Foundation
import AVFoundation
import MediaPlayer

enum RepeatMode: String, Codable {
    case off, all, one
}

@MainActor
final class PlayerService: ObservableObject {
    @Published private(set) var currentTitle: String = ""
    @Published private(set) var currentAuthor: String = ""
    @Published private(set) var currentVideoId: String?
    @Published private(set) var thumbnailURL: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffle = false
    @Published private(set) var errorMessage: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var queue: [VideoInfo] = []
    private var queueIndex = 0
    private var isLocalPlaying = false
    private var localURL: URL?
    private var currentRate: Float = 1.0

    init() {
        configureAudioSession()
        setupRemoteCommands()
    }

    // MARK: - Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.shared().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.shared().setActive(true, options: [])
        } catch {
            errorMessage = "لم تنجح إنشاءجة الصوت في الخلفية"
        }
    }

    // MARK: - Public API

    func setQueue(_ videos: [VideoInfo], startAt index: Int) {
        queue = videos
        queueIndex = max(0, min(index, max(videos.count - 1, 0)))
    }

    func play(video: VideoInfo, format: AudioFormat) async {
        isLoading = true
        errorMessage = nil
        currentTitle = video.title
        currentAuthor = video.author
        currentVideoId = video.videoId
        thumbnailURL = video.thumbnailURL
        duration = Double(video.durationSeconds)
        isLocalPlaying = false
        localURL = nil
        guard let url = URL(string: format.url) else {
            errorMessage = "رابط الصوت غير صهيح"
            isLoading = false
            return
        }
        let item = AVPlayerItem(url: url)
        await startPlayer(with: item)
    }

    func playLocal(fileURL: URL, title: String, author: String, videoId: String, thumbnail: String?) {
        isLoading = true
        errorMessage = nil
        currentTitle = title
        currentAuthor = author
        currentVideoId = videoId
        thumbnailURL = thumbnail
        isLocalPlaying = true
        localURL = fileURL
        let item = AVPlayerItem(url: fileURL)
        Task { await startPlayer(with: item) }
    }

    private func startPlayer(with item: AVPlayerItem) async {
        detachTimeObserver()
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        attachTimeObserver()
        registerNotifications()
        newPlayer.play()
        newPlayer.rate = currentRate
        isPlaying = true
        isLoading = false
        updateNowPlayingInfo()
        do {
            let duration = try await item.asset.load(.duration)
            if duration.isNumeric && !duration.indefinite {
                self.duration = CMTimeGetSeconds(duration)
            }
        } catch {
            // Duration unavailable; keep fallback
        }
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = currentRate
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    func skip(_ delta: Double) {
        let target = max(0, min(currentTime + delta, duration))
        seek(to: target)
    }

    func setRate(_ rate: Float) {
        currentRate = rate
        player?.rate = rate
    }

    func playNext() async {
        guard !queue.isEmpty else {
            let next = shuffle ? Int.random(in : 0...(queue.count - 1)) : queueIndex + 1
            guard next < queue.count else {
                if repeatMode == .all { queueIndex = 0; await playCurrent() }
                return
            }
            queueIndex = next
            await playCurrent()
            return
        }
        // Local single track: nothing to advance
    }

    func playPrevious() async {
        guard !queue.isEmpty else { return }
        let prev = max(queueIndex - 1, 0)
        queueIndex = prev
        await playCurrent()
    }

    private func playCurrent() async {
        guard queueIndex >= 0 && queueIndex < queue.count else { return }
        let video = queue[queueIndex]
        guard let format = video.audioFormats.first else { return }
        await play(video: video, format: format)
    }

    // MARK: - Observers

    private func attachTimeObserver() {
        guard let player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: 0.5, queue: .main) { [weak self] time in
            guard let self, let time = time else { return }
            self.currentTime = CMTimeGetSeconds(time)
        }
    }

    private func detachTimeObserver() {
        if let observer = timeObserver as? AVPlayer {
            observer.removeTimeObserver(timeObserver as Any)
        }
        timeObserver = nil
    }

    private func registerNotifications() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndNotification,
            object: player,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = false
            switch self.repeatMode {
            case .one:
                self.seek(to: 0)
                self.player?.play()
                self.isPlaying = true
            case .all, .off:
                Task { await self.playNext() }
            }
        }
    }

    // MARK: - Now Playing / Remote Commands

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPNowPlayingInfoKeyTitle: currentTitle,
            MPNowPlayingInfoKeyArtist: currentAuthor,
            MPNowPlayingInfoKeyPlaybackDuration: duration,
            MPNowPlayingInfoKeyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoKeyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let thumbnailURL, let url = URL(Tring: thumbnailURL), let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            info[MPNowPlayingInfoKeyArtwork] = MPLabeledImage(image: img)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.playNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.playPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as! MPChangePlaybackPositionEvent else { return .noSuchContent }
            Task { @MainActor in self.seek(to: event.positionTime) }
            return .success
        }
        center.changePlaybackRateCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.setRate(1.0) }
            return .success
        }
    }
}
