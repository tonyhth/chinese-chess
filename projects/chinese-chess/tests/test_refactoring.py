#!/usr/bin/env python3
"""
Regression tests for Cody's refactoring round (Ruby review fixes).
Run AFTER test_generate_icon.py to verify refactoring didn't break anything.

Checks:
- P0: numpy radial gradient, unified import, numpy version print
- P1: dead code removed, save_with_srgb clean, makedirs, iconutil check
- P2: horizontal lines count, small icon uses draw.rectangle
"""

import io
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageCms

PROJECT_DIR = Path("~/DevTeam/projects/chinese-chess").expanduser()
SCRIPT = PROJECT_DIR / "src/tools/generate_icon.py"
ICONSET = PROJECT_DIR / "ChineseChess.iconset"
PREVIEW = PROJECT_DIR / "icon-preview-1024.png"
ICNS = PROJECT_DIR / "ChineseChess.icns"

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


def read_script():
    return SCRIPT.read_text()


def test_p0_numpy_radial_gradient():
    """P0: draw_piece uses numpy _make_radial_gradient_piece, not per-pixel overlay."""
    print("\n=== P0: numpy Radial Gradient ===")
    src = read_script()

    check("_make_radial_gradient_piece exists", "def _make_radial_gradient_piece" in src)
    check("draw_piece calls _make_radial_gradient_piece",
          "_make_radial_gradient_piece(radius" in src)

    # Verify NO old-style per-pixel overlay loop in draw_piece
    piece_func = src[src.index("def draw_piece("):src.index("def ", src.index("def draw_piece(") + 1)]
    check("No per-pixel gradient loop in draw_piece",
          "for r in range(radius, 0, -1)" not in piece_func,
          "found old per-pixel loop pattern")


def test_p0_numpy_import():
    """P0: numpy imported at top level, version printed in main()."""
    print("\n=== P0: numpy Import ===")
    src = read_script()

    # Check top-level import (first 30 lines)
    top_lines = "\n".join(src.split("\n")[:30])
    check("numpy imported at top level", "import numpy" in top_lines)

    # Check version printed
    check("numpy version printed in main()", "numpy version" in src)


def test_p1_dead_code_removed():
    """P1: Dead functions and constants removed."""
    print("\n=== P1: Dead Code Removal ===")
    src = read_script()

    check("draw_radial_gradient_circle removed",
          "def draw_radial_gradient_circle" not in src)
    check("draw_gradient_rect removed",
          "def draw_gradient_rect" not in src)
    check("ICON_SIZES constant removed",
          "ICON_SIZES =" not in src and "ICON_SIZES=" not in src)


def test_p1_save_with_srgb_clean():
    """P1: save_with_srgb has no dead comments."""
    print("\n=== P1: save_with_srgb Clean ===")
    src = read_script()

    func_start = src.index("def save_with_srgb(")
    func_end = src.index("\ndef ", func_start + 1)
    func_body = src[func_start:func_end]

    # No TODO/stub comments
    check("No TODO/FIXME in save_with_srgb",
          "TODO" not in func_body and "FIXME" not in func_body)
    check("No stale strip-alpha comment",
          "# Convert to RGB" not in func_body or "# Keep RGBA" not in func_body or
          func_body.count("# Convert to RGB") <= 1)


def test_p1_makedirs():
    """P1: Output dirs auto-created with makedirs."""
    print("\n=== P1: Auto makedirs ===")
    src = read_script()

    check("ICONSET_DIR mkdir with parents",
          "ICONSET_DIR.mkdir(parents=True" in src)
    check("PREVIEW_PATH parent mkdir",
          "PREVIEW_PATH.parent.mkdir" in src)


def test_p1_iconutil_check():
    """P1: --full mode checks iconutil availability."""
    print("\n=== P1: iconutil Availability Check ===")
    src = read_script()

    check("shutil.which('iconutil') check before --full",
          'shutil.which("iconutil")' in src or "shutil.which('iconutil')" in src)

    # Verify the check happens in main() before generate_all_sizes
    main_start = src.index("def main(")
    main_body = src[main_start:]
    check("iconutil check in main() before generation",
          "shutil.which" in main_body and
          main_body.index("shutil.which") < main_body.index("generate_all_sizes"))


def test_p2_horizontal_lines():
    """P2: Grid has 6 horizontal lines [0,1,3,5,7,9]."""
    print("\n=== P2: Horizontal Line Count ===")
    src = read_script()

    # Find the horizontal lines loop in draw_grid_lines
    grid_start = src.index("def draw_grid_lines(")
    grid_end = src.index("\ndef ", grid_start + 1)
    grid_body = src[grid_start:grid_end]

    check("Horizontal lines = 6 [0,1,3,5,7,9]",
          "[0, 1, 3, 5, 7, 9]" in grid_body,
          "line list not found")


def test_p2_small_icon_rectangle():
    """P2: generate_icon_small uses draw.rectangle for background."""
    print("\n=== P2: Small Icon Background ===")
    src = read_script()

    small_start = src.index("def generate_icon_small(")
    small_end = src.index("\ndef ", small_start + 1)
    small_body = src[small_start:small_end]

    check("Uses draw.rectangle for background",
          "draw.rectangle" in small_body)


def test_performance():
    """Performance: --full should complete in <10s (was ~60s before numpy fix)."""
    print("\n=== Performance ===")

    start = time.time()
    r = subprocess.run(
        [sys.executable, str(SCRIPT), "--full"],
        capture_output=True, text=True, cwd=str(PROJECT_DIR)
    )
    elapsed = time.time() - start

    check("--full runs successfully", r.returncode == 0)
    check(f"--full completes in <10s (actual: {elapsed:.1f}s)", elapsed < 10)


if __name__ == "__main__":
    test_p0_numpy_radial_gradient()
    test_p0_numpy_import()
    test_p1_dead_code_removed()
    test_p1_save_with_srgb_clean()
    test_p1_makedirs()
    test_p1_iconutil_check()
    test_p2_horizontal_lines()
    test_p2_small_icon_rectangle()
    test_performance()

    print(f"\n{'=' * 50}")
    print(f"Regression Results: {PASS} passed, {FAIL} failed out of {PASS + FAIL}")
    sys.exit(1 if FAIL > 0 else 0)
