# Scene

一個 macOS menu bar app — click 一下，所有可見窗口即刻入位。V0.4 新加咗 Workspaces（情境切換）、layout thumbnail、3 個縱向 preset 同多語 UI，建基於 V0.3 嘅 drag-to-swap、V0.2 嘅自訂 layout、自訂 hotkey、smooth animation、設定視窗。

**需要 macOS 14（Sonoma）或以上。**

> English version: [README.md](README.md)

## 安裝

**用 Homebrew**（推薦）：

```bash
brew install --cask chifunghillmanchan/tap/scene
```

自動幫你清走 quarantine flag，唔會彈「cannot be verified」嘅 Gatekeeper 警告。首次開 Scene 嗰陣，去 **System Settings → Privacy & Security → Accessibility** 撳着 Scene 就得。

**或者直接下載 DMG**：**[Scene-0.4.1.dmg](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.4.1/Scene-0.4.1.dmg)**（約 1.4 MB，Apple Silicon，macOS 14+）

所有版本：[Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) · 用 DMG 嘅話，跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Gatekeeper + Accessibility 授權步驟。

## 示範片

<video src="https://github.com/ChiFungHillmanChan/macbook-resizer/raw/main/docs/media/scene-marketing.mp4" controls muted width="720">
  你個 browser 唔 render 到 embed 嘅 video。<a href="docs/media/scene-marketing.mp4">撳呢度 download 示範片（MP4，13 MB）</a>。
</video>

## V0.4 新功能

- **Workspaces（情境）** — 一嚿 bundle 包住 layout + apps + Focus 模式 + 自動觸發（手動 / monitor / 時間 / 日曆），撳一下就切換成個工作情境
- **Layout thumbnail** — menu bar 同設定度每個 layout 都即時 render 出 slot 比例嘅小圖
- **3 個新縱向 preset** — Main + Side Vertical（⌘⌃8）、Halves Vertical（⌘⌃9）、Thirds Vertical（⌘⌃0）
- **多語 UI** — 完整支援 English + 繁體中文（香港）；部分支援 繁體中文（台灣）
- 連埋 V0.2（自訂 + 動畫）、V0.3（drag-to-swap）一齊出，係首次公開 release

## V0.3 — 拖拉交換

- **拖視窗就可以重排**：揸住任何 placed window 拖落另一個 placed window 嘅位，source 即時 snap，被換走嗰個行 V0.2 動畫引擎（250ms easeOut，跟 Animation tab 嘅設定）。
- **Interaction tab**：開 / 閂 drag-to-swap；拖拉距離 threshold 可調（10–100pt）。
- **逃生出口**：揸住 ⌥ 拖就唔 swap（free-move）；drag 中途撳 Esc 就 cancel，視窗 snap 返原位。
- **Unit test 數目**：92 → 116 個（V0.4.1 再加到 158）。

## V0.4.1 修補

- **DMG 瘦身到 1.4 MB**（上一版 2.8 MB）— 靠 `-Osize`、LZFSE、pngquant 壓縮 icon 同埋重新設計嘅安裝視窗背景。
- **靚仔安裝視窗** — 自訂背景圖加埋方向箭頭，icon 位置 pin 死，收埋 toolbar/sidebar，畫面好清。
- **Workspace 啟動更穩** — layout 套唔到嗰陣唔會再彈「已啟動」通知；single-flight 防止多次啟動打架；日曆 keyword 留空唔會再誤撞所有 event。
- **授權指引更清晰** — 重新安裝後 macOS 綁住舊 cdhash 嘅授權失效，onboarding 視窗直接畀你 `tccutil reset` 指令同一個「複製」按鈕，唔使再試「toggle OFF/ON」呢啲唔可靠嘅做法。
- `WorkspaceStore.insert` 加防重複 ID guard。

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

