#!/usr/bin/env python3
"""Generate egg character PNG assets for VocabGame v1.17.
v2: Fixed highlight, feet placement, rounded tuft.
"""
from PIL import Image, ImageDraw
import math
import os
import json

ASSETS_ROOT = os.path.expanduser(
    "~/DevTeam/projects/vocab-game/VocabGame/Resources/Assets.xcassets/EggCharacters"
)

CHARACTERS = {
    "egg_yellow": {"body": (255, 210, 50),  "cheek": (255, 160, 120), "name": "蛋小黄"},
    "egg_pink":   {"body": (255, 160, 190), "cheek": (255, 120, 150), "name": "蛋小粉"},
    "egg_blue":   {"body": (120, 190, 255), "cheek": (255, 160, 160), "name": "蛋小蓝"},
    "egg_green":  {"body": (140, 220, 140), "cheek": (255, 170, 140), "name": "蛋小绿"},
    "egg_black":  {"body": (70,  70,  80),  "cheek": (200, 140, 140), "name": "蛋小黑"},
    "egg_red":    {"body": (240, 90,  80),  "cheek": (255, 160, 130), "name": "蛋小红"},
}

STATES = ["idle", "happy", "sad", "excited", "mini"]


def egg_shape(cx, cy, w, h):
    points = []
    n = 80
    for i in range(n):
        t = 2 * math.pi * i / n
        x = cx + (w / 2) * math.sin(t)
        y_factor = 1.0 + 0.15 * math.cos(t)
        y = cy + (h / 2) * math.cos(t) * y_factor
        points.append((x, y))
    return points


