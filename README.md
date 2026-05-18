# AudioPin

![Build](https://github.com/leonardourci/audio-pin/actions/workflows/build.yml/badge.svg)

A free, open-source macOS menu bar app that **pins your preferred audio input and output devices** and **locks microphone gain** — so macOS stops hijacking your audio whenever you plug in a cable or pair a Bluetooth device.

## Why

macOS auto-switches the default input/output to whichever device was most recently connected, with no native way to override. Zoom, Chrome, and other apps fight your manual mic level via AGC. Existing tools solve one piece each. AudioPin unifies them: device pinning, gain lock, and per-profile auto-switching — in a single menu bar app with no telemetry, no network, no cloud.

## Features

- **Pin preferred input + output devices.** Auto-switches back when a higher-priority device connects, or to the next available device when one disconnects.
- **Device priority list.** Rank devices once; AudioPin always picks the highest-priority connected one.
- **Microphone gain lock.** Holds your mic level. Apps (Zoom, Chrome, Meet) can't AGC it away.
- **Output volume + input gain sliders.** Adjust system volumes from the menu bar with click-to-jump precision.
- **Profiles.** Named bundles of preferred devices + gain settings + icons. Switch manually or auto-activate when a specific device connects.
- **Export / import settings as portable JSON.** Move setups between Macs.
- **Launch at login.** Via `SMAppService`.
- **Event-driven, lightweight.** No polling. No telemetry. No network. Ever.

## Requirements

- macOS 14 (Sonoma) or later.
- Swift 6 / Xcode 16+ (only to build from source).
- No third-party dependencies.

## Install

Download the latest `AudioPin-X.Y.Z.zip` from [Releases](../../releases), unzip, and drag `AudioPin.app` to `/Applications`.

### First launch — Gatekeeper

AudioPin is **unsigned** (notarization needs an Apple Developer Program subscription — not in scope for v0). Without it, macOS shows either:

> *"AudioPin" is damaged and cannot be opened. You should move it to the Trash.*

or a Gatekeeper warning. Neither means the binary is actually broken — macOS just refuses unsigned downloads by default.

To run it the first time, strip the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/AudioPin.app
open /Applications/AudioPin.app
```

You only need to do this once. Subsequent launches behave normally.

Prefer not to trust prebuilt binaries? [Build from source](#build-from-source).

## Build from source

```bash
git clone https://github.com/leonardourci/audio-pin.git
cd audio-pin
open Package.swift   # opens in Xcode
# press ⌘R to build and launch
```

Or from the terminal:

```bash
swift build -c release
.build/release/AudioPin
```

Note: `swift run` skips the `.app` bundle and `Info.plist`, so the menu bar icon may not appear. Use Xcode (⌘R) for proper menu-bar testing, or build `.app` via Xcode and run the bundle.

### First-launch microphone permission

AudioPin reads input device gain, so macOS prompts for **Microphone** access on first launch. Approve it; otherwise gain-lock no-ops. To re-enable: System Settings → Privacy & Security → Microphone → toggle AudioPin on.

## Usage

Click the headphones icon in the menu bar to open the panel. From there:

- **Output / Input** — pick the active device and adjust its volume / gain.
- **Profiles** — switch active profile, or create one from the current device combo (`+`). Double-click a profile's icon to edit its details in Settings.
- **Lock mic gain** — holds the mic at the current level. Persists per profile.
- **Enforce pinning** — global on/off for device pinning.
- **Settings…** — full editor for device priority lists, profiles (preferred I/O, gain target, icon, auto-trigger device), export/import, launch-at-login.

## Architecture

Clean architecture, three layers (Infrastructure → Domain → UI). See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for details: protocol boundaries, concurrency model, self-write filter, runaway guard.

## Tests

```bash
swift test
```

20 unit tests cover the Domain engines (`DevicePinEngine`, `GainLockEngine`), `ProfileStore`, the priority-list reorder logic, and the `Profile` model. CoreAudio is mocked via protocol fakes. Tests use Apple's [swift-testing](https://github.com/swiftlang/swift-testing) framework (`import Testing`, `@Test`, `#expect`) — no XCTest dependency.

**Running tests without Xcode** (e.g. on a managed Mac with only Command Line Tools): install Apple's official Swift toolchain via [swiftly](https://www.swift.org/install/macos/swiftly/) — no Apple ID required.

```bash
brew install swiftly
swiftly init --assume-yes --quiet-shell-followup
export PATH="$HOME/.swiftly/bin:$PATH"   # add to ~/.zshrc to persist
swift test
```

## Releases

Releases are cut by merging `main` into the `release` branch. CI reads `VERSION`, extracts the matching section from [`CHANGELOG.md`](CHANGELOG.md), tags `v$VERSION`, builds `AudioPin.app`, zips it, and publishes a GitHub Release with the changelog prose **plus** auto-generated PR list + contributors below.

To cut a release:

```bash
# 1. write release notes — move [Unreleased] entries into a new versioned section in CHANGELOG.md
#    (you can @mention contributors with @username — GitHub auto-links them)

# 2. bump
echo "0.2.0" > VERSION
git add VERSION CHANGELOG.md && git commit -m "chore: release 0.2.0"
git push origin main

# 3. ship
git checkout release
git merge main
git push origin release
```

CI aborts if the tag already exists or if `CHANGELOG.md` is missing a section for the new version. Bump `VERSION` and update `CHANGELOG.md` before every release merge.

## Contributing

PRs and issues welcome. Please open an issue before significant work so we can discuss scope.

Conventions:

- Swift 6, language mode `.v6`.
- No third-party dependencies for v1.
- Don't add CoreAudio imports outside `Infrastructure/`.
- Write comments only when the *why* is non-obvious (CoreAudio quirks, self-write filter, per-channel fallback). Skip restating *what* the code does.

## License

MIT. See [`LICENSE`](LICENSE).
