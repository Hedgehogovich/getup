import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    @StateObject private var loopSync = AudioLoopSync()
    @ObservedObject private var preview = PreviewPlayer.shared

    @State private var voices: [SayVoice] = []
    @State private var languageRestartPending = false
    @State private var pickerLanguage: String? = nil
    @State private var openAtLogin: Bool = LoginItem.isInstalled
    @State private var logsCopied = false
    @State private var showCustomAudioError = false
    @State private var customAudioErrorTitle = ""
    @State private var customAudioErrorMessage = ""

    private let fireMinuteOptions = [0, 15, 30, 45, 50]
    private let snoozeOptions = [5, 10, 15, 20, 30]
    private let autoDismissOptions = [5, 10, 15, 30, 60]

    private var availableLanguages: [String] { LocaleHelper.availableLanguages }
    private static func nativeName(_ code: String) -> String { LocaleHelper.nativeName(code) }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            audioTab
                .tabItem { Label("Audio", systemImage: "speaker.wave.2.fill") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 500)
        .padding(20)
        .task {
            if voices.isEmpty {
                let list = await Task.detached(priority: .userInitiated) { SaySynth.listVoices() }.value
                voices = list
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section("Schedule") {
                Picker("Fire at minute", selection: $store.current.fireMinute) {
                    ForEach(fireMinuteOptions, id: \.self) { m in
                        Text(String(format: "xx:%02d", m)).tag(m)
                    }
                }
            }
            Section("Snooze") {
                Picker("Snooze duration", selection: $store.current.snoozeMinutes) {
                    ForEach(snoozeOptions, id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                Text("How long to wait after pressing Snooze.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Language") {
                Picker("Language", selection: $pickerLanguage) {
                    Text("System default").tag(String?.none)
                    ForEach(availableLanguages, id: \.self) { code in
                        Text(Self.nativeName(code)).tag(String?.some(code))
                    }
                }
                .onChange(of: pickerLanguage) { _, new in
                    if new != store.current.language {
                        store.current.language = new
                        languageRestartPending = true
                    }
                }
                if languageRestartPending {
                    Button {
                        DaemonRestart.restart()
                    } label: {
                        Label("Restart now to apply", systemImage: "arrow.clockwise")
                    }
                }
            }
            Section("Startup") {
                Toggle("Run at startup", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, new in
                        if new { LoginItem.enable() } else { LoginItem.disable() }
                    }
                Text("When off, Getup runs only when launched manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Toggle("Show in Dock", isOn: $store.current.showInDock)
                Text("When on, Getup also appears in the Dock and ⌘Tab. Useful when the camera notch hides menu-bar icons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Overlay") {
                Picker("Auto-dismiss", selection: $store.current.overlayAutoDismissSeconds) {
                    Text("Never").tag(Int?.none)
                    ForEach(autoDismissOptions, id: \.self) { secs in
                        Text(String(format: NSLocalizedString("%d s", comment: "auto-dismiss seconds picker option"), secs))
                            .tag(Int?.some(secs))
                    }
                }
                Text("Auto-close the hourly reminder after this delay. Audio stops too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.current.overlayMediaEnabled {
                    Text(String(format: NSLocalizedString("Using custom media: %@",
                                                          comment: "Caption beneath the custom media button"),
                                store.current.overlayMediaFilename ?? "—"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Remove custom media") { revertOverlayMedia() }
                } else {
                    Button("Custom media…") { pickOverlayMedia() }
                    Text("Show an image, GIF, or video in the overlay. Supports PNG, JPG, GIF, MP4, MOV.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Privacy") {
                Toggle("Hide from screen sharing", isOn: $store.current.hideFromScreenCapture)
                Text("When on, the overlay is invisible to Teams, QuickTime, and other screen-capture tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Quiet hours") {
                Toggle("Enable quiet hours", isOn: $store.current.quietHoursEnabled)
                if store.current.quietHoursEnabled {
                    DatePicker("Start",
                               selection: minutesBinding(\.quietHoursStartMinutes),
                               displayedComponents: .hourAndMinute)
                    DatePicker("End",
                               selection: minutesBinding(\.quietHoursEndMinutes),
                               displayedComponents: .hourAndMinute)
                }
                Text("Skip the hourly reminder between these times. Manual “Stretch now” still works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            pickerLanguage = store.current.language
            openAtLogin = LoginItem.isInstalled   // re-sync in case install.sh / uninstall changed it.
        }
    }

    private var audioTab: some View {
        Form {
            Section("When to play audio") {
                Picker("Mode", selection: $store.current.audioMode) {
                    ForEach(AudioMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section("Volume") {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $store.current.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                    Text(String(format: "%.0f%%", store.current.volume * 100))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                .disabled(store.current.audioMode == .silent)
            }
            if store.current.useCustomAudio {
                customAudioSection
            } else {
                generatedAudioSection
            }
        }
        .formStyle(.grouped)
        .onChange(of: store.current.voice) { _, _ in
            if !store.current.useCustomAudio { scheduleRegen() }
        }
        .onChange(of: store.current.customPhrase) { _, _ in
            if !store.current.useCustomAudio { scheduleRegen() }
        }
        .onDisappear {
            loopSync.cancel()
            preview.stop()
        }
        .alert(customAudioErrorTitle, isPresented: $showCustomAudioError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(customAudioErrorMessage)
        }
    }

    private var generatedAudioSection: some View {
        Group {
            Section("Voice & phrase") {
                Picker("Voice", selection: $store.current.voice) {
                    if !voices.contains(where: { $0.name == store.current.voice }) {
                        Text(String(format: NSLocalizedString("%@ (not installed)", comment: "voice picker fallback when configured voice missing"),
                                    store.current.voice))
                            .tag(store.current.voice)
                    }
                    ForEach(voices, id: \.self) { v in
                        Text(verbatim: "\(v.name)  —  \(v.locale)").tag(v.name)
                    }
                }
                TextField("Phrase", text: $store.current.customPhrase, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    previewToggleButton(generated: true)
                    audioStatusIndicator
                    Spacer()
                }
            }
            Section("Audio source") {
                Button("Use custom audio file…") { pickCustomAudio() }
                Text("Replaces the generated audio. Supports .aiff, .mp3, .m4a, .wav.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var customAudioSection: some View {
        Section("Audio source") {
            Text(String(format: NSLocalizedString("Using custom audio: %@",
                                                  comment: "Caption beneath the custom audio button"),
                        store.current.customAudioFilename ?? "—"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                previewToggleButton(generated: false)
                Button("Use generated audio instead") { revertCustomAudio() }
                Spacer()
            }
        }
    }

    private func scheduleRegen() {
        loopSync.schedule(voice: store.current.voice, phrase: store.current.customPhrase)
    }

    @ViewBuilder
    private func previewToggleButton(generated: Bool) -> some View {
        Button {
            if preview.isPlaying {
                preview.stop()
            } else if generated {
                preview.playSay(voice: store.current.voice,
                                phrase: store.current.customPhrase)
            } else {
                preview.playFile()
            }
        } label: {
            if preview.isPlaying {
                Label("Stop", systemImage: "stop.fill")
            } else {
                Label("Preview", systemImage: "play.fill")
            }
        }
        .disabled(previewDisabled(generated: generated))
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let start = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(byAdding: .minute, value: store.current[keyPath: keyPath], to: start) ?? start
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.current[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func previewDisabled(generated: Bool) -> Bool {
        if preview.isPlaying { return false }
        return generated
            ? store.current.customPhrase.isEmpty
            : AppPaths.existingSoundFile == nil
    }

    private func pickCustomAudio() {
        guard let url = CustomAudio.showOpenPanel() else { return }
        do {
            let filename = try CustomAudio.install(from: url)
            loopSync.cancel()
            // Single struct reassign → one didSet, one JSON encode.
            var next = store.current
            next.customAudioFilename = filename
            next.useCustomAudio = true
            store.current = next
        } catch CustomAudio.InstallError.unsupportedExtension {
            customAudioErrorTitle = NSLocalizedString("Unsupported audio format",
                                                      comment: "Alert title when picked file is not aiff/mp3/m4a/wav")
            customAudioErrorMessage = NSLocalizedString("Use .aiff, .mp3, .m4a, or .wav.",
                                                        comment: "Alert body for unsupported audio format")
            showCustomAudioError = true
        } catch CustomAudio.InstallError.ioFailure(let detail) {
            customAudioErrorTitle = NSLocalizedString("Could not install audio",
                                                      comment: "Alert title when copy fails")
            customAudioErrorMessage = detail
            showCustomAudioError = true
        } catch {
            customAudioErrorTitle = NSLocalizedString("Could not install audio",
                                                      comment: "Alert title when copy fails")
            customAudioErrorMessage = error.localizedDescription
            showCustomAudioError = true
        }
    }

    private func revertCustomAudio() {
        CustomAudio.revertToGenerated()
        var next = store.current
        next.useCustomAudio = false
        next.customAudioFilename = nil
        store.current = next
        SaySynth.saveLoopIfMissing(voice: store.current.voice,
                                   phrase: store.current.customPhrase)
    }

    private func pickOverlayMedia() {
        guard let url = CustomMedia.showOpenPanel() else { return }
        do {
            let filename = try CustomMedia.install(from: url)
            var next = store.current
            next.overlayMediaFilename = filename
            next.overlayMediaEnabled = true
            store.current = next
        } catch CustomMedia.InstallError.unsupportedExtension {
            customAudioErrorTitle = NSLocalizedString("Unsupported media format",
                                                      comment: "Alert title when picked overlay media isn't supported")
            customAudioErrorMessage = NSLocalizedString("Use PNG, JPG, GIF, MP4, or MOV.",
                                                        comment: "Alert body for unsupported overlay media format")
            showCustomAudioError = true
        } catch CustomMedia.InstallError.ioFailure(let detail) {
            customAudioErrorTitle = NSLocalizedString("Could not install media",
                                                      comment: "Alert title when overlay media copy fails")
            customAudioErrorMessage = detail
            showCustomAudioError = true
        } catch {
            customAudioErrorTitle = NSLocalizedString("Could not install media",
                                                      comment: "Alert title when overlay media copy fails")
            customAudioErrorMessage = error.localizedDescription
            showCustomAudioError = true
        }
    }

    private func revertOverlayMedia() {
        CustomMedia.revertToDefault()
        var next = store.current
        next.overlayMediaEnabled = false
        next.overlayMediaFilename = nil
        store.current = next
    }

    @ViewBuilder
    private var audioStatusIndicator: some View {
        switch loopSync.status {
        case .idle:
            EmptyView()
        case .regenerating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Updating audio…").font(.caption).foregroundStyle(.secondary)
            }
        case .succeeded:
            Text("Audio updated ✓").font(.caption).foregroundStyle(.secondary)
        case .failed:
            Text("Audio update failed").font(.caption).foregroundStyle(.red)
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 10) {
            if let icon = NSImage(named: "NSApplicationIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }
            Text("Getup").font(.system(size: 28, weight: .bold))
            Text("Hourly stretch reminders for macOS")
                .foregroundStyle(.secondary)
            Text(versionLabel).font(.caption).foregroundStyle(.secondary)
            Spacer().frame(height: 8)
            HStack(spacing: 12) {
                Button("Open support folder") { openSupportFolder() }
                Button(logsCopied ? "Copied ✓" : "Copy logs") { copyDiagnostics() }
                    .disabled(logsCopied)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 16)
    }

    private var versionLabel: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }

    private func openSupportFolder() {
        NSWorkspace.shared.open(AppPaths.supportDir)
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(buildDiagnosticReport(), forType: .string)
        logsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { logsCopied = false }
    }

    private func buildDiagnosticReport() -> String {
        var out = "Getup \(versionLabel)\n"
        out += "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        out += String(repeating: "—", count: 40) + "\n"
        let log = AppPaths.stderrLog
        if let data = try? Data(contentsOf: log),
           let text = String(data: data, encoding: .utf8) {
            // Last 500 lines keeps the paste tractable for bug reports.
            let tail = text.split(separator: "\n", omittingEmptySubsequences: false).suffix(500)
            out += tail.joined(separator: "\n")
        } else {
            out += "(no log file at \(log.path))"
        }
        return out
    }
}
