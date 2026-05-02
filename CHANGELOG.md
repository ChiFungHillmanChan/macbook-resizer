# Changelog

All notable changes to Scene. Newest releases are listed first.

For binaries, see the [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases).

## V0.6.1 — Free Mode

- **Free Mode toggle.** New "Free Mode" entry in the menu bar (between Layouts and Settings). One click pauses every automatic Scene behavior: layout hotkeys (⌘⌃1-9,0), workspace hotkeys (⌘⌥1-4), drag-swap, seam-resize, and workspace auto-triggers (monitor connect / time / calendar). Saved layouts, workspaces, hotkey bindings, and settings are all preserved — they just don't fire until you toggle back on. The Free Mode row gains a leading checkmark when active, the Layouts and Workspaces rows visibly dim, and the menu bar icon swaps from `rectangle.3.group` to `pause.rectangle` so dormant state is visible at a glance.
- **Always starts active on launch.** Free Mode is in-memory only — every quit + relaunch returns Scene to its normal active state. There is no persisted "Scene is paused" state to forget about.
- **No SceneCore changes; tests still 317/317** — pure SceneApp UI + Coordinator gating. State lives in `Coordinator.freeMode` (`@Published Bool`), with early-returns at `applyLayout(_:)` / `applyWorkspace(id:)` and a matching `paused` flag on `TriggerSupervisor` for auto-triggers. Drag-swap is gated in the AX observer closures so the observer itself stays installed and re-enables instantly when toggled back.

## V0.6.0 — Diagnostics + Persistent Workspaces

- **Diagnostics.** New "Diagnostics" section in Settings → About. When enabled (default ON), Scene records orchestration events to `~/Library/Application Support/Scene/diagnostics/events-YYYY-MM-DD.jsonl` — layout fires, workspace step timing, AX permission changes, screen arrangement diffs, animation outcomes (including silent AX `setFrame` failures previously swallowed by `os.Logger`). Capped at 2 MB total disk, gzip rotation on day boundary, 7-day retention. Toggling off drains the writer + deletes everything; toggling back on regenerates the salt for forward secrecy. The **"Export Diagnostics for Bug Report"** button packages a sanitized zip — workspace names, app bundle IDs, monitor names, calendar keywords, and Focus shortcut names are all replaced with 11-character SHA hashes; the salt itself never leaves your Mac (only `hashID` does, so within one bundle hashes are correlatable but not reversible) — reveals it in Finder, and opens a pre-filled GitHub issue with environment info. Reporting a bug now takes 30 seconds.
- **Persistent Workspaces.** Workspaces gain three new fields: **Pinned Apps** (always launched on activation; treated as belonging to this workspace), **Assign to Desktop 1-9** (Scene posts your Mission Control "Switch to Desktop N" shortcut so the activation lands on a specific Space), and **Enforcement Mode** (Off / Arrange only / Hide inactive pinned apps / Quit inactive pinned apps). With Hide or Quit, switching workspaces auto-hides or terminates the previous workspace's pinned apps so each context stays visually clean. macOS doesn't expose a public API for forcing third-party windows onto a specific Space, so this is "switch desktop + pin apps + hide/quit enforcement", not literal window relocation. Requires "Switch to Desktop N" enabled in System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
- **Workspace editor Save UX.** The Save button is now disabled when there are no unsaved edits, shows a grey "Unsaved changes" badge while you have a dirty draft, and flashes a green "Saved ✓" indicator for 2 seconds after a successful commit. No more guessing whether your click registered.
- **Tests: 244 → 317.** 73 new tests covering `DiagnosticEvent` Codable + byte-cap, `EnvironmentSnapshot` signature stability + sensitivity to resolution / scale / main-flag / active changes, `EventLog` ring buffer, `DiagnosticWriter` actor (race-safe drain — single `AsyncStream` + sole consumer; no detached `Task {}`), `DiagnosticBudget` (newline-aware truncation, eviction policy, 7-day retention), `GzipWriter` (round-trip verified via `/usr/bin/gunzip`), `SaltStore` (mode 0600, regeneration), `ExportSanitizer` (PII-drop property check across realistic input), `SettingsStore` v2→v3 migration.

## V0.5.7 — Custom Layouts, Seam Drag, Dirty-State Save

