import XCTest
@testable import VoiceOverlay

final class AudioMIMEHelperTests: XCTestCase {
    
    // MARK: - mimeType(for:)
    
    func testMimeTypeWav() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "wav"), "audio/wav")
    }
    
    func testMimeTypeMp3() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "mp3"), "audio/mpeg")
    }
    
    func testMimeTypeMpga() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "mpga"), "audio/mpeg")
    }
    
    func testMimeTypeM4a() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "m4a"), "audio/mp4")
    }
    
    func testMimeTypeMp4() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "mp4"), "audio/mp4")
    }
    
    func testMimeTypeWebm() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "webm"), "audio/webm")
    }
    
    func testMimeTypeOgg() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "ogg"), "audio/ogg")
    }
    
    func testMimeTypeFlac() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "flac"), "audio/flac")
    }
    
    func testMimeTypeUnknownFallback() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "xyz"), "application/octet-stream")
    }
    
    func testMimeTypeCaseInsensitive() {
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "WAV"), "audio/wav")
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "Mp3"), "audio/mpeg")
        XCTAssertEqual(AudioMIMEHelper.mimeType(for: "M4A"), "audio/mp4")
    }
    
    // MARK: - audioFormat(for:) — only wav/mp3 accepted by input_audio API
    
    func testAudioFormatWav() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "wav"), "wav")
    }
    
    func testAudioFormatMp3() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "mp3"), "mp3")
    }
    
    func testAudioFormatMpga() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "mpga"), "mp3")
    }
    
    func testAudioFormatM4aFallsBackToWav() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "m4a"), "wav")
    }
    
    func testAudioFormatOggFallsBackToWav() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "ogg"), "wav")
    }
    
    func testAudioFormatFlacFallsBackToWav() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "flac"), "wav")
    }
    
    func testAudioFormatUnknownFallsBackToWav() {
        XCTAssertEqual(AudioMIMEHelper.audioFormat(for: "aac"), "wav")
    }
    
    // MARK: - validateFileSize(at:)
    
    func testValidateFileSizeWithValidFile() throws {
        let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_audio.wav")
        let data = Data(repeating: 0, count: 1024) // 1KB
        try data.write(to: tmpFile)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        
        XCTAssertNil(AudioMIMEHelper.validateFileSize(at: tmpFile), "Valid small file should pass validation")
    }
    
    func testValidateFileSizeWithEmptyFile() throws {
        let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_empty.wav")
        try Data().write(to: tmpFile)
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        
        let error = AudioMIMEHelper.validateFileSize(at: tmpFile)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("пустой"), "Error message should mention empty file")
    }
    
    func testValidateFileSizeWithNonexistentFile() {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent_test_file_\(UUID().uuidString).wav")
        let error = AudioMIMEHelper.validateFileSize(at: fakeURL)
        XCTAssertNotNil(error, "Nonexistent file should return error")
    }
    
    // MARK: - allowedExtensions
    
    func testAllowedExtensionsContainsCommonFormats() {
        let expected = ["wav", "mp3", "m4a", "mp4", "webm"]
        for ext in expected {
            XCTAssertTrue(AudioMIMEHelper.allowedExtensions.contains(ext), "allowedExtensions should contain \(ext)")
        }
    }
    
    // MARK: - allowedContentTypes
    
    func testAllowedContentTypesIsNotEmpty() {
        XCTAssertFalse(AudioMIMEHelper.allowedContentTypes.isEmpty, "allowedContentTypes should not be empty")
    }
}
