#!/usr/bin/env python3
"""
ChineseChess.app icon generator.

Generates a macOS .icns icon from design specs in icon-design.md.
Outputs a 1024px preview PNG first for visual verification.

Usage:
    python3 generate_icon.py              # Generate 1024px preview only
    python3 generate_icon.py --full       # Generate all sizes + .icns
"""

import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageCms

# ─── Config ───────────────────────────────────────────────────────────────────

SIZE = 1024
SUPERELLIPSE_N = 5
SUPERELLIPSE_RADIUS = 480
SUPERELLIPSE_POINTS = 720

# Colors (sRGB)
COL_BOARD_LIGHT = (222, 184, 135)   # #DEB887
COL_BOARD_DARK  = (210, 170, 120)   # #D2AA78
COL_GRID        = (74,  55,  40)    # #4A3728
COL_RED         = (204, 0,   0)     # #CC0000
COL_BLACK       = (26,  26,  26)    # #1A1A1A
COL_PIECE_LIGHT = (255, 253, 230)   # #FFFDE6
COL_PIECE_DARK  = (220, 200, 170)   # #DCC8AA

# Font paths in priority order
FONT_PATHS = [
    "/System/Library/Fonts/STKaiti.ttf",
    "/Library/Fonts/Kaiti.ttc",
    os.path.expanduser("~/Library/Fonts/方正楷体简体.TTF"),
    "/System/Library/Fonts/Supplemental/Songti.ttc",  # fallback
]

# Output paths
PROJECT_DIR = Path("~/DevTeam/projects/chinese-chess").expanduser()
PREVIEW_PATH = PROJECT_DIR / "icon-preview-1024.png"
ICONSET_DIR = PROJECT_DIR / "ChineseChess.iconset"


# ─── Font loading ────────────────────────────────────────────────────────────

def find_font():
    """Find a suitable Chinese font, returning (path, is_kaiti)."""
    for i, path in enumerate(FONT_PATHS):
        if os.path.isfile(path):
            try:
                f = ImageFont.truetype(path, 20)
                bbox = f.getbbox("帅")
                if bbox[2] > bbox[0] and bbox[3] > bbox[1]:
                    is_kaiti = i < 3  # first 3 entries are kaiti variants
                    return path, is_kaiti
            except Exception:
                continue
    return None, False


# ─── Mask generation ─────────────────────────────────────────────────────────

def superellipse_mask(size=SIZE, radius=SUPERELLIPSE_RADIUS,
                      n=SUPERELLIPSE_N, num_points=SUPERELLIPSE_POINTS):
    """Generate a superellipse mask using polygon approximation."""
    cx, cy = size // 2, size // 2
    points = []
    for i in range(num_points):
        t = 2 * math.pi * i / num_points
        cos_t = math.cos(t)
        sin_t = math.sin(t)
        x = cx + radius * (1 if cos_t >= 0 else -1) * abs(cos_t) ** (2.0 / n)
        y = cy + radius * (1 if sin_t >= 0 else -1) * abs(sin_t) ** (2.0 / n)
        points.append((x, y))

    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(points, fill=255)
    return mask


def _superellipse_distance(size, radius):
    """Compute normalized superellipse distance for every pixel (numpy).

    Returns a float array where d < 1 inside, d == 1 at boundary, d > 1 outside.
    """
    cx, cy = size / 2.0, size / 2.0
    y, x = np.mgrid[0:size, 0:size]
    dx = np.abs(x - cx) / radius
    dy = np.abs(y - cy) / radius
    return (dx ** SUPERELLIPSE_N + dy ** SUPERELLIPSE_N) ** (1.0 / SUPERELLIPSE_N)


def _edge_fade_mask(size=SIZE, radius=SUPERELLIPSE_RADIUS, fade_width=60):
    """Create a gradient mask that fades from 255 (interior) to 0 (near boundary).

    Inside the superellipse but within fade_width of the boundary, alpha
    linearly decreases from 255 to 0. This makes all content near the edge
    (grid lines, text) smoothly fade out before the hard mask cuts them.
    """
    d = _superellipse_distance(size, radius)
    fade_threshold = 1.0 - fade_width / radius

    mask = np.full((size, size), 255, dtype=np.uint8)

    # Outside superellipse: 0
    mask[d >= 1.0] = 0

    # In fade zone: linear 255 -> 0
    fade_zone = (d >= fade_threshold) & (d < 1.0)
    fade_ratio = (d[fade_zone] - fade_threshold) / (1.0 - fade_threshold)
    mask[fade_zone] = (255 * (1.0 - fade_ratio)).astype(np.uint8)

    return Image.fromarray(mask, 'L')


