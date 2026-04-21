# Scene — Apple Developer 帳戶啓用後嘅完整 Setup（粵語版）

呢份文件係喺你 Apple Developer Program 帳戶（US$99/年）啓用之後，由「攞 Developer ID certificate」一路做到「用家唔使撳 right-click → Open 就可以開 app」嘅完整 checklist。

> **前提**：Apple 通常要 24–48 細個鐘審批你嘅會籍。未啓用之前，你可以按住 **Part 0（準備）** 嘅嘢先做一部分（例如整 icon、寫 entitlements），但 Part A 之後嘅嘢冇 Team ID / certificate 係做唔到嘅。

---

## 0. 準備（啓用前可以做）

### 0.1 檢查 icon set 係咪完整

而家嘅 `SceneApp/SceneApp/Assets.xcassets/AppIcon.appiconset/` 有 16 / 32 / 128 / 256 @1x 同 @2x，但**冇 512@2x（即係 1024×1024）**。Apple 嘅 notarization 本身唔強制要，但：

- Xcode 16 build 嘅時候會出 warning
- Finder 喺 Retina 顯示屏顯示 app icon 嘅時候，1024 版本先可以 crisp
- 第日如果要上 Mac App Store，1024 係硬性要求

**點整 1024×1024**：你要有一張 1024×1024 嘅原始 PNG（例如 `Scene-icon-source.png`）。如果冇，可以用而家嘅 512 升 scale（但會少少糊）：

```bash
cd ~/Desktop/macbook-resizer/SceneApp/SceneApp/Assets.xcassets/AppIcon.appiconset

# 方法 A：有 1024 原圖（最好），假設放喺 ~/Desktop/Scene-icon-1024.png
sips -z 1024 1024 ~/Desktop/Scene-icon-1024.png --out icon_512x512@2x.png

# 方法 B：用 512 升到 1024（會糊，唔建議長期用）
sips -z 1024 1024 icon_512x512.png --out icon_512x512@2x.png

# Compress 返（跟返 V0.4.1 嘅 pngquant workflow）
pngquant --quality=65-80 --ext .png --force icon_512x512@2x.png
```

然後要改 `Contents.json`，喺 `images` array 尾添返呢個 entry：

```json
{
  "filename" : "icon_512x512@2x.png",
  "idiom" : "mac",
  "scale" : "2x",
  "size" : "512x512"
}
```

搞掂之後 `swift build` / `xcodebuild` 應該冇 warning。

### 0.2 準備 entitlements 檔案

而家個 project 冇 `.entitlements`。Hardened runtime 已經開咗（`ENABLE_HARDENED_RUNTIME = YES`），但 notarization 建議你有個 explicit 嘅 entitlements 檔，就算係空嘅都好，咁可以擺明你冇用 sandbox、冇用 JIT 之類嘅嘢。

新增 `SceneApp/SceneApp/SceneApp.entitlements`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

> **點解咁寫？** Scene 嘅核心功能（AX API 控制 window）同 sandbox 係唔兼容嘅 — sandbox 會封鎖 Accessibility API。所以明確聲明 `app-sandbox = false`。呢個**唔會**影響 notarization 通過率，因為 Developer ID distribution 根本唔要求 sandbox，只有 Mac App Store 先要。

喺 Xcode 入面 link 呢個檔案：

1. 開 `SceneApp/SceneApp.xcodeproj`
2. 揀 `SceneApp` target → **Signing & Capabilities** tab
3. Code Signing Entitlements 欄位寫 `SceneApp/SceneApp.entitlements`
4. 或者直接喺 pbxproj 搵 `CODE_SIGN_ENTITLEMENTS` setting 加入

### 0.3 Info.plist 加 export compliance key

而家 `Info.plist` 冇聲明加密嘢。Scene 淨係用系統標準 HTTPS / TLS（更新檢查嘅 `URLSession`），咁樣符合 Apple 嘅 **exempt** 條件。加個 key 就唔使以後每年填 export compliance 問卷：

