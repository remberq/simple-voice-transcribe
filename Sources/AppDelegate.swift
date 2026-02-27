import AppKit
import SwiftUI
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    private var overlayStateCancellable: AnyCancellable?
    private var transcribingAnimationTimer: Timer?
    private var transcribingFrameIndex = 0
    
    private let idleStatusSymbolName = "mic.circle.fill"
    private let transcribingStatusSymbolFrames = [
        "hourglass",
        "hourglass.bottomhalf.filled",
        "hourglass.tophalf.filled"
    ]
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        
        // Request Notification Permissions
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
        
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = makeStatusSymbolImage(named: idleStatusSymbolName)
        }

        // Ensure app icon is explicitly set for system surfaces (for example notifications).
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay (Debug)", action: #selector(toggleOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Test Notification", action: #selector(testNotification), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Troubleshooting", action: #selector(openOpsDocs), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Setup overlay silently
        OverlayController.shared.setup()
        
        // Pre-warm the Keychain access and proactively ask for Permissions on first launch.
        // Doing this here prevents the Keychain Prompt from blocking the Settings window UI later.
        DispatchQueue.global(qos: .userInitiated).async {
            if let activeId = SettingsManager.shared.activeProviderId {
                _ = SettingsManager.shared.getAPIKey(for: activeId)
            }
            DispatchQueue.main.async {
                PermissionsCoordinator.shared.requestAll { _ in }
            }
        }
        
        // Register global hotkey
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.toggleOverlay()
        }
        HotkeyManager.shared.registerHotkey()
        
        // Reflect overlay runtime state in status bar icon.
        observeOverlayState()
    }
    
    @objc func toggleOverlay() {
        OverlayController.shared.toggle()
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
        
        // Critical: Force the app and window to the foreground despite LSUIElement
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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

    private func observeOverlayState() {
        overlayStateCancellable = OverlayController.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .transcribing {
                    self.startTranscribingStatusAnimation()
                } else {
                    self.stopTranscribingStatusAnimation()
                    self.statusItem.button?.image = self.makeStatusSymbolImage(named: self.idleStatusSymbolName)
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
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Voice Overlay")
            ?? NSImage(systemSymbolName: idleStatusSymbolName, accessibilityDescription: "Voice Overlay")
        image?.isTemplate = true
        return image
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .sound])
    }
}
