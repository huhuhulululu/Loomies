#!/usr/bin/env python3
"""Offline QA for real-human full-nude photoreal import drops.

Scores chest/pelvis edge residue (same spirit as PhotorealCoveringQA).
Does NOT flip NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude.

Setup: requires opencv-python-headless + numpy; a venv works, e.g.
  python3 -m venv .venv-qa && .venv-qa/bin/pip install opencv-python-headless numpy

Usage:
  python3 scripts/photoreal-import-qa.py
  python3 scripts/photoreal-import-qa.py preview/body-avatar/import-full-nude/
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import cv2
    import numpy as np
except ImportError:
    print("Need opencv-python-headless + numpy (venv ok)", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "Packages/ClosetUI/Sources/ClosetUI/Resources/BodyAvatar"
IMPORT = ROOT / "preview/body-avatar/import-full-nude"

CHEST_THR = 0.085
PELVIS_THR = 0.090

SEXES = ("female", "male")
PHENOS = (
    "eastAsian", "southeastAsian", "southAsian", "european",
    "african", "latinx", "middleEastern", "indigenous",
)
YAWS = (0, 45, 90, 135, 180, 225, 270, 315)


def edge_score(gray: np.ndarray, y0, y1, x0, x1) -> float:
    h, w = gray.shape
    y0, y1 = max(1, y0), min(h - 1, y1)
    x0, x1 = max(1, x0), min(w - 1, x1)
    roi = gray[y0:y1, x0:x1].astype(np.float32) / 255.0
    if roi.size == 0:
        return 1.0
    # body only
    body = roi > 0.12
    if body.sum() < 50:
        return 1.0
    gx = cv2.Sobel(roi, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(roi, cv2.CV_32F, 0, 1, ksize=3)
    mag = np.sqrt(gx * gx + gy * gy)
    return float(mag[body].mean())


def analyze(path: Path) -> dict:
    im = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if im is None:
        return {"path": str(path), "ok": False, "error": "unreadable"}
    if im.ndim == 2:
        gray = im
    else:
        gray = cv2.cvtColor(im[:, :, :3], cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    chest = edge_score(gray, int(h * 0.30), int(h * 0.40), int(w * 0.28), int(w * 0.72))
    pelvis = edge_score(gray, int(h * 0.48), int(h * 0.62), int(w * 0.30), int(w * 0.70))
    passes = chest < CHEST_THR and pelvis < PELVIS_THR
    return {
        "path": str(path),
        "ok": True,
        "w": w,
        "h": h,
        "chest": round(chest, 4),
        "pelvis": round(pelvis, 4),
        "passes_zero_covering_heuristic": passes,
    }


def expected_names() -> list[str]:
    names = []
    for sex in SEXES:
        names.append(f"photoreal_{sex}_front.png")
        for p in PHENOS:
            names.append(f"photoreal_{sex}_{p}_front.png")
            for y in YAWS:
                if y == 0:
                    continue
                names.append(f"photoreal_{sex}_{p}_yaw{y:03d}.png")
        for y in YAWS:
            if y == 0:
                continue
            names.append(f"photoreal_{sex}_yaw{y:03d}.png")
    return names


def main() -> int:
    dirs = [Path(a) for a in sys.argv[1:]] or [IMPORT, BUNDLE]
    print("=== Photoreal full-nude import QA ===")
    print("Cert flip is MANUAL; this only reports heuristic scores.\n")

    any_pass = False
    scanned = 0
    for d in dirs:
        if not d.exists():
            print(f"(skip missing dir) {d}")
            continue
        pngs = sorted(d.rglob("photoreal_*.png"))
        if not pngs:
            # also scan flat drops without prefix
            pngs = sorted(p for p in d.glob("*.png") if "mask" not in p.name.lower())
        print(f"-- {d} ({len(pngs)} png) --")
        for p in pngs:
            if "Face" in p.parts or "Skin" in p.parts or "Meshes" in p.parts:
                continue
            if "full-nude-inpaint" in p.parts and "v" in p.stem:
                # experimental inpaint candidates still scored
                pass
            r = analyze(p)
            scanned += 1
            if not r.get("ok"):
                print(f"  FAIL read {p.name}: {r.get('error')}")
                continue
            flag = "PASS-heuristic" if r["passes_zero_covering_heuristic"] else "FAIL-covering"
            if r["passes_zero_covering_heuristic"]:
                any_pass = True
            print(
                f"  {flag}  chest={r['chest']:.4f} pelvis={r['pelvis']:.4f}  {p.name}"
            )

    print("\n-- Minimum for cert attempt --")
    for sex in SEXES:
        stem = f"photoreal_{sex}_front.png"
        hit = (BUNDLE / stem).exists() or (IMPORT / stem).exists()
        print(f"  {'found' if hit else 'MISSING'}  {stem}")

    present = {p.name for p in BUNDLE.glob("photoreal_*.png")}
    present |= {p.name for p in IMPORT.glob("photoreal_*.png")} if IMPORT.exists() else set()
    missing = [n for n in expected_names() if n not in present]
    print(f"\nInventory: {len(present)} photoreal_* present; {len(missing)} named slots empty")
    print("(multi-phenotype × multi-yaw is preferred, not all required for first cert)")

    print("\nHARD: photorealFrontAssetsCertifiedFullNude stays false until human QA")
    print("      confirms zero covering on real-human plates (heuristic alone insufficient).")
    if scanned == 0:
        return 1
    # exit 0 always for report mode; cert is manual
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
