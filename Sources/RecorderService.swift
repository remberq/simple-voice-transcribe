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
    private var onPendingStopComplete: ((URL?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }
    
    func startRecording() {
        guard !isPreparing else { return }
        isPreparing = true
        pendingStop = false
        
        checkPermission { [weak self] granted in
            guard let self = self else { return }
            
            guard granted else {
                print("Microphone permission denied.")
                self.isPreparing = false
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
                self.audioRecorder?.record()
                self.startMetering()
                print("Recording started at: \(url)")
            } catch {
                print("Failed to setup audio recorder: \(error)")
            }
            
            self.isPreparing = false
            
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
            return nil 
        }
        
        stopMetering()
        audioRecorder?.stop()
        let finalUrl = recordingURL
        self.audioRecorder = nil
        self.recordingURL = nil
        print("Recording stopped. File at: \(String(describing: finalUrl))")
        return finalUrl
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
            onPendingStopComplete = completion
        } else {
            completion(stopRecording())
        }
    }
}
