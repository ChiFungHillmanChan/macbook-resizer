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

- [ ] Press **⌘⌃4** → top 4 windows form a 2×2 grid in z-order (frontmost = top-left).

### P5 — Underflow

- [ ] Close to leave only 2 windows open.
- [ ] Press **⌘⌃4** → top-left and top-right slots filled; bottom-left and bottom-right left empty.

### P6 — Zero windows

- [ ] Hide or close all app windows.
- [ ] Press **⌘⌃2**:
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
- [ ] Press **⌘⌃2** → only the external display's windows are rearranged; the internal display's windows are untouched.

### P10 — visibleFrame

- [ ] Set Dock to always visible (disable auto-hide).
- [ ] Press **⌘⌃1** (Full) → the window's top edge sits below the menu bar and its bottom edge sits above the Dock.

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
- [ ] **Hotkey conflict block-save** — try to record ⌘⌃2 (used by Halves) on another layout → alert: "This chord is already used by Halves. Unbind it first or pick another."
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
5. ⌘⌃4 (2x2 preset) → windows animate into a 2x2 layout
6. Grab one window by title bar, drag onto another placed window's slot → preview rectangle appears → release → swap executes (source snaps, displaced window animates via V0.2 engine)
7. Drag a placed window with ⌥ held → no preview, no swap (free-move)
8. Drag a placed window < 30pt → no preview, window returns naturally (sub-threshold)
9. Drag a placed window into a region outside any slot (far off-screen) → preview disappears, no swap on release
10. Start a drag, press Esc mid-drag → window animates back to origin slot
11. Open Settings → Interaction tab → toggle "Enable drag-to-swap" off → drag placed window → no preview, no swap
12. Restore toggle; set threshold slider to 80pt → drag 50pt → no swap; drag 100pt → swap fires
13. Fire another layout (⌘⌃1) while a drag preview is showing → preview hides cleanly, new observer set installed
14. Revoke AX permission (System Settings → Privacy → Accessibility → uncheck Scene) → onboarding reappears; verify Console shows observer group `stop` log line
15. Re-grant AX permission → fire layout → drag-to-swap works again
16. Open Stage Manager → fire layout → drag-to-swap still works on visible windows
17. Quit Scene → no leaked AXObservers (Activity Monitor sample: no AXObserverRef retain-count growth across 10 layout fires)

Expected: all 17 pass. Record any failures on the V0.3 release issue.

### V0.3 Settings migration smoke

18. Start from V0.2 install with an existing `~/Library/Application Support/Scene/settings.json` (version: 1) → launch V0.3 → file auto-upgrades to version: 2 with `dragSwap: { enabled: true, distanceThresholdPt: 30 }` appended. Verify with `cat ~/Library/Application\ Support/Scene-testing/settings.json | jq`.

---

## V0.4 manual smoke checklist

Reset state first (optional — resets Workspaces + layouts + settings to factory):

```bash
rm -rf ~/Library/Application\ Support/Scene
killall SceneApp 2>/dev/null; true
```

Build & launch: `xcodebuild -project SceneApp/SceneApp.xcodeproj -scheme SceneApp -configuration Debug CODE_SIGNING_REQUIRED=NO build` then launch from `~/Library/Developer/Xcode/DerivedData/SceneApp-*/Build/Products/Debug/SceneApp.app` (or install via `dist/Scene-0.4.1.dmg`).

