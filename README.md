# Scene

A macOS menu bar app for instant window layouts. Click one of seven presets and every visible window snaps into place.

**Requires macOS 14 (Sonoma) or later.**

> 繁體中文版本： [README.zh-HK.md](README.zh-HK.md)

## Install

**Homebrew** (recommended):

```bash
brew install --cask chifunghillmanchan/tap/scene
```

Quarantine is stripped automatically — no "cannot be verified" prompt. On first launch, grant Accessibility in **System Settings → Privacy & Security → Accessibility**.

**Or download the DMG directly**: **[Scene-0.4.1.dmg](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.4.1/Scene-0.4.1.dmg)** (~1.4 MB, Apple Silicon, macOS 14+)

All versions: [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) · DMG users, see [`docs/INSTALL.md`](docs/INSTALL.md) for the one-time Gatekeeper + Accessibility-permission steps.

## Demo

<video src="https://github.com/ChiFungHillmanChan/macbook-resizer/raw/main/docs/media/scene-marketing.mp4" controls muted width="720">
  Your browser does not render embedded video. <a href="docs/media/scene-marketing.mp4">Download the demo clip (MP4, 13 MB)</a>.
</video>

## New in v0.4

- **Workspaces** — bundle layout + apps + Focus mode + auto-triggers (manual / monitor / time / calendar) into a one-click context switcher
- **Layout thumbnails** — every layout reference in the menu and settings now shows a live rendering of its slot proportions
- **3 new vertical preset layouts** — Main + Side Vertical (⌘⌃8), Halves Vertical (⌘⌃9), Thirds Vertical (⌘⌃0)
- **Multilingual UI** — full English + 繁體中文 (香港) support; partial 繁體中文 (台灣)
- Bundled with V0.2 (customization + animation) and V0.3 (drag-to-swap) for one big first public release

### V0.3 — Drag-to-Swap

- **Drag to rearrange**: grab any placed window and drag it onto another — swap executes with the displaced window animating via the V0.2 engine (250ms easeOut, respects the Animation tab toggle).
- **Interaction tab**: enable / disable drag-to-swap; tune drag-distance threshold (10–100pt).
- **Escape hatches**: hold ⌥ while dragging to free-move without swap; press Esc mid-drag to cancel and snap back to origin.
- **Test count**: 92 → 116 unit tests (V0.4.1 raises total to 158).

## V0.4.1 polish

- **Under-1MB DMG** — previous 2.8 MB → **1.4 MB**, via `-Osize` + LZFSE + pngquant icon compression + styled installer background.
- **Styled installer window** — custom background with a directional arrow, pinned icon positions, hidden toolbar/sidebar, clean "drag to Applications" layout.
- **Workspace activation reliability** — no more false-success banner when layout apply fails; single-flight guard prevents concurrent activations from racing; empty Calendar keyword no longer matches every event.
- **Better "grant denied" onboarding** — when re-installs invalidate the TCC cdhash binding, the onboarding window now surfaces the exact `tccutil reset` command with a one-click Copy button, instead of unreliable "toggle OFF/ON" advice.
- **Duplicate-ID guard** in `WorkspaceStore.insert`.

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

