import Foundation
import os.log

class Logger {
    static let shared = Logger()
    
    private let queue = DispatchQueue(label: "com.anti.VoiceOverlay.Logger")
    private let logFileURL: URL
    
    // Fallback to os.log for fatal errors where the file system isn't available
    private let systemLogger = OSLog(subsystem: "com.anti.VoiceOverlay", category: "App")
    
    public var logsDirectory: URL {
        return logFileURL.deletingLastPathComponent()
    }
    
    private init() {
        let fileManager = FileManager.default
        
        // Find or create ~/Library/Application Support/VoiceOverlay/Logs
        if let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupportDir.appendingPathComponent("VoiceOverlay")
            let logsDir = appDir.appendingPathComponent("Logs")
            
            do {
                try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Failed to create logs directory: %{public}@", log: systemLogger, type: .error, error.localizedDescription)
            }
            
            self.logFileURL = logsDir.appendingPathComponent("VoiceOverlay.log")
        } else {
            // Fallback to cache directory if Application Support is somehow unavailable
            let fallbackDir = fileManager.temporaryDirectory.appendingPathComponent("VoiceOverlayLogs")
            try? fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
            self.logFileURL = fallbackDir.appendingPathComponent("VoiceOverlay.log")
        }
        
        // Initialize file if not exists
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        info("Logger initialized. Logging to \(logFileURL.path)")
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "INFO", message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: "ERROR", message: message, file: file, function: function, line: line)
    }
    
    private func log(level: String, message: String, file: String, function: String, line: Int) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let formattedMessage = "[\(timestamp)] [\(level)] [\(filename):\(line)] \(function) - \(message)\n"
        
        // Print to Xcode console
        print(formattedMessage, terminator: "")
        
        // Append to file safely in background queue
        queue.async {
            guard let data = formattedMessage.data(using: .utf8) else { return }
            
            do {
                let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                defer { try? fileHandle.close() }
                
                if #available(macOS 10.15.4, *) {
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                } else {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
            } catch {
                // If appending fails, we use OSLog as a fallback
                os_log("Failed to write to log file: %{public}@", log: self.systemLogger, type: .error, error.localizedDescription)
            }
        }
    }
}
