#!/usr/bin/env python3
"""
程序化生成蛋仔角色素材（Pillow 本地生成）

用法：
  python3 character-gen-procedural.py
  python3 character-gen-procedural.py --color yellow --state idle
  python3 character-gen-procedural.py --dry-run

输出到 ~/DevTeam/projects/vocab-game/character-gen/
"""

import argparse
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_ROOT = Path("~/DevTeam/projects/vocab-game/character-gen").expanduser()

COLORS = ["yellow", "pink", "blue", "green", "red", "black"]
STATES = ["idle", "happy", "excited", "sad"]

CHAR_COLORS = {
    "yellow": {"r_top": 255, "g_top": 230, "b_top": 110, "r_delta": 40, "g_delta": 55, "b_delta": 40, "foot": (255, 200, 80)},
    "pink":   {"r_top": 255, "g_top": 200, "b_top": 210, "r_delta": 40, "g_delta": 55, "b_delta": 50, "foot": (255, 170, 190)},
    "blue":   {"r_top": 160, "g_top": 210, "b_top": 255, "r_delta": 30, "g_delta": 45, "b_delta": 40, "foot": (120, 180, 230)},
    "green":  {"r_top": 170, "g_top": 240, "b_top": 170, "r_delta": 40, "g_delta": 55, "b_delta": 40, "foot": (130, 210, 130)},
    "red":    {"r_top": 255, "g_top": 160, "b_top": 150, "r_delta": 40, "g_delta": 50, "b_delta": 40, "foot": (255, 120, 110)},
    "black":  {"r_top": 140, "g_top": 140, "b_top": 145, "r_delta": 50, "g_delta": 50, "b_delta": 50, "foot": (100, 100, 105)},
}

# Body constants
CX, CY = SIZE // 2, SIZE // 2 + 35
BODY_RX, BODY_RY = 360, 265
EYE_Y = CY - 55
EYE_DX = 75


def create_layer(size=SIZE):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def draw_body(color_key):
    layer = create_layer()
    pixels = layer.load()
    cc = CHAR_COLORS[color_key]
    for py in range(max(0, CY - BODY_RY - 2), min(SIZE, CY + BODY_RY + 2)):
        dy_norm = (py - CY) / BODY_RY
        if abs(dy_norm) >= 1: continue
        x_r = int(BODY_RX * math.sqrt(1 - dy_norm**2))
        t = max(0, min(1, (py - (CY - BODY_RY)) / (2 * BODY_RY)))
        light = 1.0 - t * 0.12
        r = min(255, int((cc["r_top"] - cc["r_delta"] * t) * light))
        g = min(255, int((cc["g_top"] - cc["g_delta"] * t) * light))
        b = min(255, int((cc["b_top"] - cc["b_delta"] * t) * light))
        for px in range(max(0, CX - x_r - 1), min(SIZE, CX + x_r + 1)):
            dx_norm = (px - CX) / max(1, x_r)
            if abs(dx_norm) > 1: continue
            ea = min(1.0, (1.0 - abs(dx_norm)) / 0.05) if abs(dx_norm) > 0.95 else 1.0
            pixels[px, py] = (r, g, b, int(255 * ea))
    return layer


def draw_highlight():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    d.ellipse([CX - 180, CY - 180, CX + 40, CY - 40], fill=(255, 255, 255, 50))
    d.ellipse([CX - 120, CY - BODY_RY + 30, CX - 60, CY - BODY_RY + 90], fill=(255, 255, 255, 80))
    return layer.filter(ImageFilter.GaussianBlur(20))


def draw_shadow():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    d.ellipse([CX - BODY_RX + 80, CY + BODY_RY, CX + BODY_RX - 80, CY + BODY_RY + 20], fill=(0, 0, 0, 30))
    return layer.filter(ImageFilter.GaussianBlur(10))


def draw_feet(color_key):
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    fc = CHAR_COLORS[color_key]["foot"] + (255,)
    fy = CY + BODY_RY - 30
    for dx in [-95, 95]:
        fx = CX + dx
        d.ellipse([fx - 50, fy - 40, fx + 50, fy + 30], fill=fc)
    return layer


