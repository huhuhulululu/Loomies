# TestFlight 发布手册

## 状态（2026-08-05）

| 项 | 状态 |
|----|------|
| App 工程 + 四 SPM 包 | ✅ |
| App Icon 1024 | ✅ |
| PrivacyInfo.xcprivacy | ✅ |
| 出口合规 `ITSAppUsesNonExemptEncryption=NO` | ✅ |
| 版本 `0.1.0` (build **37**) | ✅ |
| Build 37 | ✅ Delivery `26e18067-729c-4e75-acf4-abb5d2dc8f48`（D101–D105：第二轮审计 HIGH 清空 + 日间天气/打分权重/导出/派生档 + 转移史不崩 + 遥测文案跟 hasSink） |
| Build 36 | ✅ D100（4 tab 定案 + F2 死码族 + 臀宽合身） |
| Build 28 | ✅ Delivery `09d8ffe1-2731-4ba7-a8ca-68638271e5e6`（ModelSave 诚实链 + 空态/VO 扫尾 + 天气源/fail-orange + Storage 列表 + cloth-done 完善） |
| Build 27 | ✅ Delivery `3c30f1d9-51ad-4e15-8c48-d7f1d7e92e96`（Open-Meteo 天气 + 条码 Open Facts + 旅程 e2e 打磨 / displaySlot 全链路） |
| Build 26 | ✅ Delivery `8cce71fe-be57-4cbc-ae7f-bbd51a7b1d4f`（纸娃娃正确穿衣 D75：displaySlot 全链路 + 侧淡 + 空层/fitCaption） |
| Build 25 | ✅ Delivery `fcd039ee-3ab2-4435-a735-d7b06213b431`（catalog 丁字裤 + 多人种多角 + Body 流程 D71） |
| Build 24 | ✅ Delivery `f8670c42-31c3-49d8-975e-06fcf8a18347`（早期 3D/hybrid） |
| `scripts/tf-upload-now.sh` | ✅ 一键 archive+export+altool |
| Archive codesign | ✅ Manual + profile `Closet App Store TF2`（仅 App 目标） |
| ASC API 上传 | ✅ Key `YFRZC2GC2V` + Issuer 已接线 |
| Build 4 | ✅ Delivery `1971ce14-573b-4b50-857a-fbdbbb58f7ad`（BodyMorph） |
| Build 5 | ✅ Delivery `d4a70b44-09d3-4e38-a73f-6fa3f48428ed`（fine-tune 持久化） |
| Build 6 | ✅ Delivery `575a6095-4748-4c85-aab0-ceab48518d6f`（乳贴带平坦 + CG morph） |
| Build 7 | ✅ Delivery `7403fdf0-d564-4efc-85eb-b14cdef12330`（保留乳贴+丁字裤：扫描线双线性 + 双保护带） |
| Build 8 | ✅ Delivery `0a170ea3-6a8b-4f70-bdbd-f0c251f5d8b9`（日历/Me/合身网格/城市气候补全） |
| Build 9 | ✅ Delivery `b49717d4-4422-41e1-b61f-fcc7f8ace131`（棚灰统一+写实+PHPicker） |
| Build 10 | ✅ Delivery `393636e5-9b21-428e-a41b-e50eec6c00ce`（相机/Vision/本地缩略图） |
| Build 11 | ✅ Delivery `a2f3721f-5498-4946-8646-399b805cdb8e`（Today/收藏纸娃娃叠衣预览） |
| Build 12 | ✅ Delivery `23e83f97-3062-4ca9-aa99-b9b51699c825`（数据导出 + CCPA 删除全部） |
| Build 13 | ✅ Delivery `6f473b94-cfa0-4467-b43c-7df7f2131298`（旅程测试打磨） |
| Build 14 | ✅ Delivery `713d0a3a-80f1-4642-84c6-4f48d4926c39`（Today Avatar 首屏方案 B） |
| Build 15 | ✅ Delivery `f1a97831-5fb4-4132-bc10-4bc1145d8967`（Today 英雄区仔细打磨） |

**坑**：① CLI 全局 `PROVISIONING_PROFILE_SPECIFIER` 会污染 SPM 资源包；② export 时 PATH 勿让 Homebrew rsync 抢先（见 D35）。

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

# 3) 注册 Bundle ID + App 记录（首次，已完成 — 实际 ASC 记录：Loomies / Loomy001）
#    Bundle ID: com.pinglin.closet
#    Name: Loomies
#    SKU: Loomy001
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
xcrun altool --upload-app --type ios --file build/export/Loomies.ipa \
  --apiKey YFRZC2GC2V --apiIssuer "$ASC_ISSUER_ID"
```

## 状态更新（2026-08-03）

- App ASC 名：**Loomies**（id `6797632035`，bundle `com.pinglin.closet`，SKU `Loomy001`）
- IPA 已上传成功：Delivery UUID `cd57d7c8-f970-4516-8f16-980fa0ddcb78`
- TestFlight：https://appstoreconnect.apple.com/apps/6797632035/testflight/ios
- 展示名后续 build 改为 Loomies（project.yml）
