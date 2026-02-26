import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request Notification Permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
        
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Voice Overlay")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay (Debug)", action: #selector(toggleOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Troubleshooting", action: #selector(openOpsDocs), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Setup overlay silently
        OverlayController.shared.setup()
        
        // Pre-warm permissions
        PermissionsCoordinator.shared.requestAll { authorized in
            if !authorized {
                print("Permissions missing on launch. App will warn when triggered.")
            }
        }
        
        // Register global hotkey
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.toggleOverlay()
        }
        HotkeyManager.shared.registerHotkey()
    }
    
    @objc func toggleOverlay() {
        OverlayController.shared.toggle()
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
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
}
