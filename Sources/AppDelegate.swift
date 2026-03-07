import AppKit
import SwiftUI
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var appMenu: NSMenu!
    var settingsWindow: NSWindow?
    var historyWindow: NSWindow?
    var welcomeWindow: NSWindow?
    var mockMenuItem: NSMenuItem!
    private var historyCancellable: AnyCancellable?
    private var transcribingAnimationTimer: Timer?
    private var transcribingFrameIndex = 0
    private var shouldRestoreVisibleWindowsAfterPermissionPrompt = false
    private var permissionFlowObservers: [NSObjectProtocol] = []
    
    private let idleStatusSymbolName = "mic.circle.fill"
    private let transcribingStatusSymbolFrames = [
        "hourglass",
        "hourglass.bottomhalf.filled",
        "hourglass.tophalf.filled"
    ]
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Decrease tooltip delay so the tray icon tooltip shows up faster
        UserDefaults.standard.set(100, forKey: "NSInitialToolTipDelay")
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        
        // Request Notification Permissions
        markPermissionPromptWillBeShown()
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
            DispatchQueue.main.async {
                self?.restoreVisibleWindowsAfterPermissionPromptIfNeeded()
            }
        }
        
        // Ensure app icon is explicitly set for system surfaces (for example notifications).
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }
        
        let permissionFlowStartObserver = NotificationCenter.default.addObserver(
            forName: PermissionsCoordinator.permissionFlowWillStartNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.markPermissionPromptWillBeShown()
        }
        
        let permissionFlowFinishObserver = NotificationCenter.default.addObserver(
            forName: PermissionsCoordinator.permissionFlowDidFinishNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoreVisibleWindowsAfterPermissionPromptIfNeeded()
        }
        
        permissionFlowObservers = [permissionFlowStartObserver, permissionFlowFinishObserver]
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay (Debug)", action: #selector(toggleOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Приветствие", action: #selector(openWelcomeFromMenu), keyEquivalent: "w"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "История транскрибаций", action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Загрузить файл", action: #selector(triggerFileUpload), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        mockMenuItem = NSMenuItem(title: SettingsManager.shared.mockModeEnabled ? "Выключить мок (с задержкой)" : "Включить мок (с задержкой)", action: #selector(toggleMockMode), keyEquivalent: "m")
        menu.addItem(mockMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Troubleshooting", action: #selector(openOpsDocs), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.appMenu = menu
        self.appMenu.delegate = self
        
        if let button = statusItem.button {
            button.image = makeStatusSymbolImage(named: idleStatusSymbolName)
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup overlay silently
        OverlayController.shared.setup()
        
        // Pre-warm the Keychain access to prevent Keychain prompt delays in Settings.
        DispatchQueue.global(qos: .userInitiated).async {
            if let activeId = SettingsManager.shared.activeProviderId {
                _ = SettingsManager.shared.getAPIKey(for: activeId)
            }
        }
        
        // Register global hotkey
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.toggleOverlay()
        }
        HotkeyManager.shared.onFileUploadHotkeyPressed = { [weak self] in
            self?.triggerFileUpload()
        }
        HotkeyManager.shared.registerHotkey()
        
        // Reflect history active jobs in status bar icon animation.
        observeHistoryState()
        
        showWelcomeOnFirstLaunchIfNeeded()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        restoreVisibleWindowsAfterPermissionPromptIfNeeded()
    }
    
    @objc func toggleOverlay() {
        if !SettingsManager.shared.hasCompletedWelcome || PermissionsCoordinator.shared.microphoneAuthorizationStatus != .authorized {
            openWelcome()
            return
        }
        
        OverlayController.shared.toggle()
    }
    
    @objc func triggerFileUpload() {
        OverlayController.shared.toggleFileUpload()
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let isSettingsOpen = settingsWindow != nil && settingsWindow!.isVisible
        let isHistoryOpen = historyWindow != nil && historyWindow!.isVisible
        let isWelcomeOpen = welcomeWindow != nil && welcomeWindow!.isVisible
        
        if let event = NSApp.currentEvent, event.type == .leftMouseUp && (isSettingsOpen || isHistoryOpen || isWelcomeOpen) {
            bringVisibleWindowsToFront()
        } else {
            statusItem.menu = appMenu
            statusItem.button?.performClick(nil)
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 370),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Voice Overlay Settings"
            window.center()
            window.contentView = hostingController.view
            window.isReleasedWhenClosed = false
            
            self.settingsWindow = window
        }
        
        bringSettingsToFront()
    }
    
    @objc func openHistory() {
        if historyWindow == nil {
            let view = HistoryView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "История транскрибаций"
            window.center()
            window.contentView = hostingController.view
            window.isReleasedWhenClosed = false
            
            self.historyWindow = window
        }
        
        bringHistoryToFront()
    }
    
    @objc func openWelcomeFromMenu() {
        openWelcome()
    }
    
    func openWelcome() {
        if welcomeWindow == nil {
            let view = WelcomeView(
                onRequestMicrophone: { updateStatus in
                    let coordinator = PermissionsCoordinator.shared
                    let status = coordinator.microphoneAuthorizationStatus
                    
                    switch status {
                    case .notDetermined:
                        coordinator.requestMicrophonePermission { newStatus in
                            updateStatus(newStatus)
                        }
                    case .denied, .restricted:
                        coordinator.openSystemSettings(for: .microphone)
                        updateStatus(coordinator.microphoneAuthorizationStatus)
                    case .authorized:
                        updateStatus(status)
                    @unknown default:
                        updateStatus(status)
                    }
                },
                onStart: { [weak self] in
                    SettingsManager.shared.hasCompletedWelcome = true
                    self?.closeWelcome()
                },
                onClose: { [weak self] in
                    self?.closeWelcome()
                }
            )
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Добро пожаловать"
            window.center()
            window.contentView = hostingController.view
            window.isReleasedWhenClosed = false
            
            self.welcomeWindow = window
        }
        
        bringWelcomeToFront()
    }
    
    func closeWelcome() {
        welcomeWindow?.orderOut(nil)
    }
    
    @objc func toggleMockMode() {
        SettingsManager.shared.mockModeEnabled.toggle()
        mockMenuItem.title = SettingsManager.shared.mockModeEnabled ? "Выключить мок (с задержкой)" : "Включить мок (с задержкой)"
    }
    
    @objc func openOpsDocs() {
        // Open the runbooks document
        let docsPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/ops/troubleshooting.md")
        NSWorkspace.shared.open(docsPath)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    @objc func testNotification() {
        OverlayController.shared.sendDebugNotification()
    }

    private func observeHistoryState() {
        historyCancellable = TranscriptionHistoryManager.shared.$jobs
            .receive(on: RunLoop.main)
            .sink { [weak self] jobs in
                guard let self = self else { return }
                
                let hasActiveJobs = jobs.contains(where: { $0.status == .uploading || $0.status == .processing })
                
                if hasActiveJobs {
                    self.startTranscribingStatusAnimation()
                    self.statusItem.button?.toolTip = "Идет обработка файла"
                } else {
                    self.stopTranscribingStatusAnimation()
                    self.statusItem.button?.image = self.makeStatusSymbolImage(named: self.idleStatusSymbolName)
                    self.statusItem.button?.toolTip = nil
                }
            }
    }

    private func startTranscribingStatusAnimation() {
        if transcribingAnimationTimer != nil { return }
        transcribingFrameIndex = 0
        statusItem.button?.image = makeStatusSymbolImage(named: transcribingStatusSymbolFrames[0])
        
        transcribingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.transcribingFrameIndex = (self.transcribingFrameIndex + 1) % self.transcribingStatusSymbolFrames.count
            let symbolName = self.transcribingStatusSymbolFrames[self.transcribingFrameIndex]
            self.statusItem.button?.image = self.makeStatusSymbolImage(named: symbolName)
        }
    }

    private func stopTranscribingStatusAnimation() {
        transcribingAnimationTimer?.invalidate()
        transcribingAnimationTimer = nil
        transcribingFrameIndex = 0
    }

    private func makeStatusSymbolImage(named symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Voice Overlay")?.withSymbolConfiguration(config)
            ?? NSImage(systemSymbolName: idleStatusSymbolName, accessibilityDescription: "Voice Overlay")?.withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
    
    private func showWelcomeOnFirstLaunchIfNeeded() {
        // If either welcome hasn't been completed or mic permission isn't granted, ensure we show Welcome
        if !SettingsManager.shared.hasCompletedWelcome || PermissionsCoordinator.shared.microphoneAuthorizationStatus != .authorized {
            openWelcome()
        }
    }
    
    private func bringWelcomeToFront() {
        guard let welcomeWindow = welcomeWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow.orderFrontRegardless()
        welcomeWindow.makeKeyAndOrderFront(nil)
    }
    
    private func bringSettingsToFront() {
        guard let settingsWindow = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.orderFrontRegardless()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    private func bringHistoryToFront() {
        guard let historyWindow = historyWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        historyWindow.orderFrontRegardless()
        historyWindow.makeKeyAndOrderFront(nil)
    }
    
    private func bringVisibleWindowsToFront() {
        if welcomeWindow?.isVisible == true { bringWelcomeToFront() }
        if settingsWindow?.isVisible == true { bringSettingsToFront() }
        if historyWindow?.isVisible == true { bringHistoryToFront() }
    }
    
    private func markPermissionPromptWillBeShown() {
        shouldRestoreVisibleWindowsAfterPermissionPrompt = true
    }
    
    private func restoreVisibleWindowsAfterPermissionPromptIfNeeded() {
        guard shouldRestoreVisibleWindowsAfterPermissionPrompt else { return }
        shouldRestoreVisibleWindowsAfterPermissionPrompt = false
        
        // System permission dialogs can dismiss asynchronously relative to callback timing.
        // Restore window order immediately and once more shortly after dismissal.
        DispatchQueue.main.async { [weak self] in
            self?.bringVisibleWindowsToFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.bringVisibleWindowsToFront()
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let action = userInfo["action"] as? String, action == "openHistory" {
            DispatchQueue.main.async {
                self.openHistory()
            }
        }
        completionHandler()
    }
}
