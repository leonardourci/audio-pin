<div align="center">
  <h1>AudioPin</h1>
  <p>Keep your Mac on the audio devices and microphone level you choose.</p>
  <img src="https://github.com/leonardourci/audio-pin/actions/workflows/build.yml/badge.svg" alt="Build" />
</div>

<p align="center">
  <img width="650" alt="Meme: a man telling a brain &quot;No thanks, I use AI&quot;" src="https://github.com/user-attachments/assets/c97ae011-bb93-49f2-9779-160461c4d748" />
</p>

AudioPin is a free, open-source macOS menu bar app for keeping your preferred input and output devices selected and locking your microphone gain.

Plugging in a display or connecting Bluetooth headphones can change your Mac's audio devices. Apps can also change your microphone level through automatic gain control (AGC). AudioPin lets you save the setup you want and restores it when those settings change.

## Features

- **Device pinning.** Keep a profile's preferred input and output selected while they're connected.
- **Priority lists.** When a preferred device is unavailable, use the first connected device in your input or output priority list. Switch back when the preferred device returns.
- **Microphone gain lock.** Restore the profile's target input level when another app changes the device gain.
- **Volume and gain sliders.** Adjust output volume and microphone gain from the menu bar. Click the slider track to jump to a level or drag to adjust it.
- **Profiles.** Save named setups with preferred devices, a gain target, gain lock, and an icon. Switch manually or set a connected device to trigger a profile.
- **Settings export and import.** Save your configuration as JSON and move it between Macs.
- **Launch at login.** Enable it in Settings; AudioPin uses macOS's `SMAppService`.
- **Update notices.** Check GitHub for a newer release and open its download page from the menu bar.

Audio changes are handled through CoreAudio listeners. Settings stay in local `UserDefaults`, and there is no telemetry. The update checker contacts GitHub when it starts and every 24 hours; audio controls work locally.

Volume and gain controls depend on what the device exposes to CoreAudio. Gain lock restores the device's input level; it does not control audio processing inside other apps. If enforcement fires too often, AudioPin skips writes and shows **Fighting another app** in the panel.

## Requirements

- macOS 14 (Sonoma) or later.
- To build from source: Swift 6.2 or later, using Xcode with a compatible Swift toolchain or a standalone toolchain. The repository's `.swift-version` pins Swift 6.3.2.
- No third-party package dependencies.

## Install

