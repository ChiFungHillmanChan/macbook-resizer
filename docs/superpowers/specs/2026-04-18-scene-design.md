# Scene — Design Spec (V0.1)

**日期：** 2026-04-18
**目標 macOS：** 14+ (Sonoma+)
**語言：** Swift 5.9+
**外部 dependency：** 無（純 Foundation / AppKit / SwiftUI / ApplicationServices / Carbon）

---

## 1. 目標

Scene 係一個 macOS menu bar app，click 一下就可以將當前可見窗口瞬間排成 7 種 preset layout 之一。 Rectangle / Magnet 類 app 需要用戶逐個窗口揀位，Scene 一下 click 搞掂全部。

## 2. 7 個 Preset Layout

| ID | 名 | slot 數 | 描述 |
|---|---|---|---|
| `.full` | Full | 1 | 單窗口佔 100% |
| `.halves` | Halves | 2 | 左右 50/50 |
| `.thirds` | Thirds | 3 | 三直欄等寬 |
| `.quads` | Quads | 4 | 2×2 grid |
| `.mainSide` | Main+Side | 2 | 左 70% + 右 30% |
| `.leftSplitRight` | LeftSplit-Right | 3 | 左欄上下分 + 右欄 full |
| `.leftRightSplit` | Left-RightSplit | 3 | 左欄 full + 右欄上下分 |

Slot 全部用 **unit rect**（x/y/w/h ∈ [0, 1]），apply 時乘以當前 `screen.visibleFrame`（排除 menu bar + Dock）——絕對唔 hardcode pixel。

## 3. 核心行為決定

| # | 情境 | 決定 |
|---|---|---|
| 1 | 可見窗口多過 slot 數量 | 前 N 個（按 z-order）入 slot，其餘**最小化** |
| 2 | 可見窗口少過 slot 數量 | 頭 N 個 slot 放窗口，其餘 slot **留空** |
| 3 | Multi-display（V0.1） | 只處理**滑鼠所在 screen**（active screen）嘅窗口 |
| 3b | Multi-display（V0.2+） | 每個 mon 獨立 apply，detect 多 mon 時可設唔同 layout |
| 4a | Drag-to-swap 觸發時機 | 拖緊時顯示**半透明 preview overlay**；鬆手先 commit swap |
| 4b | 「最近 slot」定義 | 窗口 **center point** 同邊個 slot center **距離最短** |
| 5 | Spaces / Stage Manager | 只處理**當前 Space** 嘅窗口；Stage Manager V0.1 唔特別處理 |
| 6 | 動畫 | V0.1 **冇動畫**（即時 snap）；V0.2 再加 interpolation |
| 7a | 0 個可見窗口 | 用 `UNUserNotificationCenter` 彈「No windows to arrange」 |
| 7b | 1 個窗口 + 多 slot preset | 放 slot 1，其餘 slot 留空 |
| 8 | Settings 視窗 | V0.1 **冇**；menu bar dropdown 淨係 7 個 preset + Quit |
| 9 | Permission UX | 第一次開**彈 onboarding window**（獨立 `NSWindow`，唔係 sheet——menu bar-only app 冇 main window 掛唔到 sheet）；權限冇咗 icon **變灰** + dropdown 變 grant 按鈕 |

## 4. Architecture

**Approach：B+（Swift Package core library + 薄 Xcode App shell）**

```
macbook-resizer/
├── Package.swift                           ← SceneCore library manifest
├── Sources/SceneCore/
│   ├── AX/
│   │   ├── AXWindow.swift                  ← AXUIElement wrapper
│   │   ├── AXWindowEnumerator.swift        ← listVisibleWindows()
│   │   └── AXPermission.swift              ← permission check
│   ├── Layout/
│   │   ├── Layout.swift                    ← Layout struct + 7 presets
│   │   ├── Slot.swift                      ← unit CGRect
│   │   └── LayoutEngine.swift              ← plan() / apply()
│   ├── Interaction/
│   │   ├── DragSwapController.swift        ← AXObserver + swap
│   │   └── HotkeyManager.swift             ← Carbon RegisterEventHotKey
│   └── Display/
│       └── ScreenResolver.swift            ← active screen detection
├── Tests/SceneCoreTests/
│   ├── LayoutPlanTests.swift
│   ├── SlotMappingTests.swift
│   ├── ZOrderMappingTests.swift
│   ├── NearestSlotTests.swift
│   ├── ElectronToleranceTests.swift
│   ├── EdgeCaseTests.swift
│   └── MockWindow.swift
└── SceneApp.xcodeproj/
    └── SceneApp/
        ├── SceneApp.swift                  ← @main (App protocol)
        ├── AppDelegate.swift
        ├── MenuBarView.swift               ← SwiftUI MenuBarExtra
        ├── OnboardingView.swift
        ├── Info.plist                      ← LSUIElement = YES
        └── SceneApp.entitlements
```

