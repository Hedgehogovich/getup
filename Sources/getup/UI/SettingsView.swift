import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    /// Owned by the view: schedules a debounced `say -o` regeneration of `sound.aiff` whenever
    /// voice or phrase changes, so settings + audio file stay in lockstep without a save button.
    /// `@StateObject` so the debounce task survives across body re-renders.
    @StateObject private var loopSync = AudioLoopSync()

    @State private var voices: [SayVoice] = []
    @State private var languageRestartPending = false
    @State private var pickerLanguage: String? = nil
    @State private var openAtLogin: Bool = LoginItem.isInstalled

    private let fireMinuteOptions = [0, 15, 30, 45, 50]

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
                Text("Apple Watch Stand reminders fire at xx:50.")
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
                Text("When off, getup runs only when launched manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Toggle("Show in Dock", isOn: $store.current.showInDock)
                Text("When on, getup also appears in the Dock and ⌘Tab. Useful when the camera notch hides menu-bar icons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            pickerLanguage = store.current.language
            openAtLogin = LoginItem.isInstalled    // re-sync in case install.sh / uninstall changed state
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
                    Button {
                        SaySynth.preview(voice: store.current.voice,
                                         phrase: store.current.customPhrase)
                    } label: {
                        Label("Preview", systemImage: "play.fill")
                    }
                    .disabled(store.current.customPhrase.isEmpty)

                    audioStatusIndicator
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        // Debounced auto-regen of sound.aiff. Initial onAppear-driven mutations don't fire
        // here (two-closure onChange skips the initial value); only true edits trigger.
        .onChange(of: store.current.voice) { _, _ in scheduleRegen() }
        .onChange(of: store.current.customPhrase) { _, _ in scheduleRegen() }
        .onDisappear { loopSync.cancel() }
    }

    private func scheduleRegen() {
        loopSync.schedule(voice: store.current.voice, phrase: store.current.customPhrase)
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
            Text("🚶 getup").font(.system(size: 28, weight: .bold))
            Text("Hourly stretch reminders for macOS")
                .foregroundStyle(.secondary)
            Text("v0.1").font(.caption).foregroundStyle(.secondary)
            Spacer().frame(height: 8)
            HStack {
                Button("Open log folder") { openSupportFolder() }
                Button("Open audio folder") { openSupportFolder() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 16)
    }

    private func openSupportFolder() {
        NSWorkspace.shared.open(AppPaths.supportDir)
    }
}