Download the latest `AudioPin-X.Y.Z.zip` from [Releases](https://github.com/leonardourci/audio-pin/releases), unzip it, and drag `AudioPin.app` to `/Applications`.

### First launch: Gatekeeper

Release builds are ad-hoc signed, without Developer ID signing or notarization. macOS may show a Gatekeeper warning or this message:

> “AudioPin” is damaged and cannot be opened. You should move it to the Trash.

For a release downloaded from this repository, remove the quarantine attribute and open the app:

```bash
xattr -dr com.apple.quarantine /Applications/AudioPin.app
open /Applications/AudioPin.app
```

This is a first-launch workaround for that downloaded copy. You can also [build from source](#build-from-source).

### Microphone permission

The app bundle includes a microphone usage description for reading the gain level. If macOS asks for **Microphone** access, allow it. You can manage access in **System Settings → Privacy & Security → Microphone → AudioPin**.

## Usage

Click the headphones icon in the menu bar. On a fresh install, choose **Set up AudioPin…** and add devices to the input or output priority lists in Settings. The main controls appear once at least one list has a device.

- **Output / Input:** choose the active profile's preferred devices and adjust output volume or input gain.
- **Profiles:** click a profile to activate it. Use `+` to save the current device combination with a name and icon. Duplicate combinations are prevented. Double-click a profile's icon to open Settings, then select the profile to edit it.
- **Lock mic gain:** lock the current input level for the active profile. Adjusting the input slider while locked updates its target.
- **Enforce pinning:** turn device pinning on or off globally. Gain lock is a separate setting for each profile.
- **Settings…:** edit device priority lists, profile devices, gain targets, icons, and auto-trigger devices. Export or import JSON settings and enable launch at login here.
- **Update available:** choose **Download** to open the release page, or dismiss the notice for that version.

With pinning enabled, activating a profile applies its device choices. AudioPin also reapplies them when connected devices or the system's default devices change. If several profiles have connected trigger devices, the first matching profile in the saved list is selected when the device list changes.

## Build from source

Clone the repository:

```bash
git clone https://github.com/leonardourci/audio-pin.git
cd audio-pin
```

Open the package in Xcode and use ⌘R to build and run:

```bash
open Package.swift
```

Or build and run the executable from the terminal:

```bash
swift build -c release
.build/release/AudioPin
```

Running the executable directly, including with `swift run`, does not assemble an `.app` bundle or include its `Info.plist`. For menu bar testing with the bundle metadata and microphone usage description, assemble the app as the release workflow does:

```bash
mkdir -p AudioPin.app/Contents/MacOS AudioPin.app/Contents/Resources
cp .build/release/AudioPin AudioPin.app/Contents/MacOS/AudioPin
cp Sources/AudioPin/Info.plist AudioPin.app/Contents/Info.plist
chmod +x AudioPin.app/Contents/MacOS/AudioPin
codesign --force --deep --sign - AudioPin.app
open AudioPin.app
```

## Architecture

The code separates CoreAudio access in `Infrastructure/`, device pinning and gain lock in `Domain/`, and SwiftUI views and view models in `UI/`. `AppState` connects them. Engines use protocols so tests can supply fake hardware.

See [the architecture notes](docs/ARCHITECTURE.md) for more on the protocol boundaries, concurrency, self-write filter, and runaway guard. The source is the reference for current behavior.

## Tests

```bash
swift test
```

The 20 unit tests cover `DevicePinEngine`, `GainLockEngine`, `ProfileStore`, priority-list reordering, and the `Profile` model. CoreAudio is mocked through protocol fakes. Tests use Apple's [Swift Testing](https://github.com/swiftlang/swift-testing) framework (`import Testing`, `@Test`, `#expect`), with no XCTest dependency.

For a Mac with Command Line Tools but no Xcode, install Apple's Swift toolchain with [swiftly](https://www.swift.org/install/macos/swiftly/). No Apple ID is required:

```bash
brew install swiftly
swiftly init --assume-yes --quiet-shell-followup
export PATH="$HOME/.swiftly/bin:$PATH"   # add to ~/.zshrc to persist
swift test
```

## Releases

To publish a release, merge `main` into the `release` branch. CI reads `VERSION`, extracts the matching section from [CHANGELOG.md](CHANGELOG.md), tags `v$VERSION`, builds and ad-hoc signs `AudioPin.app`, and publishes the zip. Release notes include the changelog section plus GitHub's generated PR and contributor list.

1. Move the relevant `[Unreleased]` entries into a versioned section in `CHANGELOG.md`. You can mention contributors with `@username`.
2. Update `VERSION` and commit both files on `main`:

   ```bash
   echo "0.2.0" > VERSION
   git add VERSION CHANGELOG.md
   git commit -m "chore: release 0.2.0"
   git push origin main
   ```

3. Merge into `release` and push:

   ```bash
   git checkout release
   git merge main
   git push origin release
   ```

CI stops if the tag already exists or the new version has no nonempty changelog section. Update both files before each release merge.

## Contributing

Issues and PRs are welcome. Open an issue before significant work so we can agree on scope.

- Use Swift 6 language mode (`.v6`).
- Keep the app free of third-party package dependencies for v1.
- Keep CoreAudio imports inside `Infrastructure/`.
- Write comments when the reason is non-obvious, such as a CoreAudio quirk, self-write filter, or per-channel fallback. Skip comments that repeat the code.

## License

[MIT](LICENSE).
