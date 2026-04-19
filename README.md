# Scene

A macOS menu bar app for instant window layouts. Click one of seven presets and every visible window snaps into place.

**Requires macOS 14 (Sonoma) or later.**

> 繁體中文版本： [README.zh-HK.md](README.zh-HK.md)

## Features (V0.2)

- **7 built-in layout presets** — Full, Halves, Thirds, Quads, Main + Side (70/30), LeftSplit + Right, Left + RightSplit
- **Build your own layouts** — 11 grid templates (columns / rows / 2×2 / 3×2 / 4 L-shape variants) with proportion sliders
- **Per-layout custom hotkeys** with conflict detection (block-save: one chord per layout)
- **Smooth window animation** with adjustable duration (100–500 ms) and easing (Linear / Ease Out / Spring)
- **Settings window** — Layouts / Hotkeys / Animation / About (open via menu bar icon → Settings… or ⌘,)
- **One click, all windows** — frontmost window goes to slot 1, the rest follow z-order
- **Overflow handling** — windows beyond slot count get minimized
- **Electron-aware** — retries ±5 px corrections for Cursor, VS Code, Slack, etc.
- **Multi-display** — only rearranges windows on the screen under the mouse
- **Dock/menu-bar-aware** — uses `visibleFrame` so windows never slide under the menu bar or Dock
- **Animation perf safety** — falls back to instant placement when 7+ windows are visible
- **Zero external dependencies** — pure Foundation, AppKit, SwiftUI, Carbon

## Layouts

| ID | Name | Slots |
|---|---|---|
| 1 | Full | 1 (100%) |
| 2 | Halves | 2 (50/50) |
| 3 | Thirds | 3 equal columns |
| 4 | Quads | 2×2 grid |
| 5 | Main + Side | 70% / 30% |
| 6 | LeftSplit + Right | left column split top/bottom, right column full |
| 7 | Left + RightSplit | left column full, right column split top/bottom |

## Install

End users: download the DMG from the releases page (or run `scripts/build-dmg.sh` locally), drag `Scene.app` into `/Applications`, and follow [`docs/INSTALL.md`](docs/INSTALL.md) for the one-time Gatekeeper + Accessibility-permission steps.

## Build from source

### Prerequisites

- macOS 14+
- Xcode 16+ (for building the app — free from the Mac App Store)
- Swift 5.9+ (bundled with Xcode)

### Build via Xcode

```bash
git clone <repo-url>
cd macbook-resizer
open SceneApp/SceneApp.xcodeproj
```

In Xcode, select the `SceneApp` scheme and press ⌘R. The app runs as a menu bar extra (no Dock icon).

### Build a distributable DMG

```bash
./scripts/build-dmg.sh          # produces dist/Scene-0.1.0.dmg
```

This builds a universal binary (arm64 + x86_64), ad-hoc signs it, and packages it into a DMG with an `Applications` drop shortcut. No Apple Developer account required.

### Run the core library tests

The layout logic lives in `SceneCore`, a Swift package that works without Xcode:

```bash
swift test
```

92 unit tests cover layout math, window-to-slot mapping, animation state machine, JSON persistence, hotkey conflicts, and edge cases.

## Usage

1. On first launch, Scene asks for **Accessibility permission**. Grant it in System Settings → Privacy & Security → Accessibility.
2. Click the Scene icon in the menu bar (`rectangle.3.group`) to see the 7 presets.
3. Click any preset, or press ⌘⇧1 – ⌘⇧7.
4. Quit via the menu's **Quit Scene** item.

### Hotkey reference

| Shortcut | Layout |
|---|---|
| ⌘⇧1 | Full |
| ⌘⇧2 | Halves |
| ⌘⇧3 | Thirds |
| ⌘⇧4 | Quads |
| ⌘⇧5 | Main + Side |
| ⌘⇧6 | LeftSplit + Right |
| ⌘⇧7 | Left + RightSplit |

### Edge-case behavior

| Scenario | Behavior |
|---|---|
| More windows than slots | First N placed by z-order; remainder minimized |
| Fewer windows than slots | Windows placed; extra slots left empty |
| No visible windows | macOS notification (or menu bar icon blink if notifications are denied) |
| Permission revoked mid-session | Menu bar icon greys out; hotkeys unregister within 2 s |
| Electron apps | Single ±5 px retry if the window undershoots/overshoots the target |
| System Settings | macOS enforces a minimum window size — position is respected, size may not be |

## Architecture

```
macbook-resizer/
├── Package.swift
├── Sources/SceneCore/          # pure logic, unit-testable without Xcode
│   ├── AX/                     # Accessibility API wrappers
│   ├── Display/                # screen picker
│   ├── Interaction/            # hotkey + drag-swap controllers
│   └── Layout/                 # Slot, Layout, LayoutEngine, Plan, Geometry
├── Tests/SceneCoreTests/       # 26 XCTest cases
├── SceneApp/                   # Xcode project — menu bar shell
│   └── SceneApp/
│       ├── SceneAppApp.swift          # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift          # orchestration layer
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md                     # end-user install walkthrough
    └── TESTING.md                     # manual smoke-test checklist
```

The split is deliberate: `SceneCore` owns all the hard logic (AX calls, layout math, hotkey plumbing) and is covered by 26 unit tests. `SceneApp` is a thin SwiftUI/AppKit shell that only wires UI and app lifecycle. You can run `swift test` on `SceneCore` from the command line without installing Xcode — only the final `.app` build needs it.

## Persistence

V0.2 writes two JSON files atomically into:

```
~/Library/Application Support/Scene/
├── layouts.json     # 7 seeds + your custom layouts + each layout's hotkey
└── settings.json    # animation enabled/duration/easing
```

Delete this folder to reset to factory state.

## Roadmap (V0.3+)

Deferred from V0.2:

- **Drag-to-swap** — after applying a preset, drag any window and it snaps to the nearest slot, swapping with whoever lives there. `DragSwapController` is already in `SceneCore`; only the `AXObserver` bridge remains.
- **Per-display layouts** — apply different presets to each monitor independently.
- **Pattern learning** — observe manual window arrangements and suggest presets ("you usually split 70/30 in the afternoon — save?").
- **AI / natural-language input** — type "cursor left, chrome right" → LLM → layout JSON.
- **Per-app rules** — e.g., "always put Slack in slot 4".
- **Launch-at-Login** UI.
- **Free-form canvas-drag** layout editor (the EpycZones approach).
- **Notarization** (requires Developer ID) — eliminates the Gatekeeper bypass step.

## License

TBD.
