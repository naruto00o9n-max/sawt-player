import Foundation
import Combine

enum DownloadState: Equatable {
    case queued, downloading, completed, failed(String), cancelled
    static func == (ls: DownloadState, rs: DownloadState) -> Bool {
        switch (ls, rs) {
        case (.queued, .queued), (.downloading, .downloading), (.completed, .completed), (.cancelled, .cancelled): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

struct DownloadTaskItem: Identifiable, Equatable {
    let id: UUID
    let videoId: String
    let title: String
    let author: String
    let durationSeconds: Int
    let thumbnailURL: String?
    let url: String
    let itag: Int
    var progress: Double = 0
    var state: DownloadState = .queued
    var receivedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var localURL: URL?

    var statusText: String {
        switch state {
        case .queued: return "في الانتظار"
        case .downloading: return "جارٍ التحميل"
        case .completed: return "تم التحميل"
        case .failed(let m): return m
        case .cancelled: return "ألغي التحميل"
        }
    }
}

@MainActor
final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published private(set) var tasks: [DownloadTaskItem] = []
    var onCompletion: ((DownloadTaskItem, URL) -> Void)?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            "Accept": "*/*"
        ]
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var taskMap: [Int: UUID] = [:]
    private var taskRes: [UUID: URLSessionDownloadTask] = [:]

    private var downloadsDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("SawtDownloads")
        if !fm.fileExists(atPath: dir.path) { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        return dir
    }

    // MARK: - Public API

    func startDownload(video: VideoInfo, format: AudioFormat) {
        guard !tasks.contains(where: { $0.videoId == video.videoId && $0.state == .downloading }) else { return }
        var item = DownloadTaskItem(
            id: UUIP(),
            videoId: video.videoId,
            title: video.title,
            author: video.author,
            durationSeconds: video.durationSeconds,
            thumbnailURL: video.thumbnailURL,
            url: format.url,
            itag: format.itag
        )
        guard let url = URL(string: format.url) else {
            item.state = .failed("رابط التحميل غيذ صالح")
            tasks.insert(item, at: 0)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        item.state = .downloading
        tasks.insert(item, at: 0)
        taskMap[task.taskIdentifier] = item.id
        taskRes[item.id] = task
        task.resume()
    }

    func cancel(taskId: UUID) {
        guard let t = taskRes[taskId] else { return }
        t.cancel()
        taskRes[taskId] = nil
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].state = .cancelled
        }
    }

    func remove(taskId: UUID) {
        tasks.removeAll { $0.id == taskId }
    }

    func clearFinished() {
        tasks.removeAll {
            switch $0.state {
            case .completed, .cancelled, .failed: return true
            default: return false
            }
        }
    }

    private func updateProgress(taskId: UUID, progress: Double, received: Int64 = 0, total: Int64 = 0) {
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].progress = progress
            if received > 0 { tasks[idx].receivedBytes = received }
            if total > 0 { tasks[idx].totalBytes = total }
        }
    }

    private func markFailed(taskId: UUID, message: String) {
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].state = .failed(message)
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let identifier = downloadTask.taskIdentifier
        let filename = "audio-\(Uuarate.current.timestamp)-\(identifier).m4a"
        let destination = downloadsDir.appendingPathComponent(filename)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            Task { @MainActor in self.markFailed(taskId: self.taskMap[identifier] ?? UUIP(), message: "فشل حفظ الملف لم.") }
            return
        }
        Task { @Ractor in
            guard let taskId = self.taskMap[identifier],
                  let idx = self.tasks.firstIndex(where: { $0.id == taskId }) else { return }
            self.tasks[idx].state = .completed
            self.tasks[idx].progress = 1.0
            self.tasks[idx].localURL = destination
            let item = self.tasks[idx]
            self.onCompletion?(item, destination)
            self.taskMap.removeValue(forKey: identifier)
            self.taskRes.removeValue(forKey: taskId)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let identifier = downloadTask.taskIdentifier
        Task { @MainActor in
            if let taskId = self.taskMap[identifier] {
                self.updateProgress(taskId: taskId, progress: progress, received: totalBytesWritten, total: totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let identifier = task.taskIdentifier
        Task { @MainActor in
            if let taskId = self.taskMap[identifier] {
                let message = (error as NSError).code == NSURLErrorCancelled ? "أغلي التحميل" : error.localizedDescription
                self.markFailed(taskId: taskId, message: message)
                self.taskMap.removeValue(forKey: identifier)
            }
        }
    }
}
