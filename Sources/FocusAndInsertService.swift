import Foundation
import AppKit

class FocusAndInsertService {
    static let shared = FocusAndInsertService()
    
    private var initialPID: pid_t?
    
    // TG-11: Caret/Cursor Anchoring State
    private var mouseLocationAtHotkey: CGPoint?
    private var caretRectAtHotkey: CGRect?
    private var focusedElementFrameAtHotkey: CGRect?
    
    private init() {}
    
    /// Called when the hotkey is pressed to capture the screen layout context.
    func captureInteractionAnchor() {
        // 1. Capture Mouse Location (Global Screen Coordinates)
        if let event = CGEvent(source: nil) {
            self.mouseLocationAtHotkey = event.location
        } else {
            self.mouseLocationAtHotkey = NSEvent.mouseLocation
        }
        
        // 2. Discover Caret/Element Frames
        self.caretRectAtHotkey = nil
        self.focusedElementFrameAtHotkey = nil
        
        var focusedElementRaw: CFTypeRef?
        var error: AXError = .failure
        
        // 2a. Try targeting the frontmost app directly (more reliable for sandboxed/native apps)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRaw)
        }
        
        // 2b. Fallback to System-Wide context if direct app query failed
        if error != .success || focusedElementRaw == nil {
            let systemWideElement = AXUIElementCreateSystemWide()
            error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRaw)
        }
        
        guard error == .success, let focusedElementRef = focusedElementRaw else {
            return
        }
        
        let focusedElement = focusedElementRef as! AXUIElement
        
        // Attempt to get caret rect via SelectedTextRange
        var selectedRangeRaw: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRaw) == .success,
           let selectedRangeValue = selectedRangeRaw as! AXValue? {
            
            var range = CFRange()
            if AXValueGetValue(selectedRangeValue, .cfRange, &range) {
                var boundsRaw: CFTypeRef?
                if AXUIElementCopyParameterizedAttributeValue(focusedElement, kAXBoundsForRangeParameterizedAttribute as CFString, selectedRangeValue, &boundsRaw) == .success,
                   let boundsValue = boundsRaw as! AXValue? {
                    var bounds = CGRect()
                    if AXValueGetValue(boundsValue, .cgRect, &bounds) {
                        self.caretRectAtHotkey = bounds
                    }
                }
            }
        }
        
        // Always try to get the element's overall frame as a fallback
        // The standard attributes are kAXPositionAttribute and kAXSizeAttribute
        var positionRaw: CFTypeRef?
        var sizeRaw: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute as CFString, &positionRaw) == .success,
           let posValue = positionRaw as! AXValue?,
           AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute as CFString, &sizeRaw) == .success,
           let sizeValue = sizeRaw as! AXValue? {
            
            var position = CGPoint.zero
            var size = CGSize.zero
            
            if AXValueGetValue(posValue, .cgPoint, &position), AXValueGetValue(sizeValue, .cgSize, &size) {
                self.focusedElementFrameAtHotkey = CGRect(origin: position, size: size)
            }
        }
    }
    
    /// Calculates the optimal screen point for the overlay, clamped to the visible space.
    func calculateOverlayPosition() -> CGPoint {
        var anchor: CGPoint
        
        // Target positioning logic
        if let caret = caretRectAtHotkey, caret.size.width > 0 || caret.size.height > 0 {
            // Near the caret
            anchor = CGPoint(x: caret.maxX + 16, y: caret.midY)
        } else if let frame = focusedElementFrameAtHotkey, frame.size.width > 0 || frame.size.height > 0 {
            // Near the focused element
            anchor = CGPoint(x: frame.maxX + 16, y: frame.midY)
        } else if let mouse = mouseLocationAtHotkey {
            // Near the mouse
            anchor = CGPoint(x: mouse.x + 24, y: mouse.y - 24)
        } else {
            // Utter fallback
            anchor = CGPoint(x: 100, y: 100)
        }
        
        // Clamp to screen bounds
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let margin: CGFloat = 12.0
            
            // Assume the overlay is roughly 80x80 size.
            // Screen coordinates in CG are often flipped (0,0 top-left) vs NS (0,0 bottom-left).
            // AX UI returns origins with 0,0 at top-left.
            // NSScreen returns 0,0 at bottom-left for primary screen.
            // We need to convert CG (top-left) to NS (bottom-left) for NSPanel positioning.
            
            let frameHeight = screen.frame.height
            let nsY = frameHeight - anchor.y // Convert CG to NS Y
            
            // Apply clamps
            let clampedX = max(visibleFrame.minX + margin, min(anchor.x, visibleFrame.maxX - 80 - margin))
            let clampedY = max(visibleFrame.minY + margin, min(nsY, visibleFrame.maxY - 80 - margin))
            
            return CGPoint(x: clampedX, y: clampedY)
        }
        
        return anchor
    }
    
    /// Called when recording starts to securely baseline the active application.
    func captureInitialFocus() {
        if let app = NSWorkspace.shared.frontmostApplication {
            self.initialPID = app.processIdentifier
            print("Captured initial focus PID: \(app.processIdentifier) (\(app.localizedName ?? "Unknown"))")
        } else {
            self.initialPID = nil
        }
    }
    
    /// Main entry point to handle transcribed text.
    /// Returns the toast message to display.
    func handleTranscription(_ text: String) -> String {
        let settings = SettingsManager.shared
        
        // 1. Copy to clipboard (NSPasteboard)
        if settings.alwaysCopy || !settings.autoInsertEnabled {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            print("Copied to clipboard.")
        }
        
        guard settings.autoInsertEnabled else { 
            return "Copied to clipboard" 
        }
        
        // 2. Safety Guard: Check if PID changed
        if let baseline = initialPID, let currentApp = NSWorkspace.shared.frontmostApplication {
            if currentApp.processIdentifier != baseline {
                print("Safety Guard: App focus changed from \(baseline) to \(currentApp.processIdentifier). Aborting paste.")
                return "Focus changed — copied only"
            }
        }
        
        // 3. Check accessibility to prevent pasting on desktop or non-inputs
        if isFocusedElementEditable() {
            if settings.fallbackToPaste {
                simulateCmdV()
                return "Inserted into input"
            } else {
                print("Editable element found, but paste fallback disabled via settings.")
                return "Copied to clipboard"
            }
        } else {
            print("Foreground element is not editable. Skipping Cmd+V.")
            return "Copied to clipboard"
        }
    }
    
    /// Inspects the system-wide active element using Accessibility APIs
    private func isFocusedElementEditable() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedElementRaw: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRaw)
        
        guard error == .success, let focusedElementRef = focusedElementRaw else {
            // Cannot determine focus. To be safe, we allow pasting as fallback,
            // or we block it. Let's block it to avoid erratic behavior.
            return false
        }
        
        let focusedElement = focusedElementRef as! AXUIElement
        
        // Get the role of the focused element
        var roleRaw: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRaw)
        
        guard roleError == .success, let role = roleRaw as? String else {
            return false
        }
        
        print("Focused element role: \(role)")
        
        // Typical editable roles:
        // AXTextField, AXTextArea, AXComboBox, AXWebArea, AXDocument (sometimes Notes/Word)
        let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXWebArea", "AXDocument", "AXTextGroup"]
        if editableRoles.contains(role) {
            return true
        }
        
        // Secondary check: does it have a writable kAXValueAttribute?
        // In many Chromium/Electron apps (like Slack), elements might just have a string value.
        var isSettable: DarwinBoolean = false
        let settableError = AXUIElementIsAttributeSettable(focusedElement, kAXValueAttribute as CFString, &isSettable)
        if settableError == .success && isSettable.boolValue {
            return true
        }
        
        return false
    }
    
    /// Uses CoreGraphics to simulate the user pressing Cmd+V
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // V keycode is 9
        let vKeyCode: CGKeyCode = 0x09
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        
        // Add Cmd flag
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post events to the system
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        print("Simulated Cmd+V")
    }
}
