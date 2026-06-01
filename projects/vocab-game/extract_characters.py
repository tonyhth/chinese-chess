#!/usr/bin/env python3
"""
Attempt to extract egg characters from the 6-egg promotional image.
Uses a combination of techniques:
1. Manual bounding box crop for each character
2. Background removal via GrabCut
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import os

INPUT = '/tmp/eggy_assets/source_6eggs_colorful.jpg'
OUTDIR = '/tmp/eggy_extracted'
os.makedirs(OUTDIR, exist_ok=True)

img = Image.open(INPUT).convert('RGBA')
W, H = img.size  # 1920x1080

# Based on image analysis, approximate bounding boxes for each character
# These are rough estimates from the description
characters = {
    # Upper left area - red hooded character
    'egg_red': (200, 80, 500, 450),
    # Left side - green hooded character
    'egg_green': (100, 350, 420, 700),
    # Upper right - blue hooded character
    'egg_blue': (1350, 60, 1650, 400),
    # Right side - pink hooded character  
    'egg_pink': (1450, 300, 1750, 650),
    # Lower left - black/dark hooded character
    'egg_black': (150, 550, 450, 900),
    # Lower right - yellow hooded character
    'egg_yellow': (1400, 600, 1700, 950),
}

for name, bbox in characters.items():
    x1, y1, x2, y2 = bbox
    # Add padding
    pad = 30
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(W, x2 + pad)
    y2 = min(H, y2 + pad)
    
    crop = img.crop((x1, y1, x2, y2))
    crop.save(os.path.join(OUTDIR, f'{name}_raw.png'))
    print(f'Saved {name}: {crop.size}')

print('\nRaw crops saved. Now visually inspect to refine boxes.')
