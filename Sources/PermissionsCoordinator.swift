import AVFoundation
import AppKit

class PermissionsCoordinator {
    static let shared = PermissionsCoordinator()
    static let permissionFlowWillStartNotification = Notification.Name("PermissionsCoordinatorPermissionFlowWillStart")
    static let permissionFlowDidFinishNotification = Notification.Name("PermissionsCoordinatorPermissionFlowDidFinish")
    
    var isMicrophoneAuthorized: Bool {
        return microphoneAuthorizationStatus == .authorized
    }
    
    var microphoneAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }
    
    private init() {}
    
    func requestMicrophonePermission(completion: @escaping (AVAuthorizationStatus) -> Void) {
        NotificationCenter.default.post(name: Self.permissionFlowWillStartNotification, object: PermissionType.microphone)

        switch microphoneAuthorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    let status = self?.microphoneAuthorizationStatus ?? .denied
                    completion(status)
                    NotificationCenter.default.post(name: Self.permissionFlowDidFinishNotification, object: PermissionType.microphone)
                }
            }
        case .authorized, .denied, .restricted:
            completion(microphoneAuthorizationStatus)
            NotificationCenter.default.post(name: Self.permissionFlowDidFinishNotification, object: PermissionType.microphone)
        @unknown default:
            completion(microphoneAuthorizationStatus)
            NotificationCenter.default.post(name: Self.permissionFlowDidFinishNotification, object: PermissionType.microphone)
        }
    }
    
    enum PermissionType {
        case microphone
    }
    
    func openSystemSettings(for type: PermissionType = .microphone) {
        NotificationCenter.default.post(name: Self.permissionFlowWillStartNotification, object: type)
        
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
