import AVFoundation
import AppKit

class PermissionsCoordinator {
    static let shared = PermissionsCoordinator()
    
    // Status to hold whether everything is granted
    var isFullyAuthorized: Bool {
        return isMicrophoneAuthorized && isAccessibilityAuthorized
    }
    
    var isMicrophoneAuthorized: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    var isAccessibilityAuthorized: Bool {
        return AXIsProcessTrusted()
    }
    
    private init() {}
    
    func requestAll(completion: @escaping (Bool) -> Void) {
        // Step 1: Request Accessibility. This brings up the system prompt if missing.
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Step 2: Request Microphone
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    completion(self?.isFullyAuthorized ?? false)
                }
            }
        } else {
            completion(isFullyAuthorized)
        }
    }
    
    enum PermissionType {
        case microphone
        case accessibility
    }
    
    func openSystemSettings(for type: PermissionType = .accessibility) {
        let urlString: String
        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
