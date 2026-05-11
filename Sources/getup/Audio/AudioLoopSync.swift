import Foundation

/// Debounced regenerator for `sound.aiff`. Settings auto-saves voice + phrase mutations to
/// disk, but the actual audio file is a separate ~2-second AIFF rendered by `say -o`. This
/// type bridges the two: every voice/phrase mutation schedules a `say` invocation after a
/// quiet period (default 1.5s of no further changes), so the user gets a working audio
/// loop matching what they just typed without ever clicking a "Save" button.
///
/// `status` drives a small UI indicator: regenerating shows a spinner, succeeded shows
/// "Audio updated ✓" then auto-fades to idle, failed sticks until the next mutation.
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

    /// - `debounce`: quiet period before the next `say` invocation. Default 1.5s.
    /// - `succeededFade`: how long the "Audio updated ✓" indicator lingers before resetting.
    /// - `saver`: injected for tests. Production passes `SaySynth.saveLoop`.
    init(
        debounce: Duration = .seconds(1.5),
        succeededFade: Duration = .seconds(3),
        saver: @escaping @Sendable (String, String, @escaping @Sendable (Bool) -> Void) -> Void = { v, p, c in SaySynth.saveLoop(voice: v, phrase: p, completion: c) }
    ) {
        self.debounce = debounce
        self.succeededFade = succeededFade
        self.saver = saver
    }

    /// Schedule a regen. Called from `SettingsView.onChange` for voice + phrase. Repeated
    /// calls within the debounce window collapse — only the last call's voice+phrase reach
    /// the saver. Empty phrase cancels any pending work and resets to `.idle`.
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

    /// Cancel any pending or in-flight regen. Status is left as-is — caller decides whether
    /// to reset. Used from `SettingsView.onDisappear`.
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
