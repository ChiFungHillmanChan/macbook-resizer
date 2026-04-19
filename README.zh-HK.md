# Scene

一個 macOS menu bar app — click 一下，所有可見窗口即刻入位。V0.2 加咗自訂 layout、自訂 hotkey、smooth animation、設定視窗。

**需要 macOS 14（Sonoma）或以上。**

> English version: [README.md](README.md)

## V0.2 功能

- **7 個內建 layout preset** — Full / Halves / Thirds / Quads / Main + Side（70/30）/ LeftSplit + Right / Left + RightSplit
- **自己整 layout** — 11 種 grid template（columns / rows / 2×2 / 3×2 / 4 種 L-shape），用 slider 拖比例
- **每個 layout 自訂 hotkey**，撞 chord 會 block-save（一個 chord 只屬於一個 layout）
- **Smooth window animation** — duration 100–500ms 可調，easing 揀 Linear / Ease Out / Spring
- **設定視窗** — Layouts / Hotkeys / Animation / About（menu bar icon → Settings… 或 ⌘,）
- **一 click 整齊** — frontmost window 入 slot 1，其餘按 z-order 排
- **Overflow 處理** — 多過 slot count 嘅 window 自動 minimize
- **Electron-aware** — Cursor、VS Code、Slack 等做 ±5px retry 修正
- **Multi-display** — 只 rearrange 滑鼠所在 screen 嘅 window
- **Dock / menu bar aware** — 用 `visibleFrame`，window 永遠唔會滑入去佢哋下面
- **Animation 性能保護** — 7+ 個 window fall back 到 instant placement
- **零外部 dependency** — 純 Foundation、AppKit、SwiftUI、Carbon

## Layout 表

| ID | 名 | Slot |
|---|---|---|
| 1 | Full | 1（100%）|
| 2 | Halves | 2（50/50）|
| 3 | Thirds | 3 個等闊 column |
| 4 | Quads | 2×2 grid |
| 5 | Main + Side | 70% / 30% |
| 6 | LeftSplit + Right | 左邊 column 上下分，右邊全高 |
| 7 | Left + RightSplit | 左邊 column 全高，右邊上下分 |

## Install

End user：去 [Releases](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) download DMG（或者 local 跑 `scripts/build-dmg.sh`）→ 拖 `Scene.app` 入 `/Applications` → 跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Gatekeeper + Accessibility 授權步驟。

## 由 source build

### Prerequisites

- macOS 14+
- Xcode 16+（Mac App Store 免費下載）
- Swift 5.9+（Xcode 入面有）

### 用 Xcode build

```bash
git clone https://github.com/ChiFungHillmanChan/macbook-resizer.git
cd macbook-resizer
open SceneApp/SceneApp.xcodeproj
```

Xcode 揀 `SceneApp` scheme → ⌘R。App 以 menu bar extra 形式行（冇 Dock icon）。

### Build distributable DMG

```bash
./scripts/build-dmg.sh 0.2.0    # 出 dist/Scene-0.2.0.dmg
```

Build universal binary（arm64 + x86_64），ad-hoc sign，pack 入 DMG 連 `Applications` drop shortcut。唔使 Apple Developer account。

### 跑 SceneCore 嘅 unit test

Layout / animation / store / hotkey 全部 logic 喺 `SceneCore`，係 Swift package，唔使 Xcode：

```bash
swift test
```

92 個 unit test 覆蓋 layout 數學、window-to-slot mapping、animation 狀態機、JSON persistence、hotkey 衝突、edge case。

## 用法

1. 第一次 launch，Scene 會問 **Accessibility permission**。喺 System Settings → Privacy & Security → Accessibility 開咗佢。
2. Click menu bar 嘅 Scene icon（`rectangle.3.group`）→ 會見到 7 個 preset，下面有 Settings…
3. Click 任何 preset，或者按 ⌘⇧1 – ⌘⇧7。
4. 開 Settings…（⌘,）整自己嘅 layout、改 hotkey、調 animation。
5. Quit 用 menu 嘅 **Quit Scene**。

### Default hotkey 表

| Shortcut | Layout |
|---|---|
| ⌘⇧1 | Full |
| ⌘⇧2 | Halves |
| ⌘⇧3 | Thirds |
| ⌘⇧4 | Quads |
| ⌘⇧5 | Main + Side |
| ⌘⇧6 | LeftSplit + Right |
| ⌘⇧7 | Left + RightSplit |

