#!/usr/bin/env python3
"""Polish BodyAvatar croquis edges for clean stacking on any backdrop.

Fixes the sticker look: white/gray fringes after matte.
Can re-matte from RGB pre-alpha backup or polish existing RGBA.

Usage:
  python3 app-shell/scripts/croquis-polish-alpha.py
  python3 app-shell/scripts/croquis-polish-alpha.py --src app-shell/build/body-avatar-pre-alpha-20260803205941
"""
from __future__ import annotations

import argparse
import shutil
from collections import deque
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DST = ROOT / "Packages/ClosetUI/Sources/ClosetUI/Resources/BodyAvatar"
DEFAULT_SRC = ROOT / "app-shell/build/body-avatar-pre-alpha-20260803205941"

GRAY_LO, GRAY_HI = 90, 215
CHROMA_MAX = 24
FLOOD_THR = 38
FLOOR_STRIP = 0.07


def is_grayish(r, g, b):
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    chroma = mx - mn
    luma = (r.astype(np.float32) + g + b) / 3.0
    return (chroma <= CHROMA_MAX) & (luma >= GRAY_LO) & (luma <= GRAY_HI)


def flood_bg(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    gray = is_grayish(r, g, b)
    seeds = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    seed_cols = [rgb[y, x].astype(np.float32) for y, x in seeds]
    bg = np.zeros((h, w), dtype=bool)
    q = deque(seeds)
    for y, x in seeds:
        bg[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if ny < 0 or nx < 0 or ny >= h or nx >= w or bg[ny, nx]:
                continue
            pix = rgb[ny, nx].astype(np.float32)
            near = any(float(np.max(np.abs(pix - s))) <= FLOOD_THR for s in seed_cols)
            if not (near or gray[ny, nx]):
                continue
            chroma = float(np.max(pix) - np.min(pix))
            luma = float(pix.mean())
            if chroma > 28 and 90 < luma < 220:
                continue
            if luma < 72 and chroma < 32:  # hair
                continue
            bg[ny, nx] = True
            q.append((ny, nx))
    y0 = int(h * (1.0 - FLOOR_STRIP))
    luma = (r + g + b) / 3.0
    chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    floorish = np.zeros((h, w), dtype=bool)
    floorish[y0:, :] = (chroma[y0:, :] < 30) & (luma[y0:, :] > 75) & (luma[y0:, :] < 205)
    bg |= floorish | gray
    m = max(4, int(min(h, w) * 0.008))
    bg[:m, :] = True
    bg[-m:, :] = True
    bg[:, :m] = True
    bg[:, -m:] = True
    return bg


def largest_fg(fg: np.ndarray) -> np.ndarray:
    h, w = fg.shape
    seen = np.zeros_like(fg, dtype=bool)
    best, best_n = None, 0
    for y in range(h):
        for x in range(w):
            if not fg[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            cells = []
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


def erode_mask(mask: np.ndarray, n: int) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    for _ in range(n):
        img = img.filter(ImageFilter.MinFilter(3))
    return np.array(img) > 127


def dilate_mask(mask: np.ndarray, n: int) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    for _ in range(n):
        img = img.filter(ImageFilter.MaxFilter(3))
    return np.array(img) > 127


def feather(mask: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    if radius > 0:
        img = img.filter(ImageFilter.GaussianBlur(radius=radius))
    return np.array(img).astype(np.float32) / 255.0


def defringe(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Pull edge colors to interior; kill white/gray fringe on partial alpha."""
    h, w, _ = rgb.shape
    out = rgb.astype(np.float32).copy()
    a = alpha.astype(np.float32)
    # solid interior for color pull
    solid = a > 0.92
    # edge band
    edge = (a > 0.02) & (a < 0.92)
    if not edge.any():
        return np.clip(out, 0, 255)

    # blurred interior color as target
    solid_rgb = out.copy()
    solid_rgb[~solid] = 0
    solid_w = solid.astype(np.float32)
    # box-ish via gaussian on weighted
    for c in range(3):
        ch = Image.fromarray(np.clip(solid_rgb[:, :, c], 0, 255).astype(np.uint8))
        wt = Image.fromarray((solid_w * 255).astype(np.uint8))
        ch_b = np.array(ch.filter(ImageFilter.GaussianBlur(radius=3.5))).astype(np.float32)
        wt_b = np.array(wt.filter(ImageFilter.GaussianBlur(radius=3.5))).astype(np.float32) / 255.0
        wt_b = np.maximum(wt_b, 1e-3)
        pulled = ch_b / wt_b
        mix = np.clip((0.92 - a) / 0.9, 0, 1)  # more pull when more transparent
        out[:, :, c] = np.where(edge, out[:, :, c] * (1 - mix * 0.85) + pulled * (mix * 0.85), out[:, :, c])

    # un-premultiply residual studio / white
    for bg in (
        np.array([158.0, 158.0, 158.0]),
        np.array([200.0, 200.0, 200.0]),
        np.array([240.0, 240.0, 240.0]),
    ):
        aa = np.clip(a[..., None], 1e-3, 1.0)
        un = (out - (1.0 - aa) * bg) / aa
        # only apply on edge-ish with grayish current
        luma = out.mean(axis=2)
        chroma = out.max(axis=2) - out.min(axis=2)
        fringe = edge & (chroma < 40) & (luma > 120)
        out = np.where(fringe[..., None], un, out)

    # hard kill near-white low-chroma fringe → transparent-ish RGB
    luma = out.mean(axis=2)
    chroma = out.max(axis=2) - out.min(axis=2)
    bad = edge & (luma > 195) & (chroma < 28)
    out[bad] = out[bad] * 0.35  # darken fringe toward skin pull residual
    return np.clip(out, 0, 255)


def tighten_alpha(alpha: np.ndarray, rgb: np.ndarray) -> np.ndarray:
    """Zero alpha where residual is studio/white fringe; slight erode soft edge."""
    a = alpha.copy()
    luma = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    # kill soft white/gray halo pixels
    kill = (a > 0) & (a < 0.85) & (chroma < 26) & (luma > 145)
    a[kill] = 0
    # shrink 1px then light feather recovery is done outside
    hard = a > 0.5
    hard = erode_mask(hard, 1)
    # keep core solid
    solid = alpha > 0.95
    hard |= solid
    # rebuild soft edge from hard (thin feather)
    soft = feather(dilate_mask(hard, 1), 0.9)
    # preserve hair wisps: dark low-chroma with some original alpha
    hair = (luma < 90) & (chroma < 35) & (alpha > 0.15) & (alpha < 0.95)
    a = np.where(hair, np.maximum(alpha, soft * 0.7), soft)
    a = np.where(solid, 1.0, a)
    a[kill] = 0
    return np.clip(a, 0, 1)


def process_rgb(rgb_u8: np.ndarray) -> Image.Image:
    bg = flood_bg(rgb_u8)
    fg = largest_fg(~bg)
    # light erode to bite into fringe, then feather
    core = erode_mask(fg, 1)
    alpha = feather(core, 0.85)
    # also allow slightly larger dilate for hair
    hair_zone = dilate_mask(fg, 2) & ~core
    rgb = rgb_u8.astype(np.float32)
    # hair: keep original alpha soft if dark
    luma = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    hair = hair_zone & (luma < 95) & (chroma < 40)
    alpha = np.where(hair, np.maximum(alpha, 0.55), alpha)
    alpha = np.where(bg & (alpha < 0.55), 0.0, alpha)

    rgb_c = defringe(rgb, alpha)
    alpha = tighten_alpha(alpha, rgb_c)
    rgb_c = defringe(rgb_c, alpha)

    rgba = np.dstack([rgb_c[:, :, 0], rgb_c[:, :, 1], rgb_c[:, :, 2], alpha * 255.0])
    rgba = rgba.astype(np.uint8)
    a0 = rgba[:, :, 3] == 0
    rgba[a0, 0] = 0
    rgba[a0, 1] = 0
    rgba[a0, 2] = 0
    # zero RGB when nearly transparent to stop fringe bleed
    low = rgba[:, :, 3] < 8
    rgba[low, 0] = 0
    rgba[low, 1] = 0
    rgba[low, 2] = 0
    return Image.fromarray(rgba, mode="RGBA")


def process_rgba(im: Image.Image) -> Image.Image:
    """Polish existing RGBA (if no RGB backup)."""
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(np.float32)
    a = arr[:, :, 3].astype(np.float32) / 255.0
    # rebuild hard matte from alpha then polish
    hard = a > 0.4
    hard = largest_fg(hard)
    hard = erode_mask(hard, 1)
    alpha = feather(hard, 0.85)
    luma = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    hair = (luma < 95) & (chroma < 40) & (a > 0.12)
    alpha = np.where(hair, np.maximum(alpha, a), alpha)
    rgb_c = defringe(rgb, alpha)
    alpha = tighten_alpha(alpha, rgb_c)
    rgb_c = defringe(rgb_c, alpha)
    rgba = np.dstack([rgb_c, alpha * 255.0]).astype(np.uint8)
    a0 = rgba[:, :, 3] < 8
    rgba[a0, :3] = 0
    return Image.fromarray(rgba, mode="RGBA")


def halo_score(im: Image.Image) -> dict:
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(np.float32)
    a = arr[:, :, 3].astype(np.float32)
    edge = (a > 15) & (a < 230)
    luma = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    white = edge & (luma > 180) & (chroma < 35)
    gray = edge & (luma > 130) & (luma <= 180) & (chroma < 25)
    clear = (a == 0).mean() * 100
    return {
        "clear%": round(float(clear), 1),
        "white_halo": int(white.sum()),
        "gray_halo": int(gray.sum()),
        "soft": int(((a > 0) & (a < 250)).sum()),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=None)
    ap.add_argument("--dst", type=Path, default=DEFAULT_DST)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    src = args.src
    if src is None:
        src = DEFAULT_SRC if DEFAULT_SRC.is_dir() else args.dst
    files = sorted(src.glob("croquis_*.png"))
    if not files:
        raise SystemExit(f"no croquis in {src}")

    bak = None
    if not args.dry_run:
        bak = ROOT / "app-shell/build" / f"body-avatar-pre-polish-{datetime.now():%Y%m%d%H%M%S}"
        bak.mkdir(parents=True, exist_ok=True)
        for p in args.dst.glob("croquis_*.png"):
            shutil.copy2(p, bak / p.name)
        print("backup", bak)

    args.dst.mkdir(parents=True, exist_ok=True)
    for p in files:
        im0 = Image.open(p)
        if im0.mode == "RGBA" and src.resolve() == args.dst.resolve():
            out = process_rgba(im0)
        else:
            out = process_rgb(np.array(im0.convert("RGB")))
        sc = halo_score(out)
        print(f"{p.name:42} {sc}")
        if not args.dry_run:
            dest = args.dst / p.name
            out.save(dest, format="PNG", optimize=True)
            if "_yaw000" in p.name:
                out.save(args.dst / p.name.replace("_yaw000", ""), format="PNG", optimize=True)
    print("done")


if __name__ == "__main__":
    main()
