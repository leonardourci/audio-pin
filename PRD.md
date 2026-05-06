# AudioPin — PRD

**Status:** Draft v0.1
**Owner:** Leonardo (acendeo)
**Date:** 2026-05-05
**License:** MIT

---

## 1. One-liner

Free, open-source macOS menu bar app that pins your preferred audio input and output devices, locks microphone gain, and switches profiles automatically — so macOS stops hijacking your audio every time you plug in a cable or pair a Bluetooth device.

## 2. Problem

macOS auto-switches the default audio input/output to whichever device was most recently connected, with no native way to override that behavior. Apps like Zoom, Google Meet, and Chrome also auto-adjust microphone gain via AGC, fighting the user's manual settings. Existing OSS solutions each solve one piece (device pin OR gain lock OR profiles) but none unify them in a single, simple menu bar app.

## 3. Target users

- Engineers, streamers, podcasters, remote workers on macOS Tahoe (16+).
- Users with multiple audio devices: USB mic + AirPods/headphones + external speakers.
- People tired of paying for SoundSource ($39) or maintaining shell scripts.

## 4. Goals

- Set preferred input/output device once → it stays, even across disconnect/reconnect of any device.
- Lock microphone gain to a fixed level → apps cannot AGC it away.
- Define profiles (e.g., "Work", "Gaming", "Recording") and auto-activate them based on connected devices.
- Stay out of the user's way: menu bar only, zero windows except a simple settings sheet.

## 4a. Non-functional requirements

Lightweight is a feature. Hard rules:

- Event-driven only. No polling.
- Self-write filter on **default-device pin** path: ignore listener events within 50 ms of own `AudioObjectSetPropertyData` for `kAudioHardwarePropertyDefaultInput/OutputDevice`. Spike confirmed default-device listener echoes own writes. Without filter → feedback loop.
- Gain-lock path does NOT need self-write filter. Spike confirmed `kAudioDevicePropertyVolumeScalar` listener does not echo own writes. Listener only fires on external changes (Settings UI, other apps).
- Volume property lives on per-channel elements (1, 2), not Main, on USB mics. Read/write must iterate channels and apply consistently.
- Runaway guard: if any reset path fires > 10×/sec for > 1 s, bail, log, surface "fighting another app" hint in menu.
- No network. No telemetry. Ever.

## 5. Non-goals

Explicitly **NOT** part of this app, ever or until further notice:

- Per-app audio routing or per-app volume (FineTune / SoundSource territory) — *deferred to v2 maybe, not MVP*.
- 10-band EQ or audio effects.
- Bluetooth pairing / connection management (ToothFairy territory).
- iOS / iPadOS support.
- Recording, streaming, or system audio capture (Background Music / Audio Hijack territory).
- Cross-platform (Windows, Linux).
- Cloud sync of settings / accounts / telemetry.
- Auto-updater in MVP (manual download from GitHub Releases).

## 6. MVP scope (v1.0)

| # | Feature | Description |
|---|---------|-------------|
| 1 | **Output device priority list** | User ranks output devices. Highest-priority connected device becomes default. |
| 2 | **Input device priority list** | Same, for input. |
| 3 | **Auto-restore on connect** | Plug in a higher-priority device → switches automatically. Disconnect → falls back to next available. Reconnect → switches back. |
| 4 | **Microphone gain lock** | User sets target input volume (0–100%). App resets it whenever an app or the system tries to change it. Toggle on/off per profile. |
| 5 | **Pause toggle** | Menu bar checkbox: "Enforce pinning" on/off. When off, user can switch devices manually with no interference. |
| 6 | **Profiles** | Named bundles of (preferred input, preferred output, gain target, gain lock on/off). User can switch manually or auto-activate when a specific device connects. Defaults: "Default". |
| 7 | **Launch at login** | Checkbox in settings. Uses `SMAppService`. |
| 8 | **Settings sheet** | Single SwiftUI window: device priority lists, profiles, launch-at-login toggle, gain target slider. No multi-page wizard. |
| 9 | **Menu bar UI** | Icon + dropdown showing: current input + output device (with name), active profile, pause toggle, "Open Settings", "Quit". |
| 10 | **Export / Import settings** | One-click export of all profiles + device priority lists + general settings to a single portable JSON file. Import from same file restores full state. Used for backup, migrating to a new Mac, or sharing setups. Plain-text JSON, human-readable, diff-friendly. |

## 7. Out of MVP (v2+)

| # | Feature | Why deferred |
|---|---------|--------------|
| A | **Custom global shortcuts** | Hotkeys to toggle pause, cycle profile, force-switch device. KeyboardShortcuts package; not blocking MVP. |
| B | **Per-app rules** | "Spotify on speakers, Zoom on AirPods." Requires hooking into per-app audio (CoreAudio HAL plugin or IOKit). Complex; defer. |
| C | **Aggregate Device wizard** | Auto-create a no-volume aggregate device to nuke AGC system-wide. Useful but niche. |
| D | **Auto-updater (Sparkle)** | Manual download fine for early adopters. Adds notarization friction. |
| E | **Homebrew Cask** | Submit after first stable release tag. |
| F | **Per-app volume control** | Big scope creep; FineTune already exists. Only do if community asks loudly. |

## 8. Tech stack

