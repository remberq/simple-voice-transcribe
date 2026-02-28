import Foundation

class AsyncUploadHelper: NSObject, URLSessionTaskDelegate {
    private var progressHandler: ((Double) -> Void)?
    
    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandler?(progress)
    }
    
    static func upload(request: URLRequest, data: Data, onProgress: ((Double) -> Void)?) async throws -> (Data, URLResponse) {
        let helper = AsyncUploadHelper(progressHandler: onProgress)
        // A dedicated session per upload so we can attach a delegate without affecting shared
        let session = URLSession(configuration: .default, delegate: helper, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        
        return try await session.upload(for: request, from: data)
    }
}
