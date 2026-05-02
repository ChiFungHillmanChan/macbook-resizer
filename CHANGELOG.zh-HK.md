# 更新紀錄

Scene 嘅完整版本史，最新嘅 release 喺最頂。

要 download binary，去 [Releases page](https://github.com/ChiFungHillmanChan/macbook-resizer/releases)。

## V0.6.1 — 閒置模式（Free Mode）

- **一掣暫停 Scene。** Menu bar 多咗個「閒置模式」row（喺 Layouts 同 Settings 之間）。撳一下，Scene 嘅自動行為全部暫停：layout 快捷鍵（⌘⌃1-9,0）、workspace 快捷鍵（⌘⌥1-4）、拖邊互換、seam resize、同 workspace 嘅自動觸發（接駁 monitor / 時間 / calendar event）。已儲存嘅 layout、workspace、快捷鍵綁定、設定統統保留 — 純粹係唔再自動 fire，撳返一下就回復正常。閒置時 row 入面有個 ✓，Layouts 同 Workspaces 嗰啲 row 變灰，menu bar 個 icon 由 `rectangle.3.group` 變 `pause.rectangle`，一眼睇得出 Scene 而家停咗。
- **每次開 Scene 都係正常啟動。** 閒置模式只係 in-memory state — quit 之後再開 Scene 永遠都係正常運作模式，唔會記住你上次撳過。冇得忘記咗 Scene 仲喺度暫停緊。
- **冇改 SceneCore；test 維持 317/317** — 純 SceneApp UI + Coordinator gating。State 喺 `Coordinator.freeMode`（`@Published Bool`），喺 `applyLayout(_:)` / `applyWorkspace(id:)` 入口擋走，配合 `TriggerSupervisor.paused` 處理自動觸發。Drag-swap 嘅 AX observer closure 入面 gate，observer 本體唔會停，所以 toggle 返開唔使重新 arm。

## V0.6.0 — 診斷紀錄 + 持續性 Workspaces

- **診斷紀錄。** Settings → 關於 加咗「診斷紀錄」section。Default 開咗，Scene 會將 layout / workspace 啟動 / AX 權限變化 / 螢幕排列改變 / 動畫結果等運作事件紀錄落 `~/Library/Application Support/Scene/diagnostics/events-YYYY-MM-DD.jsonl`，連動畫入面被 `os.Logger` 食咗嘅 AX `setFrame` 失敗都見到。disk 上限 2 MB hard cap，每日切檔 gzip 壓縮，保留 7 日。撳 toggle off 會 drain 個 writer + 完全刪走啲嘢；off → on 會重新 generate salt（forward secrecy）。**「匯出診斷紀錄畀 bug 報告用」**個掣會包一個 sanitized zip — workspace 名、bundle ID、mon 名、calendar 關鍵字、Focus shortcut 名全部換成 11-character SHA hash，salt 永遠唔會離開你部 Mac（只係 export 個 `hashID` 出去，bundle 入面嘅 hash 可以互相對照但唔會反向出 plaintext） — 完成之後 Finder 跳出嚟 highlight 個 zip + 自動開瀏覽器去 GitHub issue（已 pre-fill 環境資料同 hash ID）。報 bug 而家 30 秒搞掂。
- **持續性 Workspaces。** Workspace 多咗三個 field：**Pinned Apps**（啟動時必定 launch，視為屬於呢個 workspace），**Assign to Desktop 1-9**（Scene 會 post Mission Control 嘅「Switch to Desktop N」shortcut 切去指定嘅 Space），同**Enforcement Mode**（Off / Arrange only / Hide inactive pinned apps / Quit inactive pinned apps）。揀 Hide 或者 Quit 嘅話，切 workspace 嗰陣會自動 hide 或者 quit 上一個 workspace 嘅 pinned apps，每個 workspace 永遠都係淨係見到自己嘅 app。macOS 冇公開 API 強制第三方 window 留喺指定 Space，所以呢個係「切 desktop + pin app + hide/quit 強制」，唔係真係搬 window 過去。要喺 System Settings → 鍵盤 → 鍵盤快速鍵 → Mission Control 入面 enable 咗「Switch to Desktop N」先 work。
- **Workspace 編輯器 Save UX。** Save 掣冇改動時 disable，改緊嘢時顯示灰色「有未儲存嘅改動」，撳完顯示綠色「已儲存 ✓」2 秒。冇得再撳完唔知有冇 save 到。
- **測試：244 → 317。** 73 個新 test，覆蓋 `DiagnosticEvent` Codable + byte-cap、`EnvironmentSnapshot` signature 嘅穩定性同對解像度 / scale / main flag / active 變化嘅敏感度、`EventLog` ring buffer、`DiagnosticWriter` actor（race-safe drain — 單一 `AsyncStream` + 唯一 consumer，冇 detached `Task {}`）、`DiagnosticBudget`（newline 安全 truncate + eviction + 7 日 retention）、`GzipWriter`（用 `/usr/bin/gunzip` round-trip 驗證）、`SaltStore`（mode 0600 + regenerate）、`ExportSanitizer`（PII drop 嘅 property check）、`SettingsStore` v2 → v3 migration。

## V0.5.7 — 自訂排列 + 拖邊同步 + Save 掣有反應

- **自己畫任何形狀嘅排列。** Settings → Layouts 多咗個「+ Custom」掣（square-on-square 個 icon）。撳落去，右邊係一個全屏嘅空白畫布 — 撳任何一格，出 menu：「橫向拆開」、「縱向拆開」、「刪除呢格」。逐層切，切到你想要嘅形狀：3 窄 + 2 闊、唔對稱嘅 L+4、7 格嘅 dashboard — 你諗到嘅都畫到。存 + 綁 hotkey，跟內建排列一樣用。用戶自己畫嘅排列而家同 11 個內建 template 平起平坐。
- **拖一個 window 邊，隔籬嗰個自動跟住郁。** Scene 已經幫你 tile 好之後，你拉邊個 window 嘅邊，隔籬嗰個會實時縮放填滿個 gap。支援 `twoCol` / `twoRow` / `threeCol` / `threeRow`（單隔隙切法；三欄/三行中間格會自動判斷你拉緊邊嗰個邊）。自訂排列（custom tree）暫時未跟郁 — reflow 數學而家仲係靠 template 嘅 axis，要支援任意 tree 要再寫；下個 release 補。拖嗰陣揸住 Option 就 bypass 呢個行為，macOS 自己去 resize，Scene 唔理。
- **Save 掣終於真係有用，仲會俾你知做咗嘢。** 修咗 Settings → Layouts 嘅兩個 bug。(a) 以前撳 Save 係 silent no-op — 睇落似 save 咗係因為 slider 每動一下都 auto 寫入 store，但係 `.onChange(of: draft.template)` 會喺你切去第二個 layout 嗰陣悄悄將 proportion reset 返 default，結果你改過嘅嘢就咁被洗咗。而家個 editor 用 `@State draft` + 明確 call `LayoutStore.update`，同 `WorkspaceEditorView` pattern 一致。(b) Save 掣而家配合 dirty-state — 成功 save 完之後即刻暗咗，有新改動先再光返。再唔駛估你撳嗰下究竟入咗去冇。
- **多 screen coordinate 修補。** 重寫咗 `AXWindow` wrapper 同 drag-swap observer callback 嘅 AX ↔ NSScreen coordinate 轉換 — 所有 drag-swap / seam-resize 嘅計算而家統一喺 NSScreen（bottom-left）coordinate system 入面行，top-left 嘅 AX 轉換淨係喺 boundary 一次到位。多 screen setup（第二個 monitor 喺主 screen 下面或者左邊嗰啲 arrangement）而家 drag-swap 同 seam-resize 都會計到正確嘅目標位置，唔會再有 window 飛出 screen 外面嘅情況。
- **Tests：177 → 244。** 加咗 67 個新 unit test 覆蓋 `LayoutReflow`（pure seam math）、`SeamResizeController`（event handling + self-fire guard + config gating）、`LayoutNode`（tree flatten + Codable + 100% coverage invariant + 完整 5 格示例）、加 `CustomLayout` 嘅 legacy JSON decode round-trip — 由 v0.5.6 升上嚟，舊 layouts.json 一定 decode 到，啲舊 layout 唔會冇咗。

## V0.5.6 — In-app update installer

- **撳 → 自動裝 → 自動重開，唔使再手動 download。** Menu 入面「有新版本」而家會出個確認 alert，唔再淨係開 GitHub release page。撳 **「安裝並重開」** Scene 就會自動 download 新版本 DMG（先核對係咪 Team ID `22K6G3HH9G` 簽嘅）、行 detached helper script、quit、helper 用 `ditto --noqtn` 換咗 `/Applications/Scene.app`（保留 `com.apple.macl` xattr — TCC 嘅 Accessibility 授權靠呢個錨定）、再開新 Scene。想睇 changelog 先安裝？「睇 Release Notes」掣仲喺度。
- **Accessibility 授權跨版本保留。** TCC 將授權綁喺 binary 嘅 Designated Requirement 度，呢個喺同一個 Developer ID 簽嘅 release 之間係穩定嘅。配合 `ditto --noqtn` 嘅 xattr-preserving copy，新 Scene 開機嗰陣 `AXIsProcessTrusted` 已經係 true — 唔使重新 grant、唔使去 System Settings 撳掣、唔使行 `tccutil reset`。（V0.5.5 → V0.5.6 仲係要手動裝一次，因為 V0.5.5 個 menu 仲係淨係開 GitHub page；之後 V0.5.6 起就行 in-app installer。）
- **裝之前要驗簽。** Download 完嘅 DMG 會做 `codesign -dv` 檢查，`TeamIdentifier` 要對到先過。Team ID 唔對直接 reject，彈 error alert 出嚟，唔會默默裝錯嘢。
- **Helper script 自包含、安全。** 寫去 `/tmp/`，`ditto` 之前 backup 舊 app 去 `/tmp/Scene.app.bak-$$`，`ditto` 失敗就 rollback；`hdiutil detach` unmount DMG、刪走 cache、自我刪除。Log 寫去 `/tmp/scene-update-<pid>.log` 方便事後 debug。
- **SceneCore 冇改；測試仲係 177/177 全通過** — `UpdateInstaller.swift` 喺 SceneApp 度係新嘅；`UpdateChecker` 加咗幾行去 surface GitHub release `assets[]` 嘅 `dmgURL`。

## V0.5.5 — Quit-relaunch 即時 check 新版本 + Workspaces delete 掣

- **Quit + relaunch 即時撳 GitHub check 新版本** — `UpdateChecker.startPeriodicChecks()` 喺 launch 時而家會 bypass 24 小時冷卻。之前如果 Scene 喺 v0.5.3 已經 cache 咗 `lastCheckedAt`（嗰時 v0.5.4 仲未 publish），而你喺 24 小時內 quit 再 relaunch，就會悄悄 skip 咗 GitHub call，menu bar 完全唔會見到「有新版本」。每個鐘嘅 background timer 同 wake-from-sleep 仍然守 24 小時冷卻（嗰啲 fire 唔需要用家 intent，要保護 GitHub rate limit）。
- **Workspaces tab toolbar 加返 delete 掣** — `WorkspacesTab` toolbar 而家有 `trash` 掣，同 `LayoutsTab` 一樣。之前淨係靠 `List.onDelete` swipe gesture，但係 macOS NavigationSplitView 上幾乎冇人發現呢個手勢，用家以為四個 seeded workspace（Coding、Meeting、Reading、Streaming）係冇得 delete。Inline-swipe 保留做 secondary affordance。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 純 SceneApp UI / 生命週期修補。

## V0.5.4 — 首次啟動可靠性 + Accessibility 升級救援

- **Welcome 唔再等 Accessibility 先彈** — 一次性 welcome 視窗而家喺第一次 launch 即刻彈，唔再 gate 喺 `AXIsProcessTrusted`。之前由 ad-hoc-signed v0.4.x 升上 notarized v0.5+ 嘅用家，因為 cdhash 改咗 TCC 對唔上，AX 永遠授唔到，結果 welcome 永遠唔出。新流程：welcome 先彈 → 用家 dismiss 之後，如果 AX 仲未授權，先彈 onboarding。
- **Accessibility 救援提示一開始就睇到** — `tccutil reset Accessibility com.hillman.SceneApp` 指令、**複製指令**掣、貼到 Terminal 嘅步驟，喺 onboarding 視窗一開就睇到。之前要撳「再檢查」失敗一次先會出，但係大部分用家喺 System Settings 撳着之後就等 2 秒輪詢自動偵測，根本冇撳「再檢查」，所以一直冇睇過救援指令。
- **返返嚟嘅用家如果未授權，自動彈 onboarding** — 如果 welcome flag 已經 set 但 AX 仲係冇授權，啟動時會自動彈 onboarding，唔使再喺 menu bar 度搵「Grant Accessibility」呢個收埋嘅選項。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 純 SceneApp UI / 生命週期修補。

## V0.5.3 — 動畫更順 + Intel 支援

- **Native app 動畫升到 60Hz** — `WindowAnimator` 嘅 AX write throttle 而家按動畫嘅 window 組合揀 ceiling：入面有任何 Electron app（VS Code、Cursor、Chrome、Brave、Slack、Discord、Figma、Notion、Obsidian、Teams）就維持 30Hz 保護 back-pressure；全部係 native app（Safari、Finder、Xcode、Notes、Preview、系統設定、Mail、Messages）就升到 60Hz。Native app 喺同一段動畫時間內得到差唔多兩倍幀數，喺 ProMotion 屏幕上感覺明顯順啲。
- **Duration 按距離 scale** — 你喺 Settings 設定嘅 `durationMs` 而家當係「~600pt 對角線移動」嘅參考值。短距離（同 screen 內細幅度）縮到 ~70%，感覺 snappy 啲；長距離（跨屏 / 全屏重排）拉到 ~140%，冇咁匆忙。兩頭都有 clamp，最後仲有 `AnimationConfig` 本身嘅 [100, 500]ms 做 safety net。
- **AX dedup 更 tight** — 每個 window 嘅 AX write dedup tolerance 由 0.5pt 降到 0.2pt，拎返少少本來喺 easeOut 尾段被食咗嘅幀。
- **Universal binary** — Intel（x86_64）Mac 而家支援。一個 DMG 包埋兩個 slice，macOS launch 時自動揀 native 嗰個。Apple Silicon 唔使行 Rosetta。
- **Deployment target 回到 macOS 14** — Xcode 之前喺 build 機嘅 macOS 26.4 下靜雞雞將 project 嘅 `MACOSX_DEPLOYMENT_TARGET` 改咗做 26.4，今次 reset 返 14.0 同 `Package.swift` 同埋文件 support 一致。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 三個 smoothness 改動全部喺 `WindowAnimator`（AppKit bridge）入面。

## V0.5.2 — 首次啟動歡迎畫面

- **一次性 welcome window** — 新用家第一次授權 Accessibility 之後，會彈個歡迎視窗。確認 Scene 喺 menu bar 運行緊，用純 SwiftUI 畫咗個 menu bar mock，Scene icon 周圍有脈動嘅圈，下面有個彈上彈落嘅箭咀指住佢。兩個掣：**「知道喇」**（關閉）或者**「打開設定」**（主要 CTA，彈到 Workspaces tab）。
- **用 `UserDefaults` flag 守** — `hasShownFirstLaunchWelcomeV1` flag 跨 reinstall 保留。Flag 係**彈出嚟嗰刻**就 set（唔係 dismiss 時），即使你 `⌘Q` 中途 quit，下次 launch 都唔會再彈。
- **可以重新打開** — **Settings → About → 「再睇歡迎畫面」**可以隨時叫返個 welcome 出嚟，flag 唔會被清。
- **AX 未畀權限路徑協調** — 如果啟動時 AX 未畀，舊有 AX onboarding 先彈；用家授權咗之後，welcome 接住彈。兩個窗口唔會重疊。
- **多語支援** — 英文、繁體中文（香港）粵語、繁體中文（台灣）。
- **Dynamic 版本號** — About tab 而家由 `CFBundleShortVersionString` 讀 bundle，唔再用死咗嘅 `"V0.4"` catalog 常數，將來 bump version 唔使改 String Catalog。
- **SceneCore 冇改；測試仲係 177/177 全通過** — 純 SceneApp UI feature。

## V0.4.3 — 更新提示

- **「有新版本」menu 項目** — Scene 每 24 小時撳一次 GitHub `releases/latest` API，如果遠端 tag 新過本機就喺 menu bar 頂顯示 tinted 嘅 update 項。撳落去就開 release page 下載新 DMG。冇用 Sparkle，冇 silent auto-install。
- **點解唔 auto-install？** Scene 係 ad-hoc sign，每次 build 個 `cdhash` 都變。Silent replace 會令你嘅 Accessibility 授權每次都失效，核心功能就冚。留畀你自己行 DMG，Homebrew tap 嘅 postflight（清 quarantine）先至照跑。
- **V0.4.2 之前嘅用戶要手動升一次** — 個 nudge 由今次 release 先加。v0.3 / v0.4.0 / v0.4.1 / v0.4.2 binaries 冇 update-check 邏輯，所以唔會見到提示。裝咗 v0.4.3 之後，將來發新版就會自動提你。
- **19 個新 unit test** — semver 比較 function 抽咗入 SceneCore（`isVersionTag(_:newerThan:)`）。總 test 數：158 → 177。

## V0.4.2 — 修 bug

- **ProMotion 動畫 lag** — AX 寫入而家 throttle 到 30Hz（由 display 原生 120Hz 減落嚟），加埋每個 window 0.5pt 範圍內 dedup。Cursor ↔ Chrome swap 返返原本設定嘅 250ms，唔再拖長到成秒以上。
- **Workspace 「一打開就預選咗」** — `activeWorkspaceID` 而家只係 session-only state。之前版本會由 disk restore 返，搞到 menu bar 顯示用戶呢個 session 冇揀過嘅 workspace 被剔住。舊 disk state 會被靜悄悄 ignore 同清走。
- **即時 Workspace click** — `appsToQuit` 空 list 唔再食 5 秒 gentle-quit grace period；`appsToLaunch` 空 list 又跳過 1.5 秒 settle。Default seed workspace click 完 ~50ms 就出 layout，唔再係 ~6.5 秒先有反應。
- **開新窗口後再撳同一個 layout** — 連續撳同一個 layout hotkey 兩次，第二次會加 200ms settle 先 re-enumerate window，畀 `CGWindowListCopyWindowInfo` 時間登記到新窗口。第一次撳 layout 嘅 latency 冇變。

## V0.4.1 — 修補

- **DMG 瘦身到 1.4 MB**（上一版 2.8 MB）— 靠 `-Osize`、LZFSE、pngquant 壓縮 icon 同埋重新設計嘅安裝視窗背景。
- **靚仔安裝視窗** — 自訂背景圖加埋方向箭頭，icon 位置 pin 死，收埋 toolbar/sidebar，畫面好清。
- **Workspace 啟動更穩** — layout 套唔到嗰陣唔會再彈「已啟動」通知；single-flight 防止多次啟動打架；日曆 keyword 留空唔會再誤撞所有 event。
- **授權指引更清晰** — 重新安裝後 macOS 綁住舊 cdhash 嘅授權失效，onboarding 視窗直接畀你 `tccutil reset` 指令同一個「複製」按鈕，唔使再試「toggle OFF/ON」呢啲唔可靠嘅做法。
- `WorkspaceStore.insert` 加防重複 ID guard。

## V0.4 — Workspaces

- **Workspaces（情境）** — 一嚿 bundle 包住 layout + apps + Focus 模式 + 自動觸發（手動 / monitor / 時間 / 日曆），撳一下就切換成個工作情境。
- **Layout thumbnail** — menu bar 同設定度每個 layout 都即時 render 出 slot 比例嘅小圖。
- **3 個新縱向 preset** — Main + Side Vertical（⌘⌃8）、Halves Vertical（⌘⌃9）、Thirds Vertical（⌘⌃0）。
- **多語 UI** — 完整支援 English + 繁體中文（香港）；部分支援 繁體中文（台灣）。
- 連埋 V0.2（自訂 + 動畫）、V0.3（drag-to-swap）一齊出，係首次公開 release。

### V0.3 — 拖拉交換

- **拖視窗就可以重排** — 揸住任何 placed window 拖落另一個 placed window 嘅位，source 即時 snap，被換走嗰個行 V0.2 動畫引擎（250ms easeOut，跟 Animation tab 嘅設定）。
- **Interaction tab** — 開 / 閂 drag-to-swap；拖拉距離 threshold 可調（10–100pt）。
- **逃生出口** — 揸住 ⌥ 拖就唔 swap（free-move）；drag 中途撳 Esc 就 cancel，視窗 snap 返原位。
- **Unit test 數目** — 92 → 116 個（V0.4.1 再加到 158）。

### V0.2 — 自訂 + 動畫

- **10 個內建 layout preset** — Full、Halves、Thirds、Quads、Main + Side（70/30）、LeftSplit + Right、Left + RightSplit，加埋三個縱向 variant。
- **11 種 grid template** 連 proportion slider，畀你自己整 layout。
- **每個 layout 自訂 hotkey**，撞 chord 會 block-save。
- **Smooth window animation** — duration 100–500 ms 可調，easing 揀 Linear / Ease Out / Spring。

### V0.1 — 首次釋出

- 撳一下就將 active screen 上面所有可見 window snap 入 layout。
- Frontmost window 入 slot 1，其餘按 z-order 排。
- Overflow window 自動 minimize；用 `visibleFrame`，window 永遠唔會滑入 menu bar / Dock 下面。
- 26 個 unit test。
