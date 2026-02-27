import Foundation
import Security
import Combine

/// Represents a single saved STT provider configuration
struct ProviderConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: String // "openai", "gemini", "openrouter", "custom"
    var name: String // Display name
    var baseURL: String? // For custom servers
    var model: String
}

/// A singleton managing both UserDefaults (booleans, ints) and Keychain (sensitive strings)
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Core UserDefaults Keys
    // Core UserDefaults Keys
    private let kHotkeyKeyCode = "hotkeyKeyCode"
    private let kHotkeyModifiers = "hotkeyModifiers"
    private let kSavedProviders = "savedProviders"
    private let kActiveProviderId = "activeProviderId"
    private let kStoreAPIKeyInKeychain = "storeAPIKeyInKeychain"
    
    // Keychain Constants
    private let kKeychainService = "com.anti.VoiceOverlay"
    private let kKeychainAccountAPIKey = "com.anti.VoiceOverlay.APIKey"
    
    // Default Hotkey: Cmd+Shift+Space
    // space = 49 (0x31)
    // cmd = optionCmd? Actually cmdShift = 768 in carbon? 
    // We'll use 49 for space, 768 for cmd+shift in carbon modifiers as initial defaults
    
    @Published var hotkeyKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyKeyCode, forKey: kHotkeyKeyCode) }
    }
    
    @Published var hotkeyModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: kHotkeyModifiers) }
    }
    

    @Published var savedProviders: [ProviderConfig] {
        didSet {
            if let data = try? JSONEncoder().encode(savedProviders) {
                UserDefaults.standard.set(data, forKey: kSavedProviders)
            }
        }
    }
    
    @Published var activeProviderId: UUID? {
        didSet {
            if let id = activeProviderId {
                UserDefaults.standard.set(id.uuidString, forKey: kActiveProviderId)
            } else {
                UserDefaults.standard.removeObject(forKey: kActiveProviderId)
            }
        }
    }
    
    @Published var storeAPIKeyInKeychain: Bool {
        didSet { UserDefaults.standard.set(storeAPIKeyInKeychain, forKey: kStoreAPIKeyInKeychain) }
    }

    // Used when keychain persistence is disabled.
    private var sessionAPIKeys: [UUID: String] = [:]
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Register default values so they exist even if not explicitly set yet
        defaults.register(defaults: [
            kHotkeyKeyCode: 49,
            kHotkeyModifiers: 768,
            kStoreAPIKeyInKeychain: true
        ])
        
        self.hotkeyKeyCode = defaults.integer(forKey: kHotkeyKeyCode)
        self.hotkeyModifiers = defaults.integer(forKey: kHotkeyModifiers)
        
        if let data = defaults.data(forKey: kSavedProviders),
           let decoded = try? JSONDecoder().decode([ProviderConfig].self, from: data) {
            self.savedProviders = decoded
        } else {
            self.savedProviders = []
        }
        
        if let idStr = defaults.string(forKey: kActiveProviderId), let id = UUID(uuidString: idStr) {
            self.activeProviderId = id
        }
        
        self.storeAPIKeyInKeychain = defaults.bool(forKey: kStoreAPIKeyInKeychain)
    }
    
    // MARK: - API Key (Keychain)
    
    /// Reads the API Key from the system Keychain for a specific provider
    func getAPIKey(for id: UUID) -> String? {
        if !storeAPIKeyInKeychain {
            return sessionAPIKeys[id]
        }

        return readAPIKeyFromKeychain(for: id)
    }

    /// Writes or updates the API key based on selected storage mode.
    func setAPIKey(_ key: String, for id: UUID) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        if storeAPIKeyInKeychain {
            writeAPIKeyToKeychain(trimmedKey, for: id)
            sessionAPIKeys[id] = nil
        } else {
            sessionAPIKeys[id] = trimmedKey
        }
    }

    /// Removes key from both session memory and keychain.
    func deleteAPIKey(for id: UUID) {
        sessionAPIKeys[id] = nil
        deleteAPIKeyFromKeychain(for: id)
    }

    // MARK: - Keychain internals

    private var keychainAccountAPIKey: String { return kKeychainAccountAPIKey }
    
    private func getAccountString(for id: UUID) -> String {
        return "\(keychainAccountAPIKey).\(id.uuidString)"
    }

    private func readAPIKeyFromKeychain(for id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: getAccountString(for: id),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func writeAPIKeyToKeychain(_ key: String, for id: UUID) {
        guard let data = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: getAccountString(for: id)
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Update existing
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            // Add new
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func deleteAPIKeyFromKeychain(for id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: getAccountString(for: id)
        ]

        SecItemDelete(query as CFDictionary)
    }
}
