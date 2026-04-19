# Drag-to-Swap Deferred to V0.2

**Date:** 2026-04-19
**Plan reference:** `docs/superpowers/plans/2026-04-19-scene-v0.1.md` — Task 23 Option A

## Status

`SceneCore.DragSwapController` is fully implemented (commit `e2363f4`) and ready to use, but the **app-level wiring** — connecting `AXObserver` callbacks to `DragSwapController.handleWindowMoved(...)` — is deferred.

## Why defer

`AXObserver` requires a C callback that bridges back into Swift via an opaque pointer. Doing this correctly under Swift 6 strict concurrency is non-trivial, and V0.1 already ships the full 7-preset layout flow via menu and hotkeys.

## What V0.1 does NOT have

- Drag a window after applying a preset → window does **not** snap to nearest slot
- No swap behavior between windows

## What V0.1 DOES have

- Menu-bar click → 7 preset layouts
- ⌘⇧1–7 global hotkeys
- Permission onboarding + degraded state
- Overflow minimize / underflow empty-slot / Electron tolerance / multi-display active-screen

## V0.2 plan

1. Add `DragSwapHost` in `SceneApp/`:
   - Register `AXObserver` per pid of placed windows
   - Listen `kAXMovedNotification`
   - Bridge to `DragSwapController.handleWindowMoved`
2. Hook into `Coordinator.applyLayout` so `DragSwapHost` starts tracking after each successful apply.
3. Replace this note with implementation.
