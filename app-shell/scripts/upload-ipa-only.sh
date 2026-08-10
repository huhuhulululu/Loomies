#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# ASC credentials from env — see ../.env.asc.example (source .env.asc first)
export ASC_KEY_ID="${ASC_KEY_ID:?set ASC_KEY_ID (source app-shell/.env.asc)}"
export ASC_ISSUER_ID="${ASC_ISSUER_ID:?set ASC_ISSUER_ID (source app-shell/.env.asc)}"
IPA=${1:-$(find build/export -name '*.ipa' | head -1)}
if [[ -z "$IPA" ]]; then
  echo "No IPA in build/export — pass a path as \$1" >&2
  exit 1
fi
echo "Uploading $IPA ..."
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