def draw_egg_character(draw, cx, cy, size, char_key, state):
    info = CHARACTERS[char_key]
    body_color = info["body"]
    cheek_color = info["cheek"]

    w = size * 0.7
    h = size * 0.78

    # Shadow
    shadow_points = egg_shape(cx + 2, cy + 4, w, h)
    draw.polygon(shadow_points, fill=(0, 0, 0, 35))

    # Body
    body_points = egg_shape(cx, cy, w, h)
    draw.polygon(body_points, fill=body_color)

    # Body outline (subtle darker edge)
    draw.polygon(body_points, outline=(*[max(c - 40, 0) for c in body_color[:3]], 60))

    # Body highlight — upper area, NOT overlapping eyes
    shine_cx = cx
    shine_cy = cy - h * 0.38
    shine_rx = w * 0.2
    shine_ry = h * 0.12
    draw.ellipse(
        [shine_cx - shine_rx, shine_cy - shine_ry,
         shine_cx + shine_rx, shine_cy + shine_ry],
        fill=(*[min(c + 50, 255) for c in body_color[:3]], 80)
    )

    # Hair tuft (小揪揪) — rounded, softer
    tuft_base_y = cy - h * 0.4
    tuft_top_y = tuft_base_y - size * 0.14
    # Rounded tuft using overlapping ellipses
    tuft_color = (*[min(c + 20, 255) for c in body_color[:3]], 255)
    tuft_dark = body_color
    # Main tuft body
    draw.ellipse(
        [cx - size * 0.05, tuft_top_y - size * 0.04,
         cx + size * 0.07, tuft_base_y + size * 0.02],
        fill=tuft_color
    )
    # Tuft tip (slightly darker)
    draw.ellipse(
        [cx - size * 0.02, tuft_top_y - size * 0.06,
         cx + size * 0.04, tuft_top_y + size * 0.02],
        fill=tuft_dark
    )

    # Cheeks
    cheek_y = cy + h * 0.06
    cheek_r = size * 0.055
    draw.ellipse(
        [cx - w * 0.28 - cheek_r, cheek_y - cheek_r,
         cx - w * 0.28 + cheek_r, cheek_y + cheek_r],
        fill=(*cheek_color, 100)
    )
    draw.ellipse(
        [cx + w * 0.28 - cheek_r, cheek_y - cheek_r,
         cx + w * 0.28 + cheek_r, cheek_y + cheek_r],
        fill=(*cheek_color, 100)
    )

    # Eyes
    eye_y = cy - h * 0.06
    eye_spacing = w * 0.2
    eye_r = size * 0.05

    if state == "happy":
        for sign in [-1, 1]:
            ex = cx + sign * eye_spacing
            draw.arc(
                [ex - eye_r, eye_y - eye_r * 0.5, ex + eye_r, eye_y + eye_r * 0.7],
                start=10, end=170, fill=(50, 50, 60),
                width=max(2, int(size * 0.014))
            )
    elif state == "sad":
        for sign in [-1, 1]:
            ex = cx + sign * eye_spacing
            draw.ellipse(
                [ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r],
                fill=(50, 50, 60)
            )
            pr = eye_r * 0.35
            draw.ellipse(
                [ex - pr + eye_r * 0.2, eye_y - pr - eye_r * 0.15,
                 ex + pr + eye_r * 0.2, eye_y + pr - eye_r * 0.15],
                fill=(255, 255, 255)
            )
        # Tear
        tx = cx + eye_spacing + eye_r * 0.5
        ty = eye_y + eye_r * 1.3
        tear_r = eye_r * 0.3
        draw.ellipse([tx - tear_r, ty - tear_r, tx + tear_r, ty + tear_r],
                     fill=(150, 200, 255, 200))
    elif state == "excited":
        for sign in [-1, 1]:
            ex = cx + sign * eye_spacing
            big_r = eye_r * 1.4
            draw.ellipse(
                [ex - big_r, eye_y - big_r, ex + big_r, eye_y + big_r],
                fill=(50, 50, 60)
            )
            pr = big_r * 0.5
            draw.ellipse(
                [ex - pr + big_r * 0.15, eye_y - pr - big_r * 0.15,
                 ex + pr + big_r * 0.15, eye_y + pr - big_r * 0.15],
                fill=(255, 255, 255)
            )
            pr2 = big_r * 0.2
            draw.ellipse(
                [ex - pr2 - big_r * 0.25, eye_y + pr2 * 0.3,
                 ex + pr2 - big_r * 0.25, eye_y + pr2 * 1.5],
                fill=(255, 255, 255, 180)
            )
    else:  # idle
        for sign in [-1, 1]:
            ex = cx + sign * eye_spacing
            draw.ellipse(
                [ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r],
                fill=(50, 50, 60)
            )
            pr = eye_r * 0.35
            draw.ellipse(
                [ex - pr + eye_r * 0.2, eye_y - pr - eye_r * 0.12,
                 ex + pr + eye_r * 0.2, eye_y + pr - eye_r * 0.12],
                fill=(255, 255, 255)
            )

    # Egg小黑 eyepatch
    if char_key == "egg_black":
        patch_x = cx + eye_spacing
        patch_y = eye_y
        patch_r = eye_r * 1.6
        draw.ellipse(
            [patch_x - patch_r, patch_y - patch_r,
             patch_x + patch_r, patch_y + patch_r],
            fill=(30, 30, 30)
        )
        draw.line(
            [(patch_x - patch_r, patch_y - patch_r * 0.3),
             (cx - eye_spacing, eye_y - eye_r)],
            fill=(30, 30, 30), width=max(2, int(size * 0.012))
        )

    # Mouth
    mouth_y = cy + h * 0.14
    lw = max(2, int(size * 0.012))
    if state == "happy":
        mw = size * 0.14
        draw.arc(
            [cx - mw, mouth_y - mw * 0.2, cx + mw, mouth_y + mw * 0.7],
            start=10, end=170, fill=(50, 50, 60), width=lw
        )
    elif state == "sad":
        mw = size * 0.09
        draw.arc(
            [cx - mw, mouth_y - mw * 0.4, cx + mw, mouth_y + mw * 0.2],
            start=190, end=350, fill=(50, 50, 60), width=lw
        )
    elif state == "excited":
        mw = size * 0.07
        draw.ellipse(
            [cx - mw, mouth_y - mw * 0.5, cx + mw, mouth_y + mw * 0.5],
            fill=(50, 50, 60)
        )
        tw = mw * 0.45
        draw.ellipse(
            [cx - tw, mouth_y + mw * 0.05, cx + tw, mouth_y + mw * 0.55],
            fill=(240, 130, 130)
        )
    else:  # idle
        mw = size * 0.08
        draw.arc(
            [cx - mw, mouth_y - mw * 0.2, cx + mw, mouth_y + mw * 0.4],
            start=10, end=170, fill=(50, 50, 60), width=lw
        )

    # Feet (positioned higher to avoid cutoff)
    foot_y = cy + h * 0.42
    foot_w = size * 0.11
    foot_h = size * 0.055
    foot_color = (*[max(c - 30, 0) for c in body_color[:3]], 255)
    for sign in [-1, 1]:
        fx = cx + sign * w * 0.17
        draw.ellipse(
            [fx - foot_w, foot_y - foot_h * 0.3, fx + foot_w, foot_y + foot_h],
            fill=foot_color
        )


def generate_character(char_key, state, base_size):
    s = base_size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = s / 2, s / 2 + s * 0.02

    if state == "excited":
        cy -= s * 0.03

    draw_egg_character(draw, cx, cy, s, char_key, state)
    return img


def create_imageset(char_key, state, imageset_dir):
    os.makedirs(imageset_dir, exist_ok=True)
    sizes = {"@1x": 128 if state == "mini" else 512,
             "@2x": 256 if state == "mini" else 1024}
    filenames = []
    for scale, px in sizes.items():
        img = generate_character(char_key, state, px)
        fname = f"{char_key}_{state}{'@2x' if scale == '@2x' else ''}.png"
        img.save(os.path.join(imageset_dir, fname), "PNG")
        filenames.append(fname)

    contents = {
        "images": [
            {"filename": filenames[0], "idiom": "universal", "scale": "1x"},
            {"filename": filenames[1], "idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"}
        ],
        "info": {"author": "xcode", "version": 1}
    }
    with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    return imageset_dir


if __name__ == "__main__":
    os.makedirs(ASSETS_ROOT, exist_ok=True)
    for char_key in CHARACTERS:
        for state in STATES:
            imageset_name = f"{char_key}_{state}.imageset"
            create_imageset(char_key, state, os.path.join(ASSETS_ROOT, imageset_name))
            print(f"  ✓ {imageset_name}")
    print(f"\n✅ Generated {len(CHARACTERS) * len(STATES)} imagesets")
