import AppKit
import SwiftUI
import UserNotifications

class OverlayController: ObservableObject {
    static let shared = OverlayController()
    
    @Published var state: OverlayState = .idle
    @Published var toastMessage: String?
    
    
    private var panel: NSPanel?
    
    // Use an internal initializer to configure SwiftUI bindings
    private init() {}
    
    func setup(at point: CGPoint? = nil) {
        if panel != nil { return }
        
        let overlayView = OverlayView(controller: self)
        let hostingView = NSHostingView(rootView: overlayView)
        
        // Define panel size to match SwiftUI view (80 content + 16 padding each side = 112)
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 112, height: 112),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Appear on top, join all spaces including fullscreen
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Transparent background
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false // Shadow is handled by SwiftUI
        
        newPanel.contentView = hostingView
        
        if let point = point {
            newPanel.setFrameOrigin(point)
        } else if let screen = NSScreen.main {
            let x = screen.frame.midX - 56
            let y = screen.frame.minY + 100
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // For morphing states like .transcribing or .error which are wider, 
        // we might expand the panel content size later if needed, but for now 
        // SwiftUI handles rendering out-of-bounds if the view expands slightly.
        // Actually, we should allow the panel to animate its frame if SwiftUI changes, or just set it large enough.
        // Let's set the panel width to 160 but the hit box in SwiftUI to just the icon, 
        // OR dynamically adjust panel frame in SwiftUI `.onReceive`. For TG-11's scope, 80x80 is fine for record/idle.
        
        self.panel = newPanel
    }
    
    func show(at point: CGPoint? = nil) {
        if panel == nil { 
            setup(at: point) 
        } else if let point = point {
            panel?.setFrameOrigin(point)
        }
        panel?.orderFrontRegardless() // Show without grabbing focus
    }
    
    func hide(after delay: TimeInterval = 0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.hide(after: 0)
            }
            return
        }
        
        toastMessage = nil
        panel?.orderOut(nil) // Hide without destroying — close() invalidates the panel
        
        if state == .recording || state == .paused {
            _ = RecorderService.shared.stopRecording()
        }
        state = .idle
    }
    
    func toggle() {
        if let panel = panel, panel.isVisible {
            if state == .recording {
                // If recording, stop and transcribe instead of discarding
                handleStop()
            } else {
                hide()
            }
        } else {
            // Re-capture focus anchors on hotkey toggle
            FocusAndInsertService.shared.captureInteractionAnchor()
            let point = FocusAndInsertService.shared.calculateOverlayPosition()
            show(at: point)
        }
    }
    
    // MARK: - Interactions
    
    func handleTap() {
        if !PermissionsCoordinator.shared.isMicrophoneAuthorized {
            if state == .error {
                // If already in error and tapped again, open microphone settings
                PermissionsCoordinator.shared.openSystemSettings(for: .microphone)
                hide()
            } else {
                state = .error
            }
            return
        }
        
        switch state {
        case .idle:
            state = .recording
            FocusAndInsertService.shared.captureInitialFocus()
            RecorderService.shared.startRecording()
        case .recording, .paused:
            // Do nothing on tap if recording (hold to stop handles it)
            break
        case .transcribing, .error:
            // Dismiss or reset on tap
            state = .idle
            hide()
        }
    }
    
    func handleStop() {
        guard state == .recording else { return }
        
        state = .transcribing
        
        if let fileUrl = RecorderService.shared.stopRecording() {
            transcribeAndInsert(fileUrl: fileUrl)
        } else {
            // Recorder is still preparing — use async callback to get the URL when ready
            RecorderService.shared.stopRecording { [weak self] url in
                guard let self = self else { return }
                if let url = url {
                    self.transcribeAndInsert(fileUrl: url)
                } else {
                    self.showNotification(title: "Transcription Failed", body: "Could not save audio file.")
                    self.hide()
                }
            }
        }
    }
    
    private func transcribeAndInsert(fileUrl: URL) {
        // Determine transcriber
        let transcriber: TranscriptionService
        if SettingsManager.shared.providerSelection == "remote" {
            if let apiKey = SettingsManager.shared.getAPIKey(), !apiKey.isEmpty {
                transcriber = RemoteTranscriptionService(apiKey: apiKey)
            } else {
                print("Remote provider selected but no API key found. Falling back to Mock.")
                transcriber = MockTranscriptionService()
            }
        } else {
            transcriber = MockTranscriptionService()
        }
        
        // Kick off async transcription
        Task {
            do {
                let text = try await transcriber.transcribe(audioFileURL: fileUrl)
                print("Transcription Context:\n\(text)")
                
                // Copy to clipboard and potentially insert into focused app
                let toastResult = FocusAndInsertService.shared.handleTranscription(text)
                
                await MainActor.run {
                    self.showNotification(title: "Voice Overlay", body: toastResult)
                    self.hide()
                }
            } catch {
                print("Transcription failed: \(error)")
                await MainActor.run {
                    self.showNotification(title: "Transcription Error", body: error.localizedDescription)
                    self.hide()
                }
            }
        }
    }
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Optionally add a sound
        // content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }
}
