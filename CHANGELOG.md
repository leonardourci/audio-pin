# Changelog

All notable changes to AudioPin are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Ad-hoc codesign the `.app` in CI before zipping. Reduces the "AudioPin is damaged and cannot be opened" Gatekeeper message on first launch. Notarization still required for friction-free install.

### Docs
- README documents the `xattr -dr com.apple.quarantine` unblock for users on unsigned downloads.

## [0.1.0] - 2026-05-19

### Added
- Initial release.
- Pin preferred input and output audio devices with a priority list. Auto-restore on connect/disconnect.
- Microphone gain lock per profile. Holds the mic level against AGC from apps like Zoom, Chrome, Meet.
- Menu bar popover: device pickers, live volume + gain sliders with click-to-jump, profile rows with icons, inline create-profile form, help popovers for Lock mic gain and Enforce pinning.
- Settings window: current devices, device priority lists with drag-and-drop reorder plus up/down arrows, profile editor (icon, preferred I/O, gain target, auto-trigger device), JSON export/import, launch at login.
- Profiles with per-profile SF Symbol icons (8-icon curated set, rotates by default).
- Event-driven CoreAudio listeners. Self-write filter on device-pin path. Runaway guard on enforcement paths.
- swift-testing unit suite (20 tests) covering Domain engines, ProfileStore, priority-list reorder, and the Profile model.
