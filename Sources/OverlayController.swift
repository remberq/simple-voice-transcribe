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
                // If recording, stop and transcribe instantly
                handleStop()
            } else {
                hide()
            }
        } else {
            let mouseLoc = NSEvent.mouseLocation
            var point = CGPoint(x: mouseLoc.x + 24, y: mouseLoc.y - 24)
            
            if let screen = NSScreen.main {
               point.x = max(screen.visibleFrame.minX + 12, min(point.x, screen.visibleFrame.maxX - 92))
               point.y = max(screen.visibleFrame.minY + 12, min(point.y, screen.visibleFrame.maxY - 92))
            }
            
            show(at: point)
            
            // Instantly start recording
            if state == .idle {
                handleTap()
            }
        }
    }
    
    // MARK: - Interactions
    
    func handleTap() {
        switch state {
        case .idle:
            RecorderService.shared.startRecording { [weak self] didStart in
                guard let self = self else { return }
                guard self.state == .idle else { return }

                if didStart {
                    self.state = .recording
                } else {
                    self.state = .error
                }
            }
        case .recording, .paused:
            // Do nothing on tap if recording (hold to stop handles it)
            break
        case .error:
            PermissionsCoordinator.shared.openSystemSettings(for: .microphone)
            hide()
        case .transcribing:
            // Dismiss on tap
            state = .idle
            hide()
        }
    }
    
    func handleStop() {
        guard state == .recording else { return }
        
        // If recording yields immediately
        if let fileUrl = RecorderService.shared.stopRecording() {
            // Immedidately return UI to idle so user can start recording again
            state = .idle
            hide()
            transcribeAndInsert(fileUrl: fileUrl)
        } else {
            // Wait for it to finish flushing if needed
            state = .transcribing 
            RecorderService.shared.stopRecording { [weak self] url in
                guard let self = self else { return }
                self.state = .idle
                self.hide()
                if let url = url {
                    self.transcribeAndInsert(fileUrl: url)
                } else {
                    self.presentCompletionFeedback(title: "Ошибка", body: "Не удалось сохранить аудио.", openHistory: false)
                }
            }
        }
    }
    
    private func transcribeAndInsert(fileUrl: URL) {
        // Determine transcriber
        var transcriber: TranscriptionService
        let settings = SettingsManager.shared
        
        var providerName = "Unknown"
        
        if let activeId = settings.activeProviderId,
           let config = settings.savedProviders.first(where: { $0.id == activeId }) {
            
            providerName = config.name
            let apiKey = settings.getAPIKey(for: activeId) ?? ""
            
            // Allow mock to work without key. Other providers need one, unless custom logic applies.
            if apiKey.isEmpty && config.type != "mock" {
                Logger.shared.error("[\(config.name)] Selected but no API key found. Falling back to Mock.")
                transcriber = MockTranscriptionService()
            } else {
                switch config.type {
                case "openai":
                    transcriber = OpenAITranscriptionService(apiKey: apiKey, model: config.model)
                case "gemini":
                    transcriber = GeminiTranscriptionService(apiKey: apiKey, model: config.model)
                case "openrouter":
                    transcriber = RemoteTranscriptionService(apiKey: apiKey, model: config.model, baseURL: "https://openrouter.ai/api/v1")
                case "custom":
                    let base = config.baseURL ?? "https://api.openai.com/v1"
                    let cleanBase = base.hasSuffix("/chat/completions") ? base.replacingOccurrences(of: "/chat/completions", with: "") : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    transcriber = RemoteTranscriptionService(apiKey: apiKey, model: config.model, baseURL: cleanBase)
                case "raif":
                    transcriber = OpenAITranscriptionService(
                        apiKey: apiKey,
                        model: config.model,
                        baseURL: "https://llm-api.cibaa.raiffeisen.ru/v1",
                        prompt: config.prompt,
                        language: config.language,
                        speakerCount: config.speakerCount
                    )
                case "mock":
                    transcriber = MockTranscriptionService()
                default:
                    transcriber = MockTranscriptionService()
                }
            }
        } else {
            Logger.shared.error("No active provider found. Falling back to Mock.")
            transcriber = MockTranscriptionService()
        }
        
        let manager = TranscriptionHistoryManager.shared
        let job = manager.addJob(url: fileUrl, providerName: providerName)
        
        // Kick off async transcription
        let task = Task {
            do {
                if settings.mockModeEnabled {
                    // Simulate upload delay
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
                
                manager.updateJob(id: job.id, status: .processing)
                
                if settings.mockModeEnabled {
                    // Simulate processing delay
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
                
                let text = try await transcriber.transcribe(audioFileURL: fileUrl)
                // If cancelled while awating, exit gracefully
                try Task.checkCancellation()
                
                Logger.shared.info("Transcription \(job.id) completed successfully. Length: \(text.count)")
                
                manager.updateJob(id: job.id, status: .completed, resultText: text)
                
                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                
                await MainActor.run {
                    self.presentCompletionFeedback(title: "Текст скопирован", body: "Транскрибация завершена успешно.", openHistory: true)
                }
            } catch is CancellationError {
                Logger.shared.info("Transcription \(job.id) was cancelled by user.")
                // No feedback needed, the History Manager handled the status
            } catch {
                if Task.isCancelled { return }
                Logger.shared.error("Transcription \(job.id) failed: \(error.localizedDescription)")
                manager.updateJob(id: job.id, status: .failed, errorMessage: error.localizedDescription)
                
                await MainActor.run {
                    self.presentCompletionFeedback(title: "Ошибка", body: error.localizedDescription, openHistory: true)
                }
            }
        }
        
        manager.registerTask(id: job.id, task: task)
    }
    
    private func presentCompletionFeedback(title: String, body: String, openHistory: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            Logger.shared.info("[Notifications] authorizationStatus=\(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.scheduleNotification(title: title, body: body, openHistory: openHistory)
                DispatchQueue.main.async {
                    self.hide()
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        self.scheduleNotification(title: title, body: body, openHistory: openHistory)
                        DispatchQueue.main.async {
                            self.hide()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showToastAndHide(body)
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self.showToastAndHide(body)
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.showToastAndHide(body)
                }
            }
        }
    }

    private func scheduleNotification(title: String, body: String, openHistory: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if openHistory {
            content.userInfo = ["action": "openHistory"]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                Logger.shared.info("[Notifications] Notification scheduled successfully")
            }
        }
    }

    private func showToastAndHide(_ message: String) {
        toastMessage = message
        hide(after: 1.8)
    }

    func sendDebugNotification() {
        presentCompletionFeedback(title: "Voice Overlay Debug", body: "Test notification", openHistory: true)
    }
}
