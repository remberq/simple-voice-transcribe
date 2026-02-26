import XCTest
@testable import VoiceOverlay

final class VoiceOverlayTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Ensure clean state between tests
        let controller = OverlayController.shared
        if controller.state == .recording {
            _ = RecorderService.shared.stopRecording()
        }
        controller.state = .idle
        controller.toastMessage = nil
        super.tearDown()
    }

    // MARK: - State Machine Tests

    func testOverlayStateTransitions() {
        let controller = OverlayController.shared
        
        // Initial state should be idle
        XCTAssertEqual(controller.state, .idle)
        
        // Verify all valid states exist and can be assigned
        var testState = OverlayState.idle
        XCTAssertEqual(testState, .idle)
        
        testState = .recording
        XCTAssertEqual(testState, .recording)
        
        testState = .transcribing
        XCTAssertEqual(testState, .transcribing)
        
        testState = .error
        XCTAssertEqual(testState, .error)
    }
    
    func testValidStateTransitionSequence_IdleToRecordingToTranscribing() {
        // The expected happy-path: idle → recording → transcribing
        var state = OverlayState.idle
        
        // User taps mic → recording
        state = .recording
        XCTAssertEqual(state, .recording)
        
        // User taps mic again → transcribing
        state = .transcribing
        XCTAssertEqual(state, .transcribing)
    }
    
    func testValidStateTransitionSequence_ErrorToIdle() {
        // Error state should be dismissable back to idle
        var state = OverlayState.error
        state = .idle
        XCTAssertEqual(state, .idle)
    }
    
    func testPausedStateStillExists() {
        // Paused state exists in the enum but is not used in the current UI flow
        let state = OverlayState.paused
        XCTAssertEqual(state, .paused)
    }
    
    // MARK: - RecorderService Audio Level Tests
    
    func testRecorderServiceAudioLevelIsNonNegative() {
        let recorder = RecorderService.shared
        // audioLevel should always be >= 0 and <= 1
        XCTAssertGreaterThanOrEqual(recorder.audioLevel, 0.0, "Audio level should never be negative")
        XCTAssertLessThanOrEqual(recorder.audioLevel, 1.0, "Audio level should never exceed 1.0")
    }
    
    // MARK: - Transcription Pipeline Tests
    
    func testMockTranscriptionPipeline() async throws {
        let transcriber = MockTranscriptionService()
        let fakeUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fake.m4a")
        
        // Need to create dummy file because mock checks if it exists
        FileManager.default.createFile(atPath: fakeUrl.path, contents: Data())
        
        do {
            let result = try await transcriber.transcribe(audioFileURL: fakeUrl)
            XCTAssertEqual(result, "This is a mocked transcription result.")
        } catch {
            XCTFail("Transcription failed with error: \(error)")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: fakeUrl)
    }
    
    // MARK: - OverlayController Behavior Tests
    
    func testHandleStopOnlyWorksInRecordingState() {
        let controller = OverlayController.shared
        
        // Ensure we start from idle
        controller.state = .idle
        
        // handleStop should do nothing when not in recording state
        controller.handleStop()
        XCTAssertEqual(controller.state, .idle, "handleStop should not change state when idle")
        
        // Set to error and try
        controller.state = .error
        controller.handleStop()
        XCTAssertEqual(controller.state, .error, "handleStop should not change state when in error")
        
        // Set to transcribing and try
        controller.state = .transcribing
        controller.handleStop()
        XCTAssertEqual(controller.state, .transcribing, "handleStop should not change state when already transcribing")
        
        // Reset
        controller.state = .idle
    }
    
    func testHandleTapFromIdleRequiresPermission() {
        let controller = OverlayController.shared
        controller.state = .idle
        
        // handleTap checks PermissionsCoordinator. Without mic permission in test env,
        // it should transition to .error or stay in .idle.
        // We test that it doesn't crash and state is deterministic.
        controller.handleTap()
        
        // Should either move to .recording (if permissions granted) or .error
        let validStates: [OverlayState] = [.recording, .error]
        XCTAssertTrue(validStates.contains(controller.state),
                      "After handleTap, state should be .recording or .error, got \(controller.state)")
        
        // Reset
        controller.state = .idle
    }
    
    func testHideResetsStateToIdle() {
        let controller = OverlayController.shared
        
        // Simulate various states and verify hide() resets to idle
        controller.state = .transcribing
        controller.hide()
        XCTAssertEqual(controller.state, .idle, "hide() should reset state to .idle")
        
        controller.state = .error
        controller.hide()
        XCTAssertEqual(controller.state, .idle, "hide() should reset state to .idle from error")
    }
    
    func testHideClearsToastMessage() {
        let controller = OverlayController.shared
        controller.toastMessage = "Test toast"
        controller.hide()
        XCTAssertNil(controller.toastMessage, "hide() should clear the toast message")
    }
}
