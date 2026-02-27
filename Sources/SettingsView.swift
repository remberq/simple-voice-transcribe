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
                Text("Настройки провайдера")
                    .font(.headline)
                
                Picker("Провайдер", selection: $settings.providerSelection) {
                    Text("OpenAI").tag("openai")
                    Text("Google Gemini").tag("gemini")
                    Text("OpenRouter").tag("openrouter")
                    Text("Свой (Custom OpenAI)").tag("custom")
                    Text("Mock (Тестовый)").tag("mock")
                }
                .pickerStyle(.menu)
                .onChange(of: settings.providerSelection) { newValue in
                    // Reset model to default for the provider when switching
                    switch newValue {
                    case "openai": settings.selectedModel = "whisper-1"
                    case "gemini": settings.selectedModel = "gemini-1.5-flash"
                    case "openrouter": settings.selectedModel = "openai/gpt-4o-audio-preview"
                    default: break
                    }
                }
                
                if settings.providerSelection != "mock" {
                    Divider()
                        .padding(.vertical, 8)
                        
                    providerConfigSection
                    
                    Divider()
                        .padding(.vertical, 8)
                        
                    apiKeySection
                }
            }
        }
    }
    
    @ViewBuilder
    private var providerConfigSection: some View {
        switch settings.providerSelection {
        case "custom":
            VStack(alignment: .leading, spacing: 12) {
                Text("Настройки Custom сервера")
                    .font(.headline)
                
                HStack {
                    Text("Имя:"); Spacer()
                    TextField("Имя провайдера", text: $settings.customProviderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }
                
                HStack {
                    Text("Base URL:"); Spacer()
                    TextField("https://api.example.com/v1", text: $settings.customProviderBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }
                
                HStack {
                    Text("Модель STT:"); Spacer()
                    TextField("whisper-1", text: $settings.customProviderModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }
            }
            
        case "openai":
            Picker("Модель", selection: $settings.selectedModel) {
                Text("Whisper 1 (whisper-1)").tag("whisper-1")
            }
            .pickerStyle(.menu)
            
        case "gemini":
            Picker("Модель", selection: $settings.selectedModel) {
                Text("Gemini 1.5 Flash").tag("gemini-1.5-flash")
                Text("Gemini 1.5 Pro").tag("gemini-1.5-pro")
                Text("Gemini 2.0 Flash").tag("gemini-2.0-flash")
            }
            .pickerStyle(.menu)
            
        case "openrouter":
            Picker("Модель", selection: $settings.selectedModel) {
                Text("GPT-4o Audio Preview").tag("openai/gpt-4o-audio-preview")
                Text("Whisper 3 (Large)").tag("openai/whisper-large-v3")
            }
            .pickerStyle(.menu)
            
        default:
            EmptyView()
        }
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Ключ")
                .font(.headline)

            Toggle("Хранить API-ключ в Связке ключей (Keychain)", isOn: $settings.storeAPIKeyInKeychain)
            
            HStack {
                SecureField("Введите API-ключ", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        settings.setAPIKey(apiKeyInput)
                    }
                
                Button("Сохранить") {
                    settings.setAPIKey(apiKeyInput)
                }

                Button("Удалить") {
                    settings.deleteAPIKey()
                    apiKeyInput = ""
                }
            }
            
            HStack {
                if let storedKey = settings.getAPIKey(), !storedKey.isEmpty {
                    Text("Ключ сохранен (\(storedKey.count) символов)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Ключ не сохранен")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Button("Проверить подключение") {
                    testConnection()
                }
                .disabled((settings.getAPIKey() ?? "").isEmpty)
            }
            
            if !connectionTestResult.isEmpty {
                Text(connectionTestResult)
                    .font(.caption)
                    .foregroundColor(connectionTestSuccess ? .green : .red)
            }
            
            if settings.storeAPIKeyInKeychain {
                Text("Ключ безопасно хранится в macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Режим только на сессию: ключ удаляется при выходе.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @State private var connectionTestResult: String = ""
    @State private var connectionTestSuccess: Bool = false
    
    private func testConnection() {
        connectionTestResult = "Проверка..."
        connectionTestSuccess = false
        
        let provider = settings.providerSelection
        guard let apiKey = settings.getAPIKey(), !apiKey.isEmpty else {
            connectionTestResult = "Ошибка: Нет ключа API"
            return
        }
        
        Task {
            // Determine the URL based on the provider
            var urlString = ""
            switch provider {
            case "openai":
                urlString = "https://api.openai.com/v1/models"
            case "openrouter":
                urlString = "https://openrouter.ai/api/v1/models"
            case "gemini":
                urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
            case "custom":
                let base = settings.customProviderBaseURL
                let cleanBase = base.hasSuffix("/chat/completions") ? base.replacingOccurrences(of: "/chat/completions", with: "") : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                urlString = "\(cleanBase)/models"
            default:
                await MainActor.run {
                    self.connectionTestResult = "Ошибка: Неподдерживаемый провайдер для проверки"
                }
                return
            }
            
            guard let url = URL(string: urlString) else {
                await MainActor.run { self.connectionTestResult = "Ошибка: Неверный URL сервера" }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // OpenAI/OpenRouter/Custom require Bearer token
            if provider != "gemini" {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                if provider == "openrouter" {
                    request.setValue("VoiceOverlay/1.0", forHTTPHeaderField: "HTTP-Referer")
                    request.setValue("Voice Overlay macOS App", forHTTPHeaderField: "X-Title")
                }
            }
            
            request.timeoutInterval = 10 // Quick timeout for connection test
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            self.connectionTestSuccess = true
                            self.connectionTestResult = "Успешное подключение к \(provider.capitalized)!"
                        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                            self.connectionTestSuccess = false
                            self.connectionTestResult = "Ошибка: Неверный API ключ"
                        } else {
                            self.connectionTestSuccess = false
                            self.connectionTestResult = "Ошибка: Сервер вернул код \(httpResponse.statusCode)"
                        }
                    } else {
                        self.connectionTestSuccess = false
                        self.connectionTestResult = "Ошибка: Неизвестный ответ сервера"
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionTestSuccess = false
                    self.connectionTestResult = "Ошибка подключения: \(error.localizedDescription)"
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
