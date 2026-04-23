# Scene

A macOS menu bar app for instant window layouts. Click one of ten presets and every visible window snaps into place. First-time users get a friendly welcome window on first launch.

**Requires macOS 14 (Sonoma) or later. Universal binary — runs native on both Apple Silicon and Intel.**

> 繁體中文版本： [README.zh-HK.md](README.zh-HK.md)

## Install

**Homebrew** (recommended):

```bash
brew install --cask chifunghillmanchan/tap/scene
```

Quarantine is stripped automatically — no "cannot be verified" prompt. On first launch, grant Accessibility in **System Settings → Privacy & Security → Accessibility**.

**Or download the DMG directly**: **[Scene-0.5.5.dmg](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.5.5/Scene-0.5.5.dmg)** (Universal: Apple Silicon + Intel, macOS 14+, notarized by Apple — no Gatekeeper prompt)

All versions: [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) · DMG users, see [`docs/INSTALL.md`](docs/INSTALL.md) for the one-time Gatekeeper + Accessibility-permission steps.

## Demo

<video src="https://github.com/ChiFungHillmanChan/macbook-resizer/raw/main/docs/media/scene-marketing.mp4" controls muted width="720">
  Your browser does not render embedded video. <a href="docs/media/scene-marketing.mp4">Download the demo clip (MP4, 13 MB)</a>.
</video>

## V0.5.5 update-detection on relaunch + Workspaces delete button

- **Quit-and-relaunch now refreshes the update check** — `UpdateChecker.startPeriodicChecks()` now bypasses the 24-hour debounce on launch. Previously, if Scene cached `lastCheckedAt` on a version where the next release wasn't published yet, a relaunch within 24 hours would silently skip the GitHub call and the user would never see the new release in the menu until the next day. The hourly background timer and the wake-from-sleep trigger keep the 24h debounce (those fire automatically without explicit user intent — the GitHub rate-limit guard belongs there, not on user-driven relaunches).
- **Delete button in Workspaces tab toolbar** — `WorkspacesTab` now exposes a `trash` button next to "+ New" and "Duplicate", matching `LayoutsTab`. Previously the only way to remove a workspace was the inline `List.onDelete` swipe gesture, which on macOS NavigationSplitView is barely discoverable — users believed the four seeded workspaces (Coding, Meeting, Reading, Streaming) couldn't be removed. Inline-swipe is preserved as a secondary affordance.
- **No SceneCore changes; tests still 177/177** — pure SceneApp UI / lifecycle fix.

## V0.5.4 first-launch reliability + Accessibility recovery

- **Welcome window no longer gated on Accessibility** — the one-time welcome screen now appears on the very first launch regardless of permission state. Previously it was held back until `AXIsProcessTrusted` returned true, so anyone stuck on the cdhash-mismatch upgrade path (typical when going from an ad-hoc-signed v0.4.x to a notarized v0.5+) never saw the introduction. The welcome now runs first, then the Accessibility prompt chains automatically when the user dismisses it.
- **Accessibility recovery hint shown upfront** — the `tccutil reset Accessibility com.hillman.SceneApp` command, the **Copy** button, and the "paste into Terminal" instructions are visible the moment the onboarding window opens. The previous behavior gated this hint behind a failed "Check again" click — but most users grant in System Settings and let the 2-second polling timer pick it up, so they never clicked Check again and never discovered the rescue command.
- **Returning users without AX get the prompt automatically** — if Accessibility is missing on a launch where the welcome flag is already set, the onboarding window now opens by itself instead of waiting for the user to find the hidden "Grant Accessibility" item in the menu bar.
- **No SceneCore changes; tests still 177/177** — pure SceneApp UI / lifecycle fix.

## V0.5.3 smoother animation + Intel support

- **60Hz window animation for native apps** — the AX-write throttle in `WindowAnimator` now picks its ceiling per-animation: 30Hz when any window belongs to a known Electron app (VS Code, Cursor, Chrome, Brave, Slack, Discord, Figma, Notion, Obsidian, Teams), 60Hz when all windows are native (Safari, Finder, Xcode, Notes, Preview, System Settings, Mail, Messages). Native apps get roughly twice the frame count inside the same animation window, which reads as noticeably smoother on ProMotion displays.
- **Distance-proportional duration** — the configured `durationMs` is now treated as a reference for a ~600pt diagonal move. Short moves (same-screen nudges) contract toward ~70% of the base for a snappier feel; long moves (across-display / full-screen rearrangements) expand toward ~140% so they don't feel rushed. Clamped both ways; `AnimationConfig`'s own [100, 500]ms range is the final safety net.
- **Tighter write de-dup** — per-window AX write dedup tolerance dropped from 0.5pt → 0.2pt, reclaiming a few frames at the end of easeOut curves where tiny deltas were previously suppressed.
- **Universal binary** — Intel (x86_64) Macs now supported. One DMG ships both slices; macOS picks the native one at launch. No Rosetta required on Apple Silicon.
- **Deployment target restored to macOS 14** — Xcode had silently bumped the Xcode project's `MACOSX_DEPLOYMENT_TARGET` to 26.4 (matching the build machine's OS); reset to 14.0 to match `Package.swift` and the documented minimum.
- **No SceneCore changes; tests still 177/177** — all three smoothness tweaks live in `WindowAnimator`, the AppKit bridge.