# ─── Drawing helpers ─────────────────────────────────────────────────────────

def draw_board_background(img):
    """Draw the chess board gradient background (3-stop vertical gradient)."""
    draw = ImageDraw.Draw(img)
    h = SIZE
    for y in range(h):
        ratio = y / max(1, h - 1)
        if ratio < 0.5:
            t = ratio * 2
            color = tuple(
                int(COL_BOARD_LIGHT[i] + (COL_BOARD_DARK[i] - COL_BOARD_LIGHT[i]) * t)
                for i in range(3)
            )
        else:
            t = (ratio - 0.5) * 2
            color = tuple(
                int(COL_BOARD_DARK[i] + (COL_BOARD_LIGHT[i] - COL_BOARD_DARK[i]) * t)
                for i in range(3)
            )
        draw.line([(0, y), (SIZE - 1, y)], fill=color + (255,))
    return img


def draw_grid_lines(img, padding=120):
    """Draw simplified decorative grid lines.

    Edge fade is handled by _edge_fade_mask applied in generate_icon_1024,
    not per-line alpha. Lines just draw at full opacity here.
    """
    draw = ImageDraw.Draw(img)
    grid_color = COL_GRID + (100,)

    gx0, gy0 = padding, padding
    gx1, gy1 = SIZE - padding, SIZE - padding
    grid_w = gx1 - gx0
    grid_h = gy1 - gy0

    # Vertical lines (representative subset: 5 of 9 columns)
    for i in [0, 2, 4, 6, 8]:
        x = gx0 + grid_w * i / 8
        draw.line([(x, gy0), (x, gy0 + grid_h * 4 / 9)], fill=grid_color, width=2)
        draw.line([(x, gy0 + grid_h * 5 / 9), (x, gy1)], fill=grid_color, width=2)

    # Horizontal lines (6 representative lines instead of full 10, per design §3.1)
    for i in [0, 1, 3, 5, 7, 9]:
        y = gy0 + grid_h * i / 9
        draw.line([(gx0, y), (gx1, y)], fill=grid_color, width=2)

    # Palace diagonals (two palaces)
    px0 = gx0 + grid_w * 3 / 8
    px1 = gx0 + grid_w * 5 / 8
    py0 = gy0
    py2 = gy0 + grid_h * 2 / 9
    draw.line([(px0, py0), (px1, py2)], fill=grid_color, width=2)
    draw.line([(px1, py0), (px0, py2)], fill=grid_color, width=2)

    py0b = gy0 + grid_h * 7 / 9
    py2b = gy1
    draw.line([(px0, py0b), (px1, py2b)], fill=grid_color, width=2)
    draw.line([(px1, py0b), (px0, py2b)], fill=grid_color, width=2)

    return img


def _make_radial_gradient_piece(radius, opacity=255):
    """Create a piece body image with radial gradient using numpy (fast).

    Returns an RGBA Image of size (radius*2, radius*2).
    """
    d = 2 * radius
    cy, cx = radius, radius
    y, x = np.mgrid[0:d, 0:d]
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    ratio = np.clip(dist / radius, 0, 1)  # 0 at center, 1 at edge

    # Interpolate: center=COL_PIECE_LIGHT, edge=COL_PIECE_DARK
    arr = np.zeros((d, d, 4), dtype=np.uint8)
    for c in range(3):
        arr[:, :, c] = (
            COL_PIECE_DARK[c] * ratio + COL_PIECE_LIGHT[c] * (1 - ratio)
        ).astype(np.uint8)

    # Mask to circle
    arr[:, :, 3] = np.where(dist <= radius, opacity, 0).astype(np.uint8)
    return Image.fromarray(arr, 'RGBA')