- **Build-your-own layouts.** Settings → Layouts has a new "+ Custom" button (the square-on-square icon). Clicking it gives you a blank canvas — click any slot to split it horizontally or vertically, drag seams to adjust proportions, delete a slot to collapse it into its sibling. Design any tile shape you want (3-narrow over 2-wide, asymmetric L+4, a 7-slot dashboard — whatever); save it, bind a hotkey, and it fires like any built-in layout. User-authored custom layouts are now first-class citizens next to the 11 built-in templates.
- **Companion resize when dragging.** When Scene has already tiled your windows and you drag the edge of one, the neighbouring tile now follows — shrinks or grows to fill the gap — in real time. Supported on `twoCol` / `twoRow` / `threeCol` / `threeRow` layouts (single-seam splits; the middle slot of a 3-way split auto-picks whichever edge you grabbed). Custom-tree layouts don't reflow yet — the reflow math is template-axis-based for now, and extending it to arbitrary trees will come in a later release. Hold Option during drag to bypass the reflow and let macOS do its native resize without Scene interfering.
- **Save button actually persists and gives visual feedback.** Fixed two bugs in Settings → Layouts. (a) The Save button on existing layouts was a silent no-op — changes appeared to apply because the binding auto-wrote to the store on every slider tick, but `.onChange(of: draft.template)` reset proportions to their defaults the moment you clicked away, so your customisations got silently wiped on return. The editor now uses a proper `@State draft` with explicit commit through `LayoutStore.update`, matching `WorkspaceEditorView`. (b) The Save button is now wired to a dirty-state check — darkens after a successful save, re-enables only when you edit further. No more guessing whether the save actually took.
- **Multi-display coordinate fix.** Reworked the AX ↔ NSScreen coordinate conversion at the `AXWindow` wrapper boundary and the drag-swap observer callback — all drag-swap / seam-resize math now operates in a single NSScreen (bottom-left) coordinate system, with top-left AX conversion done once at the boundary. On multi-display setups where the secondary display is positioned below or to the left of the primary, drag-swap and seam-resize now compute the correct seam target instead of landing windows off-screen.
- **Tests: 177 → 244.** Added 67 new unit tests covering `LayoutReflow` (pure seam math), `SeamResizeController` (event handling + self-fire guards + config gating), `LayoutNode` (tree flatten + Codable + 100%-coverage invariant + the canonical 5-slot example verbatim), plus legacy-JSON decode round-trip on `CustomLayout` so upgrading from v0.5.6 never loses existing layouts.

## V0.5.6 — In-app Update Installer