## V0.5.2 first-launch welcome

- **One-time welcome window** — new users now see a friendly welcome screen on first launch after Accessibility permission is granted. Confirms "Scene is running", shows a native SwiftUI illustration of a mock menu bar with the Scene icon highlighted and a bouncing arrow pointing at it, and offers two buttons: **"Got it"** (dismiss) or **"Open Settings"** (primary, opens Workspaces tab).
- **Gated by `UserDefaults`** — the `hasShownFirstLaunchWelcomeV1` flag survives reinstalls. Flag is set at show-time (not dismiss-time), so a `⌘Q` during the welcome does not cause it to re-appear on the next launch.
- **Re-openable** — **Settings → About → "Show welcome screen again"** re-triggers the welcome on demand without clearing the flag.
- **AX-missing path coordinated** — if AX is not yet granted at launch, the existing AX onboarding appears first; after the user grants permission, the welcome appears in its place. The two windows never overlap.
- **Localized** — English, 繁體中文 (香港) 粵語, 繁體中文 (台灣).
- **Dynamic version string** — the About tab now reads `CFBundleShortVersionString` from the bundle instead of a stale `"V0.4"` catalog constant, so future releases no longer require a String Catalog edit just to update the displayed version.
- **No SceneCore changes; tests still 177/177** — this is a pure SceneApp UI feature.

## V0.4.3 passive update nudge

- **"Update available" menu item** — Scene polls GitHub's `releases/latest` endpoint at most once every 24 hours per device and surfaces a tinted menu bar entry when a newer release exists. Click it and the GitHub release page opens in your browser; install the DMG as usual. No Sparkle, no silent auto-install.
- **Why not auto-install?** Scene is ad-hoc signed, so every new build has a different `cdhash`. A silent replace would invalidate your Accessibility grant on every update, breaking the core feature. Keeping you in the DMG install path means the Homebrew tap's quarantine-strip postflight still runs cleanly.
- **One-time upgrade for everyone on ≤ v0.4.2** — the nudge ships starting from this release. Older builds (v0.3, v0.4.0, v0.4.1, v0.4.2) have no update-check code, so they won't see it. After you install v0.4.3, future releases will prompt you automatically.
- **19 new unit tests** — the semver comparison moved into SceneCore as `isVersionTag(_:newerThan:)`. Total tests: 158 → 177.

## V0.4.2 bug fixes

- **Animation lag on ProMotion** — AX writes are now throttled to 30Hz (from the display-native 120Hz) and deduped within 0.5pt per window. Cursor ↔ Chrome swaps now complete in the configured 250ms instead of dragging out to a second or more.
- **Workspace "preselected on launch"** — `activeWorkspaceID` is now session-only state. Earlier builds restored it from disk, so the menu bar showed a checkmark against a workspace the user did not pick in the current session. Old state on disk is silently ignored and dropped.
- **Instant workspace click** — an empty `appsToQuit` list no longer spends the 5-second gentle-quit grace period, and an empty `appsToLaunch` list skips the 1.5-second settle. Default seeded workspaces fire their layout within ~50ms of the click instead of ~6.5 seconds.
- **Layout re-fire after opening a new window** — hitting the same layout hotkey twice now adds a 200ms settle before re-enumerating windows, giving `CGWindowListCopyWindowInfo` time to register the brand-new window. First fire of any layout is unchanged.

## New in v0.4

- **Workspaces** — bundle layout + apps + Focus mode + auto-triggers (manual / monitor / time / calendar) into a one-click context switcher
- **Layout thumbnails** — every layout reference in the menu and settings now shows a live rendering of its slot proportions
- **3 new vertical preset layouts** — Main + Side Vertical (⌘⌃8), Halves Vertical (⌘⌃9), Thirds Vertical (⌘⌃0)
- **Multilingual UI** — English / 繁體中文 (香港) / 繁體中文 (台灣), all at ~99% key coverage
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

- **10 built-in layout presets** — Full, Halves, Thirds, Quads, Main + Side (70/30), LeftSplit + Right, Left + RightSplit, plus vertical variants: Main + Side (Vertical), Halves (Vertical), Thirds (Vertical)
- **Build your own layouts** — 11 grid templates (columns / rows / 2×2 / 3×2 / 4 L-shape variants) with proportion sliders
- **Per-layout custom hotkeys** with conflict detection (block-save: one chord per layout or workspace)
- **Smooth window animation** with adjustable duration (100–500 ms) and easing (Linear / Ease Out / Spring)
- **Settings window** — Workspaces / Layouts / Hotkeys / Interaction / About (open via menu bar icon → Settings… or ⌘,)
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
| 8 | Main + Side (Vertical) | top row 70%, bottom row 30% |
| 9 | Halves (Vertical) | 2 equal rows |
| 10 | Thirds (Vertical) | 3 equal rows |

