#!/usr/bin/env bash
# 一键回归四包 + 可选 xcodebuild（Debug 模拟器）
# ClosetModel 跟 CI 一样加 --no-parallel（D211：安静机器上才跑得动三道时间门）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
total=0
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do
  echo "=== $p ==="
  extra=()
  if [[ "$p" == ClosetModel ]]; then
    extra=(--no-parallel)
  fi
  if out=$(swift test --package-path "Packages/$p" "${extra[@]}" 2>&1); then
    echo "$out" | tail -3
    n=$(echo "$out" | sed -n 's/.*with \([0-9]*\) tests.*/\1/p' | tail -1)
    total=$((total + ${n:-0}))
  else
    echo "$out" | tail -30
    fail=1
  fi
done
echo "TOTAL_TESTS=$total"

# Prefer an installed iOS 26 Simulator. Do not hard-require one name/OS.
# Prints "name|OS" lines (BSD awk — this script runs on a Mac with Xcode).
ios26_available_iphones() {
  awk '
    /^-- iOS 26/ {
      os=$0
      sub(/^-- iOS /, "", os)
      sub(/ --.*$/, "", os)
      next
    }
    /^-- / { os=""; next }
    os != "" && $0 ~ /iPhone/ {
      name=$0
      sub(/^[[:space:]]+/, "", name)
      sub(/ \(.*$/, "", name)
      print name "|" os
    }
  '
}

ios26_runtime_block() {
  awk '
    /^-- iOS 26/ { show=1; print; next }
    /^-- / { show=0 }
    show { print }
  '
}

pick_ios_simulator_destination() {
  local list sims preferred name os
  if ! command -v xcrun >/dev/null; then
    echo "xcrun missing — cannot pick an iOS Simulator destination." >&2
    return 1
  fi
  if ! list=$(xcrun simctl list devices available 2>/dev/null); then
    echo "xcrun simctl list failed." >&2
    return 1
  fi
  sims=$(printf '%s\n' "$list" | ios26_available_iphones)
  if [[ -z "${sims}" ]]; then
    echo "No available iOS 26 iPhone simulator." >&2
    echo "Available iOS 26 simulators:" >&2
    if printf '%s\n' "$list" | grep -q '^-- iOS 26'; then
      printf '%s\n' "$list" | ios26_runtime_block >&2
    else
      echo "(no iOS 26 runtimes found)" >&2
      printf '%s\n' "$list" >&2
    fi
    return 1
  fi
  preferred=$(printf '%s\n' "$sims" | grep -F 'iPhone 17 Pro|26.2' | head -1 || true)
  if [[ -z "$preferred" ]]; then
    preferred=$(printf '%s\n' "$sims" | grep -F 'iPhone 17 Pro|' | head -1 || true)
  fi
  if [[ -z "$preferred" ]]; then
    preferred=$(printf '%s\n' "$sims" | head -1)
    echo "Note: preferred 'iPhone 17 Pro, OS=26.2' is not installed; using ${preferred%%|*}, OS=${preferred#*|}." >&2
  elif [[ "$preferred" != "iPhone 17 Pro|26.2" ]]; then
    echo "Note: OS 26.2 + iPhone 17 Pro not paired; using ${preferred%%|*}, OS=${preferred#*|}." >&2
  fi
  name="${preferred%%|*}"
  os="${preferred#*|}"
  printf '%s\n' "platform=iOS Simulator,name=${name},OS=${os}"
}

if [[ "${1:-}" == "--ios" ]]; then
  echo "=== xcodebuild simulator ==="
  command -v xcodegen >/dev/null || { echo "xcodegen missing — brew install xcodegen" >&2; exit 1; }
  dest=$(pick_ios_simulator_destination) || exit 1
  echo "destination: $dest"
  cd app-shell && xcodegen generate
  xcodebuild -scheme ClosetApp -project ClosetApp.xcodeproj \
    -destination "$dest" \
    -configuration Debug build
fi
exit $fail