V0.2 你可以改任何 chord（要至少一個非 Shift modifier，避免撞 typing）。

### Edge case 行為

| 情況 | 行為 |
|---|---|
| Window 多過 slot | 前 N 個按 z-order 入 slot，其餘 minimize |
| Window 少過 slot | Window 入晒，多餘 slot 留空 |
| 冇 visible window | macOS 通知（或 menu bar icon 閃，如果通知被禁）|
| 中途 revoke permission | Menu bar icon 變灰；hotkey 2 秒內 unregister |
| Electron app | Window 偏離 target 做一次 ±5px 修正 |
| System Settings | Apple 強制最細尺寸——position 入位但 size 縮唔細 |
| 8+ 個 window | Animation 自動 fall back 到 instant（性能保護） |
| 連續撳 hotkey | Animation interrupt + retarget，唔會 jump |

## 設定持久化

兩個 JSON 檔，atomic write 入：

```
~/Library/Application Support/Scene/
├── layouts.json     # 7 個 seed + 你 add 嘅 custom layout + 每個嘅 hotkey
└── settings.json    # animation 設定
```

刪呢個 folder 就 reset 返出廠 state。

## 架構

```
macbook-resizer/
├── Package.swift
├── Sources/SceneCore/          # 純邏輯，唔使 Xcode unit test 得
│   ├── AX/                     # Accessibility API wrapper
│   ├── Animation/              # Clock, FrameInterpolator, AnimationRunner（V0.2）
│   ├── Display/                # screen picker
│   ├── Interaction/            # hotkey + drag-swap controller
│   ├── Layout/                 # Slot, Layout, LayoutEngine + LayoutTemplate, CustomLayout, PresetSeeds, LayoutStore（V0.2）
│   └── Settings/               # AnimationConfig, HotkeyBinding, SettingsStore, Cancellable（V0.2）
├── Tests/SceneCoreTests/       # 92 個 XCTest case
├── SceneApp/                   # Xcode project — menu bar shell + 設定視窗
│   └── SceneApp/
│       ├── Animation/          # WindowAnimator（CVDisplayLink + AX bridge）
│       ├── Settings/           # SettingsWindowController + 4 個 tab + LayoutEditorView + HotkeyCaptureView
│       ├── Stores/             # LayoutStoreViewModel, SettingsStoreViewModel
│       ├── SceneAppApp.swift   # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift   # orchestration 層
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md              # 用戶安裝步驟
    └── TESTING.md              # 手動 smoke test checklist（V0.1 + V0.2）
```

故意分層：**`SceneCore` 完全 framework-neutral**——冇 SwiftUI、冇 Combine、冇 ObservableObject。所有 hard logic（AX call、layout 數學、animation 狀態機、store CRUD）住喺度，92 個 unit test 覆蓋。**`SceneApp` 係薄殼**，只負責 SwiftUI binding + AppKit lifecycle。SceneCore 用 closure-based observation 同 SceneApp 通訊（`@MainActor class FooStoreViewModel: ObservableObject` 做 adapter）。

`swift test` 由 command line 跑得，唔使 Xcode；只有最後 `.app` build 先要。

詳細架構 + 進階文檔：[Wiki（繁體中文）](https://github.com/ChiFungHillmanChan/macbook-resizer/wiki/Home-zh-HK)

## V0.3 路線圖（未做）

- **Drag-to-swap** — applyLayout 之後拖 window，自動 snap 去最近 slot 同其他 window 對調。`DragSwapController` 喺 SceneCore 已經寫好，剩 `AXObserver` bridge 未 wire。
- **Per-display layouts** — 唔同 monitor apply 唔同 preset。
- **Pattern learning** — 觀察用家手動拖 window 嘅 pattern，建議 "下午 2-5pm 通常 Cursor 70+Chrome 30，要唔要 save 做 preset?"
- **AI / 自然語言 input** — 打 "cursor 左 chrome 右" → LLM → layout JSON。
- **Per-app rule** — e.g.「Slack 永遠入 slot 4」。
- **Launch at Login** UI。
- **Free-form canvas drag** layout editor（EpycZones 嗰種）。
- **Notarization**（需要 Developer ID）— end user 就唔使做 Gatekeeper bypass。

## License

TBD。
