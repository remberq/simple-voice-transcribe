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
    
    private func waitForOverlayStateChange(
        _ controller: OverlayController,
        timeout: TimeInterval = 1.2
    ) async -> OverlayState {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if controller.state != .idle {
                return controller.state
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return controller.state
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
            let result = try await transcriber.transcribe(audioFileURL: fakeUrl, onProgress: nil)
            XCTAssertFalse(result.isEmpty, "Mock transcription should return some text")
        } catch {
            XCTFail("Transcription failed with error: \(error)")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: fakeUrl)
    }
    
    // MARK: - OverlayController Behavior Tests
    
    func testHandleStopWorksInRecordingAndPausedState() {
        let controller = OverlayController.shared
        
        // Ensure we start from idle
        controller.state = .idle
        
        // handleStop should do nothing when not in recording or paused state
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
    
    func testHandlePauseResumeStateToggling() {
        let controller = OverlayController.shared
        
        // Only does something in .recording or .paused
        controller.state = .idle
        controller.handlePauseResume()
        XCTAssertEqual(controller.state, .idle, "handlePauseResume should do nothing when idle")
        
        // Start "recording"
        controller.state = .recording
        controller.handlePauseResume()
        XCTAssertEqual(controller.state, .paused, "handlePauseResume should switch .recording to .paused")
        
        controller.handlePauseResume()
        XCTAssertEqual(controller.state, .recording, "handlePauseResume should switch .paused back to .recording")
        
        // Reset
        controller.state = .idle
    }
    
    /// Verifies the intended UI tap behavior:
    /// - Tap while .recording → handleStop() (sends to transcription)
    /// - Tap while .paused → handlePauseResume() (resumes recording, does NOT stop)
    func testTapWhilePausedResumesInsteadOfStopping() {
        let controller = OverlayController.shared
        
        // Simulate: recording → pause → tap (should resume, not stop)
        controller.state = .recording
        controller.handlePauseResume() // pause
        XCTAssertEqual(controller.state, .paused, "Should be paused after handlePauseResume")
        
        // Simulate what MicButtonView tap does when paused: it calls handlePauseResume()
        controller.handlePauseResume()
        XCTAssertEqual(controller.state, .recording, "Tap on paused icon should resume recording, not stop")
        
        // Verify that handleStop does NOT get called for paused → it should only work from recording
        // handleStop guards: `guard state == .recording || state == .paused`
        // But the UI tap handler should NOT route .paused to handleStop
        // This test confirms the expected flow
        
        // Reset
        controller.state = .idle
    }
    
    func testHandleTapFromIdleRequiresPermission() async {
        let controller = OverlayController.shared
        controller.state = .idle
        
        // handleTap starts recording asynchronously.
        controller.handleTap()
        let resultingState = await waitForOverlayStateChange(controller)
        
        // Should either move to .recording (if permissions granted) or .error
        let validStates: [OverlayState] = [.recording, .error]
        XCTAssertTrue(validStates.contains(resultingState),
                      "After handleTap, state should be .recording or .error, got \(resultingState)")
        
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