- **Language:** Swift 6
- **UI:** SwiftUI (`MenuBarExtra` API), Settings via `Settings` scene
- **Audio APIs:** CoreAudio (`AudioObjectAddPropertyListener` for device-change events, `AudioObjectSetPropertyData` for switching)
- **Min macOS:** 16.0 (Tahoe)
- **Persistence:** `UserDefaults` for live settings. Canonical export format: single JSON file (`~/.audiopin/profiles.json`) covering profiles, device priority lists, general settings. Versioned schema (`schemaVersion: 1`) for forward-compat. Import validates schema, falls back gracefully on unknown fields.
- **Login item:** `SMAppService.mainApp.register()`
- **No deps for MVP** beyond stdlib + Apple frameworks. Adds (when needed): `KeyboardShortcuts` (Sindre Sorhus, MIT) for v2 hotkeys.

## 9. Architecture

- **Event-driven**, not polling. Register CoreAudio listeners for:
  - `kAudioHardwarePropertyDevices` (device list change)
  - `kAudioHardwarePropertyDefaultInputDevice` / `DefaultOutputDevice` (someone changed default)
  - `kAudioDevicePropertyVolumeScalar` (someone changed input gain)
- On any event → re-evaluate active profile against connected devices → switch if needed → reset gain if locked.
- Pause flag short-circuits the enforcement step.

## 10. Device identity (UID + name)

Each device has a stable `kAudioDevicePropertyDeviceUID` (e.g., `BuiltInMicrophoneDevice`, `AirPods-Pro-12345`). UIDs survive renames, App-store apps already use them.

- **Storage:** `{ uid: String, lastKnownName: String }` per priority entry.
- **Match logic:** look up by UID first. If UID not present in current device list, try name match as fallback (handles weird cases like firmware reset). On every successful match, refresh `lastKnownName`.
- **UI:** display `lastKnownName`. Keep UID hidden.

## 11. UX outline

**Menu bar dropdown** (single click on icon):

```
🎧 AudioPin
─────────────────
Output: AirPods Pro
Input:  Shure MV7
Profile: Work ✓
─────────────────
☑ Enforce pinning
Profiles  ▶  • Default
              • Work
              • Gaming
─────────────────
Settings…
Quit AudioPin
```

**Settings sheet** (single window, tabs or sections):

- **Devices**: two lists (input, output), drag to reorder, checkbox "in priority list".
- **Profiles**: list of profiles, edit each (preferred I/O, gain target, gain lock toggle, auto-trigger device).
- **General**: launch at login, app version, link to GitHub, **Export Settings…** / **Import Settings…** buttons (NSSavePanel / NSOpenPanel, default path `~/.audiopin/profiles.json`).

## 12. Edge cases & decisions

| Case | Behavior |
|------|----------|
| Highest-priority device disconnects | Fall to next available in list. |
| All listed devices disconnected | Don't override macOS default; let system fallback win. |
| User manually picks a different device via Control Center | If "Enforce pinning" on → app overrides within 1 event tick. If off → respect user. |
| Two profiles both auto-trigger on same device | First profile in profile list wins. User can reorder. |
| App quits | Devices stay where they are (no reset). User remains in last state. |
| Mic gain lock fights an app mid-call | App sets, listener fires, we reset. Rapid back-and-forth possible if app is aggressive (Chrome AGC). Mitigation note: recommend Aggregate Device trick in README. |
| First launch | No profiles configured → menu bar shows "Set up AudioPin" → opens settings. |

## 13. Distribution

- **Repo:** public on GitHub (acendeo or org TBD).
- **Releases:** manual `.dmg` builds attached to GitHub Releases.
- **Signing:** unsigned for MVP (user must right-click → Open first time, Gatekeeper warns). Notarization deferred — needs Apple Developer Program ($99/yr).
- **Homebrew Cask:** v2.
- **Updates:** manual; users watch GitHub repo. README documents how to check.

## 14. Success metrics (informal)

- 50+ GitHub stars within 3 months of public launch.
- 5+ external contributors (issues / PRs).
- "It just works" feedback in issues — zero "did not switch device" bugs in steady state.

## 15. Open questions

1. App icon: design needed (placeholder for v0). Anyone in the network do icon design?
2. Support older macOS (Sequoia 15)? Current decision: **no, Tahoe 16+ only**, keeps SwiftUI APIs modern (`MenuBarExtra`, `SMAppService`). Revisit if community asks.
3. Localization: ship `en` only for MVP. Accept community PRs for `pt-BR`, others.

## 16. Phases / rough plan

- **Phase 0 — Repo & boilerplate:** init Xcode project, MIT LICENSE, README skeleton, GitHub Actions for build.
- **Phase 1 — Core engine:** CoreAudio listeners, device list model, switch logic, gain lock.
- **Phase 2 — Menu bar UI:** `MenuBarExtra` with current device display + pause toggle.
- **Phase 3 — Settings sheet:** device priority lists, basic profile.
- **Phase 4 — Profiles:** multi-profile support, auto-trigger by device.
- **Phase 5 — Polish:** launch at login, app icon, README, first GitHub Release.
- **Phase 6 — v2 backlog:** shortcuts, Homebrew Cask, Sparkle, per-app rules.

---

**Files in repo:**

- `PRD.md` — this doc.
- `RELEASE.md` — how to cut a release.
- `README.md` — user-facing intro (TBD).
- `LICENSE` — MIT.
- `AudioPin.xcodeproj/` — Xcode project (TBD).