End user：去 [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) download DMG（或者[直接撳呢度 download 最新嘅 v0.4.1 DMG](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.4.1/Scene-0.4.1.dmg)，又或者 local 跑 `scripts/build-dmg.sh`）→ 拖 `Scene.app` 入 `/Applications` → 跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Gatekeeper + Accessibility 授權步驟。

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
./scripts/build-dmg.sh 0.4.1    # 出 dist/Scene-0.4.1.dmg
```

Build Apple Silicon（arm64）binary，ad-hoc sign，pack 入 DMG 連 `Applications` drop shortcut。唔使 Apple Developer account。macOS 14 嘅機絕大多數都係 Apple Silicon；如果要兼容 Intel Mac，喺 build script 加返 `ARCHS="arm64 x86_64"`。

### 跑 SceneCore 嘅 unit test

Layout / animation / store / hotkey 全部 logic 喺 `SceneCore`，係 Swift package，唔使 Xcode：

```bash
swift test
```

158 個 unit test 覆蓋 layout 數學、window-to-slot mapping、animation 狀態機、JSON persistence、hotkey 衝突、drag-to-swap 邏輯、edge case。

## 用法

1. 第一次 launch，Scene 會問 **Accessibility permission**。喺 System Settings → Privacy & Security → Accessibility 開咗佢。
2. Click menu bar 嘅 Scene icon（`rectangle.3.group`）→ 會見到 7 個 preset，下面有 Settings…
3. Click 任何 preset，或者按 ⌘⌃1 – ⌘⌃7。
4. 開 Settings…（⌘,）整自己嘅 layout、改 hotkey、調 animation。
5. Quit 用 menu 嘅 **Quit Scene**。

### Default hotkey 表

| Shortcut | Layout |
|---|---|
| ⌘⌃1 | Full |
| ⌘⌃2 | Halves |
| ⌘⌃3 | Thirds |
| ⌘⌃4 | Quads |
| ⌘⌃5 | Main + Side |
| ⌘⌃6 | LeftSplit + Right |
| ⌘⌃7 | Left + RightSplit |

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
│   ├── Interaction/            # HotkeyManager, DragSwapController,
│   │                           #   WindowAnimationSink, WindowMoveObserving
│   ├── Layout/                 # Slot, Layout, LayoutEngine + LayoutTemplate, CustomLayout, PresetSeeds, LayoutStore（V0.2）
│   └── Settings/               # AnimationConfig, HotkeyBinding, DragSwapConfig,
│                               #   SettingsStore, Cancellable
├── Tests/SceneCoreTests/       # 158 個 XCTest case
├── SceneApp/                   # Xcode project — menu bar shell + 設定視窗
│   └── SceneApp/
│       ├── Animation/          # WindowAnimator（CVDisplayLink + AX bridge）
│       ├── Interaction/        # AXMoveObserverGroup, AXWindowLookup, DragSwapAnimationSink（V0.3）
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
    └── TESTING.md              # 手動 smoke test checklist（V0.1–V0.4）
```

故意分層：**`SceneCore` 完全 framework-neutral**——冇 SwiftUI、冇 Combine、冇 ObservableObject。所有 hard logic（AX call、layout 數學、animation 狀態機、store CRUD、drag-to-swap）住喺度，158 個 unit test 覆蓋。**`SceneApp` 係薄殼**，只負責 SwiftUI binding、AppKit lifecycle，同埋 framework-neutral library 做唔到嘅 AppKit/AX bridge（`WindowAnimator`、`AXMoveObserverGroup`、`AXWindowLookup`、`DragSwapAnimationSink`）。SceneCore 用 closure-based observation 同 SceneApp 通訊（`@MainActor class FooStoreViewModel: ObservableObject` 做 adapter）。

`swift test` 由 command line 跑得，唔使 Xcode；只有最後 `.app` build 先要。

詳細架構 + 進階文檔：[Wiki（繁體中文）](https://github.com/ChiFungHillmanChan/macbook-resizer/wiki/Home-zh-HK)

## V0.5 路線圖（未做）

- **Per-display layouts** — 唔同 monitor apply 唔同 preset。
- **Pattern learning** — 觀察用家手動拖 window 嘅 pattern，建議 "下午 2-5pm 通常 Cursor 70+Chrome 30，要唔要 save 做 preset?"
- **AI / 自然語言 input** — 打 "cursor 左 chrome 右" → LLM → layout JSON。
- **Per-app rule** — e.g.「Slack 永遠入 slot 4」。
- **Launch at Login** UI。
- **Free-form canvas drag** layout editor（EpycZones 嗰種）。
- **Notarization**（需要 Developer ID）— end user 就唔使做 Gatekeeper bypass。

## License

MIT —睇 [`LICENSE`](LICENSE)。
