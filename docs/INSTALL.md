# Installing Scene

Scene is distributed as a `.dmg` file. The DMG is **ad-hoc signed** (no Apple Developer account involved), so macOS Gatekeeper will prompt you on first launch. The steps below walk through that.

## Requirements

- **macOS 14 (Sonoma) or later**
- Apple Silicon (M1/M2/M3/M4) or Intel Mac (both are supported by the same universal binary)

## Install from DMG

1. **Download** `Scene-0.1.0.dmg` (from `dist/` if you built locally, or from wherever the release is hosted).
2. **Double-click** the DMG to mount it. A window opens showing `Scene.app` and an `Applications` shortcut.
3. **Drag `Scene.app` into `Applications`**.
4. Eject the mounted DMG.

## First launch (bypass Gatekeeper)

Because the build isn't notarized by Apple, double-clicking Scene the first time will show:

> **"Scene" cannot be opened because the developer cannot be verified.**

Do one of the following to launch it anyway — you only need to do this once.

### Option A (recommended) — right-click → Open

1. In Finder, open `/Applications`.
2. **Right-click** (or Control-click) `Scene.app` → **Open**.
3. A dialog appears with an **Open** button — click it.

macOS remembers the exception; future launches work normally.

### Option B — remove the quarantine flag via Terminal

```bash
xattr -cr /Applications/Scene.app
```

Then double-click Scene normally.

## Grant Accessibility permission

Scene needs Accessibility access to move other apps' windows.

1. Launch Scene. The Scene menu bar icon appears at the top-right (a small `⌧` rectangle-group icon).
2. Click the icon → **Grant Accessibility Access…**. The onboarding window opens.
3. Click **Open System Settings**. macOS jumps to **Privacy & Security → Accessibility**.
4. Find **Scene** in the list and toggle it **ON**.
5. Return to Scene — within 2 seconds the menu updates to show the 7 layout presets.

## Using Scene

- **Click** the menu bar icon → pick one of seven preset layouts.
- Or press **⌘⇧1** through **⌘⇧7** as global hotkeys.

Full feature list: see [`README.md`](../README.md).

## Uninstalling

1. Quit Scene from its menu (`Quit Scene`).
2. Drag `/Applications/Scene.app` to the Trash.
3. Optional: remove Scene from **System Settings → Privacy & Security → Accessibility** (click Scene, then the `−` button).

## Troubleshooting

| Symptom | Fix |
|---|---|
| "App is damaged and can't be opened" | Run `xattr -cr /Applications/Scene.app` in Terminal, then retry. |
| Menu bar icon never appears | Check that you ran the app from `/Applications`, not from the mounted DMG. |
| Hotkeys don't work | Confirm Accessibility permission is still on; macOS sometimes revokes it after an update. |
| Scene won't resize windows | Some apps (Apple System Settings, older Preferences apps) enforce a minimum size and ignore AX sizing requests. Not a Scene bug. |

## Building from source

If you prefer building yourself — no Apple Developer account needed:

```bash
git clone <repo>
cd macbook-resizer
./scripts/build-dmg.sh          # produces dist/Scene-0.1.0.dmg
```

Requires Xcode 16+ (available free from the Mac App Store).
