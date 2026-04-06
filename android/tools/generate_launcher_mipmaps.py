#!/usr/bin/env python3
"""
Resize android/app/src/main/res/icon.png into launcher icon sizes for each mipmap-* folder.

Prerequisite:
  pip install pillow

Usage:
  python3 android/tools/generate_launcher_mipmaps.py

Place your master image as:
  android/app/src/main/res/icon.png
(square PNG recommended, e.g. 1024×1024)

Output files (overwritten if present):
  mipmap-mdpi/ic_launcher.png      48×48
  mipmap-hdpi/ic_launcher.png      72×72
  mipmap-xhdpi/ic_launcher.png     96×96
  mipmap-xxhdpi/ic_launcher.png    144×144
  mipmap-xxxhdpi/ic_launcher.png   192×192
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)

# Launcher icon pixel sizes (Android legacy mipmap)
MIPMAP_SIZES: dict[str, int] = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

OUTPUT_NAME = "ic_launcher.png"
INPUT_NAME = "icon.png"


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    res_dir = script_dir.parent / "app" / "src" / "main" / "res"
    src = res_dir / INPUT_NAME

    if not src.is_file():
        print(f"Missing source image: {src}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(src).convert("RGBA")
    w, h = img.size
    if w != h:
        print(
            f"Warning: source is {w}×{h} (not square). Resizing uses full image; "
            "consider a square master for best results.",
            file=sys.stderr,
        )

    for folder, size in MIPMAP_SIZES.items():
        out_dir = res_dir / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / OUTPUT_NAME
        try:
            resample = Image.Resampling.LANCZOS
        except AttributeError:
            resample = Image.LANCZOS  # Pillow < 9.1
        resized = img.resize((size, size), resample)
        resized.save(out_path, format="PNG", optimize=True)
        print(f"Wrote {out_path.relative_to(res_dir.parent.parent.parent)} ({size}×{size})")

    print("Done.")


if __name__ == "__main__":
    main()
