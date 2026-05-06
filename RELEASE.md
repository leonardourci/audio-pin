# AudioPin — Release Process

Manual GitHub Releases for MVP. No notarization yet. No auto-updater.

---

## Prereqs (one-time)

- Xcode 16+ installed.
- Logged into GitHub from terminal: `gh auth login`.
- `create-dmg` for nicer DMGs (optional): `brew install create-dmg`.

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`. Pre-1.0 is `0.x.y`.

- `0.x.0` — feature drops.
- `0.x.y` — bugfixes only.
- `1.0.0` — first stable, when MVP scope (PRD §6) is complete.

## Cut a release

### 1. Bump version

In Xcode: target → General → Version + Build. Or edit `Info.plist`:

- `CFBundleShortVersionString` = `0.2.0`
- `CFBundleVersion` = monotonic build number

Commit:

```bash
git add .
git commit -m "chore: bump version to 0.2.0"
git tag v0.2.0
git push origin main --tags
```

### 2. Build a Release archive

```bash
xcodebuild \
  -project AudioPin.xcodeproj \
  -scheme AudioPin \
  -configuration Release \
  -archivePath build/AudioPin.xcarchive \
  archive
```

Export the .app:

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/AudioPin.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` (one-time, commit to repo):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>mac-application</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
```

Output: `build/export/AudioPin.app`.

### 3. Package as DMG

Simple route (zip):

```bash
cd build/export
zip -r AudioPin-0.2.0.zip AudioPin.app
```

Nicer route (DMG with drag-to-Applications):

```bash
create-dmg \
  --volname "AudioPin 0.2.0" \
  --window-size 500 300 \
  --icon "AudioPin.app" 125 150 \
  --app-drop-link 375 150 \
  build/AudioPin-0.2.0.dmg \
  build/export/AudioPin.app
```

### 4. Generate checksums

```bash
shasum -a 256 build/AudioPin-0.2.0.dmg > build/AudioPin-0.2.0.dmg.sha256
```

### 5. Create GitHub Release

```bash
gh release create v0.2.0 \
  build/AudioPin-0.2.0.dmg \
  build/AudioPin-0.2.0.dmg.sha256 \
  --title "AudioPin 0.2.0" \
  --notes-file CHANGELOG.md
```

Or via web: github.com/<org>/audiopin/releases → Draft new release → upload artifacts.

## Release notes template

Append to `CHANGELOG.md` (Keep a Changelog format):

```markdown
## [0.2.0] — 2026-05-15

### Added
- Output device priority list

### Fixed
- Reconnecting AirPods no longer triggers double-switch

### Changed
- Default gain target now 75% (was 85%)
```

## Unsigned build caveat

Because builds are unsigned, first-time users will see Gatekeeper:

> "AudioPin" cannot be opened because the developer cannot be verified.

README must document the workaround:

1. Right-click the `.app` → **Open** → **Open** in confirm dialog.
2. Or: `xattr -d com.apple.quarantine /Applications/AudioPin.app` after copying.

Once notarization happens (post-MVP), drop this section.

## Future: notarized + Sparkle auto-update

When ready:

1. Join Apple Developer Program ($99/yr).
2. Add `Developer ID Application` cert to Xcode.
3. `xcrun notarytool submit ... --wait` on the archived .app or DMG.
4. Staple: `xcrun stapler staple build/AudioPin-0.2.0.dmg`.
5. Drop "right-click → Open" instructions from README.
6. Add Sparkle framework, generate `appcast.xml`, host in repo (GitHub Pages or raw).

## Future: Homebrew Cask

After tag `v1.0.0` and a few stable releases:

```bash
brew tap homebrew/cask
# fork homebrew-cask, add Casks/audiopin.rb pointing to GitHub Release DMG, PR upstream
```

Cask template:

```ruby
cask "audiopin" do
  version "1.0.0"
  sha256 "<sha from build/AudioPin-1.0.0.dmg.sha256>"

  url "https://github.com/<org>/audiopin/releases/download/v#{version}/AudioPin-#{version}.dmg"
  name "AudioPin"
  desc "Pin macOS audio devices and lock microphone gain"
  homepage "https://github.com/<org>/audiopin"

  app "AudioPin.app"

  zap trash: [
    "~/Library/Preferences/com.audiopin.AudioPin.plist",
    "~/.audiopin",
  ]
end
```
