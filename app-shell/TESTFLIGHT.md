# TestFlight 发布手册

## 状态（2026-08-03）

| 项 | 状态 |
|----|------|
| App 工程 + 四 SPM 包 | ✅ |
| App Icon 1024 | ✅ |
| PrivacyInfo.xcprivacy | ✅ |
| 出口合规 `ITSAppUsesNonExemptEncryption=NO` | ✅ |
| 版本 `0.1.0` (2) | ✅ |
| `scripts/testflight.sh` | ✅ |
| Archive codesign | ⛔ login keychain 在本 agent 环境不可交互解锁（`errSecInternalComponent`） |
| ASC API 上传 | ⛔ 缺 **Issuer ID**（已有 Key `YFRZC2GC2V` + p8） |

## 你本机 Terminal.app 一键（推荐）

在 **Terminal.app**（非 agent）执行，会弹出钥匙串授权：

```bash
cd /Users/ping/code/cloth/app-shell

# 1) 解锁钥匙串（弹出密码框）
security unlock-keychain ~/Library/Keychains/login.keychain-db

# 2)（若尚未）填 Issuer ID
# 从 https://appstoreconnect.apple.com/access/integrations/api 复制 Issuer ID
cp -n .env.asc.example .env.asc
# 编辑 .env.asc 填 ASC_ISSUER_ID=...
source .env.asc

# 3) 注册 Bundle ID + App 记录（首次）— 用 API 或网页：
#    Bundle ID: com.pinglin.closet
#    Name: Closet
#    SKU: closet-001
#    主语言: English (U.S.)
#    可用性: United States only (D9)

# 4) Archive + 上传
./scripts/testflight.sh
```

成功后到 [App Store Connect → TestFlight](https://appstoreconnect.apple.com/apps) 等处理（通常 5–30 分钟），加内部测试员。

## 仅 Xcode GUI

1. `open ClosetApp.xcodeproj`
2. Signing：Team = Ping Lin (`28626PSX5Y`)，Automatic
3. Product → Archive
4. Distribute App → App Store Connect → Upload
5. ASC 网页补：隐私问卷、出口合规、TestFlight 内测组

## 首次 ASC 必填（网页，无法全自动）

- 隐私营养标签：无追踪；Usage Data 若上遥测再改（当前 PrivacyInfo 未采集合规声明）
- 年龄分级
- 截图（可用模拟器截 6.7"）
- 审核备注：copilot demo seeds for empty closet

## 命令对照

```bash
# 仅 archive
xcodebuild archive -project ClosetApp.xcodeproj -scheme ClosetApp \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/ClosetApp.xcarchive -allowProvisioningUpdates

# 导出 IPA（不上传）
xcodebuild -exportArchive -archivePath build/ClosetApp.xcarchive \
  -exportOptionsPlist ExportOptions-ipa.plist -exportPath build/export \
  -allowProvisioningUpdates

# 有 Issuer 后上传
xcrun altool --upload-app --type ios --file build/export/Closet.ipa \
  --apiKey YFRZC2GC2V --apiIssuer "$ASC_ISSUER_ID"
```