def draw_blush(alpha=120):
    layer = create_layer()
    by = EYE_Y + 48
    for dx in [-95, 95]:
        bl = create_layer()
        ImageDraw.Draw(bl).ellipse([CX + dx - 25, by - 15, CX + dx + 25, by + 15], fill=(255, 130, 130, alpha))
        bl = bl.filter(ImageFilter.GaussianBlur(6))
        layer = Image.alpha_composite(layer, bl)
    return layer


# --- Eyes ---

def draw_eyes_idle():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    for dx in [-EYE_DX, EYE_DX]:
        ex = CX + dx
        d.ellipse([ex-38, EYE_Y-34, ex+38, EYE_Y+34], fill=(255,255,255,255))
        d.ellipse([ex-20, EYE_Y-22, ex+28, EYE_Y+26], fill=(30,30,30,255))
        d.ellipse([ex-8, EYE_Y-12, ex+4, EYE_Y-2], fill=(255,255,255,255))
        d.ellipse([ex+8, EYE_Y-2, ex+16, EYE_Y+4], fill=(255,255,255,200))
    return layer


def draw_eyes_happy():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    for dx in [-EYE_DX, EYE_DX]:
        ex = CX + dx
        d.arc([ex-28, EYE_Y-10, ex+28, EYE_Y+12], start=200, end=340, fill=(40,30,30,255), width=7)
    return layer


def draw_eyes_excited():
    """excited 眼睛：白底 + 金色五角星瞳孔 + 3 夸张高光"""
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    for dx in [-EYE_DX, EYE_DX]:
        ex = CX + dx
        # 大白底
        d.ellipse([ex-44, EYE_Y-40, ex+44, EYE_Y+40], fill=(255,255,255,255))
        # 金色五角星瞳孔
        star_r_outer, star_r_inner = 28, 12
        star_cx, star_cy = ex + 3, EYE_Y + 2
        pts = []
        for i in range(10):
            a = math.radians(i * 36 - 90)
            r = star_r_outer if i % 2 == 0 else star_r_inner
            pts.append((star_cx + r * math.cos(a), star_cy + r * math.sin(a)))
        d.polygon(pts, fill=(255, 210, 0, 255))
        # 高光 1（大）
        d.ellipse([ex-12, EYE_Y-14, ex+2, EYE_Y-2], fill=(255,255,255,255))
        # 高光 2
        d.ellipse([ex+10, EYE_Y-4, ex+20, EYE_Y+4], fill=(255,255,255,255))
        # 高光 3
        d.ellipse([ex-4, EYE_Y+6, ex+4, EYE_Y+14], fill=(255,255,255,180))
    return layer


def draw_eyes_sad():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    for dx in [-EYE_DX, EYE_DX]:
        ex = CX + dx
        d.ellipse([ex-38, EYE_Y-34, ex+38, EYE_Y+34], fill=(255,255,255,255))
        d.ellipse([ex-22, EYE_Y-16, ex+26, EYE_Y+32], fill=(30,30,30,255))
        d.ellipse([ex-6, EYE_Y, ex+2, EYE_Y+6], fill=(255,255,255,180))
        # 八字眉
        by = EYE_Y - 42
        d.line([ex-25, by+(8 if dx<0 else 0), ex+25, by+(0 if dx<0 else 8)], fill=(60,50,40,180), width=3)
    # 泪滴（放大 50%，提高不透明度）
    tx, ty = CX - EYE_DX - 30, EYE_Y - 5
    d.ellipse([tx-12, ty-14, tx+12, ty+14], fill=(180,210,240,220))
    d.polygon([(tx-9, ty+8), (tx+9, ty+8), (tx, ty+32)], fill=(180,210,240,220))
    return layer


EYE_DRAWERS = {"idle": draw_eyes_idle, "happy": draw_eyes_happy, "excited": draw_eyes_excited, "sad": draw_eyes_sad}


# --- Mouths ---

