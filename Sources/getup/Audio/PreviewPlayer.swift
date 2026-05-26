import Foundation

@MainActor
final class PreviewPlayer: ObservableObject {
    enum Source: Equatable {
        case say(voice: String, phrase: String)
        case file
    }

    typealias Spawner = @MainActor (Source) -> Process?

    static let shared = PreviewPlayer(spawner: PreviewPlayer.defaultSpawner)

    @Published private(set) var isPlaying = false

    private var current: Process?
    private let spawner: Spawner

    init(spawner: @escaping Spawner) {
        self.spawner = spawner
    }

    func playSay(voice: String, phrase: String) {
        stop()
        guard let p = spawner(.say(voice: voice, phrase: phrase)) else { return }
        attach(p)
    }

    func playFile() {
        stop()
        guard let p = spawner(.file) else { return }
        attach(p)
    }

    func stop() {
        if let p = current, p.isRunning {
            p.terminate()
        }
        current = nil
        isPlaying = false
    }

    private func attach(_ p: Process) {
        current = p
        isPlaying = true
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                if self.current === proc {
                    self.current = nil
                    self.isPlaying = false
                }
            }
        }
    }

    @MainActor
    private static func defaultSpawner(_ source: Source) -> Process? {
        switch source {
        case .say(let voice, let phrase):
            return SaySynth.preview(voice: voice, phrase: phrase)
        case .file:
            return CustomAudio.previewCurrent()
        }
    }
}
