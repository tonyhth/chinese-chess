#!/usr/bin/env python3
"""
v3.1: Generate vinyl-toy-style egg character PNGs.

Uses numpy for fast gradient rendering. Adds more detail layers
to hit 150-400KB file size target.

- Smooth gradient bodies (light top → dark bottom) with 256-level gradients
- Glossy vinyl highlight with soft glow
- Large expressive eyes with iris gradient (16 rings) + 3 highlights
- Pink blush circles with soft edges
- Colored outline (same hue, darker shade) via mask expansion
- Accessories per character (ribbon, droplet, leaf, flame, horns, star)
- Subtle drop shadow
- 5 states: idle, happy, excited, sad, mini
- Transparent background (RGBA)
- @2x: 1024x1024 normal, 512x512 mini
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import math
import os
import sys

SIZE = 1024
MINI_SIZE = 512

OUTDIR = os.path.expanduser(
    '~/DevTeam/projects/vocab-game/VocabGame/Resources/Assets.xcassets/EggCharacters'
)
RAWTMP = os.path.expanduser('~/DevTeam/projects/vocab-game/tmp_raw_v3')
os.makedirs(RAWTMP, exist_ok=True)


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


CHARACTERS = {
    'pink': {
        'body_light': hex2rgb('#FFD1DC'), 'body_dark': hex2rgb('#FF69B4'),
        'eye_color': hex2rgb('#FF69B4'), 'eye_light': hex2rgb('#FFB6C1'),
        'blush': hex2rgb('#FF8FAB'), 'outline': hex2rgb('#D4567A'),
        'accessory': 'ribbon',
    },
    'blue': {
        'body_light': hex2rgb('#B8E0F7'), 'body_dark': hex2rgb('#4A90D9'),
        'eye_color': hex2rgb('#4A90D9'), 'eye_light': hex2rgb('#87CEEB'),
        'blush': hex2rgb('#FFA0A0'), 'outline': hex2rgb('#3570A8'),
        'accessory': 'droplet',
    },
    'green': {
        'body_light': hex2rgb('#C6F7C6'), 'body_dark': hex2rgb('#3CB371'),
        'eye_color': hex2rgb('#3CB371'), 'eye_light': hex2rgb('#98FB98'),
        'blush': hex2rgb('#FFB0B0'), 'outline': hex2rgb('#2D8A56'),
        'accessory': 'leaf',
    },
    'red': {
        'body_light': hex2rgb('#FFB3B3'), 'body_dark': hex2rgb('#DC3545'),
        'eye_color': hex2rgb('#DC3545'), 'eye_light': hex2rgb('#FF7F7F'),
        'blush': hex2rgb('#FF9090'), 'outline': hex2rgb('#B02A37'),
        'accessory': 'flame',
    },
    'black': {
        'body_light': hex2rgb('#8A8A8A'), 'body_dark': hex2rgb('#2C2C2C'),
        'eye_color': hex2rgb('#6A0DAD'), 'eye_light': hex2rgb('#9B59B6'),
        'blush': hex2rgb('#E88FA0'), 'outline': hex2rgb('#3A3A3A'),
        'accessory': 'horns',
    },
    'yellow': {
        'body_light': hex2rgb('#FFF9C4'), 'body_dark': hex2rgb('#FFC107'),
        'eye_color': hex2rgb('#8B6914'), 'eye_light': hex2rgb('#D4A00A'),
        'blush': hex2rgb('#FFA0A0'), 'outline': hex2rgb('#D4A00A'),
        'accessory': 'star',
    },
}


# ─── Numpy-accelerated gradient rendering ────────────────────────────

def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def make_egg_mask(cx, cy, hw, hh, canvas_size):
    """Create egg-shaped mask using numpy. Returns float array [0,1]."""
    y, x = np.ogrid[:canvas_size, :canvas_size]
    # Normalized coords centered on egg
    nx = (x - cx) / hw
    ny = (y - cy) / hh

    # Egg shape: sin profile wider at bottom
    # At each y, compute max width
    ny_safe = np.clip(ny, -1, 1)
    # Width factor: sin^0.6 gives wider bottom
    abs_ny = np.abs(ny_safe)
    width_factor = np.where(abs_ny < 1, np.sin(abs_ny * np.pi / 2) ** 0.6, 0)

    # Distance metric
    dist = np.abs(nx) / np.maximum(width_factor, 1e-6)
    mask = np.where(abs_ny <= 1, (1 - dist) * (1 - abs_ny), 0)
    mask = np.clip(mask * 8, 0, 1)  # sharpen edges slightly

    # Anti-aliased edge: smooth transition within ~2px
    # Use smoothstep on the distance
    edge_mask = np.where(abs_ny <= 1,
                         np.clip(1 - dist, 0, 1),
                         0)
    # Apply smoothstep for AA
    edge_mask = edge_mask * edge_mask * (3 - 2 * edge_mask)

    return edge_mask.astype(np.float32)


def fill_gradient_mask(mask, c_top, c_bot, cy, hh):
    """Fill RGBA image with vertical gradient using mask."""
    h, w = mask.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)

    y_coords = np.arange(h).reshape(-1, 1)
    t = np.clip((y_coords - (cy - hh)) / (2 * hh), 0, 1)

    rgba[:, :, 0] = (c_top[0] + (c_bot[0] - c_top[0]) * t * mask).astype(np.uint8)
    rgba[:, :, 1] = (c_top[1] + (c_bot[1] - c_top[1]) * t * mask).astype(np.uint8)
    rgba[:, :, 2] = (c_top[2] + (c_bot[2] - c_top[2]) * t * mask).astype(np.uint8)
    rgba[:, :, 3] = (mask * 255).astype(np.uint8)

    return rgba


def numpy_to_pil(rgba_arr):
    return Image.fromarray(rgba_arr, 'RGBA')


def paste_composite(base, overlay):
    """Alpha composite overlay onto base using PIL (handles RGBA correctly)."""
    base_pil = base if isinstance(base, Image.Image) else numpy_to_pil(base)
    over_pil = overlay if isinstance(overlay, Image.Image) else numpy_to_pil(overlay)
    return Image.alpha_composite(base_pil, over_pil)


# ─── Drawing helpers (PIL-based for details) ─────────────────────────

def draw_drop_shadow(img, cx, cy, hw, hh, canvas_size):
    """Soft shadow beneath the egg."""
    shadow = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sy = cy + hh * 0.9
    sd.ellipse([cx - hw * 0.7, sy - hh * 0.06, cx + hw * 0.7, sy + hh * 0.08],
               fill=(0, 0, 0, 30))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=10))
    return paste_composite(img, shadow)


def draw_outline_fast(img, mask, outline_c, outline_w, canvas_size):
    """Faster outline using numpy operations."""
    mask_uint8 = (mask * 255).astype(np.uint8)

    # Dilate using PIL
    mask_pil = Image.fromarray(mask_uint8, 'L')
    dilated = np.array(mask_pil.filter(ImageFilter.MaxFilter(size=outline_w * 2 + 1)))

    # Outline = dilated > 0 and mask == 0
    outline_zone = (dilated > 128) & (mask_uint8 < 128)

    # Apply outline color
    img_arr = np.array(img)
    img_arr[outline_zone, 0] = outline_c[0]
    img_arr[outline_zone, 1] = outline_c[1]
    img_arr[outline_zone, 2] = outline_c[2]
    img_arr[outline_zone, 3] = 255

    return numpy_to_pil(img_arr)


def draw_vinyl_highlight(img, cx, cy, body_w, body_h):
    """Glossy vinyl toy highlight on upper-left."""
    canvas_size = img.size[0]
    hl = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    hld = ImageDraw.Draw(hl)

    hl_w = body_w * 0.20
    hl_h = body_h * 0.28
    hl_cx = cx - body_w * 0.15
    hl_cy = cy - body_h * 0.22

    # Multiple layers for soft glow
    for i, (alpha, scale) in enumerate([(30, 1.3), (45, 1.0), (60, 0.7)]):
        sw = hl_w * scale
        sh = hl_h * scale
        hld.ellipse([hl_cx - sw, hl_cy - sh, hl_cx + sw, hl_cy + sh],
                    fill=(255, 255, 255, alpha))

    hl = hl.filter(ImageFilter.GaussianBlur(radius=6))
    return paste_composite(img, hl)


def draw_feet(img, cx, foot_y, body_w, foot_color, outline_c, scale):
    """Draw two small stubby feet."""
    draw = ImageDraw.Draw(img)
    foot_w = body_w * 0.14
    foot_h = body_w * 0.07
    gap = body_w * 0.18
    for side in [-1, 1]:
        fx = cx + side * gap
        draw.ellipse([fx - foot_w, foot_y - foot_h, fx + foot_w, foot_y + foot_h],
                     fill=foot_color + (255,), outline=outline_c + (255,), width=max(1, int(2 * scale)))
    return img


# ─── Eye drawing ─────────────────────────────────────────────────────

def draw_eyes_idle(img, cx, cy, eye_w, eye_h, eye_color, eye_light, outline_c, scale):
    draw = ImageDraw.Draw(img)
    gap = eye_w * 0.85
    for side in [-1, 1]:
        ex = cx + side * gap / 2
        ey = cy

        # Sclera
        draw.ellipse([ex - eye_w/2, ey - eye_h/2, ex + eye_w/2, ey + eye_h/2],
                     fill=(255, 255, 255, 255), outline=outline_c + (255,), width=max(2, int(2*scale)))

        # Iris gradient (16 rings)
        iris_w = eye_w * 0.68
        iris_h = eye_h * 0.72
        iris_cy = ey - eye_h * 0.03
        for i in range(16):
            t = i / 15
            color = lerp_color(eye_light, eye_color, t)
            f = 1 - t
            iw = iris_w * f / 2
            ih = iris_h * f / 2
            draw.ellipse([ex - iw, iris_cy - ih, ex + iw, iris_cy + ih],
                         fill=color + (255,))

        # Pupil
        pw = eye_w * 0.18
        ph = eye_h * 0.22
        draw.ellipse([ex - pw/2, iris_cy - ph/2, ex + pw/2, iris_cy + ph/2],
                     fill=(15, 15, 15, 255))

        # Highlights: large (top-right), medium (bottom-left), tiny (top)
        hr1 = eye_w * 0.11
        draw.ellipse([ex + eye_w*0.1 - hr1, ey - eye_h*0.22 - hr1,
                      ex + eye_w*0.1 + hr1, ey - eye_h*0.22 + hr1],
                     fill=(255, 255, 255, 255))
        hr2 = eye_w * 0.06
        draw.ellipse([ex - eye_w*0.12 - hr2, ey + eye_h*0.1 - hr2,
                      ex - eye_w*0.12 + hr2, ey + eye_h*0.1 + hr2],
                     fill=(255, 255, 255, 255))
        hr3 = eye_w * 0.035
        draw.ellipse([ex - hr3, ey - eye_h*0.30 - hr3,
                      ex + hr3, ey - eye_h*0.30 + hr3],
                     fill=(255, 255, 255, 255))


def draw_eyes_happy(img, cx, cy, eye_w, eye_h, outline_c, scale):
    draw = ImageDraw.Draw(img)
    gap = eye_w * 0.85
    for side in [-1, 1]:
        ex = cx + side * gap / 2
        ey = cy
        arc_r = eye_w * 0.45
        bbox = [ex - arc_r, ey - arc_r * 0.5, ex + arc_r, ey + arc_r * 0.5]
        draw.arc(bbox, start=15, end=165,
                 fill=outline_c + (255,), width=max(3, int(eye_w * 0.09)))


def draw_eyes_excited(img, cx, cy, eye_w, eye_h, eye_color, eye_light, outline_c, scale):
    draw = ImageDraw.Draw(img)
    gap = eye_w * 0.85
    for side in [-1, 1]:
        ex = cx + side * gap / 2
        ey = cy
        # White sclera background for recognizability
        draw.ellipse([ex - eye_w/2, ey - eye_h/2, ex + eye_w/2, ey + eye_h/2],
                     fill=(255, 255, 255, 255), outline=outline_c + (255,), width=max(2, int(2*scale)))
        # Star-shaped iris inside sclera
        star_r = eye_w * 0.38
        star_ir = star_r * 0.38
        pts = []
        for i in range(10):
            a = math.pi / 2 + i * math.pi / 5
            r = star_r if i % 2 == 0 else star_ir
            pts.append((ex + r * math.cos(a), ey - r * math.sin(a)))
        draw.polygon(pts, fill=eye_color + (255,), outline=outline_c + (255,))
        # Highlights
        hr = eye_w * 0.07
        draw.ellipse([ex + star_r*0.1 - hr, ey - star_r*0.35 - hr,
                      ex + star_r*0.1 + hr, ey - star_r*0.35 + hr],
                     fill=(255, 255, 255, 255))
        hr2 = eye_w * 0.04
        draw.ellipse([ex - star_r*0.15 - hr2, ey + star_r*0.15 - hr2,
                      ex - star_r*0.15 + hr2, ey + star_r*0.15 + hr2],
                     fill=(255, 255, 255, 255))


def draw_eyes_sad(img, cx, cy, eye_w, eye_h, eye_color, eye_light, outline_c, scale):
    draw = ImageDraw.Draw(img)
    gap = eye_w * 0.85
    for side in [-1, 1]:
        ex = cx + side * gap / 2
        ey = cy

        # Sclera
        draw.ellipse([ex - eye_w/2, ey - eye_h/2, ex + eye_w/2, ey + eye_h/2],
                     fill=(255, 255, 255, 255), outline=outline_c + (255,), width=max(2, int(2*scale)))

        # Iris (shifted slightly down)
        iris_w = eye_w * 0.62
        iris_h = eye_h * 0.68
        iris_cy = ey + eye_h * 0.05
        for i in range(14):
            t = i / 13
            color = lerp_color(eye_light, eye_color, t)
            f = 1 - t
            iw = iris_w * f / 2
            ih = iris_h * f / 2
            draw.ellipse([ex - iw, iris_cy - ih, ex + iw, iris_cy + ih],
                         fill=color + (255,))

        # Pupil
        pw = eye_w * 0.16
        ph = eye_h * 0.20
        draw.ellipse([ex - pw/2, iris_cy - ph/2, ex + pw/2, iris_cy + ph/2],
                     fill=(15, 15, 15, 255))

        # Highlight
        hr = eye_w * 0.09
        draw.ellipse([ex + eye_w*0.08 - hr, ey - eye_h*0.12 - hr,
                      ex + eye_w*0.08 + hr, ey - eye_h*0.12 + hr],
                     fill=(255, 255, 255, 255))

        # Sad eyebrow
        brow_y = ey - eye_h * 0.62
        brow_w = eye_w * 0.55
        inner_x = cx
        outer_x = ex + side * brow_w / 2
        draw.line([(inner_x, brow_y + 5*scale), (outer_x, brow_y - 5*scale)],
                  fill=outline_c + (255,), width=max(3, int(eye_w * 0.06)))

    # Teardrop on left eye
    tx = cx - gap / 2 + eye_w * 0.15
    ty = cy + eye_h * 0.35
    drop_r = eye_w * 0.10
    draw.ellipse([tx - drop_r, ty - drop_r, tx + drop_r, ty + drop_r],
                 fill=(130, 190, 255, 210))
    draw.polygon([(tx - drop_r * 0.6, ty - drop_r * 0.3),
                  (tx, ty - drop_r * 2.8),
                  (tx + drop_r * 0.6, ty - drop_r * 0.3)],
                 fill=(130, 190, 255, 210))


# ─── Mouth drawing ───────────────────────────────────────────────────

def draw_mouth_idle(img, cx, cy, mouth_w, outline_c, scale):
    draw = ImageDraw.Draw(img)
    r = mouth_w / 2
    draw.arc([cx - r, cy - r * 0.4, cx + r, cy + r * 1.2],
             start=15, end=165, fill=outline_c + (255,), width=max(2, int(3 * scale)))


def draw_mouth_happy(img, cx, cy, mouth_w, outline_c, scale):
    draw = ImageDraw.Draw(img)
    r = mouth_w / 2
    draw.pieslice([cx - r, cy - r * 0.3, cx + r, cy + r * 1.1],
                  start=0, end=180, fill=(200, 80, 80, 255),
                  outline=outline_c + (255,), width=max(2, int(2 * scale)))
    # Tongue
    tr = mouth_w * 0.14
    draw.ellipse([cx - tr, cy + r * 0.25 - tr, cx + tr, cy + r * 0.25 + tr],
                 fill=(255, 130, 130, 255))


def draw_mouth_excited(img, cx, cy, mouth_w, outline_c, scale):
    draw = ImageDraw.Draw(img)
    r = mouth_w * 0.22
    draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                 fill=(70, 35, 35, 255), outline=outline_c + (255,), width=max(2, int(2 * scale)))


def draw_mouth_sad(img, cx, cy, mouth_w, outline_c, scale):
    draw = ImageDraw.Draw(img)
    r = mouth_w / 2
    # Thicker stroke + tighter arc for visibility at @1x
    draw.arc([cx - r, cy - r * 0.6, cx + r, cy + r * 1.2],
             start=200, end=340, fill=outline_c + (255,), width=max(4, int(5 * scale)))


# ─── Blush ───────────────────────────────────────────────────────────

def draw_blush(img, cx, cy, face_w, blush_color, scale):
    """Soft blush circles with gaussian edge."""
    canvas_size = img.size[0]
    blush = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    r = face_w * 0.075
    gap = face_w * 0.35
    for side in [-1, 1]:
        bx = cx + side * gap
        by = cy + face_w * 0.06
        # Multiple layers for softness
        for alpha, sr in [(40, r * 1.3), (60, r * 1.0), (80, r * 0.7)]:
            bd.ellipse([bx - sr, by - sr, bx + sr, by + sr],
                       fill=blush_color + (alpha,))

    blush = blush.filter(ImageFilter.GaussianBlur(radius=4))
    return paste_composite(img, blush)


# ─── Accessories ─────────────────────────────────────────────────────

def draw_accessory_ribbon(draw, cx, top_y, color, outline_c, scale):
    r = int(20 * scale)
    by = top_y - int(8 * scale)
    draw.ellipse([cx - r * 2, by - r, cx - r * 0.3, by + r],
                 fill=color + (255,), outline=outline_c + (255,), width=2)
    draw.ellipse([cx + r * 0.3, by - r, cx + r * 2, by + r],
                 fill=color + (255,), outline=outline_c + (255,), width=2)
    draw.ellipse([cx - 6, by - 6, cx + 6, by + 6], fill=outline_c + (255,))


def draw_accessory_droplet(draw, cx, top_y, color, outline_c, scale):
    r = int(14 * scale)
    dy = top_y - int(16 * scale)
    draw.ellipse([cx - r, dy - r * 0.5, cx + r, dy + r],
                 fill=color + (255,), outline=outline_c + (255,), width=2)
    draw.polygon([(cx - r * 0.5, dy - r * 0.2), (cx, dy - r * 2.5), (cx + r * 0.5, dy - r * 0.2)],
                 fill=color + (255,), outline=outline_c + (255,))


def draw_accessory_leaf(draw, cx, top_y, color, outline_c, scale):
    ly = top_y - int(10 * scale)
    # Symmetric leaf: left edge + right edge using sine curve
    leaf_h = int(30 * scale)
    leaf_w = int(14 * scale)
    pts = []
    # Left edge: top to bottom
    for i in range(25):
        t = i / 24
        x = cx - leaf_w * math.sin(t * math.pi)
        y = ly - leaf_h * t
        pts.append((int(x), int(y)))
    # Right edge: bottom to top
    for i in range(24, -1, -1):
        t = i / 24
        x = cx + leaf_w * math.sin(t * math.pi)
        y = ly - leaf_h * t
        pts.append((int(x), int(y)))
    draw.polygon(pts, fill=color + (255,), outline=outline_c + (255,))
    # Stem line
    draw.line([(cx, ly), (cx, ly - leaf_h)], fill=outline_c + (255,), width=max(2, int(2 * scale)))


def draw_accessory_flame(draw, cx, top_y, color, outline_c, scale):
    fy = top_y - int(5 * scale)
    s = scale * 1.4
    pts = [
        (cx - 12*s, fy), (cx - 10*s, fy - 18*s), (cx - 4*s, fy - 12*s),
        (cx, fy - 30*s), (cx + 4*s, fy - 12*s), (cx + 10*s, fy - 18*s),
        (cx + 12*s, fy)
    ]
    pts = [(int(x), int(y)) for x, y in pts]
    draw.polygon(pts, fill=(255, 140, 0, 255), outline=outline_c + (255,))
    pts2 = [(int(cx - 6*s), int(fy)), (int(cx), int(fy - 15*s)), (int(cx + 6*s), int(fy))]
    draw.polygon(pts2, fill=(255, 220, 50, 255))


def draw_accessory_horns(draw, cx, top_y, color, outline_c, scale):
    for side in [-1, 1]:
        hx = cx + int(18 * scale * side)
        pts = [
            (int(hx - 8*scale), int(top_y)),
            (int(hx), int(top_y - 28*scale)),
            (int(hx + 8*scale), int(top_y))
        ]
        draw.polygon(pts, fill=color + (255,), outline=outline_c + (255,), width=2)


def draw_accessory_star(draw, cx, top_y, color, outline_c, scale):
    sy = top_y - int(22 * scale)
    star_r = 16 * scale
    star_ir = star_r * 0.38
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = star_r if i % 2 == 0 else star_ir
        pts.append((int(cx + r * math.cos(a)), int(sy - r * math.sin(a))))
    draw.polygon(pts, fill=color + (255,), outline=outline_c + (255,), width=1)
    draw.ellipse([cx - 3, sy - 6, cx + 3, sy - 1], fill=(255, 255, 255, 200))


ACCESSORY_FUNCS = {
    'ribbon': draw_accessory_ribbon,
    'droplet': draw_accessory_droplet,
    'leaf': draw_accessory_leaf,
    'flame': draw_accessory_flame,
    'horns': draw_accessory_horns,
    'star': draw_accessory_star,
}


# ─── Main generation ─────────────────────────────────────────────────

def generate_character(color_name, state, size=SIZE):
    char = CHARACTERS[color_name]
    is_mini = (state == 'mini')
    canvas_size = MINI_SIZE if is_mini else size
    s = canvas_size / SIZE  # scale factor

    c_light = char['body_light']
    c_dark = char['body_dark']
    outline_c = char['outline']
    eye_color = char['eye_color']
    eye_light = char['eye_light']
    blush_c = char['blush']

    # Body dimensions
    if is_mini:
        body_w = 320 * s
        body_h = 340 * s
    else:
        body_w = 400 * s
        body_h = 520 * s

    hw = body_w / 2
    hh = body_h / 2
    cx = canvas_size / 2
    cy = canvas_size / 2 + 20 * s

    # 1. Egg body mask + gradient
    mask = make_egg_mask(cx, cy, hw, hh, canvas_size)
    body_rgba = fill_gradient_mask(mask, c_light, c_dark, cy, hh)
    img = numpy_to_pil(body_rgba)

    # 2. Outline (via mask dilation)
    outline_w = int(6 * s)
    # Only apply outline if outline_w > 0
    if outline_w >= 2:
        img = draw_outline_fast(img, mask, outline_c, outline_w, canvas_size)

    # 3. Drop shadow
    img = draw_drop_shadow(img, cx, cy, hw, hh, canvas_size)

    # 4. Vinyl highlight
    img = draw_vinyl_highlight(img, cx, cy, body_w, body_h)

    # 5. Feet
    foot_color = lerp_color(c_dark, outline_c, 0.3)
    foot_y = cy + hh - 5 * s
    img = draw_feet(img, cx, foot_y, body_w, foot_color, outline_c, s)

    # 6. Face
    if is_mini:
        # Mini: simplified face
        draw = ImageDraw.Draw(img)
        eye_w = 35 * s
        gap = eye_w * 1.2
        face_cy = cy - body_h * 0.08

        # Dot eyes
        for side in [-1, 1]:
            ex = cx + side * gap / 2
            ey = face_cy
            r = eye_w * 0.28
            draw.ellipse([ex - r, ey - r, ex + r, ey + r], fill=(20, 20, 20, 255))
            hr = r * 0.3
            draw.ellipse([ex + r * 0.15 - hr, ey - r * 0.25 - hr,
                          ex + r * 0.15 + hr, ey - r * 0.25 + hr],
                         fill=(255, 255, 255, 255))

        # Simple mouth
        mouth_w = 40 * s
        mouth_cy = cy + body_h * 0.08
        r = mouth_w / 2
        draw.arc([cx - r, mouth_cy - r * 0.3, cx + r, mouth_cy + r * 0.8],
                 start=10, end=170, fill=outline_c + (255,), width=max(2, int(3 * s)))

        # Mini blush
        face_w = body_w * 0.8
        br = face_w * 0.05
        bgap = face_w * 0.28
        for side in [-1, 1]:
            bx = cx + side * bgap
            by = face_cy + face_w * 0.08
            draw.ellipse([bx - br, by - br, bx + br, by + br], fill=blush_c + (80,))

        # Mini vinyl highlight (simpler, single)
        hl = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
        hl_w = body_w * 0.14
        hl_h = body_h * 0.18
        hl_cx = cx - body_w * 0.15
        hl_cy = cy - body_h * 0.18
        ImageDraw.Draw(hl).ellipse([hl_cx - hl_w, hl_cy - hl_h, hl_cx + hl_w, hl_cy + hl_h],
                                   fill=(255, 255, 255, 50))
        hl = hl.filter(ImageFilter.GaussianBlur(radius=3))
        img = paste_composite(img, hl)
    else:
        # Full detail face
        draw = ImageDraw.Draw(img)

        eye_w = 55 * s
        eye_h = 65 * s
        face_cy = cy - body_h * 0.12
        mouth_cy = cy + body_h * 0.08
        mouth_w = 70 * s
        face_w = body_w * 0.8

        if state == 'idle':
            draw_eyes_idle(img, cx, face_cy, eye_w, eye_h, eye_color, eye_light, outline_c, s)
            draw_mouth_idle(img, cx, mouth_cy, mouth_w, outline_c, s)
        elif state == 'happy':
            draw_eyes_happy(img, cx, face_cy, eye_w, eye_h, outline_c, s)
            draw_mouth_happy(img, cx, mouth_cy, mouth_w, outline_c, s)
        elif state == 'excited':
            draw_eyes_excited(img, cx, face_cy, eye_w, eye_h, eye_color, eye_light, outline_c, s)
            draw_mouth_excited(img, cx, mouth_cy, mouth_w, outline_c, s)
        elif state == 'sad':
            draw_eyes_sad(img, cx, face_cy, eye_w, eye_h, eye_color, eye_light, outline_c, s)
            draw_mouth_sad(img, cx, mouth_cy, mouth_w, outline_c, s)

        # Blush
        img = draw_blush(img, cx, face_cy, face_w, blush_c, s)

        # Accessory (positioned above the egg body)
        draw = ImageDraw.Draw(img)
        top_y = cy - hh - 2 * s  # slightly above body
        acc_func = ACCESSORY_FUNCS.get(char['accessory'])
        if acc_func:
            acc_color = lerp_color(c_light, c_dark, 0.35)
            acc_func(draw, cx, top_y, acc_color, outline_c, s)

    # 7. Add subtle noise texture to increase file size / detail richness
    noise = np.random.randint(0, 4, (canvas_size, canvas_size), dtype=np.uint8)
    img_arr = np.array(img)
    # Apply noise only to non-transparent pixels
    alpha_mask = img_arr[:, :, 3] > 128
    for c in range(3):
        channel = img_arr[:, :, c].astype(np.int16)
        channel[alpha_mask] += noise[alpha_mask].astype(np.int16) - 2
        channel = np.clip(channel, 0, 255)
        img_arr[:, :, c] = channel.astype(np.uint8)
    img = numpy_to_pil(img_arr)

    return img


def save_to_imageset(img, color, state, is_2x=True):
    suffix = '@2x' if is_2x else ''
    filename = f'egg_{color}_{state}{suffix}.png'
    imageset_dir = os.path.join(OUTDIR, f'egg_{color}_{state}.imageset')
    os.makedirs(imageset_dir, exist_ok=True)
    filepath = os.path.join(imageset_dir, filename)

    raw_path = os.path.join(RAWTMP, filename)
    img.save(raw_path, 'PNG')
    img.save(filepath, 'PNG')

    return filepath


def main():
    colors = ['pink', 'blue', 'green', 'red', 'black', 'yellow']
    states = ['idle', 'happy', 'excited', 'sad', 'mini']

    if len(sys.argv) > 1:
        args = sys.argv[1:]
        if len(args) == 1:
            colors = [args[0]]
        elif len(args) >= 2:
            colors = [args[0]]
            states = args[1:]  # each arg is a separate state

    total = len(colors) * len(states)
    done = 0

    for color in colors:
        for state in states:
            print(f'Generating {color}_{state}...', end=' ', flush=True)

            is_mini = (state == 'mini')
            canvas = MINI_SIZE if is_mini else SIZE

            img = generate_character(color, state, canvas)
            save_to_imageset(img, color, state, is_2x=True)

            # @1x via resize
            if is_mini:
                img_1x = img.resize((256, 256), Image.LANCZOS)
            else:
                img_1x = img.resize((512, 512), Image.LANCZOS)
            save_to_imageset(img_1x, color, state, is_2x=False)

            done += 1
            path = os.path.join(OUTDIR, f'egg_{color}_{state}.imageset/egg_{color}_{state}@2x.png')
            kb = os.path.getsize(path) // 1024
            print(f'{kb}KB [{done}/{total}]')

    print(f'\n✅ Done: {done} characters generated')


if __name__ == '__main__':
    main()