def draw_mouth_idle():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    my = EYE_Y + 68
    d.arc([CX-22, my-8, CX+22, my+12], start=10, end=170, fill=(80,60,40,230), width=4)
    return layer

def draw_mouth_happy():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    my = EYE_Y + 68
    d.arc([CX-26, my-10, CX+26, my+16], start=5, end=175, fill=(80,60,40,230), width=5)
    d.ellipse([CX-8, my+4, CX+8, my+14], fill=(240,140,140,200))
    return layer

def draw_mouth_excited():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    my = EYE_Y + 68
    d.ellipse([CX-22, my-12, CX+22, my+16], fill=(40,30,30,230))
    d.ellipse([CX-14, my-4, CX+14, my+10], fill=(220,120,120,180))
    return layer

def draw_mouth_sad():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    my = EYE_Y + 68
    d.arc([CX-20, my-6, CX+20, my+14], start=190, end=350, fill=(80,60,40,230), width=4)
    return layer

MOUTH_DRAWERS = {"idle": draw_mouth_idle, "happy": draw_mouth_happy, "excited": draw_mouth_excited, "sad": draw_mouth_sad}


# --- Accessories ---

def draw_accessory_yellow():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    cy_top = CY - BODY_RY + 20
    cw, ch = 75, 55
    pts = [(CX-cw, cy_top+ch), (CX-cw+8, cy_top+ch*0.35), (CX-cw*0.45, cy_top+ch*0.7),
           (CX, cy_top), (CX+cw*0.45, cy_top+ch*0.7), (CX+cw-8, cy_top+ch*0.35), (CX+cw, cy_top+ch)]
    d.polygon(pts, fill=(255,200,0,255))
    d.polygon(pts, outline=(200,160,0,255))
    d.ellipse([CX-7, cy_top+18, CX+7, cy_top+32], fill=(220,50,50,255))
    return layer

def draw_accessory_pink():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    bcx, bcy = CX+55, CY-BODY_RY-5
    bc, bo = (220,50,100,255), (180,30,70,255)
    d.ellipse([bcx-60, bcy-30, bcx-5, bcy+20], fill=bc, outline=bo, width=2)
    d.ellipse([bcx+5, bcy-35, bcx+60, bcy+15], fill=bc, outline=bo, width=2)
    d.ellipse([bcx-12, bcy-12, bcx+12, bcy+12], fill=bo)
    return layer

def draw_accessory_blue():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    hy = CY - BODY_RY + 15
    d.rounded_rectangle([CX-80, hy-55, CX+80, hy+15], radius=20, fill=(245,245,255,255))
    d.rectangle([CX-78, hy+2, CX+78, hy+12], fill=(30,60,140,255))
    d.ellipse([CX-90, hy+10, CX+90, hy+35], fill=(30,60,140,255))
    ay = hy - 20
    d.line([CX, ay-12, CX, ay+10], fill=(30,60,140,255), width=3)
    d.arc([CX-8, ay+2, CX+8, ay+14], start=0, end=180, fill=(30,60,140,255), width=2)
    d.ellipse([CX-4, ay-16, CX+4, ay-8], fill=(30,60,140,255))
    return layer

def draw_accessory_green():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    bx, by = CX-15, CY-BODY_RY-5
    d.line([bx, by+15, bx, by+35], fill=(60,120,40,255), width=4)
    for ox, oy, erx, ery, rot, fc in [(-10,5,12,35,-30,(50,160,50)), (12,8,10,30,20,(60,180,60))]:
        pts = []
        for a in range(360):
            r = math.radians(a)
            lx, ly = erx*math.cos(r), ery*math.sin(r)
            rx = lx*math.cos(math.radians(rot)) - ly*math.sin(math.radians(rot))
            ry = lx*math.sin(math.radians(rot)) + ly*math.cos(math.radians(rot))
            pts.append((bx+ox+rx, by+oy+ry))
        d.polygon(pts, fill=fc+(255,), outline=(30,100,30,255))
    return layer

