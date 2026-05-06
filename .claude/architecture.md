# AudioPin — Code Architecture

## Stack
Swift 6, SwiftUI, CoreAudio. No third-party deps until v2.

## Architecture (Clean + SOLID)

```
Infrastructure  →  Domain  →  UI
```

- **Infrastructure**: `AudioHardwareService` — only file that imports CoreAudio.
- **Domain**: `DevicePinEngine`, `GainLockEngine`, `ProfileStore` — zero CoreAudio imports, depend on protocols only.
- **UI**: `MenuBarViewModel`, `SettingsViewModel` — observe `AppState`, no domain logic.

## Key Protocols (Interface Segregation)

```swift
protocol DeviceListProvider { func listDevices() -> [AudioDevice] }
protocol DefaultDeviceSetter { func setDefault(input:) throws; func setDefault(output:) throws }
protocol GainController { func gain(for:) -> Float?; func setGain(_:for:) throws }
protocol PropertyListener { func addListener(...) }
```

`AudioHardwareService` implements all four. Engines receive them via constructor injection.

## Concurrency

- All CoreAudio callbacks → route through `listenerQueue: DispatchQueue`.
- `AppState` is a Swift actor. No raw shared mutable state.
- `@MainActor` only on ViewModels.

## Self-Write Filter

`DevicePinEngine` tracks `lastWriteTime: ContinuousClock.Instant`. Ignores incoming default-device events within 50 ms of own write. Gain-lock path skips this (CoreAudio does not echo gain writes).

## Runaway Guard

Any enforcement path firing >10×/s for >1 s → stop, log, set `AppState.enforcementBlocked = true` → surface hint in menu.

## No Polling

Event-driven only. No `Timer`, no `Task { while true { sleep } }`.

## Comments

Write none unless WHY is non-obvious (CoreAudio quirk, self-write filter, per-channel element fallback).

## File Naming

`<Domain>/<Type>.swift` — e.g., `Domain/DevicePinEngine.swift`, `Infrastructure/AudioHardwareService.swift`, `UI/MenuBarViewModel.swift`.
