import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case hotkey = "Горячая клавиша"
    case transcription = "Транскрибация"
    case system = "Система"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .hotkey: return "keyboard"
        case .transcription: return "waveform"
        case .system: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var apiKeyInput: String = ""
    @State private var selectedTab: SettingsTab = .hotkey
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Always-visible tab bar
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            Divider()
            
            // MARK: - Tab content
            Group {
                switch selectedTab {
                case .hotkey:
                    hotkeyTab
                case .transcription:
                    transcriptionTab

                case .system:
                    systemTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 370)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            apiKeyInput = settings.getAPIKey() ?? ""
        }
    }
    
    // MARK: - Hotkey Tab
    private var hotkeyTab: some View {
        settingsPage {
            VStack(alignment: .leading, spacing: 16) {
                Text("Глобальная горячая клавиша")
                    .font(.headline)
                
                Text("Нажмите сочетание клавиш, чтобы показать или скрыть Voice Overlay.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HotkeyRecorderView(settings: settings)
                    .padding(.top, 4)
                
                Button("Сбросить по умолчанию (Cmd+Shift+Space)") {
                    settings.hotkeyKeyCode = 49
                    settings.hotkeyModifiers = 768
                    HotkeyManager.shared.reloadHotkey()
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Transcription Tab
    private var transcriptionTab: some View {
        settingsPage {
            VStack(alignment: .leading, spacing: 16) {
                Text("Провайдер транскрибации")
                    .font(.headline)
                
                Picker("Провайдер", selection: $settings.providerSelection) {
                    Text("Mock (Тестовый)").tag("mock")
                    Text("OpenRouter").tag("remote")
                }
                .pickerStyle(.radioGroup)
                
                if settings.providerSelection == "remote" {
                    Divider()
                        .padding(.vertical, 8)
                    Text("Настройки OpenRouter")
                        .font(.headline)

                    Toggle("Хранить API-ключ в Связке ключей (Keychain)", isOn: $settings.storeAPIKeyInKeychain)
                    
                    HStack {
                        SecureField("Вставьте API-ключ OpenRouter", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                settings.setAPIKey(apiKeyInput)
                            }
                        
                        Button("Сохранить") {
                            settings.setAPIKey(apiKeyInput)
                        }

                        Button("Удалить ключ") {
                            settings.deleteAPIKey()
                            apiKeyInput = ""
                        }
                    }
                    
                    if let storedKey = settings.getAPIKey(), !storedKey.isEmpty {
                        Text("Ключ сохранен (\(storedKey.count) символов)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Ключ не сохранен")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if settings.storeAPIKeyInKeychain {
                        Text("Ключ хранится в системной Связке ключей macOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Режим только на сессию: ключ хранится в памяти и удаляется при выходе из приложения.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Модель: openai/gpt-4o-audio-preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    

    // MARK: - System Tab
    private var systemTab: some View {
        settingsPage {
            VStack(alignment: .leading, spacing: 16) {
                Text("Разрешения")
                    .font(.headline)
                
                Button("Открыть настройки macOS (Микрофон)") {
                    PermissionsCoordinator.shared.openSystemSettings(for: .microphone)
                }
            }
        }
    }

    @ViewBuilder
    private func settingsPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
