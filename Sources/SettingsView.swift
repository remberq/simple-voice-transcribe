import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case transcription = "Транскрибация"
    case hotkey = "Горячая клавиша"
    case system = "Система"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .hotkey: return "keyboard"
        case .system: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .transcription
    
    // MARK: - Add Provider Form State
    @State private var isAddingProvider = false
    @State private var editingProviderId: UUID? = nil
    @State private var newProviderType: String = "openai"
    @State private var newProviderName: String = ""
    @State private var newAPIKey: String = ""
    @State private var newCustomBaseURL: String = ""
    @State private var newSelectedModel: String = ""
    
    // Advanced Raiffeisen Fields
    @State private var showAdvanced: Bool = false
    @State private var newPrompt: String = ""
    @State private var newSpeakerCount: String = ""
    @State private var newLanguage: String = "ru"
    
    @State private var fetchedModels: [FetchedModel] = []
    @State private var isFetchingModels = false
    @State private var fetchError: String? = nil
    
    @State private var connectionTestResult: String = ""
    @State private var connectionTestSuccess: Bool = false
    @State private var formError: String? = nil
    
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
            
            // Hidden button to close window on Escape
            Button("") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .frame(width: 550, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
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
                Text("Провайдеры транскрибации")
                    .font(.headline)
                
                if settings.savedProviders.isEmpty {
                    Text("Нет добавленных провайдеров")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(settings.savedProviders) { provider in
                            providerRow(provider)
                        }
                    }
                }
                
                if isAddingProvider {
                    addProviderForm
                } else {
                    Button(action: {
                        resetForm()
                        isAddingProvider = true
                    }) {
                        Label("Подключить", systemImage: "plus.circle")
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private func providerIcon(for type: String) -> String {
        switch type {
        case "openai": return "bolt.fill"
        case "gemini": return "sparkles"
        case "openrouter": return "network"
        case "custom": return "server.rack"
        default: return "questionmark"
        }
    }
    
    private func providerRow(_ provider: ProviderConfig) -> some View {
        HStack {
            Button(action: {
                startEditing(provider)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: providerIcon(for: provider.type))
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name)
                            .font(.subheadline).bold()
                        Text("Модель: \(provider.model)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Active selection
            Button(action: {
                settings.activeProviderId = provider.id
            }) {
                HStack(spacing: 4) {
                    Image(systemName: settings.activeProviderId == provider.id ? "checkmark.circle.fill" : "circle")
                    if settings.activeProviderId == provider.id {
                        Text("Активный").font(.caption).bold()
                    } else {
                        Text("Выбрать").font(.caption)
                    }
                }
                .foregroundColor(settings.activeProviderId == provider.id ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Delete
            Button(action: {
                settings.savedProviders.removeAll { $0.id == provider.id }
                settings.deleteAPIKey(for: provider.id)
                if settings.activeProviderId == provider.id {
                    settings.activeProviderId = settings.savedProviders.first?.id
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    editingProviderId == provider.id ? Color.blue :
                        (settings.activeProviderId == provider.id ? Color.green : Color.clear),
                    lineWidth: (editingProviderId == provider.id || settings.activeProviderId == provider.id) ? 1.5 : 1
                )
        )
    }
    
    // MARK: Add Provider form
    private var addProviderForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                Text(editingProviderId == nil ? "Новый провайдер" : "Редактирование провайдера").font(.headline)
                Spacer()
                Button("Отмена") {
                    isAddingProvider = false
                    editingProviderId = nil
                }
            }
            
            HStack {
                Text("Тип:"); Spacer()
                Picker("", selection: $newProviderType) {
                    Text("OpenAI").tag("openai")
                    // Text("Google Gemini").tag("gemini") // Hidden per user request
                    Text("OpenRouter").tag("openrouter")
                    Text("Райффайзен (Raif)").tag("raif")
                    // Text("Свой (Custom OpenAI)").tag("custom") // Hidden per user request
                }
                .pickerStyle(.menu)
                .disabled(editingProviderId != nil) // Cannot change type when editing
                .onChange(of: newProviderType) { _ in
                    if editingProviderId == nil {
                        newAPIKey = ""
                        newProviderName = ""
                        newCustomBaseURL = ""
                        resetFetchState()
                        formError = nil
                        connectionTestResult = ""
                    }
                }
            }
            
            if newProviderType == "custom" {
                HStack {
                    Text("Название:"); Spacer()
                    TextField("Например, Local Whisper", text: $newProviderName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
                HStack {
                    Text("Base URL:"); Spacer()
                    TextField("http://localhost:8080/v1", text: $newCustomBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            
            HStack {
                Text("API Ключ:"); Spacer()
                SecureField("Введите API-ключ", text: $newAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            
            HStack {
                Text("Модель:"); Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    if newProviderType == "custom" {
                        TextField("Название модели", text: $newSelectedModel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                    } else if newProviderType == "raif" {
                        Picker("", selection: $newSelectedModel) {
                            Text("faster-whisper-large-v3").tag("faster-whisper-large-v3")
                            Text("gigaam-v2-rnnt").tag("gigaam-v2-rnnt")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 300)
                        .onAppear {
                            if newSelectedModel.isEmpty {
                                newSelectedModel = "faster-whisper-large-v3"
                            }
                        }
                    } else {
                        HStack {
                            Button("Загрузить модели") {
                                fetchModels()
                            }
                            .disabled(newAPIKey.isEmpty && newProviderType != "openrouter")
                            
                            if isFetchingModels {
                                ProgressView().scaleEffect(0.5).frame(height: 10)
                            }
                        }
                        
                        if let error = fetchError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                        
                        if !fetchedModels.isEmpty {
                            Picker("", selection: $newSelectedModel) {
                                ForEach(fetchedModels, id: \.id) { model in
                                    HStack {
                                        Text(model.id)
                                        if model.isFree {
                                            Text(" 🎁 Бесплатно")
                                        }
                                    }
                                    .tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 300)
                        } else {
                            Text("Нажмите 'Загрузить модели', чтобы выбрать.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if newProviderType == "raif" {
                HStack(alignment: .top) {
                    Text("Параметры:"); Spacer()
                    DisclosureGroup("Дополнительные настройки", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Промпт:").font(.caption)
                                Spacer()
                                TextField("Опционально", text: $newPrompt)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180)
                            }
                            
                            HStack {
                                Text("Спикеров:").font(.caption)
                                Spacer()
                                TextField("Например, 2", text: $newSpeakerCount)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180)
                            }
                            
                            HStack {
                                Text("Язык:").font(.caption)
                                Spacer()
                                Picker("", selection: $newLanguage) {
                                    Text("ru").tag("ru")
                                    Text("en").tag("en")
                                }
                                .pickerStyle(.radioGroup)
                                .horizontalRadioGroupLayout()
                                .frame(width: 180, alignment: .leading)
                            }
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                    }
                    .frame(width: 300)
                }
            }
            
            if let error = formError {
                Text(error).foregroundColor(.red).font(.caption).padding(.top, 4)
            }
            
            if !connectionTestResult.isEmpty {
                Text(connectionTestResult)
                    .font(.caption)
                    .foregroundColor(connectionTestSuccess ? .green : .red)
                    .padding(.top, 4)
            }
            
            Button(editingProviderId == nil ? "Добавить" : "Обновить") {
                validateAndAdd()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
    
    private func startEditing(_ provider: ProviderConfig) {
        editingProviderId = provider.id
        newProviderType = provider.type
        newProviderName = provider.name
        newCustomBaseURL = provider.baseURL ?? ""
        newSelectedModel = provider.model
        newPrompt = provider.prompt ?? ""
        newLanguage = provider.language ?? "ru"
        newSpeakerCount = provider.speakerCount ?? ""
        newAPIKey = settings.getAPIKey(for: provider.id) ?? ""
        
        fetchedModels = [FetchedModel(id: provider.model, isFree: false)]
        
        formError = nil
        connectionTestResult = ""
        isAddingProvider = true
        
        if provider.type != "raif" {
            fetchModels()
        }
    }
    
    private func resetForm() {
        editingProviderId = nil
        newProviderType = "openai"
        newProviderName = ""
        newAPIKey = ""
        newCustomBaseURL = ""
        resetFetchState()
        formError = nil
        connectionTestResult = ""
    }
    
    private func resetFetchState() {
        fetchedModels = []
        newSelectedModel = ""
        fetchError = nil
    }
    
    private func fetchModels() {
        isFetchingModels = true
        fetchError = nil
        Task {
            do {
                let models = try await ModelFetcherService.fetchModels(providerType: newProviderType, apiKey: newAPIKey, customBaseURL: newCustomBaseURL)
                await MainActor.run {
                    self.fetchedModels = models
                    if let first = models.first {
                        self.newSelectedModel = first.id
                    }
                    self.isFetchingModels = false
                }
            } catch {
                await MainActor.run {
                    self.fetchError = "Ошибка: не удалось загрузить модели"
                    self.isFetchingModels = false
                }
            }
        }
    }
    
    private func validateAndAdd() {
        formError = nil
        connectionTestResult = ""
        
        if newProviderType != "custom" && newAPIKey.isEmpty {
            formError = "API ключ обязателен для этого провайдера"
            return
        }
        if newProviderType == "custom" && (newProviderName.isEmpty || newCustomBaseURL.isEmpty || newSelectedModel.isEmpty) {
            formError = "Заполните все поля для кастомного провайдера"
            return
        }
        if newSelectedModel.isEmpty {
            formError = "Выберите или введите модель"
            return
        }
        
        let providerName: String
        switch newProviderType {
        case "custom": providerName = newProviderName
        case "openai": providerName = "OpenAI"
        case "gemini": providerName = "Google Gemini"
        case "openrouter": providerName = "OpenRouter"
        case "raif": providerName = "Райффайзен"
        default: providerName = "Неизвестно"
        }
        
        let config = ProviderConfig(
            id: editingProviderId ?? UUID(),
            type: newProviderType,
            name: providerName,
            baseURL: newProviderType == "custom" ? newCustomBaseURL : nil,
            model: newSelectedModel.isEmpty ? "default" : newSelectedModel,
            prompt: newProviderType == "raif" && !newPrompt.isEmpty ? newPrompt : nil,
            language: newProviderType == "raif" ? newLanguage : nil,
            speakerCount: newProviderType == "raif" && !newSpeakerCount.isEmpty ? newSpeakerCount : nil
        )
        
        testConnection(config: config, apiKey: newAPIKey)
    }
    
    private func testConnection(config: ProviderConfig, apiKey: String) {
        connectionTestResult = "Проверка соединения..."
        connectionTestSuccess = false
        
        Task {
            var urlString = ""
            switch config.type {
            case "openai":
                urlString = "https://api.openai.com/v1/models"
            case "openrouter":
                urlString = "https://openrouter.ai/api/v1/models"
            case "gemini":
                urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
            case "raif":
                // the screenshot docs don't define a GET /models, they define POST /v1/audio/transcriptions
                // but any request without the file to the transcription endpoint will yield an error, 
                // so we will just hit the base endpoints and see if it's reachable or do a dummy request.
                // Let's do a dummy POST without complete body, if it's 400 Bad Request, auth succeeded. If 401, auth failed.
                urlString = "https://llm-api.cibaa.raiffeisen.ru/v1/audio/transcriptions"
            case "custom":
                let base = config.baseURL ?? ""
                let cleanBase = base.hasSuffix("/chat/completions") ? base.replacingOccurrences(of: "/chat/completions", with: "") : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                urlString = "\(cleanBase)/models"
            default:
                await MainActor.run { self.connectionTestResult = "Неподдерживаемый провайдер для проверки" }
                return
            }
            
            guard let url = URL(string: urlString) else {
                await MainActor.run { self.connectionTestResult = "Ошибка: Неверный URL сервера" }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = config.type == "raif" ? "POST" : "GET"
            
            if config.type != "gemini" {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                if config.type == "openrouter" {
                    request.setValue("VoiceOverlay/1.0", forHTTPHeaderField: "HTTP-Referer")
                    request.setValue("Voice Overlay macOS App", forHTTPHeaderField: "X-Title")
                }
            }
            
            request.timeoutInterval = 10
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            self.connectionTestSuccess = true
                            self.connectionTestResult = self.editingProviderId == nil ? "Успешное подключение! Провайдер добавлен." : "Успешное подключение! Провайдер обновлен."
                            
                            // Success -> Save
                            if let index = self.settings.savedProviders.firstIndex(where: { $0.id == config.id }) {
                                self.settings.savedProviders[index] = config
                            } else {
                                self.settings.savedProviders.append(config)
                            }
                            self.settings.setAPIKey(apiKey, for: config.id)
                            
                            if self.settings.activeProviderId == nil {
                                self.settings.activeProviderId = config.id
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                self.isAddingProvider = false
                                self.editingProviderId = nil
                            }
                            
                        // For Raiffeisen, 400 or 422 means Auth was completely fine, but payload was missing text, which is what we did on an empty POST test.
                        // FastAPI/Pydantic returns 422 Unprocessable Entity for missing form-data.
                        } else if config.type == "raif" && (httpResponse.statusCode == 400 || httpResponse.statusCode == 422) {
                            self.connectionTestSuccess = true
                            self.connectionTestResult = self.editingProviderId == nil ? "Успешное подключение! Провайдер добавлен." : "Успешное подключение! Провайдер обновлен."
                            
                            // Success -> Save
                            if let index = self.settings.savedProviders.firstIndex(where: { $0.id == config.id }) {
                                self.settings.savedProviders[index] = config
                            } else {
                                self.settings.savedProviders.append(config)
                            }
                            self.settings.setAPIKey(apiKey, for: config.id)
                            
                            if self.settings.activeProviderId == nil {
                                self.settings.activeProviderId = config.id
                            }
                            
                            // Delayed close
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                self.isAddingProvider = false
                                self.editingProviderId = nil
                            }
                        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
                            self.formError = "Ошибка соединения: Неверный API ключ"
                        } else {
                            self.formError = "Ошибка: Сервер вернул код \(httpResponse.statusCode)"
                        }
                    } else {
                        self.formError = "Ошибка: Неизвестный ответ сервера"
                    }
                }
            } catch {
                await MainActor.run {
                    self.formError = "Ошибка подключения: \(error.localizedDescription)"
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
                
                Toggle("Хранить все API ключи в Keychain", isOn: $settings.storeAPIKeyInKeychain)
                    .padding(.top, 16)
                    
                Divider()
                    .padding(.vertical, 8)
                    
                Text("Логи")
                    .font(.headline)
                    
                Button("Открыть папку с логами") {
                    let logDir = Logger.shared.logsDirectory
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logDir.path)
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