喺 `SceneApp/SceneApp/Info.plist` 嘅 `<dict>` 入面加：

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

> 呢個 key 主要影響 App Store Connect，Developer ID 只 distribution 唔係硬性要，但加咗以後如果你改 submission path 都唔使再搞。

### 0.4 確認 `LSUIElement`

Scene 係 menu bar only app，開嘅時候 activation policy 係 `.accessory`。但 `Info.plist` 最好有埋 `LSUIElement`，咁 macOS 一 launch 就知道唔使展示 Dock icon（而家係 runtime 先 set）。

喺 `Info.plist` 加：

```xml
<key>LSUIElement</key>
<true/>
```

> **留意**：呢個 key 一加咗，Settings window 開嗰陣你要保留 `NSApp.setActivationPolicy(.regular)` 嗰段 code（`AppDelegate` 應該已經有），唔係 Settings window 會失焦。

---

## Part A：Apple Developer 登入 + 攞 Certificate

### A.1 登入 developer.apple.com

1. 去 <https://developer.apple.com/account/> 用 `hillmanchan709@gmail.com` 登入
2. 首次登入會要求你同意幾份 agreement（Program License Agreement / Paid Apps 之類），全部撳 **Accept**
3. 喺左邊 menu 撳 **Membership** → 紀錄低你嘅 **Team ID**（10 位英數字符，例如 `A1B2C3D4E5`）

**Team ID 之後會用喺呢啲地方**：
- `codesign` 嘅 identity string
- `notarytool` 嘅 `--team-id` 參數
- GitHub Actions secrets（如果之後自動化）

### A.2 生成 Developer ID Application Certificate

Scene 要嘅係 **Developer ID Application**（DMG 分發用），**唔係** Apple Development 或者 Mac App Distribution。

**方法 A（建議）— 用 Xcode 自動生成**：

1. 開 Xcode → **Settings…** → **Accounts** tab
2. 撳左下角 **+** → **Apple ID** → 輸入 `hillmanchan709@gmail.com` 同密碼
3. 登入成功之後，右邊見到你個 team
4. 撳 **Manage Certificates…** → 左下角 **+** → 揀 **Developer ID Application**
5. Xcode 會自動 generate certificate + private key 落你 login keychain

**方法 B — 喺 web portal 生成**：

1. developer.apple.com → **Certificates, Identifiers & Profiles** → **Certificates** → **+**
2. 揀 **Developer ID Application**
3. 根據指示用 Keychain Access 整個 CSR（Certificate Signing Request）upload
4. 下載 `developerID_application.cer` → 雙擊 import 入 login keychain

### A.3 驗證 certificate 已經裝咗

Terminal 打：

```bash
security find-identity -v -p codesigning
```

應該睇到類似咁嘅 line：

```
1) AB12CD34... "Developer ID Application: Chi Fung Hillman Chan (A1B2C3D4E5)"
     1 valid identities found
```

**紀錄低呢個完整 identity string**，包埋引號入面嗰段，例如：

```
Developer ID Application: Chi Fung Hillman Chan (A1B2C3D4E5)
```

### A.4 生成 App-Specific Password（俾 notarytool 用）

Apple ID 本身有 2FA，`notarytool` 冇辦法直接用你嘅主密碼，要用 app-specific password。

1. 去 <https://appleid.apple.com/account/manage>
2. 登入 → **Sign-In and Security** → **App-Specific Passwords**
3. 撳 **+** → label 填 `scene-notarytool` → 記低 Apple 俾你嘅 16 位密碼（例如 `abcd-efgh-ijkl-mnop`）
4. 呢個密碼淨係會展示一次，記好佢

### A.5 喺 keychain 儲低 notarytool credentials

咁你以後 notarize 唔使每次打密碼：

```bash
xcrun notarytool store-credentials "scene-notary" \
    --apple-id "hillmanchan709@gmail.com" \
    --team-id "A1B2C3D4E5" \
    --password "abcd-efgh-ijkl-mnop"
```

