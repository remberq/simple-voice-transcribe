import Foundation
import AVFoundation

class RecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = RecorderService()
    
    /// Normalized audio level 0.0–1.0 for UI visualization
    @Published var audioLevel: CGFloat = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meteringTimer: Timer?
    
    // Safety flag to prevent rapid stop before start finishes
    private var isPreparing = false
    private var pendingStop = false
    private var pendingCancel = false
    private var onPendingStopComplete: ((URL?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined, .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func startRecording(completion: ((Bool) -> Void)? = nil) {
        guard !isPreparing else { return }
        isPreparing = true
        pendingStop = false
        pendingCancel = false
        
        checkPermission { [weak self] granted in
            guard let self = self else { return }
            
            guard granted else {
                print("Microphone permission denied.")
                self.isPreparing = false
                completion?(false)
                return
            }
            
            // Setup temp URL — WAV format for OpenAI compatibility
            let fileName = "voice_overlay_\(UUID().uuidString).wav"
            let tempDir = FileManager.default.temporaryDirectory
            let url = tempDir.appendingPathComponent(fileName)
            self.recordingURL = url
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
            
            do {
                self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                self.audioRecorder?.delegate = self
                self.audioRecorder?.isMeteringEnabled = true
                let didStart = self.audioRecorder?.record() ?? false
                self.isPreparing = false

                if self.pendingCancel {
                    self.pendingCancel = false
                    self.pendingStop = false
                    self.onPendingStopComplete = nil
                    self.cancelRecording()
                    completion?(false)
                    return
                }

                if didStart {
                    self.startMetering()
                    print("Recording started at: \(url)")
                    completion?(true)
                } else {
                    print("AVAudioRecorder failed to start recording.")
                    self.audioRecorder = nil
                    self.recordingURL = nil
                    completion?(false)
                }
            } catch {
                print("Failed to setup audio recorder: \(error)")
                self.isPreparing = false
                self.audioRecorder = nil
                self.recordingURL = nil
                completion?(false)
            }

            // If the user tapped stop before we finished building the recorder, process it now
            if self.pendingStop {
                self.pendingStop = false
                let url = self.stopRecording()
                self.onPendingStopComplete?(url)
                self.onPendingStopComplete = nil
            }
        }
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        print("Recording paused.")
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        print("Recording resumed.")
    }
    
    func stopRecording() -> URL? {
        if isPreparing {
            print("Stop called while preparing, queuing stop event.")
            pendingStop = true
            pendingCancel = false
            return nil 
        }

        let finalUrl = finalizeRecording()
        print("Recording stopped. File at: \(String(describing: finalUrl))")
        return finalUrl
    }

    func cancelRecording() {
        if isPreparing {
            print("Cancel called while preparing, queuing cancel event.")
            pendingCancel = true
            pendingStop = false
            onPendingStopComplete = nil
            return
        }

        let cancelledUrl = finalizeRecording()
        removeFileIfNeeded(at: cancelledUrl)
        print("Recording cancelled. File discarded: \(String(describing: cancelledUrl))")
    }
    
    // MARK: - Audio Level Metering
    
    private func startMetering() {
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // dB, range roughly -160 to 0
            // Normalize: treat -50 dB as silence, 0 dB as max
            let minDb: Float = -50.0
            let clampedPower = max(minDb, min(power, 0))
            let normalized = CGFloat((clampedPower - minDb) / (0 - minDb))
            DispatchQueue.main.async {
                self.audioLevel = normalized
            }
        }
    }
    
    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
    }
    
    /// Async version of stopRecording that waits for preparation to finish if needed.
    func stopRecording(completion: @escaping (URL?) -> Void) {
        if isPreparing {
            print("Stop called while preparing, queuing stop with callback.")
            pendingStop = true
            pendingCancel = false
            onPendingStopComplete = completion
        } else {
            completion(stopRecording())
        }
    }

    private func finalizeRecording() -> URL? {
        stopMetering()
        audioRecorder?.stop()
        let finalUrl = recordingURL
        audioRecorder = nil
        recordingURL = nil
        return finalUrl
    }

    private func removeFileIfNeeded(at url: URL?) {
        guard let url = url else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Failed to remove cancelled recording: \(error)")
        }
    }
}
