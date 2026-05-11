import SwiftUI

struct WizardView: View {
    @ObservedObject var store: SettingsStore
    /// Called when user clicks Get started. `languageChanged` = true if they picked anything
    /// other than System default — the controller uses that to decide whether to relaunch.
    let onComplete: (_ languageChanged: Bool) -> Void

    @State private var step: Step = .language
    @State private var pickedLanguage: String? = nil
    @State private var localeBundle: Bundle = .main
    @State private var openAtLogin: Bool = LoginItem.isInstalled
    @State private var voices: [SayVoice] = []

    enum Step { case language, audio, voice }

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
            // Resolve step 1 against the system-preferred .lproj rather than `Bundle.main`.
            // Why: Cocoa caches `.main`'s localization at process startup from `AppleLanguages`,
            // so a stale override left over from a previous run forces step 1 into the wrong
            // language until the daemon restarts. Looking up via `Bundle.preferredLocalizations`
            // matches the user's current system preference even with cruft in our domain.
            let bundleLocs = Bundle.main.localizations.filter { $0 != "Base" }
            if let pref = Bundle.preferredLocalizations(from: bundleLocs).first,
               let b = LocaleHelper.bundle(forLocale: pref) {
                localeBundle = b
            }
        }
        .task {
            // Load voices once for the wizard (used by step 3 picker AND by seedDefaults
            // so an X-close from any step picks a locale-appropriate voice). Phrase + voice
            // are seeded together: if the locale lacks either a translation OR a matching
            // voice, both fall back to English — we never mix.
            if voices.isEmpty {
                let list = await Task.detached(priority: .userInitiated) { SaySynth.listVoices() }.value
                voices = list
                seedDefaults(language: store.current.language)
            }
        }
    }

    /// Step 1 — render against `localeBundle` (seeded to system-preferred .lproj on appear)
    /// so the wizard greets the user in their actual system language even when our process
    /// has a stale `AppleLanguages` override from a previous session.
    private var languageStep: some View {
        VStack(spacing: 18) {
            Text("🚶").font(.system(size: 64))
            Text("Welcome to getup", bundle: localeBundle).font(.title.bold())
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

    /// Step 2 — render against `localeBundle` so labels appear in the just-picked language.
    private var audioStep: some View {
        VStack(spacing: 18) {
            Text("🚶").font(.system(size: 64))
            Text("Welcome to getup", bundle: localeBundle).font(.title.bold())
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

            // Bound directly to the store so the AppDelegate Combine sink flips
            // NSApp.setActivationPolicy live as the user toggles — no deferred apply needed.
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

    /// Step 3 — voice + phrase + preview. On Get started we auto-write `sound.aiff` if no
    /// sound file exists yet, so a returning user with default mode hears something at xx:50.
    private var voiceStep: some View {
        VStack(spacing: 14) {
            Text("🚶").font(.system(size: 64))
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
                    SaySynth.preview(voice: store.current.voice,
                                     phrase: store.current.customPhrase)
                } label: {
                    Label { Text("Preview", bundle: localeBundle) } icon: { Image(systemName: "play.fill") }
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
        store.current.language = pickedLanguage   // didSet writes AppleLanguages override
        if let lang = pickedLanguage, let b = LocaleHelper.bundle(forLocale: lang) {
            localeBundle = b
        } else {
            localeBundle = .main
        }
        // Re-seed defaults so the user, having just picked a language, sees a phrase + voice
        // matching that language when they reach step 3 (or, if they X-close, gets a sound.aiff
        // in the right language). Step 1 → step 2 is the only place language can change inside
        // the wizard, so the user has not yet seen / edited the voice & phrase TextField — safe
        // to overwrite.
        seedDefaults(language: pickedLanguage)
    }

    private func seedDefaults(language: String?) {
        let pair = LocaleHelper.defaultLoopDefaults(forLanguage: language, available: voices)
        store.current.customPhrase = pair.phrase
        if let v = pair.voice { store.current.voice = v }
    }
}
