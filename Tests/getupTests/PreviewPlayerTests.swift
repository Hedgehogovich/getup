import Foundation
import Testing
@testable import getup

@MainActor
@Suite("PreviewPlayer — state machine")
struct PreviewPlayerTests {
    /// Long-running process surrogate. /bin/sleep is universally present on macOS.
    private static func makeSleeper(_ seconds: Int = 60) -> Process {
        let p = Process()
        p.launchPath = "/bin/sleep"
        p.arguments = ["\(seconds)"]
        try? p.run()
        return p
    }

    private static func waitUntil(_ cond: () -> Bool, timeoutMs: Int = 2_000) async -> Bool {
        let start = Date()
        while !cond() {
            if Date().timeIntervalSince(start) * 1000 >= Double(timeoutMs) { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func playSayMarksIsPlayingTrue() {
        let spawned = SpawnRecorder()
        let player = PreviewPlayer(spawner: { source in
            spawned.record(source)
            return PreviewPlayerTests.makeSleeper()
        })
        #expect(!player.isPlaying)

        player.playSay(voice: "Alex", phrase: "hi")
        #expect(player.isPlaying)
        #expect(spawned.sources == [.say(voice: "Alex", phrase: "hi")])
        player.stop()
    }

    @Test func playSayWithNilSpawnerLeavesStateIdle() {
        let player = PreviewPlayer(spawner: { _ in nil })
        player.playSay(voice: "Alex", phrase: "hi")
        #expect(!player.isPlaying)
    }

    @Test func playFileRoutesFileSource() {
        let spawned = SpawnRecorder()
        let player = PreviewPlayer(spawner: { source in
            spawned.record(source)
            return PreviewPlayerTests.makeSleeper()
        })
        player.playFile()
        #expect(player.isPlaying)
        #expect(spawned.sources == [.file])
        player.stop()
    }

    @Test func playSayTwiceTerminatesPrevious() async {
        var spawnedProcesses: [Process] = []
        let player = PreviewPlayer(spawner: { _ in
            let p = PreviewPlayerTests.makeSleeper()
            spawnedProcesses.append(p)
            return p
        })

        player.playSay(voice: "Alex", phrase: "first")
        player.playSay(voice: "Alex", phrase: "second")
        #expect(spawnedProcesses.count == 2)

        let firstTerminated = await Self.waitUntil { !spawnedProcesses[0].isRunning }
        #expect(firstTerminated)
        #expect(spawnedProcesses[1].isRunning)
        #expect(player.isPlaying)
        player.stop()
    }

    @Test func stopTerminatesAndResetsState() async {
        var spawned: Process?
        let player = PreviewPlayer(spawner: { _ in
            let p = PreviewPlayerTests.makeSleeper()
            spawned = p
            return p
        })
        player.playSay(voice: "Alex", phrase: "hi")
        #expect(player.isPlaying)

        player.stop()
        #expect(!player.isPlaying)

        let dead = await Self.waitUntil { !(spawned?.isRunning ?? true) }
        #expect(dead)
    }

    @Test func stopWhenIdleIsNoOp() {
        let player = PreviewPlayer(spawner: { _ in nil })
        player.stop()
        #expect(!player.isPlaying)
    }

    @Test func staleTerminationHandlerDoesNotResetState() async {
        // First spawn exits immediately. Second spawn long-running. The first process's
        // terminationHandler fires after the second is already current — it must NOT flip
        // isPlaying because current !== first proc.
        var idx = 0
        let player = PreviewPlayer(spawner: { _ in
            idx += 1
            if idx == 1 {
                let p = Process()
                p.launchPath = "/usr/bin/true"
                try? p.run()
                return p
            } else {
                return PreviewPlayerTests.makeSleeper()
            }
        })

        player.playSay(voice: "Alex", phrase: "fast")
        player.playSay(voice: "Alex", phrase: "slow")

        // Give the first proc's terminationHandler ample time to run on a loaded CI runner.
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(player.isPlaying)
        player.stop()
    }
}

/// Captures spawn calls. Reference-typed so the closure can mutate without `var` capture.
@MainActor
private final class SpawnRecorder {
    private(set) var sources: [PreviewPlayer.Source] = []
    func record(_ s: PreviewPlayer.Source) { sources.append(s) }
}
