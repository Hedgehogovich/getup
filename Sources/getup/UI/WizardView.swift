import SwiftUI

struct WizardView: View {
    @ObservedObject var store: SettingsStore
    let onComplete: (_ languageChanged: Bool) -> Void
    var initialStep: Step = .language
    var initialBundle: Bundle? = nil

    @State private var step: Step
    @State private var pickedLanguage: String? = nil
    @State private var localeBundle: Bundle
    @State private var openAtLogin: Bool = LoginItem.isInstalled
    @State private var voices: [SayVoice] = []
    @ObservedObject private var preview = PreviewPlayer.shared

    enum Step { case language, audio, voice }

    init(store: SettingsStore,
         onComplete: @escaping (_ languageChanged: Bool) -> Void,
         initialStep: Step = .language,
         initialBundle: Bundle? = nil) {
        self.store = store
        self.onComplete = onComplete
        self.initialStep = initialStep
        self.initialBundle = initialBundle
        self._step = State(initialValue: initialStep)
        self._localeBundle = State(initialValue: initialBundle ?? .main)
    }

    var body: some View {
        Group {
            switch step {
            case .language: languageStep
            case .audio:    audioStep
            case .voice:    voiceStep
            }
        }
        .frame(width: 420, height: 460)
        .onAppear {
            pickedLanguage = store.current.language
            // Skip auto-resolution when caller seeded a bundle (snapshot tests do this).
            guard initialBundle == nil else { return }
            // Cocoa caches Bundle.main's localization at process startup from AppleLanguages, so
            // a stale override forces step 1 into the wrong language. Bundle.preferredLocalizations
            // resolves to the system preference even with cruft in our domain.
            let bundleLocs = Bundle.main.localizations.filter { $0 != "Base" }
            if let pref = Bundle.preferredLocalizations(from: bundleLocs).first,
               let b = LocaleHelper.bundle(forLocale: pref) {
                localeBundle = b
            }
        }
        .task {
            if voices.isEmpty {
                let list = await Task.detached(priority: .userInitiated) { SaySynth.listVoices() }.value
                voices = list
                seedDefaults(language: store.current.language)
            }
        }
    }

    private var languageStep: some View {
        VStack(spacing: 18) {
            appIconHeader
            Text("Welcome to Getup", bundle: localeBundle).font(.title.bold())
            Text("Hourly stretch reminders for macOS", bundle: localeBundle)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Language", bundle: localeBundle).font(.headline)
                Picker("", selection: $pickedLanguage) {
                    Text("System default", bundle: localeBundle).tag(String?.none)
                    ForEach(LocaleHelper.availableLanguages, id: \.self) { code in
                        Text(LocaleHelper.nativeName(code)).tag(String?.some(code))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 4)

            Button {
                applyLanguagePick()
                step = .audio
            } label: {
                Text("Continue", bundle: localeBundle).frame(minWidth: 140)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(28)
    }

    private var audioStep: some View {
        VStack(spacing: 18) {
            appIconHeader
            Text("Welcome to Getup", bundle: localeBundle).font(.title.bold())
            Text("Hourly stretch reminders for macOS", bundle: localeBundle)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("When should I play audio?", bundle: localeBundle).font(.headline)
                Picker("", selection: $store.current.audioMode) {
                    ForEach(AudioMode.allCases, id: \.self) { m in
                        Text(m.displayKey, bundle: localeBundle).tag(m)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $openAtLogin) {
                Text("Run at startup", bundle: localeBundle)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $store.current.showInDock) {
                Text("Show in Dock", bundle: localeBundle)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 4)

            Button {
                applyLoginChoice()
                step = .voice
            } label: {
                Text("Continue", bundle: localeBundle).frame(minWidth: 140)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(28)
    }

    private var voiceStep: some View {
        VStack(spacing: 14) {
            appIconHeader
            Text("Pick a voice and phrase", bundle: localeBundle).font(.title.bold())
            Text("This is what I will say each hour.", bundle: localeBundle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Voice", bundle: localeBundle).font(.headline)
                Picker("", selection: $store.current.voice) {
                    if !voices.contains(where: { $0.name == store.current.voice }) {
                        Text(store.current.voice).tag(store.current.voice)
                    }
                    ForEach(voices, id: \.self) { v in
                        Text(verbatim: "\(v.name)  —  \(v.locale)").tag(v.name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Text("Phrase", bundle: localeBundle).font(.headline).padding(.top, 4)
                TextField("", text: $store.current.customPhrase, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    if preview.isPlaying {
                        preview.stop()
                    } else {
                        preview.playSay(voice: store.current.voice,
                                        phrase: store.current.customPhrase)
                    }
                } label: {
                    Label {
                        Text("Preview", bundle: localeBundle)
                    } icon: {
                        Image(systemName: preview.isPlaying ? "stop.fill" : "play.fill")
                    }
                }
                .disabled(store.current.customPhrase.isEmpty)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer().frame(height: 4)

            Button {
                SaySynth.saveLoopIfMissing(voice: store.current.voice,
                                           phrase: store.current.customPhrase)
                onComplete(pickedLanguage != nil)
            } label: {
                Text("Get started", bundle: localeBundle).frame(minWidth: 140)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(28)
    }

    private func applyLoginChoice() {
        if openAtLogin && !LoginItem.isInstalled { LoginItem.enable() }
        if !openAtLogin && LoginItem.isInstalled { LoginItem.disable() }
    }

    private func applyLanguagePick() {
        store.current.language = pickedLanguage
        if let lang = pickedLanguage, let b = LocaleHelper.bundle(forLocale: lang) {
            localeBundle = b
        } else {
            localeBundle = .main
        }
        // Safe to overwrite voice/phrase: step 1 → step 2 is the only path that gets here,
        // and the user hasn't seen the TextField yet.
        seedDefaults(language: pickedLanguage)
    }

    private func seedDefaults(language: String?) {
        let pair = LocaleHelper.defaultLoopDefaults(forLanguage: language, available: voices)
        store.current.customPhrase = pair.phrase
        if let v = pair.voice { store.current.voice = v }
    }

    @ViewBuilder
    private var appIconHeader: some View {
        if let icon = NSImage(named: "NSApplicationIcon") {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 80, height: 80)
        }
    }
}
