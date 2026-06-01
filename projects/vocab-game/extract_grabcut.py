#!/usr/bin/env python3
"""
Extract egg characters from promotional image using GrabCut for background removal.
Then paste each character onto a clean transparent background and resize to 512x512.
"""
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
import cv2
import os

INPUT = '/tmp/eggy_assets/source_6eggs_colorful.jpg'
OUTDIR = '/tmp/eggy_final'
os.makedirs(OUTDIR, exist_ok=True)

img = cv2.imread(INPUT)
H, W = img.shape[:2]  # 1080x1920

# Refined bounding boxes based on visual inspection
# These are approximate - we'll use GrabCut to refine the edges
characters = {
    # Red character - upper left, small egg with red hood
    'egg_red': (150, 50, 520, 480),
    # Green character - left side  
    'egg_green': (50, 280, 440, 720),
    # Blue character - upper right
    'egg_blue': (1300, 30, 1700, 430),
    # Pink character - right side
    'egg_pink': (1400, 280, 1800, 680),
    # Black character - lower left
    'egg_black': (80, 520, 480, 950),
    # Yellow character - lower right
    'egg_yellow': (1350, 550, 1750, 980),
}

TARGET_SIZE = 512

for name, bbox in characters.items():
    x1, y1, x2, y2 = bbox
    
    # GrabCut
    mask = np.zeros(img.shape[:2], np.uint8)
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)
    
    rect = (x1, y1, x2 - x1, y2 - y1)
    cv2.grabCut(img, mask, rect, bgd_model, fgd_model, 10, cv2.GC_INIT_WITH_RECT)
    
    # Create binary mask: foreground = 1, background = 0
    binary_mask = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 1, 0).astype(np.uint8)
    
    # Apply mask
    result = img.copy()
    result[binary_mask == 0] = 0
    
    # Convert to PIL
    result_rgba = cv2.cvtColor(result, cv2.COLOR_BGR2RGBA)
    # Make background transparent
    for i in range(result_rgba.shape[0]):
        for j in range(result_rgba.shape[1]):
            if binary_mask[i, j] == 0:
                result_rgba[i, j, 3] = 0
    
    pil_img = Image.fromarray(result_rgba)
    
    # Crop to bounding box
    crop = pil_img.crop((x1, y1, x2, y2))
    
    # Find the actual content bounds (non-transparent pixels)
    arr = np.array(crop)
    alpha = arr[:, :, 3]
    rows = np.any(alpha > 10, axis=1)
    cols = np.any(alpha > 10, axis=0)
    
    if rows.any() and cols.any():
        rmin, rmax = np.where(rows)[0][[0, -1]]
        cmin, cmax = np.where(cols)[0][[0, -1]]
        # Add small padding
        pad = 10
        rmin = max(0, rmin - pad)
        rmax = min(crop.height, rmax + pad)
        cmin = max(0, cmin - pad)
        cmax = min(crop.width, cmax + pad)
        tight = crop.crop((cmin, rmin, cmax, rmax))
    else:
        tight = crop
    
    # Resize to target size maintaining aspect ratio, center on square canvas
    canvas = Image.new('RGBA', (TARGET_SIZE, TARGET_SIZE), (0, 0, 0, 0))
    tw, th = tight.size
    scale = min(TARGET_SIZE * 0.85 / tw, TARGET_SIZE * 0.85 / th)
    new_w = int(tw * scale)
    new_h = int(th * scale)
    resized = tight.resize((new_w, new_h), Image.LANCZOS)
    
    # Smooth the alpha edge a bit
    alpha_ch = resized.split()[3]
    alpha_ch = alpha_ch.filter(ImageFilter.SMOOTH)
    resized.putalpha(alpha_ch)
    
    x_off = (TARGET_SIZE - new_w) // 2
    y_off = (TARGET_SIZE - new_h) // 2
    canvas.paste(resized, (x_off, y_off), resized)
    
    canvas.save(os.path.join(OUTDIR, f'{name}_idle.png'))
    
    # Also save @2x
    canvas_2x = canvas.resize((TARGET_SIZE * 2, TARGET_SIZE * 2), Image.LANCZOS)
    canvas_2x.save(os.path.join(OUTDIR, f'{name}_idle@2x.png'))
    
    fg_pixels = np.sum(np.array(canvas)[:, :, 3] > 0)
    print(f'{name}: {tight.size} -> {canvas.size}, fg_pixels={fg_pixels}')

print('\n✅ All characters extracted to', OUTDIR)