def draw_piece(img, center, radius, text, text_color, font, opacity=255):
    """Draw a chess piece with radial gradient, border, and text.

    Unified light source: top-left 45° -> shadow offset bottom-right.
    """
    cx, cy = center

    # Shadow — unified: offset=(8, 8), blur=16, opacity=20%
    scale = radius / 287  # relative to main piece (287px)
    s_offset_x = max(2, int(8 * scale))
    s_offset_y = max(2, int(8 * scale))
    s_blur = max(4, int(16 * scale))
    s_opacity = int(51 * opacity / 255)  # 20% of 255 = 51

    shadow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    shadow_radius = radius + 4
    sd.ellipse([
        cx - shadow_radius + s_offset_x, cy - shadow_radius + s_offset_y,
        cx + shadow_radius + s_offset_x, cy + shadow_radius + s_offset_y
    ], fill=(0, 0, 0, s_opacity))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=s_blur))
    img = Image.alpha_composite(img, shadow)

    # Piece body — radial gradient via numpy (single image, one composite)
    piece_body = _make_radial_gradient_piece(radius, opacity)
    img.paste(piece_body, (cx - radius, cy - radius), piece_body)

    # Border ring
    border_width = max(3, int(radius * 0.04))
    border_color = text_color + (opacity,)
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
              outline=border_color, width=border_width)
    img = Image.alpha_composite(img, overlay)

    # Inner border ring (double ring effect like real chess pieces)
    inner_r = radius - border_width * 2
    if inner_r > 0:
        d2_overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
        d2 = ImageDraw.Draw(d2_overlay)
        d2.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
                   outline=border_color, width=max(1, border_width // 2))
        img = Image.alpha_composite(img, d2_overlay)

    # Text (skip for very small pieces where text would be unreadable)
    if radius >= 30:
        font_size = int(radius * 0.9)
        try:
            piece_font = ImageFont.truetype(font, font_size)
        except Exception:
            piece_font = font

        text_overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
        td = ImageDraw.Draw(text_overlay)

        # stroke_width to prevent thin strokes from breaking at small sizes
        stroke_w = max(2, int(radius * 0.04))
        td.text((cx, cy), text, fill=text_color + (opacity,), font=piece_font,
                anchor='mm', stroke_width=stroke_w, stroke_fill=text_color + (opacity,))
        img = Image.alpha_composite(img, text_overlay)

    return img


def draw_river_text(img, font_path, y_center=None):
    """Draw '楚河 · 汉界' decorative text.

    y_center defaults to 72% of icon height (aesthetic choice — placed below
    the main piece for visual balance, not at the actual river position ~46%).
    """
    if y_center is None:
        y_center = int(SIZE * 0.72)  # aesthetic position below main piece

    font_size = int(SIZE * 0.05)  # ~51px
    try:
        river_font = ImageFont.truetype(font_path, font_size)
    except Exception:
        return img

    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    text = "楚 河          汉 界"
    color = COL_GRID + (int(255 * 0.6),)  # 60% opacity
    draw.text((SIZE // 2, y_center), text, fill=color, font=river_font, anchor='mm')
    img = Image.alpha_composite(img, overlay)
    return img


# ─── Main icon generation ────────────────────────────────────────────────────

def generate_icon_1024(font_path):
    """Generate the 1024x1024 main icon."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    # 1. Board background
    img = draw_board_background(img)

    # 2. Grid lines
    img = draw_grid_lines(img)

    # 3. River text (aesthetic position below main piece, not actual river)
    img = draw_river_text(img, font_path)

    # 4. Main piece "帅" - centered, slightly above center
    main_radius = int(SIZE * 0.28)  # ~287px
    main_center = (SIZE // 2, int(SIZE * 0.42))
    img = draw_piece(img, main_center, main_radius, "帅", COL_RED, font_path, opacity=255)

    # 5. Decorative pieces - small, from corners (peeking ~60% visible)
    small_radius = int(main_radius * 0.4)
    piece_offset = int(small_radius * 0.6)

    # Red "车" - top-left
    left_center = (int(SIZE * 0.15) + piece_offset, int(SIZE * 0.15) + piece_offset)
    img = draw_piece(img, left_center, small_radius, "车", COL_RED, font_path, opacity=179)

    # Black "马" - bottom-right
    right_center = (int(SIZE * 0.85) - piece_offset, int(SIZE * 0.85) - piece_offset)
    img = draw_piece(img, right_center, small_radius, "马", COL_BLACK, font_path, opacity=179)

    # 6. Apply superellipse mask with edge fade
    hard_mask = superellipse_mask()
    fade_mask = _edge_fade_mask(SIZE, SUPERELLIPSE_RADIUS, fade_width=60)

    # Combined: min(hard, fade) per pixel
    h = np.array(hard_mask, dtype=np.uint16)
    f = np.array(fade_mask, dtype=np.uint16)
    combined = Image.fromarray(np.minimum(h, f).astype(np.uint8), 'L')

    # Composite onto transparent using combined mask
    result = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(img, mask=combined)
    return result


def generate_icon_small(size, font_path):
    """Generate simplified icon for small sizes (<=32px).

    Red ring + cream circle, no text or decorations.
    """
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # Superellipse mask for this size
    radius = int(size * 0.469)  # proportional to 480/1024
    mask = superellipse_mask(size=size, radius=radius)

    # Fill with board color (single rectangle, not per-pixel)
    draw = ImageDraw.Draw(img)
    draw.rectangle([(0, 0), (size - 1, size - 1)], fill=COL_BOARD_LIGHT + (255,))

    # Central circle: red ring + cream fill
    circle_r = int(size * 0.35)
    cx, cy = size // 2, size // 2

    # Cream fill
    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    d.ellipse([cx - circle_r, cy - circle_r, cx + circle_r, cy + circle_r],
              fill=COL_PIECE_LIGHT + (255,))
    img = Image.alpha_composite(img, overlay)

    # Red ring
    ring_w = max(1, int(size * 0.06))
    overlay2 = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(overlay2)
    d2.ellipse([cx - circle_r, cy - circle_r, cx + circle_r, cy + circle_r],
               outline=COL_RED + (255,), width=ring_w)
    img = Image.alpha_composite(img, overlay2)

    # Apply mask
    img.putalpha(mask)
    return img


def save_with_srgb(img, path):
    """Save PNG with sRGB ICC profile embedded."""
    srgb_profile = ImageCms.createProfile("sRGB")
    profile_bytes = ImageCms.ImageCmsProfile(srgb_profile).tobytes()
    img.save(str(path), 'PNG', icc_profile=profile_bytes)


def generate_all_sizes(main_icon, font_path):
    """Generate all required icon sizes."""
    # Auto-create output directory
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    # iconset requires these files (some sizes appear multiple times under different names)
    entries = [
        (16,   "icon_16x16.png"),
        (32,   "icon_16x16@2x.png"),
        (32,   "icon_32x32.png"),
        (64,   "icon_32x32@2x.png"),
        (128,  "icon_128x128.png"),
        (256,  "icon_128x128@2x.png"),
        (256,  "icon_256x256.png"),
        (512,  "icon_256x256@2x.png"),
        (512,  "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for size, filename in entries:
        if size <= 32:
            icon = generate_icon_small(size, font_path)
        else:
            icon = main_icon.resize((size, size), Image.LANCZOS)
        save_with_srgb(icon, ICONSET_DIR / filename)
        print(f"  ✓ {filename} ({size}x{size})")


def generate_icns():
    """Generate .icns from iconset using iconutil (macOS only)."""
    icns_path = PROJECT_DIR / "ChineseChess.icns"
    # Ensure parent exists
    icns_path.parent.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(icns_path)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: iconutil failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    print(f"\n✅ Generated: {icns_path}")
    return icns_path


# ─── Entry point ─────────────────────────────────────────────────────────────

def main():
    full_mode = "--full" in sys.argv

    print("ChineseChess.app Icon Generator")
    print("=" * 40)

    # Check dependencies
    from PIL import Image as _img
    version = tuple(int(x) for x in _img.__version__.split('.')[:2])
    if version < (9, 1):
        print(f"ERROR: Pillow >= 9.1.0 required, got {_img.__version__}", file=sys.stderr)
        sys.exit(1)
    print(f"Pillow version: {_img.__version__} ✓")
    print(f"numpy version: {np.__version__} ✓")

    if full_mode and not shutil.which("iconutil"):
        print("ERROR: iconutil not found. --full mode requires macOS.", file=sys.stderr)
        print("  Run without --full to generate preview PNG only.", file=sys.stderr)
        sys.exit(1)

    # Find font
    font_path, is_kaiti = find_font()
    if font_path is None:
        print("ERROR: No suitable Chinese font found!", file=sys.stderr)
        print("Tried:", file=sys.stderr)
        for p in FONT_PATHS:
            exists = "EXISTS" if os.path.isfile(p) else "MISSING"
            print(f"  [{exists}] {p}", file=sys.stderr)
        print("\nPlease install a Chinese font (楷体 recommended).", file=sys.stderr)
        sys.exit(1)

    if not is_kaiti:
        print(f"⚠️  Warning: Using fallback font (not 楷体): {font_path}")
        print("   Icon text will use 宋体 style instead of 楷体.")
    else:
        print(f"Font: {font_path} (楷体 ✓)")

    # Generate main icon
    print("\nGenerating 1024×1024 icon...")
    main_icon = generate_icon_1024(font_path)

    # Auto-create output parent
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Save preview
    save_with_srgb(main_icon, PREVIEW_PATH)
    print(f"✅ Preview saved: {PREVIEW_PATH}")

    if full_mode:
        print("\nGenerating all sizes...")
        generate_all_sizes(main_icon, font_path)
        print("\nGenerating .icns...")
        generate_icns()
    else:
        print("\nPreview mode. Run with --full to generate .icns.")


if __name__ == "__main__":
    main()
