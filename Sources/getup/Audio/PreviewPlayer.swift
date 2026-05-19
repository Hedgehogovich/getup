import Foundation

@MainActor
final class PreviewPlayer: ObservableObject {
    static let shared = PreviewPlayer()

    @Published private(set) var isPlaying = false

    private var current: Process?

    private init() {}

    func playSay(voice: String, phrase: String) {
        stop()
        guard let p = SaySynth.preview(voice: voice, phrase: phrase) else { return }
        attach(p)
    }

    func playFile() {
        stop()
        guard let p = CustomAudio.previewCurrent() else { return }
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
            DispatchQueue.main.async {
                guard let self else { return }
                if self.current === proc {
                    self.current = nil
                    self.isPlaying = false
                }
            }
        }
    }
}
