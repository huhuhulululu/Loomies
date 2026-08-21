#!/usr/bin/env bash
# LEGACY Automatic signing path. Do not use for TestFlight.
# Canonical (Manual, app-only, same as build 44): ./scripts/tf-upload-now.sh
# 需要：
#   1) DEVELOPMENT_TEAM 证书（已有 iPhone Distribution / Apple Development）
#   2) App Store Connect API：
#        export ASC_KEY_ID=YFRZC2GC2V
#        export ASC_ISSUER_ID=<Issuer UUID from ASC → Users → Integrations → Keys>
#        export ASC_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_YFRZC2GC2V.p8
#   或 Xcode 已登录 Apple ID（Automatic signing + allowProvisioningUpdates）
set -euo pipefail
echo "NOTE: legacy Automatic path. For TestFlight use ./scripts/tf-upload-now.sh" >&2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
ARCHIVE="$ROOT/build/ClosetApp.xcarchive"
EXPORT_DIR="$ROOT/build/export"
SCHEME=ClosetApp
PROJECT="$ROOT/ClosetApp.xcodeproj"

cd "$ROOT"
command -v xcodegen >/dev/null || { echo "xcodegen missing — brew install xcodegen" >&2; exit 1; }
xcodegen generate

mkdir -p "$ROOT/build"

echo "==> Archive (generic iOS device; Automatic — not the TestFlight path)"
# tee only: pipefail + grep used to fail a successful archive that printed
# no matching lines (grep exit 1). Full log is still in archive.log.
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=28626PSX5Y \
  CODE_SIGN_STYLE=Automatic \
  2>&1 | tee "$ROOT/build/archive.log"

if [[ ! -d "$ARCHIVE" ]]; then
  echo "Archive missing — see $ROOT/build/archive.log" >&2
  exit 1
fi

AUTH_ARGS=()
if [[ -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_ID:-}" ]]; then
  KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
  AUTH_ARGS=(
    -authenticationKeyPath "$KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
  echo "==> Using App Store Connect API key $ASC_KEY_ID"
fi

echo "==> Export + upload to App Store Connect"
set +e
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  | tee "$ROOT/build/export.log"
EXPORT_STATUS=${PIPESTATUS[0]}
set -e

if [[ $EXPORT_STATUS -ne 0 ]]; then
  echo "==> Upload path failed; try IPA-only export"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$ROOT/ExportOptions-ipa.plist" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
    | tee "$ROOT/build/export-ipa.log"

  IPA=$(find "$EXPORT_DIR" -name '*.ipa' | head -1)
  if [[ -z "$IPA" ]]; then
    echo "No IPA produced" >&2
    exit 1
  fi
  echo "==> IPA at $IPA"
  if [[ -n "${ASC_ISSUER_ID:-}" ]]; then
    echo "==> Upload IPA via altool"
    xcrun altool --upload-app \
      --type ios \
      --file "$IPA" \
      --apiKey "${ASC_KEY_ID:?set ASC_KEY_ID (source app-shell/.env.asc)}" \
      --apiIssuer "${ASC_ISSUER_ID}"
  else
    echo "Set ASC_ISSUER_ID to upload, or drag IPA into Transporter.app"
    open -a Transporter "$IPA" 2>/dev/null || open "$EXPORT_DIR"
  fi
fi

echo "Done. Check App Store Connect → TestFlight for processing."
