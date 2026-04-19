# Scene

一個 macOS menu bar app，click 一下就將所有可見窗口瞬間排成 7 種 preset layout 之一。

**要求 macOS 14 (Sonoma) 或以上。**

> English version: [README.md](README.md)

## 功能

- **7 個 preset layout** — Full、Halves、Thirds、Quads、Main+Side（70/30）、LeftSplit+Right、Left+RightSplit
- **一 click，全部窗口搞掂** — frontmost 窗口入 slot 1，其餘按 z-order 排
- **Global hotkey** — ⌘⇧1 至 ⌘⇧7
- **窗口多過 slot 自動 minimize**
- **Electron-aware** — Cursor、VS Code、Slack 等做 ±5px retry
- **Multi-display** — 只處理滑鼠所在 screen 嘅窗口
- **避開 Dock / menu bar** — 用 `visibleFrame` 確保窗口唔滑入佢哋下面
- **零 external dependency** — 純 Foundation、AppKit、SwiftUI、Carbon

## Layout 列表

| ID | 名 | Slot 數 |
|---|---|---|
| 1 | Full | 1（100%） |
| 2 | Halves | 2（50/50） |
| 3 | Thirds | 3 等寬直欄 |
| 4 | Quads | 2×2 grid |
| 5 | Main + Side | 70% / 30% |
| 6 | LeftSplit + Right | 左欄上下分，右欄 full |
| 7 | Left + RightSplit | 左欄 full，右欄上下分 |

## 安裝

**用家：** 去 [Releases](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) 下載 DMG（或者本地跑 `scripts/build-dmg.sh`），drag `Scene.app` 入 `/Applications`，然後跟 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性 Gatekeeper bypass 同 Accessibility 授權。

## 由 source 編譯

### 準備

- macOS 14+
- Xcode 16+（Mac App Store 免費）
- Swift 5.9+（隨 Xcode 入面）

### 用 Xcode build

```bash
git clone https://github.com/ChiFungHillmanChan/macbook-resizer.git
cd macbook-resizer
open SceneApp/SceneApp.xcodeproj
```

Xcode 揀 `SceneApp` scheme，⌘R。App 以 menu bar extra 身份行（冇 Dock icon）。

### Build 分發 DMG

```bash
./scripts/build-dmg.sh          # 出 dist/Scene-0.1.0.dmg
```

Universal binary（arm64 + x86_64），ad-hoc signed，帶 `Applications` drop shortcut。**唔需要** Apple Developer account。

## 用法

1. 第一次 launch，Scene 會要**Accessibility permission**。喺 System Settings → Privacy & Security → Accessibility 授權。
2. Click menu bar Scene icon（`rectangle.3.group`）→ 7 個 preset。
3. Click 任何 preset，或者按 ⌘⇧1 – ⌘⇧7。
4. 用完 menu 嘅 **Quit Scene** 退出。

### Hotkey 對照

| 快捷鍵 | Layout |
|---|---|
| ⌘⇧1 | Full |
| ⌘⇧2 | Halves |
| ⌘⇧3 | Thirds |
| ⌘⇧4 | Quads |
| ⌘⇧5 | Main + Side |
| ⌘⇧6 | LeftSplit + Right |
| ⌘⇧7 | Left + RightSplit |

### 邊緣情況

| 情境 | 行為 |
|---|---|
| 窗口多過 slot | 頭 N 個按 z-order 入 slot，其餘最小化 |
| 窗口少過 slot | 窗口入 slot，剩餘 slot 留空 |
| 冇可見窗口 | macOS notification（未授權時 menu bar icon 閃 + tooltip） |
| 中途撤權 | Menu bar icon 變灰，2 秒內 hotkey unregister |
| Electron app | 第一次 setFrame 偏差 → 一次 ±5px retry |
| System Settings | macOS 強制最細 size，只 set 到 position 唔 set 到 size |

## 架構

```
macbook-resizer/
├── Package.swift
├── Sources/SceneCore/          # 純邏輯，唔使 Xcode 都 unit-test
│   ├── AX/                     # Accessibility API wrappers
│   ├── Display/                # screen picker
│   ├── Interaction/            # hotkey + drag-swap
│   └── Layout/                 # Slot, Layout, LayoutEngine, Plan, Geometry
├── Tests/SceneCoreTests/       # 26 個 XCTest
├── SceneApp/                   # Xcode project — menu bar shell
│   └── SceneApp/
│       ├── SceneAppApp.swift          # @main + MenuBarExtra
│       ├── AppDelegate.swift
│       ├── Coordinator.swift          # orchestration 層
│       ├── MenuBarContentView.swift
│       ├── OnboardingView.swift
│       ├── OnboardingWindowController.swift
│       └── NotificationHelper.swift
└── docs/
    ├── INSTALL.md                     # end-user 安裝指引
    └── TESTING.md                     # manual smoke-test checklist
```

呢個分法係特登嘅：`SceneCore` 掌握全部硬 logic（AX call、layout math、hotkey plumbing），有 26 個 unit test cover。`SceneApp` 係薄 SwiftUI/AppKit shell，只 wire UI 同 app lifecycle。`SceneCore` 可以 `swift test` 跑，唔使裝 Xcode——只有最後 `.app` build 先需要 Xcode。

詳細架構 + 進階文檔：[Wiki（繁體中文）](https://github.com/ChiFungHillmanChan/macbook-resizer/wiki/Home-zh-HK)

## 路線圖（V0.2+）

V0.1 defer 嘅嘢：

- **Drag-to-swap** — apply preset 後 drag 任何窗口，自動 snap 去最近 slot 同嗰個位嘅窗口對換。`DragSwapController` 已寫好，只欠 `AXObserver` bridge。
- **動畫** — 用 ~150ms interpolate 取代即時 snap。
- **Per-display layout** — 同時喺唔同 mon apply 唔同 preset。
- **Settings 視窗** — Launch at Login、自訂 hotkey、rename/hide preset。
- **Per-app rule** — 例如「Slack 永遠放 slot 3」。

## License

待定。
