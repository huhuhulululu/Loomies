#!/usr/bin/env bash
# TestFlight: xcodegen → archive (app-only Manual TF2) → export IPA → altool
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ASC credentials from env — see ../.env.asc.example (source .env.asc first)
export ASC_KEY_ID="${ASC_KEY_ID:?set ASC_KEY_ID (source app-shell/.env.asc)}"
export ASC_ISSUER_ID="${ASC_ISSUER_ID:?set ASC_ISSUER_ID (source app-shell/.env.asc)}"
export ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

# Prefer env, else project.yml CURRENT_PROJECT_VERSION, else fail closed (no silent “4”).
if [[ -z "${CURRENT_PROJECT_VERSION:-}" ]]; then
  CURRENT_PROJECT_VERSION=$(
    sed -n 's/.*CURRENT_PROJECT_VERSION: *"\([0-9][0-9]*\)".*/\1/p' project.yml | head -1
  )
fi
BUILD_NUM="${CURRENT_PROJECT_VERSION:?set CURRENT_PROJECT_VERSION or project.yml}"
SIGN_KC="$PWD/build/signing/closet-tf.keychain-db"

echo "==> Keychain status"
security show-keychain-info ~/Library/Keychains/login.keychain-db 2>&1 || true
if [[ -f "$SIGN_KC" ]]; then
  security unlock-keychain -p "" "$SIGN_KC" 2>/dev/null \
    || security unlock-keychain -p "closet-tf" "$SIGN_KC" 2>/dev/null \
    || true
  security list-keychains -d user -s "$SIGN_KC" ~/Library/Keychains/login.keychain-db 2>/dev/null || true
fi

echo "==> xcodegen"
xcodegen generate

echo "==> Archive (Manual only on ClosetApp via project.yml; build $BUILD_NUM)"
rm -rf build/ClosetApp.xcarchive
set -x
# 勿在 CLI 传 PROVISIONING_PROFILE_SPECIFIER — 会套到 ClosetUI_ClosetUI 资源包导致失败
xcodebuild archive \
  -project ClosetApp.xcodeproj \
  -scheme ClosetApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/ClosetApp.xcarchive" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=28626PSX5Y \
  PRODUCT_BUNDLE_IDENTIFIER=com.pinglin.closet \
  CURRENT_PROJECT_VERSION="$BUILD_NUM" \
  MARKETING_VERSION=0.1.0 \
  2>&1 | tee build/archive-tf.log
set +x

if [[ ! -d build/ClosetApp.xcarchive ]]; then
  echo "Archive missing — see build/archive-tf.log" >&2
  exit 1
fi

echo "==> Verify signature"
codesign -dvvv build/ClosetApp.xcarchive/Products/Applications/Loomies.app 2>&1 | grep -E 'Authority|Identifier|TeamIdentifier' || \
codesign -dvvv build/ClosetApp.xcarchive/Products/Applications/Closet.app 2>&1 | grep -E 'Authority|Identifier|TeamIdentifier' || true

echo "==> Export IPA (system PATH — Homebrew rsync breaks Xcode -E flags)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"
# Prefer Apple rsync over Homebrew 3.x
if [[ -x /usr/bin/rsync ]]; then
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
fi
rm -rf build/export
mkdir -p build/export
cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>teamID</key>
  <string>28626PSX5Y</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>iPhone Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.pinglin.closet</key>
    <string>Closet App Store TF2</string>
  </dict>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath build/ClosetApp.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -allowProvisioningUpdates \
  2>&1 | tee build/export-tf.log

IPA=$(find build/export -name '*.ipa' | head -1)
echo "IPA=$IPA"
if [[ -z "$IPA" ]]; then
  echo "No IPA — see build/export-tf.log" >&2
  exit 1
fi

echo "==> Upload via altool"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  2>&1 | tee build/upload-tf.log

echo "==> DONE (build $BUILD_NUM)"
