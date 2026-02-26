import Foundation
import Security
import Combine

/// A singleton managing both UserDefaults (booleans, ints) and Keychain (sensitive strings)
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Core UserDefaults Keys
    private let kHotkeyKeyCode = "hotkeyKeyCode"
    private let kHotkeyModifiers = "hotkeyModifiers"
    private let kAutoInsertEnabled = "autoInsertEnabled"
    private let kFallbackToPaste = "fallbackToPaste"
    private let kAlwaysCopy = "alwaysCopy"
    private let kProviderSelection = "providerSelection"
    
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
    
    @Published var autoInsertEnabled: Bool {
        didSet { UserDefaults.standard.set(autoInsertEnabled, forKey: kAutoInsertEnabled) }
    }
    
    @Published var fallbackToPaste: Bool {
        didSet { UserDefaults.standard.set(fallbackToPaste, forKey: kFallbackToPaste) }
    }
    
    @Published var alwaysCopy: Bool {
        didSet { UserDefaults.standard.set(alwaysCopy, forKey: kAlwaysCopy) }
    }
    
    @Published var providerSelection: String {
        didSet { UserDefaults.standard.set(providerSelection, forKey: kProviderSelection) }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Register default values so they exist even if not explicitly set yet
        defaults.register(defaults: [
            kHotkeyKeyCode: 49,
            kHotkeyModifiers: 768,
            kAutoInsertEnabled: true,
            kFallbackToPaste: true,
            kAlwaysCopy: true,
            kProviderSelection: "mock"
        ])
        
        self.hotkeyKeyCode = defaults.integer(forKey: kHotkeyKeyCode)
        self.hotkeyModifiers = defaults.integer(forKey: kHotkeyModifiers)
        self.autoInsertEnabled = defaults.bool(forKey: kAutoInsertEnabled)
        self.fallbackToPaste = defaults.bool(forKey: kFallbackToPaste)
        self.alwaysCopy = defaults.bool(forKey: kAlwaysCopy)
        self.providerSelection = defaults.string(forKey: kProviderSelection) ?? "mock"
    }
    
    // MARK: - API Key (Keychain)
    
    /// Reads the API Key from the system Keychain
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: kKeychainAccountAPIKey,
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
    
    /// Writes or updates the API Key in the system Keychain
    func setAPIKey(_ key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmedKey.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: kKeychainAccountAPIKey
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
}