（替換返你自己嘅 Team ID 同 app-specific password）

之後喺 `build-dmg.sh` 入面就用 `--keychain-profile "scene-notary"` 引用，唔再見得到密碼。

---

## Part B：改 Xcode Project 設定

### B.1 喺 Xcode project 揀返 Signing

1. 開 `SceneApp/SceneApp.xcodeproj`
2. 揀 `SceneApp` target → **Signing & Capabilities** tab
3. **Team**：揀你個 Apple Developer team
4. **Signing Certificate**：
   - Debug：**Development**（日常開發用）
   - Release：**Developer ID Application**（distribution 用）
5. **Automatically manage signing**：建議開住，Xcode 會幫你生 profile

> **留意 bundle ID**：而家係 `com.hillman.SceneApp`。如果你想改（例如 `com.chifunghillmanchan.scene`），而家係最後嘅機會 — 一旦 notarize 咗就唔會再改。不過對 Developer ID 分發嚟講，bundle ID 唔係唯一 identifier（Apple 只 scope 去你個 team），冇強烈理由要改。

### B.2 Register App ID（如果用 manual signing）

如果 automatic signing 搞唔掂，你要手動去 developer.apple.com 登記 App ID：

1. **Certificates, Identifiers & Profiles** → **Identifiers** → **+**
2. 揀 **App IDs** → **App**
3. Description：`Scene`
4. Bundle ID：`Explicit` → `com.hillman.SceneApp`
5. Capabilities：**唔使**揀任何（Scene 冇用 iCloud / Push / HealthKit 之類）
6. 撳 **Continue** → **Register**

Automatic signing 嘅話 Xcode 會自己搞，唔使做呢步。

### B.3 驗證可以 build signed binary

```bash
cd ~/Desktop/macbook-resizer
xcodebuild \
    -project SceneApp/SceneApp.xcodeproj \
    -scheme SceneApp \
    -configuration Release \
    -derivedDataPath build-test \
    CODE_SIGN_IDENTITY="Developer ID Application: Chi Fung Hillman Chan (A1B2C3D4E5)" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM=A1B2C3D4E5 \
    ARCHS="arm64" \
    build
```

Build 完之後檢查個 binary 有冇正式 sign 到：

```bash
codesign --verify --deep --strict --verbose=4 \
    build-test/Build/Products/Release/SceneApp.app
```

應該講 `valid on disk` 同 `satisfies its Designated Requirement`。

執 test 之後 `rm -rf build-test`。

---

## Part C：改 `scripts/build-dmg.sh` 加 Notarization

而家 `build-dmg.sh` 係 ad-hoc sign（`CODE_SIGN_IDENTITY="-"`）。我哋要：

1. 改做 Developer ID sign
2. 加 `--timestamp`（notarization 要求 secure timestamp）
3. 加 `--options runtime`（hardened runtime — 其實 Xcode 已經開咗，但 codesign flag 要重申）
4. Sign 埋個 DMG 檔本身
5. Submit 去 notarytool 等結果
6. Staple ticket 入 DMG
7. 最後 verify 過 Gatekeeper

### C.1 改動嘅完整 diff（示意）

喺 `scripts/build-dmg.sh` 最頂加 variable：

```bash
# Developer ID — 改做你自己嘅 identity
DEVELOPER_ID="Developer ID Application: Chi Fung Hillman Chan (A1B2C3D4E5)"
NOTARY_PROFILE="scene-notary"
```

跟住 build step 由：

```bash
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS="arm64" \
    VALID_ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null
```

改做：

```bash
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$(echo "$DEVELOPER_ID" | sed -E 's/.*\(([A-Z0-9]+)\).*/\1/')" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    ARCHS="arm64" \
    VALID_ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null
```

### C.2 喺 DMG build 完之後加 notarize + staple

喺 script 最尾（`hdiutil verify` 之後，`rm -rf "$STAGE_DIR"` 之前）加：

