# AudioPin

![Build](https://github.com/acendeo/audio-pin/actions/workflows/build.yml/badge.svg)

A free, open-source macOS menu bar app that pins your preferred audio input/output devices and locks microphone gain — so macOS stops hijacking your audio when you plug in a cable or pair a Bluetooth device.

<!-- screenshot -->

## Features

- Pin preferred input and output devices — auto-switches back when a device disconnects or reconnects
- Device priority list — rank devices so AudioPin always picks the highest-priority one that is connected
- Microphone gain lock — prevents Zoom, Chrome, and other apps from changing your input level via AGC
- Profiles — named bundles of device and gain settings that auto-activate based on connected devices
- Export and import settings as JSON
- Launch at login

## Requirements

- macOS 15 Sequoia or later (Tahoe when released)
- No external dependencies

## Install

Download the latest `.dmg` from [Releases](../../releases), open it, and drag AudioPin to your Applications folder.

### Build from source

```bash
git clone https://github.com/acendeo/audio-pin.git
cd audio-pin
open Package.swift   # opens Xcode
# press Cmd+R to run
```

## First Launch

macOS will show a Gatekeeper warning because AudioPin is unsigned. Right-click the app in Finder and choose Open to bypass it. You only need to do this once.

## Usage

Click the AudioPin icon in the menu bar to open the panel. Select your preferred input and output devices from the lists and drag them to set priority order. Enable the gain lock to hold your microphone level at a fixed value. Create profiles to save different configurations and switch between them as needed.

## Contributing

Pull requests and issues are welcome. Please open an issue before starting significant work so we can discuss the approach.

## License

MIT
