#!/usr/bin/env bash
set -euo pipefail
cd /Users/ping/code/cloth/app-shell
export ASC_KEY_ID=YFRZC2GC2V
export ASC_ISSUER_ID=6734863c-c46a-4788-a30e-1594a001bdf4
IPA=${1:-$(find build/export -name '*.ipa' | head -1)}
if [[ -z "$IPA" ]]; then
  echo "No IPA in build/export — pass a path as \$1" >&2
  exit 1
fi
echo "Uploading $IPA ..."
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
