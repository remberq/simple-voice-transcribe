import XCTest
@testable import VoiceOverlay

final class TranscriptionHistoryManagerTests: XCTestCase {
    
    var manager: TranscriptionHistoryManager!
    
    override func setUp() {
        super.setUp()
        manager = TranscriptionHistoryManager.shared
        manager.jobs.removeAll()
        manager.copiedJobId = nil
    }
    
    override func tearDown() {
        manager.jobs.removeAll()
        manager.copiedJobId = nil
        super.tearDown()
    }
    
    // Helper to allow DispatchQueue.main.async blocks in the manager to execute
    func flushAsync() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    func testAddJob() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        
        let job = manager.addJob(url: fakeUrl, providerName: "openai")
        XCTAssertEqual(job.status, .uploading)
        XCTAssertEqual(job.fileFormat, "M4A")
        XCTAssertEqual(job.uploadProgress, 0.0)
        
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.count, 1)
        XCTAssertEqual(manager.jobs.first?.id, job.id)
        XCTAssertEqual(manager.activeJobsCount, 1)
    }
    
    func testUpdateJobProgress() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        let job = manager.addJob(url: fakeUrl, providerName: "openai")
        
        await flushAsync()
        XCTAssertEqual(manager.jobs.first?.uploadProgress, 0.0)
        
        manager.updateJobProgress(id: job.id, progress: 0.55)
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.first?.uploadProgress, 0.55)
        
        // Test bounds
        manager.updateJobProgress(id: job.id, progress: 1.5)
        await flushAsync()
        XCTAssertEqual(manager.jobs.first?.uploadProgress, 1.0)
        
        manager.updateJobProgress(id: job.id, progress: -0.5)
        await flushAsync()
        XCTAssertEqual(manager.jobs.first?.uploadProgress, 0.0)
    }
    
    func testUpdateJobStatusAndResult() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        let job = manager.addJob(url: fakeUrl, providerName: "openai")
        
        await flushAsync()
        
        manager.updateJob(id: job.id, status: .processing)
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.first?.status, .processing)
        XCTAssertEqual(manager.activeJobsCount, 1)
        
        manager.updateJob(id: job.id, status: .completed, resultText: "Test transcription successful", errorMessage: nil)
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.first?.status, .completed)
        XCTAssertEqual(manager.jobs.first?.resultText, "Test transcription successful")
        XCTAssertNil(manager.jobs.first?.errorMessage)
        XCTAssertEqual(manager.activeJobsCount, 0)
        
        manager.updateJob(id: job.id, status: .failed, resultText: nil, errorMessage: "API Error")
        await flushAsync()
        XCTAssertEqual(manager.jobs.first?.status, .failed)
        XCTAssertEqual(manager.jobs.first?.errorMessage, "API Error")
    }
    
    func testResetJob() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        let job = manager.addJob(url: fakeUrl, providerName: "openai")
        
        await flushAsync()
        
        manager.updateJob(id: job.id, status: .failed, resultText: "Partial", errorMessage: "Error")
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.first?.status, .failed)
        
        manager.resetJob(id: job.id)
        await flushAsync()
        
        let resetJob = manager.jobs.first
        XCTAssertEqual(resetJob?.status, .uploading)
        XCTAssertEqual(resetJob?.uploadProgress, 0.0)
        XCTAssertNil(resetJob?.resultText)
        XCTAssertNil(resetJob?.errorMessage)
    }
    
    func testDeleteJob() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        let job = manager.addJob(url: fakeUrl, providerName: "openai")
        
        await flushAsync()
        XCTAssertEqual(manager.jobs.count, 1)
        
        manager.deleteJob(id: job.id)
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.count, 0)
    }
    
    func testClearHistory() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        _ = manager.addJob(url: fakeUrl, providerName: "openai")
        _ = manager.addJob(url: fakeUrl, providerName: "openai")
        _ = manager.addJob(url: fakeUrl, providerName: "gemini")
        
        await flushAsync()
        XCTAssertEqual(manager.jobs.count, 3)
        
        manager.clearHistory()
        await flushAsync()
        
        XCTAssertEqual(manager.jobs.count, 0)
    }
    
    func testMaxJobLimit() async {
        let fakeUrl = URL(fileURLWithPath: "/tmp/fake_test.m4a")
        
        // Add 12 jobs
        for i in 0..<12 {
            _ = manager.addJob(id: UUID(), url: fakeUrl, providerName: "provider-\(i)")
            await flushAsync() // Wait so insertion order is perfectly sequential
        }
        
        // The manager is hardcoded to keep only 10 items
        XCTAssertEqual(manager.jobs.count, 10)
        
        // "provider-11" should be the most recent (first), "provider-2" should be the oldest (last)
        XCTAssertEqual(manager.jobs.first?.providerName, "provider-11")
        XCTAssertEqual(manager.jobs.last?.providerName, "provider-2")
    }
}
