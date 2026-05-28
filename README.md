# Getup

Stand up every hour. Stretch. Sit back down. Repeat.

A macOS menu-bar app that pops a full-screen reminder once an hour and gets out of the way.

> **Status:** v0.1.0 released. Unsigned — right-click → Open to bypass Gatekeeper. Signed binaries shipping once Apple paperwork lands.

## Why

You sit too much. A smart wearable's stand reminder helps if you wear one. Calendar nudges get muted. Notifications get trained out. Getup is impossible to ignore for half a second and trivial to dismiss — that's the whole point.

## Features

- Full-screen hourly reminder, on every connected display
- Optional spoken prompt in any installed system voice with any phrase you write
- 10 bundled languages (English, Spanish, French, German, Italian, Brazilian Portuguese, Russian, Japanese, Simplified Chinese, Greek)
- Three audio modes: headphones only, always, silent
- First-run wizard sets everything up in three screens
- Runs as a login item — set it and forget it
- Invisible to screen recorders and meeting apps
- No network. No telemetry. No analytics. No third-party SDKs.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon or Intel
- Swift 6.2 or later — Command Line Tools or Xcode (Xcode itself isn't required to install or run)

## Install

```bash
git clone https://github.com/Hedgehogovich/getup.git
cd getup
./build.sh && ./install.sh
```

Look for the walking-figure icon in your menu bar.

A signed `.dmg` is on the roadmap; for now, source-build is the only path.

## Usage

The first launch walks you through three screens: language, audio mode + run-at-startup, voice + phrase + preview. After that, Getup lives in your menu bar and fires once an hour at the configured minute.

When the reminder appears: click anywhere or press <kbd>Esc</kbd> to dismiss.

Menu bar icon gives you:

- **Stretch now** — fire the reminder immediately (good for testing)
- **Settings…** — open the configuration window (also <kbd>⌘,</kbd>)
- **Audio mode** — quick-pick submenu mirroring the Settings option
- **Quit Getup** — exits cleanly; won't auto-restart until next login

## Configuration

Open **Settings…** from the menu bar (or <kbd>⌘,</kbd>).

| Tab | Controls |
|-----|----------|
| **General** | Fire minute (`xx:00` / `xx:15` / `xx:30` / `xx:45` / `xx:50`), snooze duration (5–30 min), language, run-at-startup, show-in-Dock |
| **Audio** | Mode, volume, voice + phrase OR custom audio file, Preview / Stop |
| **About** | Version, **Open support folder**, **Copy logs** (last 500 lines to clipboard) |

Settings persist automatically — there's no save button. Editing the voice or phrase regenerates the spoken loop after about a second of inactivity.

### Audio modes

| Mode | When it plays |
|------|---------------|
| **Headphones only** *(default)* | When the active output looks like personal listening hardware (Bluetooth, USB, wired headphone jack) |
| **Always** | Through whatever output is active |
| **Silent** | Never — visual reminder only |

"Headphones only" is the safe default for shared-room contexts: speakers, HDMI, DisplayPort, and AirPlay are treated as not-personal and produce no sound.

### Custom audio file

Two routes:

1. **In-app picker** — Settings → Audio → **Use custom audio file…**. Standard macOS Open dialog filtered to audio types. The Audio tab swaps the voice/phrase controls for a status line + Preview / **Use generated audio instead** button.
2. **Manual drop** — same support folder, same naming:

```
~/Library/Application Support/getup/sound.{aiff,mp3,m4a,wav}
```

The loader picks the first match in that order. The auto-generated file is `sound.aiff`, so a manually placed `.mp3`, `.m4a`, or `.wav` always wins. The picker route copies your file into the support folder under the right name and wipes any stale `sound.*` so the loader can't get confused.

### Languages

Pick a language in Settings → General → Language, or stick with "System default". Changing it relaunches the app so the new locale takes effect everywhere — menu bar, Settings, overlay, wizard.

The spoken phrase matches your language when a translation and a compatible system voice both exist. If either is missing, the loop falls back to English for both phrase and voice — so the audio and on-screen text never disagree.

## Privacy

Getup runs entirely on your machine. It opens no network connections, sends no telemetry, has no analytics, and bundles no third-party SDKs. The only external process it ever spawns is `/usr/bin/say` for offline voice synthesis. Logs are written to `~/Library/Application Support/getup/` and never leave your computer.

## Uninstall

```bash
./uninstall.sh           # remove app, LaunchAgent, legacy binary; keep settings
./uninstall.sh --purge   # also wipe settings, sound files, and logs
```

## Known limits

**Screen sharing with system audio.** The reminder window is invisible to standard screen capture (Zoom, Teams, QuickTime, ScreenCaptureKit-based tools). The audio is not — Teams in particular has an "Include system audio" toggle that taps the system audio mix before any device routing happens. If you've explicitly enabled that and you're on headphones with Getup audio playing, your call participants will hear the loop. Quit Getup or mute before sharing in that situation.

## Development

```bash
./build.sh              # builds ./getup.app, redeploys to ~/Applications/, restarts the daemon
REDEPLOY=0 ./build.sh   # build only — useful for CI / packaging

tail -30 ~/Library/Application\ Support/getup/getup.err
```

Source is grouped by concern under [`Sources/getup/`](Sources/getup/) — `Audio`, `Settings`, `System`, `Overlay`, `Scheduling`, `Locale`, `UI`. Standard SwiftPM executable target; no Xcode project required.

### Tests

```bash
swift test
```

Swift Testing suite under [`Tests/getupTests/`](Tests/getupTests/). Covers settings serialization, store migration, scheduler math, the `say` voice-list parser, locale-to-voice mapping, the audio-loop debouncer, and a localization-completeness check that scans every `.lproj/Localizable.strings`.

Heads-up: a CLT-only Mac can't run `swift test` — Apple ships the `xctest` runner with Xcode only. The build step succeeds and then exits silently. The suite runs on CI (macOS GitHub Actions runners include Xcode).

### Contributing translations

Each language is a `Resources/<code>.lproj/Localizable.strings` file:

1. Copy `Resources/en.lproj/Localizable.strings` as the starting point
2. Translate the values; leave keys untouched
3. `defaultPhrase` is the spoken hourly reminder — keep it short and complete
4. Rebuild — `build.sh` auto-discovers new `.lproj` directories

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for personal, hobby, educational, and other noncommercial use. Source is open, modifications and forks are welcome for noncommercial purposes. Selling Getup or a modified version, hosting it as a paid service, or bundling it into a commercial product requires a separate commercial license — open an issue or reach out.

The name **Getup** and the app icon are trademarks of Yuri Chachilo. Forks must be renamed and re-iconed before redistribution.

## Roadmap

- [x] SwiftPM target + unit tests
- [x] App icon
- [x] GitHub Actions CI
- [x] License (PolyForm Noncommercial 1.0.0)
- [x] Custom audio file picker in Settings
- [x] First tagged GitHub release (v0.1.0)
- [ ] Apple Developer Program (codesign + notarize)
- [ ] Sparkle auto-update
- [ ] Homebrew Cask
- [ ] Sandboxed App Store target with `SMAppService` for the login item
- [ ] Distribution via Gumroad
