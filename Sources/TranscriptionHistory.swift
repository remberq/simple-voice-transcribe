import Foundation
import Combine
import AppKit

enum TranscriptionJobStatus: String, Codable {
    case running
    case completed
    case failed
    case cancelled
}

struct TranscriptionJob: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let fileSize: Int64
    let fileFormat: String
    let providerName: String
    
    var status: TranscriptionJobStatus
    var resultText: String?
    var errorMessage: String?
    
    // Relative time string helper (e.g. "5 mins ago")
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // Formatting helper for size (e.g. "1.2 MB")
    var formattedSize: String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useMB, .useKB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: fileSize)
    }
}

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()
    
    @Published var jobs: [TranscriptionJob] = []
    
    private let kHistoryStorageKey = "transcriptionHistory"
    
    // Keep track of ongoing task handles if we want to support cancellation
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    
    private init() {
        loadHistory()
    }
    
    var activeJobsCount: Int {
        jobs.filter { $0.status == .running }.count
    }
    
    func addJob(id: UUID = UUID(), url: URL, providerName: String) -> TranscriptionJob {
        // Evaluate file size and format
        let size = (try? Data(contentsOf: url))?.count ?? 0
        let format = url.pathExtension.uppercased()
        
        let job = TranscriptionJob(
            id: id,
            createdAt: Date(),
            fileSize: Int64(size),
            fileFormat: format.isEmpty ? "AUDIO" : format,
            providerName: providerName,
            status: .running
        )
        
        DispatchQueue.main.async {
            self.jobs.insert(job, at: 0) // newest first
            self.saveHistory()
        }
        
        return job
    }
    
    func updateJob(id: UUID, status: TranscriptionJobStatus, resultText: String? = nil, errorMessage: String? = nil) {
        DispatchQueue.main.async {
            if let index = self.jobs.firstIndex(where: { $0.id == id }) {
                self.jobs[index].status = status
                if let text = resultText {
                    self.jobs[index].resultText = text
                }
                if let error = errorMessage {
                    self.jobs[index].errorMessage = error
                }
                self.saveHistory()
                
                // Active task management
                if status != .running {
                    self.activeTasks[id] = nil
                }
            }
        }
    }
    
    func registerTask(id: UUID, task: Task<Void, Never>) {
        activeTasks[id] = task
    }
    
    func cancelJob(id: UUID) {
        // Find the active task and cancel it
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks[id] = nil
        }
        updateJob(id: id, status: .cancelled)
    }
    
    func deleteJob(id: UUID) {
        DispatchQueue.main.async {
            self.cancelJob(id: id) // ensure it's stopped before deleting
            self.jobs.removeAll { $0.id == id }
            self.saveHistory()
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            for id in self.activeTasks.keys {
                self.cancelJob(id: id)
            }
            self.jobs.removeAll()
            self.saveHistory()
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(jobs) {
            UserDefaults.standard.set(data, forKey: kHistoryStorageKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: kHistoryStorageKey),
           let decoded = try? JSONDecoder().decode([TranscriptionJob].self, from: data) {
            
            // Re-map any jobs that were 'running' when the app closed to 'failed' (or cancelled)
            self.jobs = decoded.map { job in
                var updatedJob = job
                if updatedJob.status == .running {
                    updatedJob.status = .failed
                    updatedJob.errorMessage = "Прервано при закрытии приложения"
                }
                return updatedJob
            }
        }
    }
}