### 層級邊界

| 層 | 依賴 | 責任 |
|---|---|---|
| `SceneCore` | Foundation, AppKit, ApplicationServices, Carbon | 純邏輯 + 系統 API；**冇 SwiftUI** |
| `SceneApp` | `SceneCore` + SwiftUI | UI shell、lifecycle、連接 core 同用家 |

**點解咁分：** `LayoutEngine.plan()` 係純函數，俾 `[MockWindow]` + screen frame，返回 `Plan`——可以 `swift test` 跑，唔使 Xcode。AX API 實際 call 包喺 `AXWindow`（implement `WindowRef` protocol），test 嗰陣 mock。

## 5. Core Components（Public API）

### 5.1 `WindowRef` protocol + `AXWindow`

```swift
public protocol WindowRef {
    var id: CGWindowID { get }
    var bundleID: String? { get }
    var frame: CGRect { get }
    var isMinimized: Bool { get }
    var isFullscreen: Bool { get }
    func setFrame(_ rect: CGRect) throws
    func minimize() throws
}

public struct AXWindow: WindowRef { /* 實作 */ }
```

### 5.2 `AXWindowEnumerator`

```swift
public enum AXWindowEnumerator {
    public static func listVisibleWindows(on screen: NSScreen) throws -> [AXWindow]
}
```

底層用 `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` 攞 z-order，配合 `AXUIElementCreateApplication(pid)` + `kAXWindowsAttribute` 攞 AX handle。只保留 frame center 落喺 `screen.frame` 嘅窗口；filter 走 minimized / fullscreen。

**重要：** slot rect apply 時乘以 `screen.visibleFrame`（排除 menu bar + Dock），**唔係** `screen.frame`，避免窗口排到 menu bar / Dock 下面。

### 5.3 `Layout` + `Slot`

```swift
public struct Slot: Sendable, Equatable {
    public let rect: CGRect  // unit rect, [0, 1]
}

public enum LayoutID: String, Sendable, CaseIterable {
    case full, halves, thirds, quads, mainSide, leftSplitRight, leftRightSplit
}

public struct Layout: Sendable, Identifiable {
    public let id: LayoutID
    public let name: String
    public let slots: [Slot]

    public static let full: Layout
    public static let halves: Layout
    public static let thirds: Layout
    public static let quads: Layout
    public static let mainSide: Layout
    public static let leftSplitRight: Layout
    public static let leftRightSplit: Layout

    public static var all: [Layout] { [full, halves, thirds, quads, mainSide, leftSplitRight, leftRightSplit] }
}
```

### 5.4 `LayoutEngine`

```swift
public struct Placement: Sendable {
    public let windowID: CGWindowID
    public let targetFrame: CGRect
}

public struct Plan: Sendable {
    public let placements: [Placement]
    public let toMinimize: [CGWindowID]
    public let leftEmptySlotCount: Int

    public var isEmpty: Bool { placements.isEmpty && toMinimize.isEmpty }
}

public enum Outcome: Sendable {
    case applied(placed: Int, minimized: Int, leftEmpty: Int, failed: Int)
    case noWindows
    // 註：`.noPermission` 唔屬於呢度——permission 失敗喺 enumerate / permission check 階段已經擋咗，
    // 由上層 orchestration（SceneApp 嘅 applyLayout coordinator）處理，唔會 reach `apply()`。
}

public struct LayoutEngine {
    /// 純函數——空窗口情境返 Plan(placements: [], toMinimize: [], leftEmptySlotCount: slots.count)
    /// 係 apply() 先將 Plan.isEmpty → Outcome.noWindows
    public static func plan(
        windows: [any WindowRef],
        visibleFrame: CGRect,       // 要求 caller 傳 screen.visibleFrame（排 menu bar + Dock）
        layout: Layout
    ) -> Plan

    public static func apply(
        _ plan: Plan,
        on windows: [any WindowRef],
        electronTolerancePx: CGFloat = 5
    ) throws -> Outcome
}
```

