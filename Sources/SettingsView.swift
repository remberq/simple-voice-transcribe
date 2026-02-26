import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    
    var body: some View {
        TabView {
            // MARK: - Hotkey Tab
            VStack(alignment: .leading, spacing: 16) {
                Text("Global Hotkey")
                    .font(.headline)
                
                Text("Press a key combination to toggle Voice Overlay. (Advanced configuration coming soon)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Currently minimal: Just show a label representing the fact we can intercept in the future.
                // Building a full interactive Carbon keycode interceptor in SwiftUI requires a custom NSViewRepresentable.
                // For TG-9 basic persistence, we represent the values.
                HStack {
                    Text("Current Hotkey Code:")
                    Text("\(settings.hotkeyKeyCode)")
                        .bold()
                }
                
                HStack {
                    Text("Modifiers (Carbon Flags):")
                    Text("\(settings.hotkeyModifiers)")
                        .bold()
                }
                
                Button("Reset to Default (Cmd+Shift+Space)") {
                    settings.hotkeyKeyCode = 49
                    settings.hotkeyModifiers = 768
                    HotkeyManager.shared.reloadHotkey()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Hotkey", systemImage: "keyboard")
            }
            
            // MARK: - Transcription Tab
            VStack(alignment: .leading, spacing: 16) {
                Text("Transcription Provider")
                    .font(.headline)
                
                Picker("Provider", selection: $settings.providerSelection) {
                    Text("Mock (Testing)").tag("mock")
                    Text("OpenRouter (Gemini Flash)").tag("remote")
                }
                .pickerStyle(.radioGroup)
                
                if settings.providerSelection == "remote" {
                    Divider()
                        .padding(.vertical, 8)
                    Text("OpenRouter Configuration")
                        .font(.headline)
                    
                    HStack {
                        SecureField("Paste your OpenRouter API key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                settings.setAPIKey(apiKeyInput)
                            }
                        
                        Button("Save Key") {
                            settings.setAPIKey(apiKeyInput)
                        }
                    }
                    
                    if let storedKey = settings.getAPIKey(), !storedKey.isEmpty {
                        Text("✅ Key saved (\(storedKey.count) chars)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("⚠️ No API key saved")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Stored securely in your macOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Model: google/gemini-2.0-flash-001")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                apiKeyInput = settings.getAPIKey() ?? ""
            }
            .tabItem {
                Label("Transcription", systemImage: "waveform")
            }
            
            // MARK: - Insertion Tab
            VStack(alignment: .leading, spacing: 16) {
                Text("Insertion Behavior")
                    .font(.headline)
                
                Toggle("Auto-insert into previously focused input", isOn: $settings.autoInsertEnabled)
                Toggle("If direct insertion fails, fallback to Paste (Cmd+V)", isOn: $settings.fallbackToPaste)
                Toggle("Always copy transcript to clipboard", isOn: $settings.alwaysCopy)
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Insertion", systemImage: "text.cursor")
            }
            
            // MARK: - Permissions & Diagnostics Tab
            VStack(alignment: .leading, spacing: 16) {
                Text("Permissions")
                    .font(.headline)
                
                Button("Open System Settings (Microphone)") {
                    PermissionsCoordinator.shared.openSystemSettings(for: .microphone)
                }
                
                Button("Open System Settings (Accessibility)") {
                    PermissionsCoordinator.shared.openSystemSettings(for: .accessibility)
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("System", systemImage: "gearshape")
            }
        }
        .frame(width: 480, height: 320)
    }
}