- **Click → install → relaunch, no manual download.** The "Update available" menu item now opens a confirmation alert instead of just opening the GitHub release page. Click **Install and Restart** and Scene downloads the new DMG (verifying it's signed by Team ID `22K6G3HH9G`), spawns a detached helper, quits, lets the helper replace `/Applications/Scene.app` (or wherever Scene is installed) via `ditto --noqtn` to preserve the `com.apple.macl` xattr that anchors the TCC Accessibility grant, and relaunches the new Scene. The "View Release Notes" button is still available for users who want to read the changelog before updating.
- **Accessibility permission survives across updates.** TCC binds the grant to the binary's Designated Requirement, which is stable across any release signed with the same Developer ID. Combined with the `ditto --noqtn` xattr-preserving copy, the new Scene launches with `AXIsProcessTrusted` already true — no re-grant, no toggling System Settings, no `tccutil reset`. (V0.5.5 → V0.5.6 still needs one manual install since V0.5.5 ships with the old release-page-opening menu item; subsequent updates from V0.5.6+ go through the in-app installer.)
- **Verification before install.** The downloaded DMG is `codesign -dv` checked and the `TeamIdentifier` is matched against the expected Developer ID before the helper script runs. A DMG with a different Team ID is rejected and the user sees an error alert instead of being silently downgraded.
- **Helper script is self-contained and safe.** Writes to `/tmp/`, backs up the old app to `/tmp/Scene.app.bak-$$` before `ditto`, rolls back if `ditto` fails, unmounts the DMG, deletes the cached download, and self-deletes. Logs to `/tmp/scene-update-<pid>.log` for post-mortems if something does break.
- **No SceneCore changes; tests still 177/177** — `UpdateInstaller.swift` is new in SceneApp, plus a few lines in `UpdateChecker` to surface `dmgURL` from the GitHub release `assets[]`.

## V0.5.5 — Update-Detection on Relaunch + Workspaces Delete Button

- **Quit-and-relaunch now refreshes the update check** — `UpdateChecker.startPeriodicChecks()` now bypasses the 24-hour debounce on launch. Previously, if Scene cached `lastCheckedAt` on a version where the next release wasn't published yet, a relaunch within 24 hours would silently skip the GitHub call and the user would never see the new release in the menu until the next day. The hourly background timer and the wake-from-sleep trigger keep the 24h debounce (those fire automatically without explicit user intent — the GitHub rate-limit guard belongs there, not on user-driven relaunches).
- **Delete button in Workspaces tab toolbar** — `WorkspacesTab` now exposes a `trash` button next to "+ New" and "Duplicate", matching `LayoutsTab`. Previously the only way to remove a workspace was the inline `List.onDelete` swipe gesture, which on macOS NavigationSplitView is barely discoverable — users believed the four seeded workspaces (Coding, Meeting, Reading, Streaming) couldn't be removed. Inline-swipe is preserved as a secondary affordance.
- **No SceneCore changes; tests still 177/177** — pure SceneApp UI / lifecycle fix.

## V0.5.4 — First-launch Reliability + Accessibility Recovery

- **Welcome window no longer gated on Accessibility** — the one-time welcome screen now appears on the very first launch regardless of permission state. Previously it was held back until `AXIsProcessTrusted` returned true, so anyone stuck on the cdhash-mismatch upgrade path (typical when going from an ad-hoc-signed v0.4.x to a notarized v0.5+) never saw the introduction. The welcome now runs first, then the Accessibility prompt chains automatically when the user dismisses it.
- **Accessibility recovery hint shown upfront** — the `tccutil reset Accessibility com.hillman.SceneApp` command, the **Copy** button, and the "paste into Terminal" instructions are visible the moment the onboarding window opens. The previous behavior gated this hint behind a failed "Check again" click — but most users grant in System Settings and let the 2-second polling timer pick it up, so they never clicked Check again and never discovered the rescue command.
- **Returning users without AX get the prompt automatically** — if Accessibility is missing on a launch where the welcome flag is already set, the onboarding window now opens by itself instead of waiting for the user to find the hidden "Grant Accessibility" item in the menu bar.
- **No SceneCore changes; tests still 177/177** — pure SceneApp UI / lifecycle fix.

## V0.5.3 — Smoother Animation + Intel Support

- **60Hz window animation for native apps** — the AX-write throttle in `WindowAnimator` now picks its ceiling per-animation: 30Hz when any window belongs to a known Electron app (VS Code, Cursor, Chrome, Brave, Slack, Discord, Figma, Notion, Obsidian, Teams), 60Hz when all windows are native (Safari, Finder, Xcode, Notes, Preview, System Settings, Mail, Messages). Native apps get roughly twice the frame count inside the same animation window, which reads as noticeably smoother on ProMotion displays.
- **Distance-proportional duration** — the configured `durationMs` is now treated as a reference for a ~600pt diagonal move. Short moves (same-screen nudges) contract toward ~70% of the base for a snappier feel; long moves (across-display / full-screen rearrangements) expand toward ~140% so they don't feel rushed. Clamped both ways; `AnimationConfig`'s own [100, 500]ms range is the final safety net.
- **Tighter write de-dup** — per-window AX write dedup tolerance dropped from 0.5pt → 0.2pt, reclaiming a few frames at the end of easeOut curves where tiny deltas were previously suppressed.
- **Universal binary** — Intel (x86_64) Macs now supported. One DMG ships both slices; macOS picks the native one at launch. No Rosetta required on Apple Silicon.
- **Deployment target restored to macOS 14** — Xcode had silently bumped the Xcode project's `MACOSX_DEPLOYMENT_TARGET` to 26.4 (matching the build machine's OS); reset to 14.0 to match `Package.swift` and the documented minimum.
- **No SceneCore changes; tests still 177/177** — all three smoothness tweaks live in `WindowAnimator`, the AppKit bridge.

## V0.5.2 — First-launch Welcome

- **One-time welcome window** — new users now see a friendly welcome screen on first launch after Accessibility permission is granted. Confirms "Scene is running", shows a native SwiftUI illustration of a mock menu bar with the Scene icon highlighted and a bouncing arrow pointing at it, and offers two buttons: **"Got it"** (dismiss) or **"Open Settings"** (primary, opens Workspaces tab).
- **Gated by `UserDefaults`** — the `hasShownFirstLaunchWelcomeV1` flag survives reinstalls. Flag is set at show-time (not dismiss-time), so a `⌘Q` during the welcome does not cause it to re-appear on the next launch.
- **Re-openable** — **Settings → About → "Show welcome screen again"** re-triggers the welcome on demand without clearing the flag.
- **AX-missing path coordinated** — if AX is not yet granted at launch, the existing AX onboarding appears first; after the user grants permission, the welcome appears in its place. The two windows never overlap.
- **Localized** — English, 繁體中文 (香港) 粵語, 繁體中文 (台灣).
- **Dynamic version string** — the About tab now reads `CFBundleShortVersionString` from the bundle instead of a stale `"V0.4"` catalog constant, so future releases no longer require a String Catalog edit just to update the displayed version.
- **No SceneCore changes; tests still 177/177** — this is a pure SceneApp UI feature.

## V0.4.3 — Passive Update Nudge

