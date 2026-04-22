# Scene

一個 macOS menu bar app — click 一下，所有可見窗口即刻入位。V0.5.3 調順咗動畫（native app 升到 60Hz、duration 按距離 scale），同時加返 Intel Mac 支援（universal binary）。V0.5.2 加咗首次啟動嘅歡迎畫面，新用家一開 app 就知 Scene 喺邊。V0.4 新加咗 Workspaces（情境切換）、layout thumbnail、3 個縱向 preset 同多語 UI，建基於 V0.3 嘅 drag-to-swap、V0.2 嘅自訂 layout、自訂 hotkey、smooth animation、設定視窗。

**需要 macOS 14（Sonoma）或以上。Universal binary — Apple Silicon 同 Intel 都行到。**

> English version: [README.md](README.md)

## 安裝

**用 Homebrew**（推薦）：

```bash
brew install --cask chifunghillmanchan/tap/scene
```

自動幫你清走 quarantine flag，唔會彈「cannot be verified」嘅 Gatekeeper 警告。首次開 Scene 嗰陣，去 **System Settings → Privacy & Security → Accessibility** 撳着 Scene 就得。

**或者直接下載 DMG**：**[Scene-0.5.3.dmg](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.5.3/Scene-0.5.3.dmg)**（Universal：Apple Silicon + Intel，macOS 14+，Apple notarized — 唔會彈 Gatekeeper 警告）

所有版本：[Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) · 用 DMG 嘅話，跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Gatekeeper + Accessibility 授權步驟。

## 示範片

<video src="https://github.com/ChiFungHillmanChan/macbook-resizer/raw/main/docs/media/scene-marketing.mp4" controls muted width="720">
  你個 browser 唔 render 到 embed 嘅 video。<a href="docs/media/scene-marketing.mp4">撳呢度 download 示範片（MP4，13 MB）</a>。
</video>

## V0.5.3 動畫更順 + Intel 支援

- **Native app 動畫升到 60Hz** — `WindowAnimator` 嘅 AX write throttle 而家按動畫嘅 window 組合揀 ceiling：入面有任何 Electron app（VS Code、Cursor、Chrome、Brave、Slack、Discord、Figma、Notion、Obsidian、Teams）就維持 30Hz 保護 back-pressure；全部係 native app（Safari、Finder、Xcode、Notes、Preview、系統設定、Mail、Messages）就升到 60Hz。native app 喺同一段動畫時間內得到差唔多兩倍幀數,喺 ProMotion 屏幕上感覺明顯順啲。
- **Duration 按距離 scale** — 你喺 Settings 設定嘅 `durationMs` 而家當係「~600pt 對角線移動」嘅參考值。短距離（同 screen 內細幅度）縮到 ~70%，感覺 snappy 啲；長距離（跨屏 / 全屏重排）拉到 ~140%，冇咁匆忙。兩頭都有 clamp，最後仲有 `AnimationConfig` 本身嘅 [100, 500]ms 做 safety net。
- **AX dedup 更 tight** — 每個 window 嘅 AX write dedup tolerance 由 0.5pt 降到 0.2pt，拎返少少本來喺 easeOut 尾段被食咗嘅幀。
- **Universal binary** — Intel（x86_64）Mac 而家支援。一個 DMG 包埋兩個 slice，macOS launch 時自動揀 native 嗰個。Apple Silicon 唔使行 Rosetta。
- **Deployment target 回到 macOS 14** — Xcode 之前喺 build 機嘅 macOS 26.4 下靜雞雞將 project 嘅 `MACOSX_DEPLOYMENT_TARGET` 改咗做 26.4，今次 reset 返 14.0 同 `Package.swift` 同埋文件 support 一致。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 三個 smoothness 改動全部喺 `WindowAnimator`（AppKit bridge）入面。

## V0.5.2 首次啟動歡迎畫面

