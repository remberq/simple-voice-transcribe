import AVFoundation
import AppKit

class PermissionsCoordinator {
    static let shared = PermissionsCoordinator()
    
    // Status to hold whether everything is granted
    var isFullyAuthorized: Bool {
        return isMicrophoneAuthorized
    }
    
    var isMicrophoneAuthorized: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    private init() {}
    
    func requestAll(completion: @escaping (Bool) -> Void) {
        // Request Microphone

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
    }
    
    func openSystemSettings(for type: PermissionType = .microphone) {
        let urlString: String
        switch type {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