`plan()` 純函數，永遠返 `Plan`（空窗口就係空 `Plan`）；`apply()` 睇 `Plan.isEmpty` 決定返 `.noWindows`。呢樣解決「`Plan.noWindows` vs `Outcome.noWindows` 概念混咗」嘅問題。

### 5.5 `HotkeyManager`（Carbon）

```swift
public final class HotkeyManager {
    public func register(id: LayoutID, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void)
    public func unregisterAll()
}
```

用 `RegisterEventHotKey` + `InstallEventHandler`，冇外部 dependency。預設：⌘⇧1 → `.full`，⌘⇧2 → `.halves`，…⌘⇧7 → `.leftRightSplit`。

### 5.6 `DragSwapController`

```swift
public final class DragSwapController {
    public init(layoutProvider: @escaping () -> Layout?)
    public func start()  // register AXObserver + kAXMovedNotification
    public func stop()
}
```

## 6. Data Flow

### 6.1 App 啟動

```
SceneApp.init
  → AppDelegate.applicationDidFinishLaunching
  → AXPermission.check()
      ├─ denied  → 開獨立 OnboardingView window（NSWindow）→ "Open System Settings" → 每 2 秒 poll
      └─ granted → HotkeyManager.register × 7
                   DragSwapController.start()
                   MenuBarExtra icon 顯示正常色
```

### 6.2 Apply Preset

```
[click menu item] 或 [press ⌘⇧N]
      → SceneApp.applyLayout(id)  ← orchestration layer
      → AXPermission.check()
          └─ !granted → 開返 onboarding window；STOP（唔 call LayoutEngine）
      → screen = ScreenResolver.activeScreen()          // 滑鼠所在
      → windows = AXWindowEnumerator.listVisibleWindows(on: screen)
      → plan = LayoutEngine.plan(windows, screen.visibleFrame, layout)
          ├─ windows.empty              → Plan(placements: [], toMinimize: [], leftEmptySlotCount: slots)
          ├─ windows.count > slots.count → 頭 N 個 placements，其餘 toMinimize
          └─ windows.count < slots.count → N 個 placements，leftEmpty = slots - N
      → outcome = LayoutEngine.apply(plan, on: windows)
          ├─ .noWindows → notifyNoWindows()（見下）
          └─ .applied → 冇 UI feedback（靜雞雞）
```

**分層責任：**
- `AXPermission` / `SceneApp` orchestration：permission gate，失敗直接跳 onboarding
- `LayoutEngine`：只負責 frame / minimize 嘅純 logic，假設 permission 已 ok；**唔產生** `.noPermission`
- `AXWindowEnumerator`：permission 冇就 throw `AXError.apiDisabled`，由 orchestration 層 catch 同轉去 onboarding

### 6.3 Drag-to-Swap

```
AXObserver: kAXMovedNotification (window A 郁緊)
      → DragSwapController.handleMove(A, newFrame)
      → currentLayout == nil？ yes → ignore
      → targetSlotIndex = nearestSlot(center(A), layout.slots × screen.visibleFrame)
      → 顯示半透明 preview overlay @ target slot
NSEvent.addGlobalMonitorForEvents(.leftMouseUp)
      → mouseUp 觸發：
          B = window(at: targetSlot)
          A.setFrame(targetSlot)
          B?.setFrame(originalSlotOfA)
          隱藏 preview overlay
```

**AX 冇 drag-end 事件。** 用 global `.leftMouseUp` monitor 判斷 drag 結束。Drag start = 第一次收到 move notification；drag end = mouseUp。

## 7. Error Handling & Edge Cases

### 7.1 Permission

| 情境 | 行為 |
|---|---|
| 第一次開 | `OnboardingView` **獨立 NSWindow**（menu bar-only app 冇 main window 掛唔到 sheet）+ "Open System Settings" button（跳 Privacy pane） |
| 中途撤銷 | Icon 變灰；dropdown 只剩 Grant + Quit；unregister hotkey |
| 重新授予 | 每 2 秒 poll `AXIsProcessTrusted()`；granted 就重新 register |

### 7.2 AX 失敗