def draw_accessory_red():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    scx, scy = CX+65, CY-BODY_RY+30
    pts = []
    for i in range(10):
        a = math.radians(i*36-90)
        r = 32 if i%2==0 else 14
        pts.append((scx+r*math.cos(a), scy+r*math.sin(a)))
    d.polygon(pts, fill=(255,210,0,255), outline=(200,160,0,255))
    d.line([scx, scy+32, scx, scy+50], fill=(200,160,0,255), width=3)
    return layer

def draw_accessory_black():
    layer = create_layer()
    d = ImageDraw.Draw(layer)
    hby = CY - BODY_RY - 5
    hc, ho = (60,20,20,255), (40,10,10,255)
    d.polygon([(CX-70,hby+30),(CX-55,hby-15),(CX-40,hby+30)], fill=hc, outline=ho, width=2)
    d.polygon([(CX+40,hby+30),(CX+55,hby-15),(CX+70,hby+30)], fill=hc, outline=ho, width=2)
    return layer

ACCESSORY_DRAWERS = {
    "yellow": draw_accessory_yellow, "pink": draw_accessory_pink, "blue": draw_accessory_blue,
    "green": draw_accessory_green, "red": draw_accessory_red, "black": draw_accessory_black,
}


# --- Composite ---

def draw_character(color, state):
    """合成一个完整角色 @2x"""
    img = draw_body(color)
    img = Image.alpha_composite(img, draw_highlight())
    img = Image.alpha_composite(img, draw_shadow())
    img = Image.alpha_composite(img, draw_feet(color))
    blush_a = 160 if state == "excited" else (150 if state == "happy" else 120)
    img = Image.alpha_composite(img, draw_blush(blush_a))
    img = Image.alpha_composite(img, EYE_DRAWERS[state]())
    img = Image.alpha_composite(img, MOUTH_DRAWERS[state]())
    img = Image.alpha_composite(img, ACCESSORY_DRAWERS[color]())
    return img


def draw_mini(color):
    """mini 版本：idle 表情缩放到 60%，放在 512×512 画布上（@2x 尺寸）"""
    full = draw_character(color, "idle")
    mini_canvas = 512  # mini @2x = 512×512
    mini_size = int(mini_canvas * 0.75)  # 角色占画布 75%
    resized = full.resize((mini_size, mini_size), Image.LANCZOS)
    canvas = create_layer(mini_canvas)
    offset = (mini_canvas - mini_size) // 2
    canvas.paste(resized, (offset, offset), resized)
    return canvas


def main():
    parser = argparse.ArgumentParser(description="程序化生成蛋仔角色素材")
    parser.add_argument("--color", choices=COLORS, help="仅生成指定颜色")
    parser.add_argument("--state", choices=STATES + ["mini"], help="仅生成指定状态")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划不生成")
    args = parser.parse_args()

    colors = [args.color] if args.color else COLORS
    states = [args.state] if args.state else (STATES + ["mini"])

    tasks = [(c, s) for c in colors for s in states]
    print(f"🎨 将生成 {len(tasks)} 张图: {len(colors)} 色 × {len(states)} 状态")

    for i, (c, s) in enumerate(tasks, 1):
        tag = f"egg_{c}_{s}"
        if args.dry_run:
            print(f"  [{i}/{len(tasks)}] {tag} (dry-run)")
            continue

        print(f"  [{i}/{len(tasks)}] {tag} ...", end=" ", flush=True)
        if s == "mini":
            img = draw_mini(c)
        else:
            img = draw_character(c, s)

        # @2x
        out_2x = OUT_ROOT / f"{tag}@2x.png"
        out_2x.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(out_2x), "PNG")

        # @1x from @2x
        size_2x = img.size[0]  # mini=512, others=1024
        size_1x = size_2x // 2
        out_1x = OUT_ROOT / f"{tag}.png"
        img_1x = img.resize((size_1x, size_1x), Image.LANCZOS)
        img_1x.save(str(out_1x), "PNG")

        kb = out_2x.stat().st_size // 1024
        print(f"✅ ({kb}KB)")

    print(f"\n🎨 完成！输出目录: {OUT_ROOT}")


if __name__ == "__main__":
    main()
