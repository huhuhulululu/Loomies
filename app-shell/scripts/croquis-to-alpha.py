#!/usr/bin/env python3
"""Flood-matte BodyAvatar croquis → transparent RGBA PNG.

Removes inconsistent baked backgrounds so UI can stack occasion backdrops.
Does NOT use soft_rect / Telea inpaint (those ruin pasties/thong).

Usage:
  python3 app-shell/scripts/croquis-to-alpha.py
  python3 app-shell/scripts/croquis-to-alpha.py --src app-shell/build/body-avatar-pre-alpha-*/
  python3 app-shell/scripts/croquis-to-alpha.py --dry-run

Pipeline: flood from corners → grayish floor strip → largest connected component
→ slight edge erode → soft feather → edge decontamination (un-premultiply gray).
"""
from __future__ import annotations

import argparse
import shutil
from collections import deque
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DST = ROOT / "Packages/ClosetUI/Sources/ClosetUI/Resources/BodyAvatar"

# Studio-gray range after unify-body-studio (≈158) + natural variation
GRAY_LO, GRAY_HI = 95, 210
CHROMA_MAX = 22
FLOOD_THR = 40  # luma distance from seed corner
FLOOR_STRIP = 0.06  # bottom fraction: more aggressive gray kill
ERODE = 1
FEATHER = 1.4


def is_grayish(r: np.ndarray, g: np.ndarray, b: np.ndarray) -> np.ndarray:
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    chroma = mx - mn
    luma = (r.astype(np.float32) + g + b) / 3.0
    return (chroma <= CHROMA_MAX) & (luma >= GRAY_LO) & (luma <= GRAY_HI)


def flood_bg(rgb: np.ndarray) -> np.ndarray:
    """BFS from four corners through near-seed / grayish pixels."""
    h, w, _ = rgb.shape
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    gray = is_grayish(r, g, b)

    seeds = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    seed_cols = [rgb[y, x].astype(np.float32) for y, x in seeds]
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for y, x in seeds:
        bg[y, x] = True
        q.append((y, x))

    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if ny < 0 or nx < 0 or ny >= h or nx >= w or bg[ny, nx]:
                continue
            pix = rgb[ny, nx].astype(np.float32)
            near = any(float(np.max(np.abs(pix - s))) <= FLOOD_THR for s in seed_cols)
            if near or gray[ny, nx]:
                # Protect warm skin / hair-ish from flood (high chroma or dark brown)
                chroma = float(np.max(pix) - np.min(pix))
                luma = float(pix.mean())
                if chroma > 28 and luma > 90 and luma < 220:
                    continue
                if luma < 70 and chroma < 30:
                    # dark hair — never flood as bg
                    continue
                bg[ny, nx] = True
                q.append((ny, nx))

    # Bottom strip: residual floor / contact shadow (grayish only)
    y0 = int(h * (1.0 - FLOOR_STRIP))
    luma = (r + g + b) / 3.0
    chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    floorish = np.zeros((h, w), dtype=bool)
    floorish[y0:, :] = (chroma[y0:, :] < 28) & (luma[y0:, :] > 80) & (luma[y0:, :] < 200)
    bg = bg | floorish | gray

    # Force outer margin as bg
    m = max(4, int(min(h, w) * 0.008))
    bg[:m, :] = True
    bg[-m:, :] = True
    bg[:, :m] = True
    bg[:, -m:] = True
    return bg


