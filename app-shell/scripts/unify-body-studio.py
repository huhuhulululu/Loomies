#!/usr/bin/env python3
"""Unify BodyAvatar croquis onto seamless studio gray + mild polish.
Does NOT use soft_rect / Telea. Backup before write.
Usage: python3 app-shell/scripts/unify-body-studio.py
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
import shutil
from datetime import datetime

TARGET = np.array([158.0, 158.5, 158.0], dtype=np.float32)
ROOT = Path(__file__).resolve().parents[2] / "Packages/ClosetUI/Sources/ClosetUI/Resources/BodyAvatar"


def studio_bg(h, w):
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    factor = 0.93 + 0.05 * np.sin(np.clip(y, 0, 1) * np.pi) + 0.09 * (y ** 1.35)
    bg = TARGET[None, None, :] * factor[..., None]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((yy - h * 0.42) / h) ** 2 + ((xx - w * 0.5) / w) ** 2)
    vig = 1.0 - 0.04 * np.clip((r - 0.55) / 0.5, 0, 1)
    return np.clip(bg * vig[..., None], 0, 255)


def process_arr(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    chroma = mx - mn
    luma = (r + g + b) / 3.0
    bg_score = (
        np.clip((18.0 - chroma) / 18.0, 0, 1)
        * np.clip((luma - 95) / 40.0, 0, 1)
        * np.clip((210 - luma) / 30.0, 0, 1)
    )
    skin = (r > g + 8) & (r > b + 5) & (luma > 100) & (luma < 210) & (chroma > 12)
    hair = (luma < 85) & (chroma < 25)
    bg_score = np.where(skin | hair, 0, bg_score)
    m = max(8, int(min(h, w) * 0.012))
    bg_score[:m, :] = 1
    bg_score[-m:, :] = np.maximum(bg_score[-m:, :], 0.85)
    bg_score[:, :m] = 1
    bg_score[:, -m:] = 1
    w_bg = np.array(
        Image.fromarray((bg_score * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(radius=2.2)
        )
    ).astype(np.float32) / 255.0
    xs = np.abs(np.arange(w) - w / 2)[None, :] / (w * 0.5)
    ys = np.abs(np.arange(h) - h * 0.4)[:, None] / (h * 0.45)
    body = np.clip(1.15 - np.sqrt((xs * 1.05) ** 2 + (ys * 0.9) ** 2), 0, 1)
    w_bg = np.where(chroma < 13, w_bg, w_bg * (1.0 - 0.55 * body))
    w_bg = np.array(
        Image.fromarray((np.clip(w_bg, 0, 1) * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(radius=1.6)
        )
    ).astype(np.float32) / 255.0
    studio = studio_bg(h, w)
    comp = rgb * (1 - w_bg[..., None]) + studio * w_bg[..., None]
    img = Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8))
    img = ImageEnhance.Contrast(img).enhance(1.05)
    img = ImageEnhance.Sharpness(img).enhance(1.14)
    img = ImageEnhance.Color(img).enhance(1.04)
    return np.array(img)


def main():
    bak = Path(__file__).resolve().parents[1] / "build" / f"body-avatar-pre-studio-{datetime.now():%Y%m%d%H%M%S}"
    bak.mkdir(parents=True, exist_ok=True)
    for p in ROOT.glob("croquis_*.png"):
        shutil.copy2(p, bak / p.name)
    for p in sorted(ROOT.glob("croquis_*.png")):
        rgb = np.array(Image.open(p).convert("RGB"), dtype=np.float32)
        out = process_arr(rgb)
        Image.fromarray(out).save(p, format="PNG", optimize=True)
        if "_yaw000" in p.name:
            shutil.copy2(p, ROOT / p.name.replace("_yaw000", ""))
    print("done; backup", bak)


if __name__ == "__main__":
    main()