```bash
echo "==> Signing DMG itself with Developer ID…"
codesign --force --sign "$DEVELOPER_ID" --timestamp "$DIST_DIR/$DMG_NAME"

echo "==> Submitting DMG to Apple notary service…"
echo "    （通常 2-10 分鐘，唔好 interrupt）"
xcrun notarytool submit "$DIST_DIR/$DMG_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> Stapling notary ticket to DMG…"
xcrun stapler staple "$DIST_DIR/$DMG_NAME"

echo "==> Verifying Gatekeeper acceptance…"
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$DIST_DIR/$DMG_NAME"
```

### C.3 可選 — 加個 `--skip-notary` flag

有時你想快速 test DMG 本身（例如 Finder layout），唔想等 notarize。可以加：

```bash
SKIP_NOTARY="${SKIP_NOTARY:-0}"

if [[ "$SKIP_NOTARY" == "0" ]]; then
    # Sign DMG + notarize + staple + spctl
    ...
else
    echo "==> SKIP_NOTARY=1 — 唔 submit 去 Apple，淨係本地 ad-hoc sign"
    codesign --force --sign "-" "$DIST_DIR/$DMG_NAME"
fi
```

咁用法：

```bash
./scripts/build-dmg.sh 0.5.0              # 正式 release，有 notarization
SKIP_NOTARY=1 ./scripts/build-dmg.sh 0.5.0-dev   # 本地 test 用
```

---

## Part D：第一次 Notarized Build（端到端）

### D.1 Pre-flight check

```bash
# 1. Swift tests 綠燈
swift test

# 2. Keychain 有 Developer ID
security find-identity -v -p codesigning | grep "Developer ID Application"

# 3. Notary profile 存在
xcrun notarytool history --keychain-profile scene-notary 2>&1 | head -5
#    （初次用會出「No submissions yet」，但冇 error 就 OK）
```

### D.2 Bump version

1. 改 `SceneApp/SceneApp.xcodeproj/project.pbxproj` 入面：
   - `MARKETING_VERSION = 0.4.3;` → `MARKETING_VERSION = 0.5.0;`
   - `CURRENT_PROJECT_VERSION = 7;` → `CURRENT_PROJECT_VERSION = 8;`
2. 改 `README.md`、`README.zh-HK.md` 入面提到嘅 `0.4.3` → `0.5.0`

### D.3 行個完整 build

```bash
cd ~/Desktop/macbook-resizer
./scripts/build-dmg.sh 0.5.0
```

呢個 script 會：
1. Clean 之前嘅 build
2. 用 Developer ID sign `Scene.app`
3. 整個 DMG 出嚟
4. Sign 埋個 DMG
5. **Submit 去 Apple**（要等 2–10 分鐘）
6. Staple 個 ticket 入 DMG
7. 用 `spctl` 驗證

成功嘅話，最後會見到：

```
==> Verifying Gatekeeper acceptance…
dist/Scene-0.5.0.dmg: accepted
source=Notarized Developer ID
```

### D.4 搞錯咗點算？

**如果 `notarytool submit` fail**：會俾你個 submission ID。用呢個 command 睇詳細 log：

```bash
xcrun notarytool log <submission-id> \
    --keychain-profile scene-notary
```

常見 issue：
- **`The binary is not signed with a valid Developer ID certificate`** — 你 ad-hoc sign 咗個 binary，改返 `build-dmg.sh` 嘅 `CODE_SIGN_IDENTITY`
- **`The executable does not have the hardened runtime enabled`** — 確認 `OTHER_CODE_SIGN_FLAGS` 有 `--options=runtime`
- **`The signature of the binary is invalid`** — 確認 `--timestamp` 有加，同埋你行 build 嗰陣電腦有 internet（timestamp server 要 online）

### D.5 本地 sanity check

搞掂之後，喺你自己部機：

```bash
# 1. Mount 個 DMG
open dist/Scene-0.5.0.dmg

# 2. 拖 Scene.app 落 Applications
# 3. 去 Applications 雙擊 Scene.app
```