- **一次性 welcome window** — 新用家第一次授權 Accessibility 之後，會彈個歡迎視窗。確認 Scene 喺 menu bar 運行緊，用純 SwiftUI 畫咗個 menu bar mock，Scene icon 周圍有脈動嘅圈，下面有個彈上彈落嘅箭咀指住佢。兩個掣：**「知道喇」**（關閉）或者**「打開設定」**（主要 CTA，彈到 Workspaces tab）。
- **用 `UserDefaults` flag 守** — `hasShownFirstLaunchWelcomeV1` flag 跨 reinstall 保留。Flag 係**彈出嚟嗰刻**就 set（唔係 dismiss 時），即使你 `⌘Q` 中途 quit，下次 launch 都唔會再彈。
- **可以重新打開** — **Settings → About → 「再睇歡迎畫面」**可以隨時叫返個 welcome 出嚟，flag 唔會被清。
- **AX 未畀權限路徑協調** — 如果啟動時 AX 未畀，舊有 AX onboarding 先彈；用家授權咗之後，welcome 接住彈。兩個窗口唔會重疊。
- **多語支援** — 英文、繁體中文（香港）粵語、繁體中文（台灣）。
- **Dynamic 版本號** — About tab 而家由 `CFBundleShortVersionString` 讀 bundle，唔再用死咗嘅 `"V0.4"` catalog 常數，將來 bump version 唔使改 String Catalog。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 純 SceneApp UI feature。

## V0.4.3 更新提示

- **「有新版本」menu 項目** — Scene 每 24 小時撳一次 GitHub `releases/latest` API，如果遠端 tag 新過本機就喺 menu bar 頂顯示 tinted 嘅 update 項。撳落去就開 release page 下載新 DMG。冇用 Sparkle，冇 silent auto-install。
- **點解唔 auto-install？** Scene 係 ad-hoc sign，每次 build 個 `cdhash` 都變。Silent replace 會令你嘅 Accessibility 授權每次都失效，核心功能就冚。留畀你自己行 DMG，Homebrew tap 嘅 postflight（清 quarantine）先至照跑。
- **V0.4.2 之前嘅用戶要手動升一次** — 個 nudge 由今次 release 先加。v0.3 / v0.4.0 / v0.4.1 / v0.4.2 binaries 冇 update-check 邏輯，所以唔會見到提示。裝咗 v0.4.3 之後，將來發新版就會自動提你。
- **19 個新 unit test** — semver 比較 function 抽咗入 SceneCore（`isVersionTag(_:newerThan:)`）。總 test 數：158 → 177。

## V0.4.2 修 bug

- **ProMotion 動畫 lag** — AX 寫入而家 throttle 到 30Hz（由 display 原生 120Hz 減落嚟），加埋每個 window 0.5pt 範圍內 dedup。Cursor ↔ Chrome swap 返返原本設定嘅 250ms，唔再拖長到成秒以上。
- **Workspace 「一打開就預選咗」** — `activeWorkspaceID` 而家只係 session-only state。之前版本會由 disk restore 返，搞到 menu bar 顯示用戶呢個 session 冇揀過嘅 workspace 被剔住。舊 disk state 會被靜悄悄 ignore 同清走。
- **即時 Workspace click** — `appsToQuit` 空 list 唔再食 5 秒 gentle-quit grace period；`appsToLaunch` 空 list 又跳過 1.5 秒 settle。Default seed workspace click 完 ~50ms 就出 layout，唔再係 ~6.5 秒先有反應。
- **開新窗口後再撳同一個 layout** — 連續撳同一個 layout hotkey 兩次，第二次會加 200ms settle 先 re-enumerate window，畀 `CGWindowListCopyWindowInfo` 時間登記到新窗口。第一次撳 layout 嘅 latency 冇變。

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

End user：去 [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases) download DMG（或者[直接撳呢度 download 最新嘅 v0.5.3 DMG](https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v0.5.3/Scene-0.5.3.dmg)，又或者 local 跑 `scripts/build-dmg.sh`）→ 拖 `Scene.app` 入 `/Applications` → 跟住 [`docs/INSTALL.md`](docs/INSTALL.md) 做一次性嘅 Accessibility 授權。

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
./scripts/build-dmg.sh 0.5.3    # 出 dist/Scene-0.5.3.dmg（universal + notarized）
```

Build universal（arm64 + x86_64）binary，Developer ID sign，submit 去 Apple notary，pack 入 DMG 連 `Applications` drop shortcut。Apple Silicon 同 Intel Mac 用同一個 DMG。如果想 local iterate DMG layout，set `SKIP_NOTARY=1` 會 skip Apple notary submission，改用 ad-hoc sign。

### 跑 SceneCore 嘅 unit test

Layout / animation / store / hotkey 全部 logic 喺 `SceneCore`，係 Swift package，唔使 Xcode：

```bash
swift test
```

177 個 unit test 覆蓋 layout 數學、window-to-slot mapping、animation 狀態機、JSON persistence、hotkey 衝突、drag-to-swap 邏輯、update nudge 嘅 semver 比較、edge case。

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