## Install

End users: download the DMG from the [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) (or grab the [latest v0.5.5 DMG directly](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.5.5/Scene-0.5.5.dmg), or run `scripts/build-dmg.sh` locally), drag `Scene.app` into `/Applications`, and follow [`docs/INSTALL.md`](docs/INSTALL.md) for the one-time Accessibility-permission step.

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
./scripts/build-dmg.sh 0.5.5    # produces dist/Scene-0.5.5.dmg (universal, notarized)
```

This builds a universal (arm64 + x86_64) binary, Developer ID-signs it, submits it to Apple for notarization, and packages it into a DMG with an `Applications` drop shortcut. Both Apple Silicon and Intel Macs install from the same DMG. Set `SKIP_NOTARY=1` for a local ad-hoc build that skips the Apple notary submission (useful while iterating on DMG layout).

### Run the core library tests

The layout logic lives in `SceneCore`, a Swift package that works without Xcode:

```bash
swift test
```

177 unit tests cover layout math, window-to-slot mapping, animation state machine, JSON persistence, hotkey conflicts, drag-to-swap logic, semver comparison for the update nudge, and edge cases.

## Usage

1. On first launch, Scene asks for **Accessibility permission**. Grant it in System Settings → Privacy & Security → Accessibility.
2. Click the Scene icon in the menu bar (`rectangle.3.group`) to see the 10 layout presets and 4 workspace presets.
3. Click any layout preset, or press ⌘⌃1 – ⌘⌃0 (where ⌘⌃0 = the 10th). Workspaces fire on ⌘⌥1 – ⌘⌥4.
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
| ⌘⌃8 | Main + Side (Vertical) |
| ⌘⌃9 | Halves (Vertical) |
| ⌘⌃0 | Thirds (Vertical) |

Workspace hotkeys (defaults):

| Shortcut | Workspace |
|---|---|
| ⌘⌥1 | Coding |
| ⌘⌥2 | Meeting |
| ⌘⌥3 | Reading |
| ⌘⌥4 | Streaming |

All layout and workspace hotkeys are re-bindable in Settings → Hotkeys; chord conflicts across layouts **and** workspaces are blocked at save time.

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
│   ├── Settings/               # AnimationConfig, HotkeyBinding, DragSwapConfig,
│   │                           #   SettingsStore, Cancellable
│   └── Workspace/              # Workspace, WorkspaceTrigger, WorkspaceSeeds,
│                               #   WorkspaceStore, FocusModeReference
├── Tests/SceneCoreTests/       # 158 XCTest cases
├── SceneApp/                   # Xcode project — menu bar shell + settings window
│   └── SceneApp/
│       ├── Animation/                 # WindowAnimator (CVDisplayLink + AX bridge)
│       ├── Interaction/               # AXMoveObserverGroup, AXWindowLookup,
│       │                              #   DragSwapAnimationSink
│       ├── Resources/                 # Localizable.xcstrings, InfoPlist.xcstrings
│       ├── Settings/                  # SettingsWindowController + 5 tabs
│       │                              #   (Workspaces / Layouts / Hotkeys / Interaction / About)
│       │                              #   + LayoutEditorView + LayoutPickerView + LayoutThumbnail
│       │                              #   + WorkspaceEditorView + WorkspaceTriggerEditor
│       │                              #   + AppPickerView + HotkeyCaptureView
│       ├── Stores/                    # LayoutStoreViewModel, SettingsStoreViewModel,
│       │                              #   WorkspaceStoreViewModel
│       ├── Workspace/                 # AppLauncher, FocusController, WorkspaceActivator
│       │   └── Triggers/              #   MonitorTriggerWatcher, TimeTriggerScheduler,
│       │                              #   CalendarTriggerWatcher, TriggerSupervisor
│       ├── SceneAppApp.swift          # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift          # orchestration layer
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md                     # end-user install walkthrough
    ├── TESTING.md                     # manual smoke-test checklist (V0.1–V0.5)
    └── media/                         # demo video + screenshots
```

The split is deliberate: `SceneCore` is framework-neutral and owns all the hard logic (AX calls, layout math, hotkey plumbing, animation state machine, JSON persistence, drag-swap). 158 unit tests run via `swift test` without Xcode. `SceneApp` is a thin SwiftUI/AppKit shell — only UI, app lifecycle, and the AppKit/AX bridges (`WindowAnimator`, `AXMoveObserverGroup`, `AXWindowLookup`, `DragSwapAnimationSink`) that can't live in a framework-neutral library. Only the final `.app` build needs Xcode.

## Persistence

Scene writes three JSON files atomically into:

```
~/Library/Application Support/Scene/
├── layouts.json      # 10 seeds + your custom layouts + each layout's hotkey
├── settings.json     # animation enabled/duration/easing + drag-swap config
└── workspaces.json   # 4 workspace seeds + your custom workspaces + active workspace ID
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
