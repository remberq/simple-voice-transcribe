import SwiftUI
import AppKit
import Carbon

struct HotkeyFormatter {
    static func format(keyCode: Int, modifiers: Int) -> String {
        // Map Carbon modifiers back to strings
        var modString = ""
        if (modifiers & controlKey) != 0 { modString += "⌃" }
        if (modifiers & optionKey) != 0 { modString += "⌥" }
        if (modifiers & shiftKey) != 0 { modString += "⇧" }
        if (modifiers & cmdKey) != 0 { modString += "⌘" }
        
        // This is a naive translation map for visual purposes.
        // A complete map would bridge UCKeyTranslate, but this handles most common globals.
        let keyString: String
        switch keyCode {
        case 49: keyString = "Space"
        case 36: keyString = "Return"
        case 51: keyString = "Backspace"
        case 53: keyString = "Esc"
        case 48: keyString = "Tab"
        case 123: keyString = "←"
        case 124: keyString = "→"
        case 125: keyString = "↓"
        case 126: keyString = "↑"
        default:
            // Extract printable character from CGKeyCode if possible gracefully
            // Fallback for simplicity: just a hex code if not commonly known
            if let char = KeyCodeToChar(keyCode: UInt16(keyCode)) {
                keyString = char.uppercased()
            } else {
                keyString = "Key(\(keyCode))"
            }
        }
        
        return modString + keyString
    }
    
    // A quick bridge from CGKeyCode to a Character (QWERTY layout approximation)
    private static func KeyCodeToChar(keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        guard let dataRef = layoutData else { return nil }
        
        let keyboardLayout = unsafeBitCast(dataRef, to: CFData.self)
        let keysDown: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer.allocate(capacity: 1)
        keysDown.pointee = 0
        
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength: Int = 0
        
        let status = UCKeyTranslate(
            unsafeBitCast(CFDataGetBytePtr(keyboardLayout), to: UnsafePointer<UCKeyboardLayout>.self),
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            keysDown,
            4,
            &realLength,
            &chars
        )
        
        keysDown.deallocate()
        
        if status == noErr && realLength > 0 {
            return String(utf16CodeUnits: chars, count: Int(realLength))
        }
        
        return nil
    }
    
    static func convertAppKitModifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> Int {
        var carbonFlags = 0
        if flags.contains(.command) { carbonFlags |= cmdKey }
        if flags.contains(.option) { carbonFlags |= optionKey }
        if flags.contains(.control) { carbonFlags |= controlKey }
        if flags.contains(.shift) { carbonFlags |= shiftKey }
        return carbonFlags
    }
}

struct HotkeyRecorderView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            Text(isRecording ? "Нажмите комбинацию клавиш..." : HotkeyFormatter.format(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers))
                .frame(minWidth: 150)
                .contentShape(Rectangle())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .foregroundColor(isRecording ? .white : .primary)
                .background(isRecording ? Color.accentColor : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func startRecording() {
        isRecording = true
        // Important: Stop global hotkey before attempting to capture locally to avoid double triggering
        HotkeyManager.shared.unregisterHotkey()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Map the event down to Carbon
            let carbonModifiers = HotkeyFormatter.convertAppKitModifiersToCarbon(event.modifierFlags)
            
            // Only accept if at least one modifier is pressed, or if it's a function key, to avoid binding "A" by itself
            if carbonModifiers > 0 || isFunctionKey(event.keyCode) {
                settings.hotkeyKeyCode = Int(event.keyCode)
                settings.hotkeyModifiers = carbonModifiers
                
                stopRecording()
                return nil // consume event
            }
            
            // If they hit escape without modifiers, maybe cancel recording
            if event.keyCode == 53 /* escape */ && carbonModifiers == 0 {
                stopRecording()
                return nil
            }
            
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        HotkeyManager.shared.reloadHotkey()
    }
    
    private func isFunctionKey(_ keyCode: UInt16) -> Bool {
        // F1-F19
        let fKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80]
        return fKeys.contains(keyCode)
    }
}