**應該冇任何 Gatekeeper 警告**。Apple 會後台 verify 個 notary ticket — 如果 internet 好，直接開；冇 internet 嘅情況下會睇 staple 過嘅 ticket，都係一樣開到。

---

## Part E：發 GitHub Release

### E.1 用 `gh` CLI 整 release

```bash
cd ~/Desktop/macbook-resizer

# 1. 確認你喺 main branch + working tree 乾淨
git status

# 2. Tag + push
git tag v0.5.0
git push origin v0.5.0

# 3. Create release（draft 先，驗證冇錯）
gh release create v0.5.0 \
    --draft \
    --title "v0.5.0 — Notarized Developer ID distribution" \
    --notes-file /tmp/scene-release-notes.md \
    dist/Scene-0.5.0.dmg
```

`/tmp/scene-release-notes.md` 內容（示例）：

```markdown
## What's new

- **Notarized + stapled DMG.** 唔再需要 right-click → Open 繞過 Gatekeeper。雙擊就直接開。
- **Accessibility grant 唔再因為 update 而 reset.** Developer ID 嘅 `cdhash` 穩定，以後 upgrade 你唔使再 `tccutil reset`。
- （其他新 feature）

## Upgrade path

- Homebrew: `brew upgrade --cask scene`
- DMG: 落載下面個 DMG，拖入 Applications，直接開
```

### E.2 測試 draft

1. 去 <https://github.com/ChiFungHillmanChan/macbook-resizer/releases>
2. 睇到 draft release，按 **Edit**，copy 個 DMG URL
3. **喺第二部乾淨嘅 Mac**（或者新 user account）落載呢個 DMG
4. 直接雙擊 — 應該冇 warning 直接開
5. 如果 OK，返去 GitHub release page → **Publish release**

> **點解要喺乾淨嘅 Mac test？** 你自己部機已經 trust 咗你嘅 certificate，所以就算 notarization 失敗都會開到 — 冇辦法單靠你自己部機驗證。

### E.3 Publish 之後

`git push origin v0.5.0` 觸發 tag push，但 release publish 先會觸發 `notify-website.yml` workflow（佢係 listen `release.published`）。所以上面個 **draft → publish** 嘅 step 係必要嘅。

---

## Part F：更新 Scene 網站（scene_landing_website）

個網站用 Astro，data 由 `scripts/fetch-releases.mjs` 由 GitHub API 抽。兩個 path：

### Path F1（自動）— 等 notify-website.yml 做

1. `notify-website.yml` 喺 release publish 嘅時候 trigger Vercel deploy hook
2. Vercel 重新 build → `fetch-releases.mjs` 由 `gh api` 抽最新 release → 寫入 `src/data/latest-release.json` + `src/data/releases.json`
3. 約 1 分鐘之內 scene.hillmanchan.dev（或你 domain）嘅 Download button 就會指向新版

**驗證**：

```bash
cd ~/Desktop/scene_landing_website

# 手動 trigger rebuild（如果 workflow 冇 fire 或者你想 verify）
node scripts/fetch-releases.mjs

# 睇下 JSON 對唔對
cat src/data/latest-release.json | head -20
```

應該見到 `"version": "0.5.0"` 同 `"dmgUrl": "…/Scene-0.5.0.dmg"`。

### Path F2（手動 fallback）— 如果自動唔 work

萬一 workflow 冇 trigger（例如 `VERCEL_DEPLOY_HOOK` secret 未設好）：

```bash
cd ~/Desktop/scene_landing_website

# 改 latest-release.json
# 改 releases.json（prepend 新 entry）

git add src/data/latest-release.json src/data/releases.json
git commit -m "chore: bump to v0.5.0 (notarized)"
git push
# Vercel 會自動 deploy
```

### F3 檢查 INSTALL 頁

`src/pages/install.astro` 同 `src/pages/zh-hk/install.astro` 入面應該**刪走** Gatekeeper bypass 嘅指示（例如「right-click → Open」、「xattr -d」）。改做：

