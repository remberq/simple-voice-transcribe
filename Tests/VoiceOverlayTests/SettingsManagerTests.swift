import XCTest
@testable import VoiceOverlay

final class SettingsManagerTests: XCTestCase {
    private let autoShownKey = "hasAutoShownWelcomeOnce"
    private let completedKey = "hasCompletedWelcome"
    
    override func tearDown() {
        let settings = SettingsManager.shared
        settings.hasAutoShownWelcomeOnce = UserDefaults.standard.bool(forKey: autoShownKey)
        settings.hasCompletedWelcome = UserDefaults.standard.bool(forKey: completedKey)
        super.tearDown()
    }
    
    func testWelcomeAutoShowFlagPersistsToUserDefaults() {
        let settings = SettingsManager.shared
        let defaults = UserDefaults.standard
        let originalValue = settings.hasAutoShownWelcomeOnce
        
        defer {
            settings.hasAutoShownWelcomeOnce = originalValue
        }
        
        settings.hasAutoShownWelcomeOnce = false
        XCTAssertFalse(defaults.bool(forKey: autoShownKey))
        
        settings.hasAutoShownWelcomeOnce = true
        XCTAssertTrue(defaults.bool(forKey: autoShownKey))
    }
    
    func testWelcomeCompletedFlagPersistsToUserDefaults() {
        let settings = SettingsManager.shared
        let defaults = UserDefaults.standard
        let originalValue = settings.hasCompletedWelcome
        
        defer {
            settings.hasCompletedWelcome = originalValue
        }
        
        settings.hasCompletedWelcome = false
        XCTAssertFalse(defaults.bool(forKey: completedKey))
        
        settings.hasCompletedWelcome = true
        XCTAssertTrue(defaults.bool(forKey: completedKey))
    }
}
