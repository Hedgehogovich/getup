import Foundation

struct SayVoice: Hashable {
    let name: String
    let locale: String
}

enum SaySynth {
    /// Pure parser for `say -v '?'` output. Lines look like:
    ///     Albert              en_US    # I have a frog in my throat. ...
    /// Split out from `listVoices()` so it can be unit-tested with canned input.
    static func parseVoices(from text: String) -> [SayVoice] {
        var voices: [SayVoice] = []
        for raw in text.split(separator: "\n") {
            let line = String(raw)
            // Pass `omittingEmptySubsequences: false` so a line starting with `#` produces
            // a LEADING empty segment — otherwise Swift's default would drop it and the
            // comment body would be read as voice content (parsed "# foo bar" as 2 tokens).
            let beforeHash = line
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? line
            let trimmed = beforeHash.trimmingCharacters(in: .whitespaces)
            // Apple's `say -v ?` output uses runs of spaces between columns, but external
            // callers / different shells / pasted fixtures may use tabs. Split on any
            // whitespace character so both work.
            let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 2 else { continue }
            let locale = tokens.last!
            let name = tokens.dropLast().joined(separator: " ")
            if !name.isEmpty { voices.append(SayVoice(name: name, locale: locale)) }
        }
        return voices.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Run `say -v '?'` and parse its output. Returns [] on failure.
    static func listVoices() -> [SayVoice] {
        let p = Process()
        p.launchPath = "/usr/bin/say"
        p.arguments = ["-v", "?"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do { try p.run() } catch { return [] }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parseVoices(from: text)
    }

    /// Speak the phrase through default output device. Fire-and-forget.
    @discardableResult
    static func preview(voice: String, phrase: String) -> Process? {
        NSLog("getup: SaySynth.preview voice=\(voice) phraseLen=\(phrase.count)")
        let p = Process()
        p.launchPath = "/usr/bin/say"
        p.arguments = ["-v", voice, phrase]
        p.terminationHandler = { task in
            NSLog("getup: SaySynth.preview ended status=\(task.terminationStatus)")
        }
        do {
            try p.run()
            NSLog("getup: SaySynth.preview launched pid=\(p.processIdentifier)")
        } catch {
            NSLog("getup: SaySynth.preview FAILED: \(error.localizedDescription)")
            return nil
        }
        return p
    }

    /// Generate `sound.aiff` only when the user has no existing `sound.{mp3,m4a,wav,aiff}`.
    /// Used by the first-run wizard so closing it via Get started OR the title-bar X still
    /// leaves the user with a working audio loop. Never overwrites a user-supplied file.
    static func saveLoopIfMissing(voice: String, phrase: String) {
        let exists = AppPaths.soundFileCandidates.contains { FileManager.default.fileExists(atPath: $0.path) }
        guard !exists else {
            NSLog("getup: SaySynth.saveLoopIfMissing — existing sound file found, skipping")
            return
        }
        saveLoop(voice: voice, phrase: phrase) { ok in
            NSLog("getup: SaySynth.saveLoopIfMissing wrote default sound.aiff ok=\(ok)")
        }
    }

    /// Generate `sound.aiff` in the support dir. Removes other extensions so it wins the loader's priority.
    static func saveLoop(voice: String, phrase: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            let dir = AppPaths.supportDir
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for ext in AppPaths.soundExtensions where ext != "aiff" {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("sound.\(ext)"))
            }
            let target = AppPaths.loopAIFF
            // Append `say` tagged silence so AVAudioPlayer.numberOfLoops = -1 produces a
            // discernible gap between repetitions instead of running phrases together
            // ("...resistance is futilemovement protocol initiated...").
            let phraseWithGap = phrase + " [[slnc 2000]]"
            let p = Process()
            p.launchPath = "/usr/bin/say"
            p.arguments = ["-v", voice, "-o", target.path, phraseWithGap]
            let ok: Bool
            do {
                try p.run()
                p.waitUntilExit()
                ok = (p.terminationStatus == 0)
            } catch {
                ok = false
            }
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