```
1. 落載 Scene-0.5.0.dmg
2. 雙擊打開
3. 拖 Scene.app 去 Applications
4. 喺 Launchpad 或 Applications 開 Scene
5. 俾 Accessibility 權限（系統設定 → 私隱與安全性 → 輔助使用）
```

咁樣步驟大幅簡化。搵呢類 keyword 嚟搜：

```bash
cd ~/Desktop/scene_landing_website
rg -i "gatekeeper|right-click|control-click|xattr|cannot be verified"
```

### F4 首頁 hero 文案可能要改

而家 landing page 有冇提 「ad-hoc signed」、「快速右 click 打開」之類嘅 wording？搜一搵：

```bash
rg -i "ad-hoc|gatekeeper|accessibility grant|cdhash|tccutil"
```

有嘅話全部刪晒或者改做「notarized by Apple — 一 click 就開到」。

---

## Part G：更新 Homebrew Tap

你有個 separate repo `homebrew-tap`（路徑通常係 `~/Desktop/homebrew-tap` 或者類似），入面有 `Casks/scene.rb` 大概咁樣：

```ruby
cask "scene" do
  version "0.4.3"
  sha256 "..."

  url "https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v#{version}/Scene-#{version}.dmg"
  name "Scene"
  desc "One-click window layout menu bar app"
  homepage "https://github.com/ChiFungHillmanChan/macbook-resizer"

  app "Scene.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Scene.app"]
  end
end
```

### G.1 Bump 版本 + hash

```bash
# 1. 計新 DMG 嘅 SHA256
shasum -a 256 ~/Desktop/macbook-resizer/dist/Scene-0.5.0.dmg
# 輸出：xxxxxxxxxxx...  Scene-0.5.0.dmg

# 2. 改 Casks/scene.rb
#    - version "0.4.3" → "0.5.0"
#    - sha256 "..." → 上面嗰個 hash

# 3. 刪走 postflight（notarized DMG 唔需要 strip quarantine）
```

### G.2 改完之後嘅 `scene.rb`（乾淨版）

```ruby
cask "scene" do
  version "0.5.0"
  sha256 "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  url "https://github.com/ChiFungHillmanChan/macbook-resizer/releases/download/v#{version}/Scene-#{version}.dmg"
  name "Scene"
  desc "One-click window layout menu bar app for macOS"
  homepage "https://github.com/ChiFungHillmanChan/macbook-resizer"

  depends_on macos: ">= :sonoma"

  app "Scene.app"

  zap trash: [
    "~/Library/Application Support/Scene",
    "~/Library/Preferences/com.hillman.SceneApp.plist",
  ]
end
```

### G.3 Test 個 cask

```bash
# 本地 install
brew uninstall --cask scene || true
brew install --cask ~/Desktop/homebrew-tap/Casks/scene.rb

# 確認 Scene.app 入咗 Applications，直接開到
open -a Scene

# Commit + push
cd ~/Desktop/homebrew-tap
git add Casks/scene.rb
git commit -m "scene: 0.4.3 → 0.5.0 (notarized)"
git push
```

用戶之後：

```bash
brew update
brew upgrade --cask scene   # 拎新版
```

---

## Part H：更新 App 內部 + Docs 文案

### H.1 `docs/INSTALL.md`

而家呢份有大段 Gatekeeper bypass（right-click → Open、spctl、xattr）。改做：

```markdown
## Install from DMG

1. Download `Scene-0.5.0.dmg` from the [Releases page](...).
2. Double-click to mount.
3. Drag `Scene.app` into `Applications`.
4. Open Scene from Launchpad or `/Applications`.

Scene 已經由 Apple notarize，所以唔會出現 "cannot be verified" 警告。

## First-launch permission

On first launch, Scene 會要求 Accessibility permission…
```

刪走 "Option A / Option B / Option C" 呢幾個 workaround section。

### H.2 `docs/TESTING.md`

