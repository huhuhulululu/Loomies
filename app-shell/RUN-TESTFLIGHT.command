#!/bin/bash
# Finder 一键：走 tf-upload-now.sh（Manual、仅 App；与 TESTFLIGHT.md / build 44 同一条路）。
# 相对本文件定位 app-shell，不写死本机路径；有 .env.asc 就 source。
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [[ -f "$ROOT/.env.asc" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.asc"
  set +a
else
  echo "No $ROOT/.env.asc — copy .env.asc.example and fill ASC_ISSUER_ID." >&2
fi
bash "$ROOT/scripts/tf-upload-now.sh"
echo ""
echo "EXIT:$?"
echo "Done — you can close this window."
read -r _
