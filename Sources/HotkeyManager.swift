import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var onHotkeyPressed: (() -> Void)?
    var onFileUploadHotkeyPressed: (() -> Void)?
    
    private var eventHandler: EventHandlerRef?
    private var recordHotKeyRef: EventHotKeyRef?
    private var fileUploadHotKeyRef: EventHotKeyRef?
    
    private init() {}
    
    func registerHotkey() {
        // Register the event handler callback (shared for both hotkeys)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // C-function pointer callback bridging into our Swift instance
        let callback: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let ptr = userData, let event = event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
            
            // Read which hotkey was pressed via EventHotKeyID
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return status }
            
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1:
                    manager.onHotkeyPressed?()
                case 2:
                    manager.onFileUploadHotkeyPressed?()
                case 3:
                    // Hotkey ID 3 (Spacebar without modifiers) triggers pause/resume
                    OverlayController.shared.handlePauseResume()
                default:
                    break
                }
            }
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPtr, &eventHandler)
        
        // --- Hotkey 1: Record toggle (default Cmd+Shift+Space) ---
        let recordKeyCode = UInt32(SettingsManager.shared.hotkeyKeyCode)
        let recordModifiers = UInt32(SettingsManager.shared.hotkeyModifiers)
        let recordHotKeyID = EventHotKeyID(signature: OSType(32), id: UInt32(1))
        
        let status1 = RegisterEventHotKey(recordKeyCode, recordModifiers, recordHotKeyID, GetApplicationEventTarget(), 0, &recordHotKeyRef)
        if status1 != noErr {
            print("Failed to register record hotkey: OSStatus \(status1)")
        } else {
            print("Registered record hotkey. Code: \(recordKeyCode), Modifiers: \(recordModifiers)")
        }
        
        // --- Hotkey 2: File upload (default Cmd+Shift+D) ---
        let uploadKeyCode = UInt32(SettingsManager.shared.fileUploadHotkeyKeyCode)
        let uploadModifiers = UInt32(SettingsManager.shared.fileUploadHotkeyModifiers)
        let uploadHotKeyID = EventHotKeyID(signature: OSType(32), id: UInt32(2))
        
        let status2 = RegisterEventHotKey(uploadKeyCode, uploadModifiers, uploadHotKeyID, GetApplicationEventTarget(), 0, &fileUploadHotKeyRef)
        if status2 != noErr {
            print("Failed to register file upload hotkey: OSStatus \(status2)")
        } else {
            print("Registered file upload hotkey. Code: \(uploadKeyCode), Modifiers: \(uploadModifiers)")
        }
    }
    
    private var spaceHotKeyRef: EventHotKeyRef?
    
    // Called when the overlay enters recording or paused states
    func registerSpaceHotkey() {
        guard spaceHotKeyRef == nil else { return }
        
        let spaceKeyCode = UInt32(49) // KeyCode for Space (kVK_Space)
        let spaceModifiers = UInt32(0) // No modifiers
        let spaceHotKeyID = EventHotKeyID(signature: OSType(32), id: UInt32(3))
        
        let status = RegisterEventHotKey(spaceKeyCode, spaceModifiers, spaceHotKeyID, GetApplicationEventTarget(), 0, &spaceHotKeyRef)
        if status != noErr {
            print("Failed to register Space hotkey: OSStatus \(status)")
        } else {
            print("Registered single Space hotkey interception.")
        }
    }
    
    // Called when the overlay exits recording or paused states
    func unregisterSpaceHotkey() {
        if let ref = spaceHotKeyRef {
            UnregisterEventHotKey(ref)
            spaceHotKeyRef = nil
            print("Unregistered single Space hotkey interception.")
        }
    }
    
    func unregisterHotkey() {
        if let ref = recordHotKeyRef {
            UnregisterEventHotKey(ref)
            recordHotKeyRef = nil
        }
        if let ref = fileUploadHotKeyRef {
            UnregisterEventHotKey(ref)
            fileUploadHotKeyRef = nil
        }
        unregisterSpaceHotkey()
    }
    
    func reloadHotkey() {
        unregisterHotkey()
        registerHotkey()
    }
}
