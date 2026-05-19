import Foundation

/// Debounces voice/phrase edits in Settings → one `say -o` regen of `sound.aiff` per quiet period.
@MainActor
final class AudioLoopSync: ObservableObject {
    enum Status: Equatable {
        case idle
        case regenerating
        case succeeded
        case failed
    }

    @Published private(set) var status: Status = .idle

    private var debounceTask: Task<Void, Never>?
    private let debounce: Duration
    private let succeededFade: Duration
    private let saver: @Sendable (String, String, @escaping @Sendable (Bool) -> Void) -> Void

    init(
        debounce: Duration = .seconds(1.5),
        succeededFade: Duration = .seconds(3),
        saver: @escaping @Sendable (String, String, @escaping @Sendable (Bool) -> Void) -> Void = { v, p, c in SaySynth.saveLoop(voice: v, phrase: p, completion: c) }
    ) {
        self.debounce = debounce
        self.succeededFade = succeededFade
        self.saver = saver
    }

    func schedule(voice: String, phrase: String) {
        guard !phrase.isEmpty else {
            cancel()
            status = .idle
            return
        }
        debounceTask?.cancel()
        let saver = self.saver
        let debounce = self.debounce
        let fade = self.succeededFade
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            await self.runRegen(voice: voice, phrase: phrase, saver: saver, fade: fade)
        }
    }

    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func runRegen(
        voice: String,
        phrase: String,
        saver: @Sendable (String, String, @escaping @Sendable (Bool) -> Void) -> Void,
        fade: Duration
    ) async {
        status = .regenerating
        let ok: Bool = await withCheckedContinuation { cont in
            saver(voice, phrase) { ok in cont.resume(returning: ok) }
        }
        guard !Task.isCancelled else { return }
        status = ok ? .succeeded : .failed
        if status == .succeeded {
            try? await Task.sleep(for: fade)
            if status == .succeeded { status = .idle }
        }
    }
}
