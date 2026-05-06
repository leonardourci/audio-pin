# AudioPin — Local Install & Dev

How to build, run, and iterate on AudioPin on your own machine. For shipping releases, see [RELEASE.md](RELEASE.md).

---

## Prerequisites

- macOS 15 (Sequoia) or newer.
- Xcode 16+ with Command Line Tools.
  ```bash
  xcode-select --install
  xcodebuild -version   # should print Xcode 16.x
  ```
- Swift 6 toolchain (bundled with Xcode 16).
  ```bash
  swift --version       # should print swift-driver 6.x
  ```

No third-party deps — pure SwiftPM + system frameworks (SwiftUI, CoreAudio).

---

## Clone

```bash
git clone https://github.com/<org>/audio-pin.git
cd audio-pin
```

---

## Option A — Run from Xcode (recommended for daily dev)

```bash
open Package.swift
```

Xcode opens the SwiftPM package as a project.

1. Top-left scheme selector → **AudioPin**.
2. Run target → **My Mac**.
3. `⌘R` to build and launch.
4. Headphones icon appears in the menu bar.
5. `⌘.` (or stop button) to quit.

This is the only path that gives you SwiftUI Previews, breakpoints, and a real `.app` bundle.

### First launch — microphone permission

AudioPin reads input device gain, so macOS will prompt for **Microphone** access. Approve it, otherwise gain-lock features no-op.

If you accidentally deny: System Settings → Privacy & Security → Microphone → toggle AudioPin on.

---

## Option B — Run from terminal

Fast iteration on non-UI code. Skips the `.app` bundle, so menu-bar UI still works but Settings window may behave oddly.

```bash
swift run AudioPin                  # debug build + run
swift build                         # debug build only
swift build -c release              # release binary
.build/release/AudioPin             # run release binary
```

Build artifacts land in `.build/` (gitignored).

---

## Testing

No test target wired yet (see PRD §8 for planned coverage). When tests land:

```bash
swift test                          # all tests
swift test --filter DevicePinEngine # one suite
```

For now, manual smoke test:

1. Launch app.
2. Click headphones icon → confirm current input/output devices listed.
3. Plug/unplug a USB or Bluetooth audio device → confirm pin behavior.
4. Check Console.app for `AudioPin` log lines.

---

## Hot reload

Swift is compiled, so there is no true `npm run dev`. Closest options, ranked by DX:

### 1. Xcode Previews (best for UI work)

Open any SwiftUI view file (`Sources/AudioPin/UI/*.swift`), `⌥⌘↩` to open the canvas. Edits re-render live without a full app rebuild.

Add a preview to a view:

```swift
#Preview {
    MenuBarView(appState: AppState())
}
```

Limitations: no real CoreAudio, no real `AppState` actor — pass mocks.

### 2. InjectionIII (full-app hot swap)

Third-party tool that swaps Swift methods at runtime without a rebuild. Dev-only — never link into release builds.

```bash
brew install --cask inject
```

Then in Xcode, add the InjectionIII bundle load to your scheme's run-time env (see [github.com/johnno1962/InjectionIII](https://github.com/johnno1962/InjectionIII) for current setup). Save a `.swift` file → method body re-injects in the running app.

Caveats: actor-isolated code and SwiftUI `@State` initialisers don't always swap cleanly. Restart the app if behavior diverges.

### 3. Watch-rebuild loop (CLI only)

If you live in a terminal:

```bash
brew install fswatch
fswatch -o Sources | xargs -n1 -I{} swift run AudioPin
```

Full process restart on every save. Crude but works.

---

## Common issues

**`swift run` builds but app does not appear**
You're looking for a Dock icon. There isn't one — AudioPin is `LSUIElement` (menu-bar only). Look for the headphones icon in the top-right menu bar.

**Build error: `MenuBarExtra` requires macOS 13+**
Wrong toolchain. Confirm `swift --version` shows 6.x and `Package.swift` `platforms` is `.macOS(.v15)`.

**CoreAudio property listener fires repeatedly**
You hit the runaway guard (see `.claude/CLAUDE.md` → Runaway Guard). Check `AppState.enforcementBlocked`. Usually a self-write echo — verify `DevicePinEngine.lastWriteTime` filter window.

**Permission denied changing default device**
Some virtual devices (Aggregate, Multi-Output) refuse `kAudioHardwarePropertyDefaultInputDevice` writes. Expected. Pin a physical device instead.

---

## Uninstall

Local dev build:

```bash
rm -rf .build
```

Installed `.app`:

```bash
rm -rf /Applications/AudioPin.app
defaults delete com.audiopin.AudioPin 2>/dev/null
rm -rf ~/.audiopin
```
