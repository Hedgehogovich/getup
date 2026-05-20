import Foundation

struct SayVoice: Hashable {
    let name: String
    let locale: String
}

enum SaySynth {
    /// Parse `say -v '?'` output. Format per line: `Name  locale  # sample text`.
    static func parseVoices(from text: String) -> [SayVoice] {
        var voices: [SayVoice] = []
        for raw in text.split(separator: "\n") {
            let line = String(raw)
            // omittingEmptySubsequences: false — comment-only lines must produce an empty leading segment, otherwise the comment body parses as voice content.
            let beforeHash = line
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? line
            let trimmed = beforeHash.trimmingCharacters(in: .whitespaces)
            let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 2 else { continue }
            let locale = tokens.last!
            let name = tokens.dropLast().joined(separator: " ")
            if !name.isEmpty { voices.append(SayVoice(name: name, locale: locale)) }
        }
        return voices.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

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

    @discardableResult
    static func preview(voice: String, phrase: String) -> Process? {
        let p = Process()
        p.launchPath = "/usr/bin/say"
        p.arguments = ["-v", voice, phrase]
        do {
            try p.run()
        } catch {
            NSLog("getup: SaySynth.preview failed: \(error.localizedDescription)")
            return nil
        }
        return p
    }

    /// Wizard safety net: if the user X-closes before step 3, this still writes a default
    /// sound.aiff so they hear audio at xx:50. Never overwrites a user-placed sound file.
    static func saveLoopIfMissing(voice: String, phrase: String) {
        guard AppPaths.existingSoundFile == nil else { return }
        saveLoop(voice: voice, phrase: phrase) { _ in }
    }

    /// Writes `sound.aiff` and removes other extensions so the audio loader picks this one.
    static func saveLoop(voice: String, phrase: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            let dir = AppPaths.supportDir
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for ext in AppPaths.soundExtensions where ext != "aiff" {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("sound.\(ext)"))
            }
            let target = AppPaths.loopAIFF
            // [[slnc 2000]] = 2s silence baked into the AIFF; without it AVAudioPlayer loops with no gap.
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
