# Manual Smoke Test

Run after installing (from `Scene.app`) or after a local Xcode build. All tests assume macOS 14+.

## Prerequisites

- Scene is installed at `/Applications/Scene.app` (or running under Xcode ⌘R).
- Accessibility permission is cleared for a fresh run — remove Scene from **System Settings → Privacy & Security → Accessibility** before **P1**.
- Optional: external display for **P9**, Cursor / VS Code / Slack for **P8**.

## Scenarios

### P1 — First-launch onboarding

- [ ] Launch Scene with no AX permission.
- [ ] Menu bar icon appears (`rectangle.3.group`).
- [ ] Clicking the icon shows only **Grant Accessibility Access…** + **Quit**.
- [ ] Clicking **Grant Accessibility Access…** opens a standalone onboarding window.
- [ ] Clicking **Open System Settings** jumps to the Accessibility pane.
- [ ] After toggling Scene on, the onboarding window closes within 2 s and the menu switches to 7 presets.

### P2 — Halves (menu)

- [ ] Open 3 windows (any apps).
- [ ] Click Scene icon → **Halves**.
- [ ] Top 2 windows by z-order split the screen 50/50.
- [ ] 3rd window is minimized.
- [ ] Neither window overlaps the menu bar or Dock.

### P3 — Thirds

- [ ] Restore the minimized window.
- [ ] Click **Thirds** → windows split into 3 equal columns.

### P4 — Hotkey (Quads)

- [ ] Press **⌘⇧4** → top 4 windows form a 2×2 grid in z-order (frontmost = top-left).

### P5 — Underflow

- [ ] Close to leave only 2 windows open.
- [ ] Press **⌘⇧4** → top-left and top-right slots filled; bottom-left and bottom-right left empty.

### P6 — Zero windows

- [ ] Hide or close all app windows.
- [ ] Press **⌘⇧2**:
  - If notification permission is granted: macOS banner shows `Scene — No windows to arrange`.
  - If denied: menu bar icon dims briefly and its tooltip changes for 3 s.

### P7 — Permission revoke + restore

- [ ] With Scene running, toggle Scene **OFF** in System Settings → Accessibility.
- [ ] Within 2 s: menu reverts to **Grant Accessibility Access…**; hotkeys stop responding.
- [ ] Toggle Scene back on → menu returns to the 7 presets within 2 s.

### P8 — Electron tolerance

- [ ] Open Cursor (or VS Code / Slack) plus one regular app.
- [ ] Apply **Halves**.
- [ ] Visually confirm the Electron window aligns with the target edge within ±5 px.

### P9 — Multi-display active screen

*Requires an external monitor.*

- [ ] Move the mouse onto the external display.
- [ ] Open 2 windows on that display.
- [ ] Press **⌘⇧2** → only the external display's windows are rearranged; the internal display's windows are untouched.

### P10 — visibleFrame

- [ ] Set Dock to always visible (disable auto-hide).
- [ ] Press **⌘⇧1** (Full) → the window's top edge sits below the menu bar and its bottom edge sits above the Dock.

## Recording results

| Test | Pass / Fail | Notes |
|---|---|---|
| P1 | | |
| P2 | | |
| P3 | | |
| P4 | | |
| P5 | | |
| P6 | | |
| P7 | | |
| P8 | | |
| P9 | | |
| P10 | | |

## Known quirks (not Scene bugs)

- **Apple System Settings** has a hard minimum size and ignores AX size requests below it. Position still snaps correctly.
- Electron apps may settle ±1–4 px off even after the tolerance retry; this is within spec.

---

## V0.2 manual smoke checklist

Reset state first:
```
rm -rf ~/Library/Application\ Support/Scene
killall SceneApp 2>/dev/null; true
```

Then build & launch and verify:

- [ ] **First-launch seeding** — Settings → Layouts shows exactly 7 presets (Full / Halves / Thirds / Quads / Main + Side / LeftSplit + Right / Left + RightSplit)
- [ ] **Edit + Reset preset** — drag the slider on Halves to 70/30. "(modified)" appears next to the name. Click Reset → slider snaps back to 50/50; the bound hotkey is unchanged
- [ ] **Delete persistence** — delete Quads. Quit and relaunch the app. Quads is still gone. Click "Restore Default Presets" → Quads is back
- [ ] **Hotkey conflict block-save** — try to record ⌘⇧2 (used by Halves) on another layout → alert: "This chord is already used by Halves. Unbind it first or pick another."
- [ ] **Animated apply** — open 4 windows. Bind ⌘⌥A to a custom layout. Fire it → windows interpolate smoothly into place
- [ ] **Animation config live** — open Animation tab. Drag duration to 500ms, switch easing to Spring → preview rectangle reflects immediately. Fire layout hotkey → animation matches
- [ ] **Disable animation** — toggle off. Fire layout hotkey → windows snap instantly
- [ ] **> 6 windows fallback** — open 8+ windows. Fire layout hotkey → windows snap instantly (no animation)
- [ ] **Interrupt** — fire layout A, then within 200 ms fire layout B → animation retargets without jump; lands on B's positions

---

## V0.3 — Drag-to-Swap Smoke Test

Run in this order after `swift test` passes locally (114 tests expected).

1. Build the app: `xcodebuild -project SceneApp/SceneApp.xcodeproj -scheme SceneApp -configuration Debug CODE_SIGNING_REQUIRED=NO build`
2. Launch from `~/Library/Developer/Xcode/DerivedData/SceneApp-*/Build/Products/Debug/SceneApp.app`
3. Grant AX permission if prompted (System Settings → Privacy → Accessibility)
4. Open 4 windows (e.g., Safari, Terminal, Notes, Finder)
5. ⌘⇧4 (2x2 preset) → windows animate into a 2x2 layout
6. Grab one window by title bar, drag onto another placed window's slot → preview rectangle appears → release → swap executes (source snaps, displaced window animates via V0.2 engine)
7. Drag a placed window with ⌥ held → no preview, no swap (free-move)
8. Drag a placed window < 30pt → no preview, window returns naturally (sub-threshold)
9. Drag a placed window into a region outside any slot (far off-screen) → preview disappears, no swap on release
10. Start a drag, press Esc mid-drag → window animates back to origin slot
11. Open Settings → Interaction tab → toggle "Enable drag-to-swap" off → drag placed window → no preview, no swap
12. Restore toggle; set threshold slider to 80pt → drag 50pt → no swap; drag 100pt → swap fires
13. Fire another layout (⌘⇧1) while a drag preview is showing → preview hides cleanly, new observer set installed
14. Revoke AX permission (System Settings → Privacy → Accessibility → uncheck Scene) → onboarding reappears; verify Console shows observer group `stop` log line
15. Re-grant AX permission → fire layout → drag-to-swap works again
16. Open Stage Manager → fire layout → drag-to-swap still works on visible windows
17. Quit Scene → no leaked AXObservers (Activity Monitor sample: no AXObserverRef retain-count growth across 10 layout fires)

Expected: all 17 pass. Record any failures on the V0.3 release issue.

### V0.3 Settings migration smoke

18. Start from V0.2 install with an existing `~/Library/Application Support/Scene/settings.json` (version: 1) → launch V0.3 → file auto-upgrades to version: 2 with `dragSwap: { enabled: true, distanceThresholdPt: 30 }` appended. Verify with `cat ~/Library/Application\ Support/Scene/settings.json | jq`.