Smoke-test checklist 應該加一 row：

```markdown
- [ ] Fresh install from notarized DMG — 直接雙擊，冇 Gatekeeper prompt
- [ ] Upgrade from previous notarized version — Accessibility grant 保留（唔使重新授權）
```

### H.3 Onboarding UI（`SceneApp/SceneApp/OnboardingView.swift`）

而家 onboarding 有段 "Still not detected? Run `tccutil reset Accessibility com.hillman.SceneApp`" 同 **Copy Command** button。呢啲係 ad-hoc sign 時代嘅 workaround。

**Notarized 之後可以淡化**（但唔好完全刪 — 第一次由 ad-hoc 版本 upgrade 上嚟嘅用戶始終要跑一次）：

改 copy 大約做：

```
「如果你由 v0.4.3 或之前升級嚟 v0.5.0，macOS 會因為 signing 方式改變咗
認為係一隻新 app，所以 Accessibility 權限要重新授權一次。

呢個係 one-time，升級到 v0.5.0 之後所有未來嘅 update 都會保留權限。」
```

相關檔案：`SceneApp/SceneApp/Resources/Localizable.xcstrings`，搵 key `onboarding.stillNotDetected` / `onboarding.tccutilHint` 之類（check 返 actual key name）。

### H.4 `CLAUDE.md`

而家最尾有段 "V0.5 deferred" 寫住 `Notarization (requires Developer ID)`。呢個 item 可以 move 上去 "V0.5 delivered" 或者直接刪。

---

## Part I：以後每個 Release 嘅 Checklist

```
□ 1. Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION（pbxproj）
□ 2. Update README.md + README.zh-HK.md 裡面嘅版本號
□ 3. swift test — 177（或更多）全綠
□ 4. ./scripts/build-dmg.sh X.Y.Z — 包含 notarize + staple
□ 5. Mount DMG → drag 去 /Applications → 雙擊 — 冇 Gatekeeper warning
□ 6. 喺第二部 Mac（或新 user account）測試同樣嘅 flow
□ 7. git tag vX.Y.Z && git push origin vX.Y.Z
□ 8. gh release create vX.Y.Z --draft … dist/Scene-X.Y.Z.dmg
□ 9. Draft release 入面 copy 個 DMG URL，喺乾淨機再 download test
□ 10. Publish release
□ 11. 等 notify-website.yml 觸發 Vercel rebuild（1–2 分鐘）
□ 12. 開 scene.hillmanchan.dev — Download button 應該自動指新版
□ 13. Update homebrew tap (Casks/scene.rb) + push
□ 14. brew upgrade --cask scene 自己 test 一次
□ 15. 如果冇問題，post 去社交平台 / Reddit r/MacApps
```

---

## Part J：可能出問題（Troubleshooting）

### J.1 Notarization 話 "Invalid" 但 log 冇寫原因

```bash
xcrun notarytool log <submission-id> --keychain-profile scene-notary notary.log
open notary.log
```

揾 `issues` array 入面。最常見：
- `The signature of the binary is invalid` → rebuild 同檢查 `--timestamp`
- `The executable requests the com.apple.security.get-task-allow entitlement` → debug build leak 咗入嚟，確認係 Release config
- `The binary uses an SDK older than the 10.9 SDK` → 唔應該 happen（Scene 要求 macOS 14），但 check 返 `MACOSX_DEPLOYMENT_TARGET`

### J.2 `spctl --assess` 話 `rejected`

```bash
spctl --assess -t open --context context:primary-signature -vv dist/Scene-0.5.0.dmg
```

如果話 `unsigned or signed by rejected authority` — 多數係 staple 失敗。再跑：

```bash
xcrun stapler staple -v dist/Scene-0.5.0.dmg
```

如果話 `CloudKit Encountered an error (-1011)` — Apple server hiccup，等 5 分鐘再試。

### J.3 Users 話 "app is damaged and can't be opened"

呢個 error 通常係 DMG download 斷線 corrupt，或者 quarantine bit 加錯。
解決：

