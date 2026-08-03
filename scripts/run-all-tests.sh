#!/usr/bin/env bash
# 一键回归四包 + 可选 xcodebuild（Debug 模拟器）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
total=0
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do
  echo "=== $p ==="
  if out=$(swift test --package-path "Packages/$p" 2>&1); then
    echo "$out" | tail -3
    n=$(echo "$out" | sed -n 's/.*with \([0-9]*\) tests.*/\1/p' | tail -1)
    total=$((total + ${n:-0}))
  else
    echo "$out" | tail -30
    fail=1
  fi
done
echo "TOTAL_TESTS=$total"
if [[ "${1:-}" == "--ios" ]]; then
  echo "=== xcodebuild simulator ==="
  cd app-shell && xcodegen generate
  xcodebuild -scheme ClosetApp -project ClosetApp.xcodeproj \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
    -configuration Debug build
fi
exit $fail
