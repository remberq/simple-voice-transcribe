import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var onHotkeyPressed: (() -> Void)?
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    private init() {}
    
    func registerHotkey() {
        // Register the event handler callback
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // C-function pointer callback bridging into our Swift instance
        let callback: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            if let ptr = userData {
                let unmanaged = Unmanaged<HotkeyManager>.fromOpaque(ptr)
                let manager = unmanaged.takeUnretainedValue()
                
                // Dispatch to main thread
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
            }
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPtr, &eventHandler)
        
        // Define Hotkey from SettingsManager
        let keyCode = UInt32(SettingsManager.shared.hotkeyKeyCode)
        let modifiers = UInt32(SettingsManager.shared.hotkeyModifiers)
        
        let hotKeyID = EventHotKeyID(signature: OSType(32), id: UInt32(1))
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register global hotkey: OSStatus \(status)")
        } else {
            print("Registered global hotkey. Code: \(keyCode), Modifiers: \(modifiers)")
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    func reloadHotkey() {
        unregisterHotkey()
        registerHotkey()
    }
}