```bash
# 喺用家部機
xattr -cr /Applications/Scene.app
```

但 notarized 版本理論上唔會撞呢個問題。如果多個用家 report，可能係你個 GitHub release asset 上傳失敗 — 重新 upload。

### J.4 Xcode 話 "No signing certificate for 'Developer ID Application'"

```bash
# 確認 certificate 有 import
security find-identity -v -p codesigning

# 如果真係 miss 咗，由 Xcode → Settings → Accounts → Manage Certificates 
# → Developer ID Application → "Download" （唔係 create 新嘅）
```

### J.5 Apple Developer 帳戶 renew

Apple Developer Program 係 US$99/年，會自動 renew。如果過期：
- 你現有 notarized build **仍然 work** — staple 過嘅 ticket 冇到期
- 但你**唔可以再整新 notarization submission**
- Certificate 會 invalidate，下次 build 要 renew 先再 sign

Calendar 或 Notion set 個 reminder，到期前 30 日 check。

---

## Part K：安全事項

### K.1 App-specific password 管理

- 呢個 password 只俾 `notarytool` 用，**唔好**commit 入 git
- 已經喺 keychain 儲咗（`notarytool store-credentials`），唔會再出現喺 terminal history
- 如果洩露咗：去 appleid.apple.com → **App-Specific Passwords** → **Revoke**

### K.2 Certificate 嘅 private key

- Xcode 生成嘅 private key 淨係喺**呢部機**嘅 login keychain
- 換機或者備份：Keychain Access → 揀個 certificate → **File → Export Items…** → 存 `.p12`（要設密碼）→ 擺喺 1Password / safe
- 失咗 private key 嘅話 revoke 舊 certificate + 生新嘅（冇辦法 recover）

### K.3 GitHub Actions 用 notarization（將來 automation）

如果以後你想 CI build + notarize，你要：
1. Export `.p12`（certificate + private key）
2. Base64 encode：`base64 -i scene-cert.p12 | pbcopy`
3. 擺做 GitHub secret：`DEVELOPER_ID_P12_BASE64`
4. 另外 secret：`DEVELOPER_ID_P12_PASSWORD`、`NOTARY_APPLE_ID`、`NOTARY_TEAM_ID`、`NOTARY_PASSWORD`
5. Workflow 入面 decode + import 去 temporary keychain

呢部分**唔建議而家做** — 手動 release 更簡單，而且 GitHub Actions macOS runner 貴（每分鐘 10x cost）。

---

## 快速參考

| 常用 command | 用途 |
|---|---|
| `security find-identity -v -p codesigning` | List signing identities |
| `codesign --verify --deep --strict -vvv Scene.app` | Verify signing |
| `spctl --assess -t open -v Scene.dmg` | Gatekeeper 模擬 |
| `xcrun notarytool submit Scene.dmg --keychain-profile scene-notary --wait` | 交 notary |
| `xcrun notarytool history --keychain-profile scene-notary` | 睇 submission history |
| `xcrun notarytool log <id> --keychain-profile scene-notary` | 睇 fail reason |
| `xcrun stapler staple Scene.dmg` | Staple notary ticket |
| `xcrun stapler validate Scene.dmg` | 確認 staple 成功 |
| `shasum -a 256 Scene.dmg` | 計 Homebrew cask 嘅 SHA |

---

## 結尾

搞掂呢啲之後：

- 用戶**一 click 就開到** Scene，冇 Gatekeeper 攔路
- Homebrew cask 簡化咗（唔使 quarantine strip）
- Accessibility 權限**會保留**過升級
- 你可以喺 README 同 landing page 寫「Notarized by Apple」呢個 trust signal
- CLAUDE.md 嘅 "V0.5 deferred" list 至少少咗一 item

接住 V0.5 可以返去做真正嘅 feature（per-display layouts、pattern learning、etc）— signing/distribution 嘅雜務 one-time cost 已經 pay 咗。

祝 ship 順利 🚀