- **"Update available" menu item** — Scene polls GitHub's `releases/latest` endpoint at most once every 24 hours per device and surfaces a tinted menu bar entry when a newer release exists. Click it and the GitHub release page opens in your browser; install the DMG as usual. No Sparkle, no silent auto-install.
- **Why not auto-install?** Scene is ad-hoc signed, so every new build has a different `cdhash`. A silent replace would invalidate your Accessibility grant on every update, breaking the core feature. Keeping you in the DMG install path means the Homebrew tap's quarantine-strip postflight still runs cleanly.
- **One-time upgrade for everyone on ≤ v0.4.2** — the nudge ships starting from this release. Older builds (v0.3, v0.4.0, v0.4.1, v0.4.2) have no update-check code, so they won't see it. After you install v0.4.3, future releases will prompt you automatically.
- **19 new unit tests** — the semver comparison moved into SceneCore as `isVersionTag(_:newerThan:)`. Total tests: 158 → 177.

## V0.4.2 — Bug Fixes

- **Animation lag on ProMotion** — AX writes are now throttled to 30Hz (from the display-native 120Hz) and deduped within 0.5pt per window. Cursor ↔ Chrome swaps now complete in the configured 250ms instead of dragging out to a second or more.
- **Workspace "preselected on launch"** — `activeWorkspaceID` is now session-only state. Earlier builds restored it from disk, so the menu bar showed a checkmark against a workspace the user did not pick in the current session. Old state on disk is silently ignored and dropped.
- **Instant workspace click** — an empty `appsToQuit` list no longer spends the 5-second gentle-quit grace period, and an empty `appsToLaunch` list skips the 1.5-second settle. Default seeded workspaces fire their layout within ~50ms of the click instead of ~6.5 seconds.
- **Layout re-fire after opening a new window** — hitting the same layout hotkey twice now adds a 200ms settle before re-enumerating windows, giving `CGWindowListCopyWindowInfo` time to register the brand-new window. First fire of any layout is unchanged.

## V0.4.1 — Polish

- **Under-1MB DMG** — previous 2.8 MB → **1.4 MB**, via `-Osize` + LZFSE + pngquant icon compression + styled installer background.
- **Styled installer window** — custom background with a directional arrow, pinned icon positions, hidden toolbar/sidebar, clean "drag to Applications" layout.
- **Workspace activation reliability** — no more false-success banner when layout apply fails; single-flight guard prevents concurrent activations from racing; empty Calendar keyword no longer matches every event.
- **Better "grant denied" onboarding** — when re-installs invalidate the TCC cdhash binding, the onboarding window now surfaces the exact `tccutil reset` command with a one-click Copy button, instead of unreliable "toggle OFF/ON" advice.
- **Duplicate-ID guard** in `WorkspaceStore.insert`.

## V0.4 — Workspaces

- **Workspaces** — bundle layout + apps + Focus mode + auto-triggers (manual / monitor / time / calendar) into a one-click context switcher.
- **Layout thumbnails** — every layout reference in the menu and settings now shows a live rendering of its slot proportions.
- **3 new vertical preset layouts** — Main + Side Vertical (⌘⌃8), Halves Vertical (⌘⌃9), Thirds Vertical (⌘⌃0).
- **Multilingual UI** — English / 繁體中文 (香港) / 繁體中文 (台灣), all at ~99% key coverage.
- Bundled with V0.2 (customization + animation) and V0.3 (drag-to-swap) for one big first public release.

### V0.3 — Drag-to-Swap

- **Drag to rearrange** — grab any placed window and drag it onto another. Swap executes with the displaced window animating via the V0.2 engine (250ms easeOut, respects the Animation tab toggle).
- **Interaction tab** — enable / disable drag-to-swap; tune drag-distance threshold (10–100pt).
- **Escape hatches** — hold ⌥ while dragging to free-move without swap; press Esc mid-drag to cancel and snap back to origin.
- **Test count** — 92 → 116 unit tests (V0.4.1 raises total to 158).

### V0.2 — Customization + Animation

- **10 built-in layout presets** — Full, Halves, Thirds, Quads, Main + Side (70/30), LeftSplit + Right, Left + RightSplit, plus vertical variants.
- **11 grid templates** with proportion sliders for building your own layouts.
- **Per-layout custom hotkeys** with conflict detection.
- **Smooth window animation** with adjustable duration (100–500 ms) and easing (Linear / Ease Out / Spring).

### V0.1 — Initial Release

- One-click layout snapping for all visible windows on the active screen.
- Frontmost window goes to slot 1, others follow z-order.
- Overflow windows minimized; `visibleFrame`-aware so windows never slide under the menu bar or Dock.
- 26 unit tests.
