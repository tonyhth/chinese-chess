#!/usr/bin/env python3
"""
Remove white/near-white background from PNG images.
Converts white pixels to transparent, preserving anti-aliased edges.

Usage:
    python3 remove_white_bg.py input.png output.png [white_threshold] [alpha_threshold]

    white_threshold: 0-255, pixels with R,G,B all above this are considered "white" (default: 220)
    alpha_threshold: 0-255, alpha below this is forced to 0 (default: 240)

Based on Pillow. Tested with CogView-3-Flash output (white #FFFFFF background).
"""

import sys
from PIL import Image
import numpy as np


def remove_white_bg(input_path: str, output_path: str, white_thresh: int = 220, alpha_thresh: int = 240):
    img = Image.open(input_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)

    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]

    # Detect white-ish pixels
    is_white = (r > white_thresh) & (g > white_thresh) & (b > white_thresh)

    # For white pixels: compute "how white" (0 = not white, 1 = pure white)
    # Use the minimum channel value as whiteness indicator
    min_channel = np.minimum(np.minimum(r, g), b)
    whiteness = np.clip((min_channel - white_thresh) / (255.0 - white_thresh), 0, 1)

    # Apply alpha: white pixels become transparent proportionally
    # Non-white pixels keep original alpha
    new_alpha = np.where(is_white, (1.0 - whiteness) * 255, a)

    # Also clean up very low alpha pixels
    new_alpha = np.where(new_alpha < alpha_thresh,
                         np.where(is_white, 0, new_alpha),
                         new_alpha)

    arr[:, :, 3] = new_alpha.astype(np.uint8)

    result = Image.fromarray(arr.astype(np.uint8), "RGBA")
    result.save(output_path, "PNG")
    print(f"  ✅ {input_path} → {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} input.png output.png [white_threshold] [alpha_threshold]")
        sys.exit(1)

    wt = int(sys.argv[3]) if len(sys.argv) > 3 else 220
    at = int(sys.argv[4]) if len(sys.argv) > 4 else 240
    remove_white_bg(sys.argv[1], sys.argv[2], wt, at)
