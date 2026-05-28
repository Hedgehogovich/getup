import Foundation
import Testing
@testable import getup

@Suite("AudioLoopSync — debounced regen")
@MainActor
struct AudioLoopSyncTests {
    /// Test recorder for the saver closure. Captures every (voice, phrase) pair the sync
    /// invoked. `result` is what the fake completes with — true = success, false = failure.
    final class Recorder: @unchecked Sendable {
        var calls: [(voice: String, phrase: String)] = []
        var result: Bool = true
    }

    /// Build an AudioLoopSync with very short debounce + fade for fast tests, and a
    /// recording saver that fires completion synchronously on the calling queue.
    private static func make(
        debounceMS: Int = 30,
        fadeMS: Int = 30,
        result: Bool = true
    ) -> (AudioLoopSync, Recorder) {
        let rec = Recorder()
        rec.result = result
        let sync = AudioLoopSync(
            debounce: .milliseconds(debounceMS),
            succeededFade: .milliseconds(fadeMS),
            saver: { v, p, completion in
                rec.calls.append((v, p))
                let ok = rec.result
                completion(ok)
            }
        )
        return (sync, rec)
    }

    @Test func debouncesRapidEditsToASingleSaverCall() async throws {
        let (sync, rec) = Self.make(debounceMS: 50)
        sync.schedule(voice: "Alex", phrase: "one")
        sync.schedule(voice: "Alex", phrase: "two")
        sync.schedule(voice: "Alex", phrase: "three")
        // 1 s gives the main-actor cooperative scheduler plenty of headroom on loaded CI runners.
        try await Task.sleep(for: .milliseconds(1000))
        #expect(rec.calls.count == 1)
        #expect(rec.calls.first?.phrase == "three")
    }

    @Test func successTransitionsToSucceededThenIdle() async throws {
        // 2 s fade — the 500 ms read lands well inside the succeeded window on any CI runner;
        // 3 s second read lands well past the 2050 ms fade-end.
        let (sync, _) = Self.make(debounceMS: 30, fadeMS: 2000, result: true)
        sync.schedule(voice: "Alex", phrase: "hello")
        try await Task.sleep(for: .milliseconds(500))    // past debounce, before fade end
        #expect(sync.status == .succeeded)
        try await Task.sleep(for: .milliseconds(3000))   // past fade
        #expect(sync.status == .idle)
    }

    @Test func failureSticks() async throws {
        let (sync, _) = Self.make(debounceMS: 30, fadeMS: 30, result: false)
        sync.schedule(voice: "Alex", phrase: "hello")
        try await Task.sleep(for: .milliseconds(400))    // past debounce + CI jitter
        #expect(sync.status == .failed)
        // Failure does NOT auto-fade — give time, status should still be .failed.
        try await Task.sleep(for: .milliseconds(200))
        #expect(sync.status == .failed)
    }

    @Test func emptyPhraseCancelsAndGoesIdle() async throws {
        let (sync, rec) = Self.make(debounceMS: 50)
        sync.schedule(voice: "Alex", phrase: "hello")  // armed
        sync.schedule(voice: "Alex", phrase: "")       // cancels
        try await Task.sleep(for: .milliseconds(120))
        #expect(rec.calls.isEmpty)
        #expect(sync.status == .idle)
    }

    @Test func cancelDropsPendingWork() async throws {
        let (sync, rec) = Self.make(debounceMS: 80)
        sync.schedule(voice: "Alex", phrase: "hi")
        sync.cancel()
        try await Task.sleep(for: .milliseconds(150))
        #expect(rec.calls.isEmpty)
    }
}