End users: download the DMG from the [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) (or grab the [latest v0.4.1 DMG directly](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.4.1/Scene-0.4.1.dmg), or run `scripts/build-dmg.sh` locally), drag `Scene.app` into `/Applications`, and follow [`docs/INSTALL.md`](docs/INSTALL.md) for the one-time Gatekeeper + Accessibility-permission steps.

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
./scripts/build-dmg.sh 0.4.1    # produces dist/Scene-0.4.1.dmg
```

This builds an Apple Silicon (arm64) binary, ad-hoc signs it, and packages it into a DMG with an `Applications` drop shortcut. No Apple Developer account required. macOS 14 devices are overwhelmingly Apple Silicon; Intel users can add `ARCHS="arm64 x86_64"` back to the build script.

### Run the core library tests

The layout logic lives in `SceneCore`, a Swift package that works without Xcode:

```bash
swift test
```

158 unit tests cover layout math, window-to-slot mapping, animation state machine, JSON persistence, hotkey conflicts, drag-to-swap logic, and edge cases.

## Usage

1. On first launch, Scene asks for **Accessibility permission**. Grant it in System Settings → Privacy & Security → Accessibility.
2. Click the Scene icon in the menu bar (`rectangle.3.group`) to see the 7 presets.
3. Click any preset, or press ⌘⌃1 – ⌘⌃7.
4. Quit via the menu's **Quit Scene** item.

### Hotkey reference

| Shortcut | Layout |
|---|---|
| ⌘⌃1 | Full |
| ⌘⌃2 | Halves |
| ⌘⌃3 | Thirds |
| ⌘⌃4 | Quads |
| ⌘⌃5 | Main + Side |
| ⌘⌃6 | LeftSplit + Right |
| ⌘⌃7 | Left + RightSplit |

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
│   ├── Animation/              # Clock, FrameInterpolator, AnimationRunner
│   ├── Display/                # screen picker
│   ├── Interaction/            # HotkeyManager, DragSwapController,
│   │                           #   WindowAnimationSink, WindowMoveObserving
│   ├── Layout/                 # Slot, Layout, LayoutEngine, Plan, Geometry,
│   │                           #   LayoutTemplate, CustomLayout, PresetSeeds, LayoutStore
│   └── Settings/               # AnimationConfig, HotkeyBinding, DragSwapConfig,
│                               #   SettingsStore, Cancellable
├── Tests/SceneCoreTests/       # 158 XCTest cases
├── SceneApp/                   # Xcode project — menu bar shell + settings window
│   └── SceneApp/
│       ├── Animation/                 # WindowAnimator (CVDisplayLink + AX bridge)
│       ├── Interaction/               # AXMoveObserverGroup, AXWindowLookup,
│       │                              #   DragSwapAnimationSink
│       ├── Settings/                  # SettingsWindowController + 4 tabs +
│       │                              #   LayoutEditorView + HotkeyCaptureView
│       ├── Stores/                    # LayoutStoreViewModel, SettingsStoreViewModel
│       ├── SceneAppApp.swift          # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift          # orchestration layer
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md                     # end-user install walkthrough
    └── TESTING.md                     # manual smoke-test checklist (V0.1–V0.4)
```

The split is deliberate: `SceneCore` is framework-neutral and owns all the hard logic (AX calls, layout math, hotkey plumbing, animation state machine, JSON persistence, drag-swap). 158 unit tests run via `swift test` without Xcode. `SceneApp` is a thin SwiftUI/AppKit shell — only UI, app lifecycle, and the AppKit/AX bridges (`WindowAnimator`, `AXMoveObserverGroup`, `AXWindowLookup`, `DragSwapAnimationSink`) that can't live in a framework-neutral library. Only the final `.app` build needs Xcode.

## Persistence

V0.2 writes two JSON files atomically into:

```
~/Library/Application Support/Scene/
├── layouts.json     # 7 seeds + your custom layouts + each layout's hotkey
└── settings.json    # animation enabled/duration/easing
```

Delete this folder to reset to factory state.

## Roadmap (V0.5+)

- **Per-display layouts** — apply different presets to each monitor independently.
- **Pattern learning** — observe manual window arrangements and suggest presets ("you usually split 70/30 in the afternoon — save?").
- **AI / natural-language input** — type "cursor left, chrome right" → LLM → layout JSON.
- **Per-app rules** — e.g., "always put Slack in slot 4".
- **Launch-at-Login** UI.
- **Free-form canvas-drag** layout editor (the EpycZones approach).
- **Notarization** (requires Developer ID) — eliminates the Gatekeeper bypass step.

## License

MIT — see [`LICENSE`](LICENSE).