def largest_fg_component(fg: np.ndarray) -> np.ndarray:
    """Keep largest 4-connected True component (the figure)."""
    h, w = fg.shape
    seen = np.zeros_like(fg, dtype=bool)
    best = None
    best_n = 0
    for y in range(h):
        for x in range(w):
            if not fg[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            cells: list[tuple[int, int]] = []
            while q:
                cy, cx = q.popleft()
                cells.append((cy, cx))
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(cells) > best_n:
                best_n = len(cells)
                best = cells
    out = np.zeros_like(fg, dtype=bool)
    if best:
        for y, x in best:
            out[y, x] = True
    return out


def erode(mask: np.ndarray, n: int) -> np.ndarray:
    if n <= 0:
        return mask
    m = mask.astype(np.uint8) * 255
    img = Image.fromarray(m, mode="L")
    for _ in range(n):
        img = img.filter(ImageFilter_MinFilter(3))
    return np.array(img) > 127


def ImageFilter_MinFilter(size: int):
    from PIL import ImageFilter

    return ImageFilter.MinFilter(size)


def feather_alpha(fg: np.ndarray, radius: float) -> np.ndarray:
    from PIL import ImageFilter

    m = (fg.astype(np.uint8) * 255)
    img = Image.fromarray(m, mode="L")
    if radius > 0:
        img = img.filter(ImageFilter.GaussianBlur(radius=radius))
    return np.array(img).astype(np.float32) / 255.0


def decontaminate(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Pull edge colors away from residual studio gray toward opaque interior."""
    h, w, _ = rgb.shape
    out = rgb.astype(np.float32).copy()
    a = alpha
    # edge band: partial alpha
    edge = (a > 0.05) & (a < 0.92)
    if not edge.any():
        return np.clip(out, 0, 255)
    # estimate bg as global mode-ish of fully transparent neighbors — use studio 158
    bg = np.array([158.0, 158.0, 158.0], dtype=np.float32)
    aa = np.clip(a[..., None], 1e-3, 1.0)
    # un-premultiply-ish: (c - (1-a)*bg) / a
    un = (out - (1.0 - aa) * bg) / aa
    out = np.where(edge[..., None], un, out)
    return np.clip(out, 0, 255)


def process(rgb_u8: np.ndarray) -> Image.Image:
    rgb = rgb_u8.astype(np.float32)
    bg = flood_bg(rgb_u8)
    fg = ~bg
    fg = largest_fg_component(fg)
    # light erode then feather
    if ERODE:
        fg = erode(fg, ERODE)
    alpha = feather_alpha(fg, FEATHER)
    # hard kill remaining pure bg
    alpha = np.where(bg & (alpha < 0.5), 0.0, alpha)
    rgb_clean = decontaminate(rgb, alpha)
    rgba = np.dstack(
        [
            rgb_clean[:, :, 0],
            rgb_clean[:, :, 1],
            rgb_clean[:, :, 2],
            alpha * 255.0,
        ]
    ).astype(np.uint8)
    # zero RGB where fully transparent (smaller files, no fringe bleed)
    a0 = rgba[:, :, 3] == 0
    rgba[a0, 0] = 0
    rgba[a0, 1] = 0
    rgba[a0, 2] = 0
    return Image.fromarray(rgba, mode="RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=None, help="Source dir of croquis_*.png (RGB or RGBA)")
    ap.add_argument("--dst", type=Path, default=DEFAULT_DST)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-backup", action="store_true")
    args = ap.parse_args()

    src = args.src or args.dst
    files = sorted(src.glob("croquis_*.png"))
    if not files:
        raise SystemExit(f"no croquis_*.png in {src}")

    bak = None
    if not args.dry_run and not args.no_backup and src.resolve() == args.dst.resolve():
        bak = ROOT / "app-shell/build" / f"body-avatar-pre-alpha-{datetime.now():%Y%m%d%H%M%S}"
        bak.mkdir(parents=True, exist_ok=True)
        for p in files:
            shutil.copy2(p, bak / p.name)
        print("backup", bak)

    args.dst.mkdir(parents=True, exist_ok=True)
    for p in files:
        im = Image.open(p).convert("RGB")
        out = process(np.array(im))
        a = np.array(out.split()[3])
        clear = float((a == 0).mean() * 100)
        dest = args.dst / p.name
        print(f"{p.name:40} clear%={clear:5.1f} → {dest if not args.dry_run else '(dry)'}")
        if not args.dry_run:
            out.save(dest, format="PNG", optimize=True)
            # keep legacy front alias in sync
            if "_yaw000" in p.name:
                alias = p.name.replace("_yaw000", "")
                out.save(args.dst / alias, format="PNG", optimize=True)
    print("done")


if __name__ == "__main__":
    main()
