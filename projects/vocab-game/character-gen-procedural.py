#!/usr/bin/env python3
"""
程序化蛋仔角色素材生成器 v3（基于 character-procedural-spec.md）
纯 Pillow + numpy，不调 API。
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import math
import os
import sys

# ─── 常量 ────────────────────────────────────────────────────────────

SIZE = 1024
MINI_SIZE = 512

OUTDIR = os.path.expanduser(
    '~/DevTeam/projects/vocab-game/VocabGame/Resources/Assets.xcassets/EggCharacters'
)
TMPDIR = os.path.expanduser('~/DevTeam/projects/vocab-game/character-gen/procedural')
os.makedirs(TMPDIR, exist_ok=True)

# ─── 角色颜色定义（来自规格文档 2.1）─────────────────────────────────

COLORS = {
    'yellow': {
        'r_top': 255, 'g_top': 230, 'b_top': 110,
        'r_delta': 40, 'g_delta': 55, 'b_delta': 40,
        'foot': (255, 200, 80),
        'accessory': 'crown',
    },
    'pink': {
        'r_top': 255, 'g_top': 200, 'b_top': 210,
        'r_delta': 40, 'g_delta': 55, 'b_delta': 50,
        'foot': (255, 170, 190),
        'accessory': 'bow',
    },
    'blue': {
        'r_top': 160, 'g_top': 210, 'b_top': 255,
        'r_delta': 30, 'g_delta': 45, 'b_delta': 40,
        'foot': (120, 180, 230),
        'accessory': 'sailor_hat',
    },
    'green': {
        'r_top': 170, 'g_top': 240, 'b_top': 170,
        'r_delta': 40, 'g_delta': 55, 'b_delta': 40,
        'foot': (130, 210, 130),
        'accessory': 'sprouts',
    },
    'red': {
        'r_top': 255, 'g_top': 160, 'b_top': 150,
        'r_delta': 40, 'g_delta': 50, 'b_delta': 40,
        'foot': (255, 120, 110),
        'accessory': 'star_clip',
    },
    'black': {
        'r_top': 140, 'g_top': 140, 'b_top': 145,
        'r_delta': 50, 'g_delta': 50, 'b_delta': 50,
        'foot': (100, 100, 105),
        'accessory': 'horns',
    },
}

# ─── 体型参数（来自规格文档 1.0）─────────────────────────────────────

BODY_CX = 512
BODY_CY = 547
BODY_RX = 360
BODY_RY = 265
FOOT_RADIUS = 50
FOOT_Y = BODY_CY + BODY_RY - 30
FOOT_OFFSET = 95
EYE_Y = BODY_CY - 55
EYE_RX = 38
EYE_RY = 34
EYE_OFFSET = 75
PUPIL_R = 24
BLUSH_Y = EYE_Y + 48
BLUSH_RX = 25
BLUSH_RY = 15
MOUTH_Y = EYE_Y + 68


# ─── Numpy 渐变填充 ─────────────────────────────────────────────────

def make_ellipse_mask(cx, cy, rx, ry, canvas_size):
    """Anti-aliased ellipse mask with 5% edge gradient."""
    y, x = np.ogrid[:canvas_size, :canvas_size]
    dx = (x - cx) / rx
    dy = (y - cy) / ry
    dist = math.sqrt(2) * np.sqrt(dx * dx + dy * dy)  # normalized distance
    # Edge AA: 5% transition
    mask = np.clip((1.0 - dist) / 0.05, 0.0, 1.0)
    return mask.astype(np.float32)


def body_gradient(mask, char, cx, cy, ry):
    """Fill body with per-pixel gradient (spec 2.1 formula)."""
    h, w = mask.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    y_coords = np.arange(h).reshape(-1, 1)

    t = np.clip((y_coords - (cy - ry)) / (2 * ry), 0.0, 1.0)
    light = 1.0 - t * 0.12

    r = np.clip((char['r_top'] - char['r_delta'] * t) * light, 0, 255)
    g = np.clip((char['g_top'] - char['g_delta'] * t) * light, 0, 255)
    b = np.clip((char['b_top'] - char['b_delta'] * t) * light, 0, 255)

    rgba[:, :, 0] = (r * mask).astype(np.uint8)
    rgba[:, :, 1] = (g * mask).astype(np.uint8)
    rgba[:, :, 2] = (b * mask).astype(np.uint8)
    rgba[:, :, 3] = (mask * 255).astype(np.uint8)
    return rgba


def pil_composite(base, overlay):
    """Alpha composite."""
    if not isinstance(base, Image.Image):
        base = Image.fromarray(base, 'RGBA')
    if not isinstance(overlay, Image.Image):
        overlay = Image.fromarray(overlay, 'RGBA')
    return Image.alpha_composite(base, overlay)


# ─── 绘图辅助 ───────────────────────────────────────────────────────

def draw_highlight(img, cx, cy):
    """Spec: body left-upper highlight ellipse, alpha=50, blur 20."""
    s = img.size[0]
    hl = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(hl)
    d.ellipse([cx - 180, cy - 180, cx + 40, cy - 40], fill=(255, 255, 255, 50))
    hl = hl.filter(ImageFilter.GaussianBlur(20))
    return pil_composite(img, hl)


def draw_shadow(img, cx, cy, rx, ry):
    """Spec: body bottom shadow, alpha=30, blur 10."""
    s = img.size[0]
    sh = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.ellipse([cx - rx + 80, cy + ry, cx + rx - 80, cy + ry + 20], fill=(0, 0, 0, 30))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    return pil_composite(img, sh)


def draw_feet(img, cx, cy, ry, foot_color, scale=1.0):
    """Two oval feet at bottom of body."""
    d = ImageDraw.Draw(img)
    fr = int(FOOT_RADIUS * scale)
    fy = int(cy + ry - 30 * scale)
    fo = int(FOOT_OFFSET * scale)
    for side in [-1, 1]:
        fx = cx + side * fo
        d.ellipse([fx - fr, fy - int(fr * 0.5), fx + fr, fy + int(fr * 0.5)],
                  fill=foot_color + (255,))
    return img


def draw_blush(img, cx, eye_y, scale=1.0, alpha=120):
    """Pink blush circles with gaussian blur."""
    s = img.size[0]
    bl = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bl)
    brx = int(BLUSH_RX * scale)
    bry = int(BLUSH_RY * scale)
    by = int((eye_y + 48 * scale))
    off = int(EYE_OFFSET * scale)
    for side in [-1, 1]:
        bx = cx + side * off
        bd.ellipse([bx - brx, by - bry, bx + brx, by + bry],
                   fill=(255, 130, 130, alpha))
    bl = bl.filter(ImageFilter.GaussianBlur(6))
    return pil_composite(img, bl)


# ─── 眼睛绘制 ───────────────────────────────────────────────────────

def draw_eyes_idle(img, cx, eye_y, scale=1.0):
    """White sclera + black pupil + 2 highlights."""
    d = ImageDraw.Draw(img)
    erx = int(EYE_RX * scale)
    ery = int(EYE_RY * scale)
    pr = int(PUPIL_R * scale)
    off = int(EYE_OFFSET * scale)
    for side in [-1, 1]:
        ex = cx + side * off
        # Sclera
        d.ellipse([ex - erx, eye_y - ery, ex + erx, eye_y + ery],
                  fill=(255, 255, 255, 255))
        # Pupil (offset +4, +2)
        px = ex + int(4 * scale)
        py = eye_y + int(2 * scale)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(30, 30, 30, 255))
        # Highlights
        h1r = int(8 * scale)
        d.ellipse([px - pr * 0.4 - h1r, py - pr * 0.4 - h1r,
                   px - pr * 0.4 + h1r, py - pr * 0.4 + h1r],
                  fill=(255, 255, 255, 255))
        h2r = int(5 * scale)
        d.ellipse([px + pr * 0.3 - h2r, py + pr * 0.3 - h2r,
                   px + pr * 0.3 + h2r, py + pr * 0.3 + h2r],
                  fill=(255, 255, 255, 255))


def draw_eyes_happy(img, cx, eye_y, scale=1.0):
    """Closed crescent eyes (^_^)."""
    d = ImageDraw.Draw(img)
    off = int(EYE_OFFSET * scale)
    w = int(30 * scale)
    h = int(10 * scale)
    for side in [-1, 1]:
        ex = cx + side * off
        d.arc([ex - w, eye_y - h, ex + w, eye_y + h],
              start=200, end=340, fill=(60, 50, 40, 255), width=max(2, int(7 * scale)))


def draw_eyes_excited(img, cx, eye_y, scale=1.0):
    """Extra-large eyes with 3 big sparkle highlights."""
    d = ImageDraw.Draw(img)
    erx = int(52 * scale)  # P0 fix: enlarged from 1.15x to ~1.37x
    ery = int(48 * scale)
    pr = int(30 * scale)   # larger pupil
    off = int(EYE_OFFSET * scale)
    for side in [-1, 1]:
        ex = cx + side * off
        d.ellipse([ex - erx, eye_y - ery, ex + erx, eye_y + ery],
                  fill=(255, 255, 255, 255))
        px = ex + int(4 * scale)
        py = eye_y + int(2 * scale)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(30, 30, 30, 255))
        # 3 big highlights (enlarged)
        for dx, dy, hr in [(-0.5, -0.5, 14), (0.3, 0.2, 10), (-0.2, 0.4, 7)]:
            hx = int(px + pr * dx * scale)
            hy = int(py + pr * dy * scale)
            r = int(hr * scale)
            d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=(255, 255, 255, 255))


def draw_eyes_sad(img, cx, eye_y, scale=1.0):
    """Normal eyes, pupil shifted down, 1 highlight, + teardrop + eyebrows."""
    d = ImageDraw.Draw(img)
    erx = int(EYE_RX * scale)
    ery = int(EYE_RY * scale)
    pr = int(PUPIL_R * scale)
    off = int(EYE_OFFSET * scale)
    for side in [-1, 1]:
        ex = cx + side * off
        d.ellipse([ex - erx, eye_y - ery, ex + erx, eye_y + ery],
                  fill=(255, 255, 255, 255))
        # Pupil shifted down (+8) and inward (-2)
        px = ex + int((-2) * scale)
        py = eye_y + int(8 * scale)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(30, 30, 30, 255))
        # 1 highlight only
        hr = int(7 * scale)
        d.ellipse([px - pr * 0.4 - hr, py - pr * 0.4 - hr,
                   px - pr * 0.4 + hr, py - pr * 0.4 + hr],
                  fill=(255, 255, 255, 255))
    # Sad eyebrows (八字眉)
    for side in [-1, 1]:
        ex = cx + side * off
        by = eye_y - int(ery * 1.3)
        bw = int(25 * scale)
        # Inner end lower, outer end higher
        inner_x = cx
        outer_x = ex + side * int(10 * scale)
        d.line([(inner_x, by + int(5 * scale)), (outer_x, by - int(3 * scale))],
               fill=(60, 50, 40, 180), width=max(2, int(3 * scale)))

    # Teardrop on left eye outer corner (P0 fix: doubled size)
    tx = cx - off - int(erx * 0.6)
    ty = eye_y - int(5 * scale)
    drx, dry = int(16 * scale), int(20 * scale)
    d.ellipse([tx - drx, ty - dry, tx + drx, ty + dry],
              fill=(180, 210, 240, 180))
    # Drop tip (pointed bottom, extended)
    tip_y = ty + dry + int(20 * scale)
    d.polygon([(tx - int(drx * 0.5), ty + int(dry * 0.2)),
               (tx, tip_y),
               (tx + int(drx * 0.5), ty + int(dry * 0.2))],
              fill=(180, 210, 240, 180))


# ─── 嘴巴绘制 ───────────────────────────────────────────────────────

def draw_mouth_idle(img, cx, mouth_y, scale=1.0):
    d = ImageDraw.Draw(img)
    r = int(20 * scale)
    d.arc([cx - r, mouth_y - int(r * 0.4), cx + r, mouth_y + int(r * 0.6)],
          start=10, end=170, fill=(80, 60, 40, 255), width=max(2, int(4 * scale)))


def draw_mouth_happy(img, cx, mouth_y, scale=1.0):
    """Bigger smile arc, wider."""
    d = ImageDraw.Draw(img)
    r = int(28 * scale)
    d.arc([cx - r, mouth_y - int(r * 0.3), cx + r, mouth_y + int(r * 0.8)],
          start=5, end=175, fill=(80, 60, 40, 255), width=max(2, int(5 * scale)))


def draw_mouth_excited(img, cx, mouth_y, scale=1.0):
    """Big O-shaped open mouth with pink tongue."""
    d = ImageDraw.Draw(img)
    mrx = int(22 * scale)
    mry = int(18 * scale)
    d.ellipse([cx - mrx, mouth_y - mry, cx + mrx, mouth_y + mry],
              fill=(40, 30, 30, 255))
    # Pink tongue
    tr = int(8 * scale)
    d.ellipse([cx - tr, mouth_y + int(mry * 0.2) - tr, cx + tr, mouth_y + int(mry * 0.2) + tr],
              fill=(240, 140, 140, 255))


def draw_mouth_sad(img, cx, mouth_y, scale=1.0):
    """Inverted arc (frown)."""
    d = ImageDraw.Draw(img)
    r = int(20 * scale)
    d.arc([cx - r, mouth_y - int(r * 0.5), cx + r, mouth_y + int(r * 0.4)],
          start=190, end=350, fill=(80, 60, 40, 255), width=max(2, int(4 * scale)))


# ─── 配饰绘制 ───────────────────────────────────────────────────────

def draw_accessory_crown(d, cx, cy, ry, scale=1.0):
    """Gold crown with 3 points and red gem."""
    acy = int(cy - ry + 20 * scale)
    cw = int(75 * scale)
    ch = int(55 * scale)
    pts = [
        (cx - cw, acy),
        (cx - int(cw * 0.7), acy - ch),
        (cx - int(cw * 0.35), acy - int(ch * 0.4)),
        (cx, acy - ch),
        (cx + int(cw * 0.35), acy - int(ch * 0.4)),
        (cx + int(cw * 0.7), acy - ch),
        (cx + cw, acy),
    ]
    d.polygon(pts, fill=(255, 200, 0, 255), outline=(200, 160, 0, 255))
    # Red gem
    gr = int(7 * scale)
    d.ellipse([cx - gr, acy - int(ch * 0.15) - gr, cx + gr, acy - int(ch * 0.15) + gr],
              fill=(220, 50, 50, 255))


def draw_accessory_bow(d, cx, cy, ry, scale=1.0):
    """Deep pink ribbon bow, offset right."""
    bx = int(cx + 40 * scale)
    by = int(cy - ry - 10 * scale)
    ww = int(60 * scale)
    wh = int(45 * scale)
    # Left wing
    d.ellipse([bx - ww - int(5 * scale), by - wh, bx - int(5 * scale), by + wh],
              fill=(220, 50, 100, 255), outline=(180, 30, 70, 255), width=max(1, int(2 * scale)))
    # Right wing
    d.ellipse([bx + int(5 * scale), by - wh, bx + ww + int(5 * scale), by + wh],
              fill=(220, 50, 100, 255), outline=(180, 30, 70, 255), width=max(1, int(2 * scale)))
    # Center knot
    kr = int(9 * scale)
    d.ellipse([bx - kr, by - kr, bx + kr, by + kr], fill=(180, 30, 70, 255))


def draw_accessory_sailor_hat(d, cx, cy, ry, scale=1.0):
    """White sailor hat with blue band and anchor."""
    hy = int(cy - ry + 15 * scale)
    hw = int(80 * scale)
    hh = int(35 * scale)
    # Hat top (rounded rect)
    d.rounded_rectangle([cx - hw, hy - hh, cx + hw, hy + int(hh * 0.3)],
                        radius=int(10 * scale), fill=(245, 245, 255, 255),
                        outline=(30, 60, 140, 255), width=max(1, int(2 * scale)))
    # Brim
    d.ellipse([cx - int(90 * scale), hy - int(12 * scale),
               cx + int(90 * scale), hy + int(12 * scale)],
              fill=(30, 60, 140, 255))
    # Band
    d.rectangle([cx - hw, hy - int(5 * scale), cx + hw, hy + int(3 * scale)],
                fill=(30, 60, 140, 255))
    # Anchor (simplified T)
    ax = cx
    ay = hy - int(hh * 0.4)
    aw = int(8 * scale)
    ah = int(14 * scale)
    d.line([(ax, ay - ah), (ax, ay + ah)], fill=(30, 60, 140, 255), width=max(1, int(2 * scale)))
    d.line([(ax - aw, ay), (ax + aw, ay)], fill=(30, 60, 140, 255), width=max(1, int(2 * scale)))


def draw_accessory_sprouts(d, cx, cy, ry, scale=1.0):
    """Two grass sprout leaves."""
    sx = int(cx - 15 * scale)
    sy = int(cy - ry - 20 * scale)
    # Left leaf (rotated ellipse approximated with polygon)
    lrx, lry = int(12 * scale), int(35 * scale)
    pts_l = []
    for i in range(30):
        t = i / 29
        a = t * math.pi
        lx = sx - lrx * math.sin(a) * math.cos(-0.5) - lry * math.sin(a) * math.sin(-0.5) * 0.3
        ly = sy - lry * math.cos(a) * 0.8 + lrx * math.sin(a) * math.sin(-0.5) * 0.3
        pts_l.append((int(sx + (-lrx * math.sin(a)) * math.cos(-0.5) - lry * (1 - t) * 0.3),
                       int(sy - lry * t)))
    # Simplified: just two elongated ellipses
    # Left leaf
    pts_left = []
    for i in range(20):
        t = i / 19
        x = sx + int(-14 * scale * math.sin(t * math.pi))
        y = sy - int(35 * scale * t)
        pts_left.append((x, y))
    for i in range(19, -1, -1):
        t = i / 19
        x = sx + int(14 * scale * math.sin(t * math.pi) * 0.6)
        y = sy - int(35 * scale * t)
        pts_left.append((x, y))
    d.polygon(pts_left, fill=(50, 160, 50, 255), outline=(30, 100, 30, 255))
    # Right leaf
    sx2 = int(cx + 5 * scale)
    pts_right = []
    for i in range(20):
        t = i / 19
        x = sx2 + int(12 * scale * math.sin(t * math.pi))
        y = sy - int(30 * scale * t)
        pts_right.append((x, y))
    for i in range(19, -1, -1):
        t = i / 19
        x = sx2 - int(10 * scale * math.sin(t * math.pi) * 0.6)
        y = sy - int(30 * scale * t)
        pts_right.append((x, y))
    d.polygon(pts_right, fill=(60, 180, 60, 255), outline=(30, 100, 30, 255))
    # Stem
    d.line([(cx, sy + int(5 * scale)), (cx, sy - int(5 * scale))],
           fill=(60, 120, 40, 255), width=max(2, int(4 * scale)))


def draw_accessory_star_clip(d, cx, cy, ry, scale=1.0):
    """Gold five-pointed star hair clip, right side."""
    sx = int(cx + 60 * scale)
    sy = int(cy - ry + 30 * scale)
    sr = int(32 * scale)
    sir = int(14 * scale)
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = sr if i % 2 == 0 else sir
        pts.append((int(sx + r * math.cos(a)), int(sy - r * math.sin(a))))
    d.polygon(pts, fill=(255, 210, 0, 255), outline=(200, 160, 0, 255))
    # Clip pin
    d.line([(sx, sy + sr), (sx, sy + sr + int(15 * scale))],
           fill=(200, 160, 0, 255), width=max(1, int(3 * scale)))


def draw_accessory_horns(d, cx, cy, ry, scale=1.0):
    """Two dark red devil horns."""
    for side in [-1, 1]:
        hx = cx + int(side * 50 * scale)
        hy = int(cy - ry - 5 * scale)
        hw = int(35 * scale)
        hh = int(45 * scale)
        pts = [
            (hx - int(hw * 0.5), hy),
            (hx + int(hw * 0.5), hy),
            (hx + side * int(hw * 0.3), hy - hh),
        ]
        d.polygon(pts, fill=(60, 20, 20, 255), outline=(40, 10, 10, 255))


ACCESSORY_FUNCS = {
    'crown': draw_accessory_crown,
    'bow': draw_accessory_bow,
    'sailor_hat': draw_accessory_sailor_hat,
    'sprouts': draw_accessory_sprouts,
    'star_clip': draw_accessory_star_clip,
    'horns': draw_accessory_horns,
}


# ─── 主生成函数 ─────────────────────────────────────────────────────

def generate_character(color_name, state, canvas_size=SIZE):
    char = COLORS[color_name]
    is_mini = (state == 'mini')
    s = canvas_size / SIZE  # scale factor

    cx = int(BODY_CX * s)
    cy = int(BODY_CY * s)
    rx = int(BODY_RX * s)
    ry = int(BODY_RY * s)
    eye_y = int(EYE_Y * s)
    mouth_y = int(MOUTH_Y * s)

    # 1. Body mask + gradient
    mask = make_ellipse_mask(cx, cy, rx, ry, canvas_size)
    body_rgba = body_gradient(mask, char, cx, cy, ry)
    img = Image.fromarray(body_rgba, 'RGBA')

    # 2. Shadow
    img = draw_shadow(img, cx, cy, rx, ry)

    # 3. Highlight
    img = draw_highlight(img, cx, cy)

    # 4. Feet
    img = draw_feet(img, cx, cy, ry, char['foot'], s)

    # 5. Face (eyes + mouth + blush)
    if state == 'idle':
        draw_eyes_idle(img, cx, eye_y, s)
        draw_mouth_idle(img, cx, mouth_y, s)
        img = draw_blush(img, cx, eye_y, s, alpha=120)
    elif state == 'happy':
        draw_eyes_happy(img, cx, eye_y, s)
        draw_mouth_happy(img, cx, mouth_y, s)
        img = draw_blush(img, cx, eye_y, s, alpha=150)  # P1: stronger blush
    elif state == 'excited':
        draw_eyes_excited(img, cx, eye_y, s)
        draw_mouth_excited(img, cx, mouth_y, s)
        img = draw_blush(img, cx, eye_y, s, alpha=160)
    elif state == 'sad':
        draw_eyes_sad(img, cx, eye_y, s)
        draw_mouth_sad(img, cx, mouth_y, s)
        img = draw_blush(img, cx, eye_y, s, alpha=120)
    elif state == 'mini':
        # Mini = scaled idle on target canvas
        # Generate full idle at 1024 then resize to target canvas_size
        idle_full = generate_character(color_name, 'idle', SIZE)
        mini_img = idle_full.resize((canvas_size, canvas_size), Image.LANCZOS)
        return mini_img

    # 6. Accessory
    if state != 'mini':
        d = ImageDraw.Draw(img)
        acc_func = ACCESSORY_FUNCS.get(char['accessory'])
        if acc_func:
            acc_func(d, cx, cy, ry, s)

    return img


def save_to_imageset(img, color, state, is_2x=True):
    suffix = '@2x' if is_2x else ''
    filename = f'egg_{color}_{state}{suffix}.png'
    imageset_dir = os.path.join(OUTDIR, f'egg_{color}_{state}.imageset')
    os.makedirs(imageset_dir, exist_ok=True)
    filepath = os.path.join(imageset_dir, filename)
    img.save(filepath, 'PNG')

    raw_path = os.path.join(TMPDIR, filename)
    img.save(raw_path, 'PNG')
    return filepath


def main():
    colors = ['yellow', 'pink', 'blue', 'green', 'red', 'black']
    states = ['idle', 'happy', 'excited', 'sad', 'mini']

    if len(sys.argv) > 1:
        args = sys.argv[1:]
        if len(args) == 1:
            colors = [args[0]]
        elif len(args) >= 2:
            colors = [args[0]]
            states = args[1:]

    total = len(colors) * len(states)
    done = 0

    for color in colors:
        for state in states:
            print(f'Generating {color}_{state}...', end=' ', flush=True)
            is_mini = (state == 'mini')
            # mini @2x = 512x512, others @2x = 1024x1024
            if is_mini:
                # Generate idle at 1024, scale down to 512 for @2x
                idle_full = generate_character(color, 'idle', SIZE)
                img = idle_full.resize((MINI_SIZE, MINI_SIZE), Image.LANCZOS)
            else:
                img = generate_character(color, state, SIZE)

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
