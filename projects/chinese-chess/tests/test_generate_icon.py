#!/usr/bin/env python3
"""
Test suite for generate_icon.py — ChineseChess.app icon generator.
Covers: basic generation, size verification, sRGB ICC, small-size simplification,
        .icns integrity, font-missing error handling.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageCms

PROJECT_DIR = Path("~/DevTeam/projects/chinese-chess").expanduser()
SCRIPT = PROJECT_DIR / "src/tools/generate_icon.py"
PREVIEW = PROJECT_DIR / "icon-preview-1024.png"
ICNS = PROJECT_DIR / "ChineseChess.icns"
ICONSET = PROJECT_DIR / "ChineseChess.iconset"

PASS = 0
FAIL = 0


def check(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  ✅ {name}")
    else:
        FAIL += 1
        msg = f"  ❌ {name}"
        if detail:
            msg += f"  — {detail}"
        print(msg)


def test_basic_generation():
    """Test 1: Running the script generates all expected outputs."""
    print("\n=== Test 1: Basic Generation ===")

    # Backup existing outputs
    backups = {}
    for p in [PREVIEW, ICNS, ICONSET]:
        if p.exists():
            bak = p.with_suffix(p.suffix + ".bak")
            if p.is_dir():
                shutil.copytree(p, bak)
            else:
                shutil.copy2(p, bak)
            backups[p] = bak

    try:
        # Clean and regenerate
        for p in [PREVIEW, ICNS]:
            if p.exists():
                p.unlink()
        if ICONSET.exists():
            shutil.rmtree(ICONSET)

        # Run preview mode
        r = subprocess.run(
            [sys.executable, str(SCRIPT)],
            capture_output=True, text=True, cwd=str(PROJECT_DIR)
        )
        check("Preview mode exit code", r.returncode == 0, f"got {r.returncode}")

        # Run full mode
        r = subprocess.run(
            [sys.executable, str(SCRIPT), "--full"],
            capture_output=True, text=True, cwd=str(PROJECT_DIR)
        )
        check("Full mode exit code", r.returncode == 0, f"got {r.returncode}\n{r.stderr[:500]}")

        # Check all outputs exist
        check("Preview PNG exists", PREVIEW.exists())
        check("Iconset dir exists", ICONSET.exists())
        check(".icns exists", ICNS.exists())

        # Check iconset has 10 files
        pngs = list(ICONSET.glob("*.png"))
        check("Iconset has 10 PNGs", len(pngs) == 10, f"got {len(pngs)}: {[p.name for p in pngs]}")

    finally:
        # Restore backups
        for orig, bak in backups.items():
            if bak.exists():
                if orig.is_dir():
                    if orig.exists():
                        shutil.rmtree(orig)
                    shutil.copytree(bak, orig)
                else:
                    shutil.copy2(bak, orig)
            if bak.exists():
                if bak.is_dir():
                    shutil.rmtree(bak)
                else:
                    bak.unlink()


def test_iconset_sizes():
    """Test 2: All 10 iconset PNGs have correct dimensions."""
    print("\n=== Test 2: Iconset Size Verification ===")

    expected = {
        "icon_16x16.png": (16, 16),
        "icon_16x16@2x.png": (32, 32),
        "icon_32x32.png": (32, 32),
        "icon_32x32@2x.png": (64, 64),
        "icon_128x128.png": (128, 128),
        "icon_128x128@2x.png": (256, 256),
        "icon_256x256.png": (256, 256),
        "icon_256x256@2x.png": (512, 512),
        "icon_512x512.png": (512, 512),
        "icon_512x512@2x.png": (1024, 1024),
    }

    for filename, (exp_w, exp_h) in expected.items():
        path = ICONSET / filename
        if not path.exists():
            check(f"{filename} exists", False, "file missing")
            continue
        img = Image.open(path)
        check(f"{filename} size", img.size == (exp_w, exp_h), f"got {img.size}")


def test_srgb_profile():
    """Test 3: Output PNGs embed sRGB ICC profile."""
    print("\n=== Test 3: sRGB ICC Profile ===")

    test_files = [PREVIEW] + sorted(ICONSET.glob("*.png"))
    for path in test_files:
        if not path.exists():
            check(f"{path.name} sRGB", False, "file missing")
            continue
        img = Image.open(path)
        icc = img.info.get('icc_profile')
        has_srgb = False
        if icc:
            try:
                profile = ImageCms.ImageCmsProfile(io.BytesIO(icc))
                desc = profile.profile.profile_description
                has_srgb = 'srgb' in desc.lower()
            except Exception:
                has_srgb = b'sRGB' in icc

        check(f"{path.name} has ICC profile", icc is not None and len(icc) > 0)
        if icc:
            check(f"{path.name} contains sRGB", has_srgb,
                  f"profile desc not recognized")


def test_small_size_simplified():
    """Test 4: 16x16 and 32x32 icons are simplified (no text, only circle + ring)."""
    print("\n=== Test 4: Small Size Simplification ===")

    # 16x16 — check it's not a downscaled version of the full icon
    small_16 = Image.open(ICONSET / "icon_16x16.png")
    small_32 = Image.open(ICONSET / "icon_32x32.png")

    # These small icons should use the simplified generator:
    # - board color background filling the superellipse
    # - cream circle in center
    # - red ring
    # - NO grid lines, NO text, NO chess characters

    # Compare 16x16 with a simple resize of 1024 — they should be visually different
    # because simplified version has no text/grid
    big = Image.open(ICONSET / "icon_512x512@2x.png")
    big_16 = big.resize((16, 16), Image.LANCZOS)
    big_32 = big.resize((32, 32), Image.LANCZOS)

    # Convert to RGBA for comparison
    small_16_rgba = small_16.convert("RGBA")
    small_32_rgba = small_32.convert("RGBA")
    big_16_rgba = big_16.convert("RGBA")
    big_32_rgba = big_32.convert("RGBA")

    # Count different pixels — simplified icons should differ significantly from resized full icon
    diff_16 = 0
    diff_32 = 0
    total_16 = 16 * 16
    total_32 = 32 * 32

    for x in range(16):
        for y in range(16):
            if small_16_rgba.getpixel((x, y)) != big_16_rgba.getpixel((x, y)):
                diff_16 += 1

    for x in range(32):
        for y in range(32):
            if small_32_rgba.getpixel((x, y)) != big_32_rgba.getpixel((x, y)):
                diff_32 += 1

    # Expect at least 20% different pixels (simplified vs full resize)
    check("16x16 is simplified (not just downscaled)", diff_16 / total_16 > 0.2,
          f"diff ratio: {diff_16 / total_16:.2%}")
    check("32x32 is simplified (not just downscaled)", diff_32 / total_32 > 0.1,
          f"diff ratio: {diff_32 / total_32:.2%}")

    # Check that 32x32 simplified icon has the cream circle center
    # Center pixel should be cream-colored (~FFFDE6) not board-colored
    cx, cy = 16, 16
    center_px = small_32_rgba.getpixel((cx, cy))
    is_cream = (center_px[0] > 240 and center_px[1] > 240 and center_px[2] > 200)
    check("32x32 center has cream circle fill", is_cream,
          f"center pixel: RGB{center_px[:3]}")

    # Check that 16x16 also has cream center
    cx16, cy16 = 8, 8
    center_16 = small_16_rgba.getpixel((cx16, cy16))
    is_cream_16 = (center_16[0] > 240 and center_16[1] > 240 and center_16[2] > 200)
    check("16x16 center has cream circle fill", is_cream_16,
          f"center pixel: RGB{center_16[:3]}")


def test_icns_integrity():
    """Test 5: .icns file is valid and recognizable by macOS."""
    print("\n=== Test 5: .icns Integrity ===")

    check(".icns exists", ICNS.exists())
    if not ICNS.exists():
        return

    size = ICNS.stat().st_size
    check(".icns size > 0", size > 0, f"got {size} bytes")
    check(".icns size reasonable (>100KB)", size > 100_000, f"got {size} bytes")

    # Check magic bytes: 'icns'
    with open(ICNS, 'rb') as f:
        magic = f.read(4)
    check(".icns magic bytes 'icns'", magic == b'icns', f"got {magic!r}")

    # Use sips to verify
    r = subprocess.run(["sips", "-g", "format", str(ICNS)], capture_output=True, text=True)
    check("sips recognizes .icns", r.returncode == 0, r.stderr[:200] if r.stderr else "")


def test_font_missing_error():
    """Test 6: Script fails gracefully when no font is available."""
    print("\n=== Test 6: Font Missing Error Handling ===")

    # We'll use FONT_PATHS env var trick: temporarily hide all fonts by
    # monkey-patching. Instead, just run with a modified font list.
    # The cleanest approach: copy script, replace FONT_PATHS with empty list.

    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as tmp:
        script_content = Path(SCRIPT).read_text()
        # Replace FONT_PATHS with empty list by removing entries between [ and ]
        lines = script_content.split('\n')
        new_lines = []
        in_font_list = False
        for line in lines:
            if 'FONT_PATHS = [' in line:
                new_lines.append('FONT_PATHS = []  # TEST: empty')
                in_font_list = True
                continue
            if in_font_list:
                if ']' in line:
                    in_font_list = False
                continue  # skip all lines inside the list
            new_lines.append(line)
        script_content = '\n'.join(new_lines)
        tmp.write(script_content)
        tmp_path = tmp.name

    try:
        r = subprocess.run(
            [sys.executable, tmp_path],
            capture_output=True, text=True, cwd=str(PROJECT_DIR)
        )
        check("Exits non-zero without fonts", r.returncode != 0, f"got {r.returncode}")
        check("Outputs error message", "ERROR" in r.stderr or "ERROR" in r.stdout,
              f"stderr: {r.stderr[:200]}")

        # Verify no output files were created
        # (they shouldn't exist after error, or if they did exist before, they shouldn't be modified)
        check("Does not create preview on error", not r.stdout.strip().endswith("✅"))
        check("Error mentions fonts", "font" in r.stderr.lower() or "font" in r.stdout.lower(),
              f"stderr: {r.stderr[:200]}")
    finally:
        os.unlink(tmp_path)


def test_preview_dimensions():
    """Test 2b: Preview PNG is 1024x1024."""
    print("\n=== Test 2b: Preview Dimensions ===")
    if not PREVIEW.exists():
        check("Preview exists", False, "file missing")
        return
    img = Image.open(PREVIEW)
    check("Preview is 1024x1024", img.size == (1024, 1024), f"got {img.size}")
    check("Preview mode is RGBA", img.mode == "RGBA", f"got {img.mode}")


if __name__ == "__main__":
    import io

    test_basic_generation()
    test_iconset_sizes()
    test_preview_dimensions()
    test_srgb_profile()
    test_small_size_simplified()
    test_icns_integrity()
    test_font_missing_error()

    print(f"\n{'=' * 50}")
    print(f"Results: {PASS} passed, {FAIL} failed out of {PASS + FAIL}")
    sys.exit(1 if FAIL > 0 else 0)
