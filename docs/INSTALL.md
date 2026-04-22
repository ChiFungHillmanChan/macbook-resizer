# Installing Scene

## Requirements

- **macOS 14 (Sonoma) or later**
- **Apple Silicon (M1/M2/M3/M4/M5) or Intel (x86_64)**. The prebuilt DMG from v0.5.3+ is a universal binary.

Scene v0.5.0+ is **notarized by Apple** — no Gatekeeper bypass, no quarantine strip, no "cannot be verified" prompt. Double-click to install.

## Install via Homebrew (recommended)

```bash
brew install --cask chifunghillmanchan/tap/scene
```

Homebrew drops `Scene.app` into `/Applications`. Jump to [Grant Accessibility permission](#grant-accessibility-permission).

Updating later:

```bash
brew upgrade --cask scene
```

Uninstalling:

```bash
brew uninstall --cask scene
# optional full cleanup (prefs, caches):
brew uninstall --cask --zap scene
```

## Install from DMG

1. **Download** the latest `Scene-X.Y.Z.dmg` from the [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases).
2. **Double-click** the DMG to mount it.
3. **Drag `Scene.app` into `Applications`**.
4. Eject the mounted DMG.
5. Open Scene from Launchpad or `/Applications`.

No right-click, no `xattr`, no System Settings detour. Because the DMG is notarized, macOS trusts it on first launch.

## Grant Accessibility permission

Scene needs Accessibility access to move other apps' windows.

1. Launch Scene. The Scene menu bar icon appears at the top-right (a small `⌧` rectangle-group icon).
2. Click the icon → **Grant Accessibility Access…**. The onboarding window opens.
3. Click **Open System Settings**. macOS jumps to **Privacy & Security → Accessibility**.
4. Find **Scene** in the list and toggle it **ON**.
5. Return to Scene — within 2 seconds the menu updates to show all layout presets.

## Using Scene

- **Click** the menu bar icon → pick a layout or workspace.
- Or press **⌘⌃1** – **⌘⌃0** (layouts) and **⌘⌥1** – **⌘⌥4** (workspaces) as global hotkeys.

Full feature list: see [`README.md`](../README.md).

## Upgrading from v0.4.3 or earlier

v0.4.x builds were ad-hoc signed; v0.5.0+ is notarized with a Developer ID certificate. macOS ties Accessibility grants to the app's code signature (`cdhash`), and the notarized build has a different `cdhash` than the ad-hoc one. So **one-time** after upgrading:

1. Quit Scene.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Remove Scene from the list (select, press `−`).
4. Install v0.5.0+ and relaunch.
5. Grant Accessibility again on the onboarding screen.

If toggling off/on doesn't work, run this once in Terminal:

```bash
tccutil reset Accessibility com.hillman.SceneApp
```

Then relaunch and re-authorize.

**Future v0.5.x → v0.5.y updates keep your grant automatically** because the `cdhash` lineage is stable under the same Developer ID.

## Uninstalling

1. Quit Scene from its menu (`Quit Scene`).
2. Drag `/Applications/Scene.app` to the Trash.
3. Optional: remove Scene from **System Settings → Privacy & Security → Accessibility** (click Scene, then the `−` button).
4. Optional full settings wipe:
   ```bash
   rm -rf ~/Library/Application\ Support/Scene
   ```

## Troubleshooting

| Symptom | Fix |
|---|---|
| "App is damaged and can't be opened" | The DMG download was corrupted. Re-download from the Releases page and verify the SHA256 matches. |
| Menu bar icon never appears | Check that you ran the app from `/Applications`, not from the mounted DMG. |
| Hotkeys don't work | Confirm Accessibility permission is still on. |
| Post-upgrade: grant looks ON but Scene says it's off | See "Upgrading from v0.4.3 or earlier" above. This is a one-time transition. |
| Scene won't resize windows | Some apps (Apple System Settings, older Preferences apps) enforce a minimum size and ignore AX sizing requests. Not a Scene bug. |

## Building from source

If you prefer building yourself, you need an Apple Developer account for notarization. Without one, set `SKIP_NOTARY=1` to produce an ad-hoc signed DMG for local testing (you'll get the Gatekeeper prompt that v0.5.0+ avoids).

```bash
git clone https://github.com/ChiFungHillmanChan/macbook-resizer.git
cd macbook-resizer
./scripts/build-dmg.sh 0.5.0                      # full notarized build (needs Developer ID)
SKIP_NOTARY=1 ./scripts/build-dmg.sh 0.5.0-dev    # local ad-hoc build
```

Requires Xcode 16+ (available free from the Mac App Store). See [`APPLE_DEVELOPER_SETUP.zh-HK.md`](../APPLE_DEVELOPER_SETUP.zh-HK.md) for the full Developer ID + notarization walkthrough (in Cantonese).