1. **First-launch seeding** — delete `~/Library/Application Support/Scene/workspaces.json`; relaunch; 4 default Workspaces appear in Settings → Workspaces.
2. **Vertical seed migration** — with an existing V0.2 `layouts.json` present (no vertical seeds), launch; 3 new vertical seeds (⌘⌃8 / ⌘⌃9 / ⌘⌃0) appear; previously-deleted V0.1 seeds stay deleted (`applyFutureSeeds` never re-adds records whose UUID is already in `knownSeedUUIDs`).
3. **Layout thumbnails** — menu bar shows accurate mini-renders (24×16) for all layouts; open Settings → Layouts → edit Halves to 70/30 → thumbnails across menu + Settings list (32×22) update live; Workspace editor's layout picker (40×26) matches.
4. **Manual workspace activation** — menu bar → pick Coding → launches configured apps (`appsToLaunch`) + applies layout + runs Focus shortcut name (if set).
5. **Hotkey activation** — bind ⌘⌥1 to Coding → press outside menu bar → same result as #4.
6. **Cross-store hotkey conflict** — try to bind ⌘⌃2 (Halves' default) to a Workspace → save-error alert names the layout ("Hotkey already used by Halves").
7. **Monitor trigger** — add `.monitorConnect("LG 34WK95U")` (or whatever your external monitor reports via `NSScreen.localizedName`) to Coding → unplug + replug → Coding auto-activates.
8. **Time trigger** — add `.timeOfDay(.weekdays, 9, 30)` to Coding → change Mac clock (or wait) to a weekday at 9:30 → auto-activates once; second firing within the same minute is suppressed by the 30-second cooldown.
9. **Calendar trigger** — add `.calendarEvent("Standup")` → grant Calendar permission (first add triggers the system sheet via `calendarPermissionRequester`) → create a test calendar event titled "Daily Standup" starting in 3 minutes → Workspace activates within 60–90 seconds. If you deny permission, the editor row shows an orange `trigger.calendar.denied_hint` pointing at System Settings.
10. **Cooldown** — fire same Workspace twice via trigger within 30 s → second fire skipped (manual fire via menu bar / hotkey bypasses cooldown).
11. **Layout reference broken** — delete a layout that a Workspace references → Workspaces tab list row shows red warning icon + `workspace.missing_layout` label; activation surfaces a "%@ references a deleted layout" notification.
12. **Multilingual (zh-HK)** — System Settings → Language → Hong Kong Chinese → quit + relaunch Scene → all UI in 粵語 (情境 / 啟動 / 撳 / 觸發 / 排列 / 快速鍵, etc.); no English fallbacks on Settings tabs or menu bar.
13. **Locale fallback (fr)** — switch system to French → Scene UI falls back to English (development-language fallback; no missing-key crashes, no blank labels).
14. **Menu bar restructure** — Workspaces section above Layouts; active Workspace has ✓ checkmark + bold name; both sections show `LayoutThumbnail` renders.
15. **Unsaved-work protection** — configure a Workspace with `appsToQuit: ["com.apple.TextEdit"]`; open TextEdit with unsaved changes; activate the Workspace; TextEdit's native save dialog appears; after 5 s timeout, Scene shows notification "Unable to quit all apps: TextEdit" (NOT force-killed; document survives).

### V0.4 Recording results

| Test | Pass / Fail | Notes |
|---|---|---|
| 1  (seeding)                | | |
| 2  (vertical migration)     | | |
| 3  (thumbnails)             | | |
| 4  (manual activation)      | | |
| 5  (hotkey activation)      | | |
| 6  (hotkey conflict)        | | |
| 7  (monitor trigger)        | | |
| 8  (time trigger)           | | |
| 9  (calendar trigger)       | | |
| 10 (cooldown)               | | |
| 11 (broken layout ref)      | | |
| 12 (zh-HK UI)               | | |
| 13 (fr fallback)            | | |
| 14 (menu bar restructure)   | | |
| 15 (unsaved-work quit)      | | |

---

## V0.5.2 — First-launch welcome window

Reset preconditions between checks as needed:

```sh
killall SceneApp 2>/dev/null; true
defaults delete com.hillman.SceneApp hasShownFirstLaunchWelcomeV1 2>/dev/null; true
```

- [ ] **Fresh install, AX pre-granted**: welcome window appears on launch with illustration + both buttons. AX onboarding does NOT appear.
- [ ] **Fresh install, AX missing**: AX onboarding appears first. After granting AX, AX onboarding closes and welcome appears. They never overlap.
- [ ] **Second launch** (no flag reset): no welcome, no AX onboarding.
- [ ] **Got it button** (or Enter key): welcome closes. No further UI appears.
- [ ] **Open Settings button**: welcome closes, Settings window opens with the Workspaces tab selected.
- [ ] **Quit during welcome** (cmd-Q before dismissing): relaunch does NOT re-show welcome — flag was set on show, not on dismiss (deliberate).
- [ ] **Re-open from About tab**: Settings → About → "Show welcome screen again" shows the welcome. Dismiss. Relaunch — no welcome. Flag stays set.
- [ ] **Locale coverage**: switch System Settings → Language to zh-HK, reset flag, relaunch — welcome uses Cantonese (粵語) copy. Repeat for zh-TW.
- [ ] **Illustration animation**: Scene icon ring pulses, arrow bounces subtly. No perceptible performance impact.

---

## V0.6 — Diagnostics

### Pre-condition: build a side-by-side testing app

To avoid disturbing the installed `Scene.app` (its layouts, AX grant,
running hotkeys, and on-disk state), build a parallel `Scene-testing.app`:

```sh
./scripts/build-testing.sh
# or build + launch in one step:
./scripts/build-testing.sh --run
```

`Scene-testing.app` differs from production:

| Attribute            | Production              | Testing                          |
|----------------------|-------------------------|----------------------------------|
| Bundle ID            | com.hillman.SceneApp    | com.hillman.SceneApp.testing     |
| Binary / Dock name   | SceneApp                | Scene-testing                    |
| Application Support  | ~/Library/Application Support/Scene/ | ~/Library/Application Support/Scene-testing/ |
| AX TCC entry         | "SceneApp"              | "Scene-testing" (separate grant) |
| UserDefaults domain  | com.hillman.SceneApp    | com.hillman.SceneApp.testing     |

`AppDelegate.applicationSupportFolderName()` detects the `.testing`
bundle suffix and routes everything (layouts.json / settings.json /
workspaces.json / diagnostics/) into the parallel folder.

Hotkey collision: the seeded layout chords (⌘⌃1-9,0) are global and will
collide if both apps are running at once. Quit production Scene before
launching testing:

```sh
killall SceneApp 2>/dev/null; true
open dist/Scene-testing.app
```

First run will prompt for Accessibility — grant it to `Scene-testing`
(fresh TCC entry, separate from production).

### Reset between runs

```sh
killall Scene-testing 2>/dev/null; true
rm -rf ~/Library/Application\ Support/Scene-testing/diagnostics
```

To wipe everything (layouts/settings/workspaces too — start fresh):

```sh
killall Scene-testing 2>/dev/null; true
rm -rf ~/Library/Application\ Support/Scene-testing
```

### A. SceneCore unit tests

```sh
cd /Users/hillmanchan/Desktop/macbook-resizer
swift test
# expect: 317+ tests passing — privacy contract, ring buffer, writer race
# test, gunzip round-trip via /usr/bin/gunzip, sanitizer property check
```

### B. Hooks fire end-to-end

After a fresh `rm -rf` of `~/Library/Application Support/Scene-testing/diagnostics/`:

- [ ] Launch app, fire 5 layouts via hotkey + 2 workspaces via menu over ~2 minutes. Plug or unplug a monitor at least once.
- [ ] `tail -20 ~/Library/Application\ Support/Scene-testing/diagnostics/events-*.jsonl` shows valid compact JSON, one line per event, each line < 500 B.
- [ ] Inspect with `jq -c '.t' ~/Library/Application\ Support/Scene-testing/diagnostics/events-*.jsonl | sort | uniq -c` — at minimum: `lf`, `loi` (or `loa`), `axp` (when permission granted), `wst` (workspace step), `scd` (screen diff if you replugged a monitor).

### C. Privacy contract — raw log

- [ ] No user-authored text leaks into the raw `.jsonl`:
  ```sh
  grep -E "(YourName|Slack|Chrome|password|tinyspeck|com\.apple)" \
    ~/Library/Application\ Support/Scene-testing/diagnostics/events-*.jsonl
  # expect: zero matches
  ```
- [ ] Salt file is mode 0600:
  ```sh
  ls -l ~/Library/Application\ Support/Scene-testing/diagnostics/.salt
  # expect: -rw-------
  ```

### D. Disk budget

- [ ] Spam 500 layout fires (hotkey held). Verify total directory < 200 KB:
  ```sh
  du -sh ~/Library/Application\ Support/Scene-testing/diagnostics/
  ```
- [ ] **Cap-hit simulation**: pre-create 5 MB of fake jsonl, restart app, verify eviction:
  ```sh
  killall Scene-testing
  yes "abc" | head -c 5000000 > ~/Library/Application\ Support/Scene-testing/diagnostics/events-2025-01-01.jsonl.gz
  # relaunch Scene-testing.app, fire one layout
  du -sh ~/Library/Application\ Support/Scene-testing/diagnostics/
  # expect: ≤ 2 MB total (the V0.6 hard cap)
  ```

### E. Export bundle + GitHub issue handoff

- [ ] Settings → About → "Export Diagnostics for Bug Report" opens NSSavePanel with default filename `scene-diagnostics-YYYYMMDD-HHMMSS.zip`. Save to ~/Downloads.
- [ ] **After save, Finder activates and the saved `.zip` is selected** (so the user can drag it into the GitHub issue without hunting for it).
- [ ] **Default browser opens to** `https://github.com/ChiFungHillmanChan/macbook-resizer/issues/new` with:
  - Title pre-filled: `Bug: ` (cursor positioned for user to type)
  - Body pre-filled with `Scene version`, `macOS` version string, and `Diagnostic hash ID`
  - Labels applied: `bug,diagnostics`
  - Reminder section asking the user to drag the `.zip` into the issue
- [ ] Drag the zip from the Finder window into the issue body — GitHub accepts the upload and shows an attachment link.
- [ ] **Hash ID in the issue body matches `Hash ID` line in `system-info.txt`** (so the maintainer can verify zip + issue belong together).
- [ ] Unzip and inspect:
  ```sh
  cd ~/Downloads
  unzip -d /tmp/scene-diag scene-diagnostics-*.zip
  ls /tmp/scene-diag
  # expect: README.txt, system-info.txt, layouts.json, workspaces.json,
  # settings.json, events-*.jsonl, recent-events.jsonl
  ```
- [ ] PII scan on the exported zip:
  ```sh
  grep -rE "(YourWorkspaceName|tinyspeck|slackmacgap|com\.apple\.Safari)" /tmp/scene-diag
  # expect: zero matches — every name + bundle ID is hashed
  ```
- [ ] Salt is NOT in the bundle:
  ```sh
  grep -i "salt" /tmp/scene-diag/system-info.txt
  # expect: zero matches; only "Hash ID" line should appear
  ```

### F. Toggle off → on

- [ ] About tab → "Enable diagnostic logging" toggle off → confirm dialog appears in correct locale → confirm.
- [ ] `~/Library/Application Support/Scene-testing/diagnostics/` directory is empty (or gone). Fire some layouts — no new events written.
- [ ] Toggle back on. Fire layouts — new events appear, but the `.salt` is fresh (regenerated). Hash family changed.

### G. v2 → v3 settings migration

Reset to a V0.5.x state by writing a v2 settings file:

```sh
killall Scene-testing
cat > ~/Library/Application\ Support/Scene-testing/settings.json <<'EOF'
{"version":2,"animation":{"enabled":true,"durationMs":250,"easing":"easeOut"},"dragSwap":{"enabled":true,"distanceThresholdPt":40}}
EOF
# relaunch Scene-testing.app
cat ~/Library/Application\ Support/Scene-testing/settings.json
# expect: version is now 3, diagnosticsEnabled: true is present
```

### H. Localization spot-check

Switch System Settings → Language to zh-HK. Reopen Scene Settings → About:

- [ ] "Diagnostics" section title reads `診斷紀錄` in Cantonese.
- [ ] Toggle label reads `開啟診斷紀錄`. Help text uses 粵語 (撳/嘅/係/啲/喺).
- [ ] Confirm-disable dialog title reads `停止紀錄同埋刪晒？`.
- [ ] Repeat in zh-TW — copy uses 書面語 (`啟用診斷紀錄`, `停用並刪除`).

### I. Sign-off

- [ ] Build DMG: `./scripts/build-dmg.sh 0.6.0`
- [ ] Notarization succeeds. Mount DMG, drag to /Applications, launch — no Gatekeeper warnings.
- [ ] AX permission survives across the upgrade (cdhash unchanged for same Developer ID-signed binary).

| Check                       | First pass | Notes |
|-----------------------------|------------|-------|
| A (unit tests)              | | |
| B (hooks fire)              | | |
| C (raw-log privacy)         | | |
| D (disk budget)             | | |
| E (export bundle)           | | |
| F (toggle off/on)           | | |
| G (v2→v3 migration)         | | |
| H (zh-HK / zh-TW UI)        | | |
| I (DMG)                     | | |