- `AXWindow.setFrame` 失敗 → 當個窗口 swallow error，log 低，繼續其他
- Outcome 加 `failed` count
- **唔 retry**（除咗 Electron tolerance 嗰次 retry）

### 7.3 Electron Tolerance

Cursor / VS Code / Slack 設 frame 後實際可能差 ±5px：

```swift
window.setFrame(target)
// 40 ms 等 Electron 反應
if abs(window.frame - target) > 5 {
    window.setFrame(target + (target - window.frame))   // 反向補償
}
// 最多 retry 一次
```

### 7.4 其他邊緣情況

| 情境 | 行為 |
|---|---|
| 窗口橫跨兩 mon | 跟 center 所在 mon |
| Apply 時 mouse drag 緊 | 檢查 `NSEvent.pressedMouseButtons`，按住左鍵就延後 |
| Swap 時 B 已 close | 變單向 move（A 郁去 target，B 無嘢發生） |
| Screen 排列改變 | 下次 apply 用最新 `NSScreen` |
| AX 偶發 `.cannotComplete` | Retry 一次後 skip |

### 7.6 Notification Fallback

`UNUserNotificationCenter` 要用戶授權。如果用戶拒絕通知 permission，「No windows to arrange」會靜默失敗。Fallback 策略：

```
notifyNoWindows():
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .authorized:
            發 UN notification
        else:
            Menu bar icon 短暫閃動（0.5 秒 dim → restore）
            Icon tooltip 暫時改做「No windows to arrange」（3 秒後復原）
    }
```

咁樣確保用戶至少會見到 feedback，唔會 click 咗 preset 好似無反應咁。

### 7.5 Logging

用 `os.Logger`，`subsystem = "com.scene.app"`。Console.app 可睇。唔寫檔、唔 leak 窗口 title。

## 8. Testing Strategy

### 8.1 Unit Tests（`swift test`，冇 Xcode）

- `LayoutPlanTests`：7 個 preset 喺 1920×1080 / 2560×1440 / 3840×2160 slot rect 正確
- `SlotMappingTests`：N=slots / N<slots / N>slots 三種情境
- `ZOrderMappingTests`：frontmost → slot 1
- `NearestSlotTests`：distance-based mapping
- `ElectronToleranceTests`：`rectsApproxEqual` 5px boundary
- `EdgeCaseTests`：0 / 1 窗口

用 `MockWindow: WindowRef` struct 注入——目標 core coverage > 80%。

### 8.2 Integration Tests（Xcode + AX permission）

- 開 TextEdit helper，listVisibleWindows + setFrame 驗證
- CGEvent.post 模擬 hotkey，callback 收到
- **唔放 CI**（CI 冇 AX 權限），release 前 manual 跑

### 8.3 Manual Smoke Test（每次 release 前）

```
[ ] 第一次開 → Onboarding 正確
[ ] 授權後 icon 變正常
[ ] 3 個 TextEdit + Thirds → 三欄
[ ] 5 個 TextEdit + Thirds → 頭 3 排，其餘 2 minimize
[ ] 2 個 TextEdit + Quads → slot 1/2，其餘空
[ ] ⌘⇧1–7 每個 hotkey
[ ] Apply Quads 後 drag + swap
[ ] 撤銷權限 → icon 變灰，dropdown 變 grant
[ ] Cursor/VS Code + Halves → ±5px 內
[ ] 外接 mon → 只影響滑鼠所在 mon
```

### 8.4 CI（GitHub Actions）

```yaml
jobs:
  test-core:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: swift test
```

## 9. Non-Goals（V0.1 唔做）

- Settings / Preferences 視窗
- 用戶自訂 preset（只有 7 個 hard-coded）
- 用戶自訂 hotkey（固定 ⌘⇧1–7）
- Per-app rule（「Slack 永遠放 slot 3」）
- 記住最後 layout / 自動 re-apply
- 動畫
- Stage Manager 群組特別處理
- Launch at login
- Menu bar icon 自訂

## 10. 未來版本預留 hook

- `Layout` struct 已經用 `id` enum，將來加 custom preset 只需 extend
- `HotkeyManager` 支援 runtime register/unregister，將來接 settings 零成本
- `ScreenResolver.activeScreen()` 可以演進成 `allScreens()` + per-screen layout
- `LayoutEngine.plan()` 純函數，將來加 animation 只係喺 `apply()` 層
