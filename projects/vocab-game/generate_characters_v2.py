#!/usr/bin/env python3
"""
v2: Generate egg character PNGs inspired by official promotional art.
Uses PIL to create clean, high-quality egg characters with:
- Proper egg shape (wider at top, narrower at bottom)
- Big expressive eyes (official style)
- Small antenna/hair tuft
- Small feet
- Clean transparent background
- Consistent style across all 6 characters
"""
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUTDIR = os.path.expanduser('~/DevTeam/projects/vocab-game/VocabGame/Resources/Assets.xcassets/EggCharacters')
os.makedirs(OUTDIR, exist_ok=True)

# Character definitions with official-inspired colors
CHARACTERS = {
    'egg_yellow': {
        'body': (255, 215, 55),
        'body_light': (255, 235, 120),
        'body_dark': (220, 180, 30),
        'cheek': (255, 160, 120, 90),
    },
    'egg_pink': {
        'body': (255, 160, 190),
        'body_light': (255, 195, 210),
        'body_dark': (230, 130, 160),
        'cheek': (255, 130, 150, 80),
    },
    'egg_blue': {
        'body': (120, 195, 255),
        'body_light': (170, 220, 255),
        'body_dark': (80, 160, 230),
        'cheek': (255, 170, 170, 80),
    },
    'egg_green': {
        'body': (140, 220, 140),
        'body_light': (180, 240, 180),
        'body_dark': (100, 185, 100),
        'cheek': (255, 180, 150, 80),
    },
    'egg_black': {
        'body': (65, 65, 80),
        'body_light': (100, 100, 115),
        'body_dark': (40, 40, 55),
        'cheek': (200, 150, 150, 70),
    },
    'egg_red': {
        'body': (240, 90, 80),
        'body_light': (255, 140, 130),
        'body_dark': (200, 60, 55),
        'cheek': (255, 200, 200, 80),
    },
}

# Mood definitions
MOODS = {
    'idle': {'eye_type': 'open', 'mouth_type': 'smile', 'eye_y_off': 0},
    'happy': {'eye_type': 'happy_squint', 'mouth_type': 'big_smile', 'eye_y_off': -2},
    'sad': {'eye_type': 'sad', 'mouth_type': 'frown', 'eye_y_off': 3},
    'excited': {'eye_type': 'star', 'mouth_type': 'open_smile', 'eye_y_off': -3},
}

def draw_egg_shape(draw, cx, cy, w, h, body_color, light_color, dark_color):
    """Draw a proper egg shape: wider top, narrower bottom"""
    # Main body - egg shape using ellipse
    # The egg is wider at the top
    bbox = [cx - w/2, cy - h/2, cx + w/2, cy + h/2]
    
    # Shadow
    shadow_bbox = [bbox[0]+3, bbox[1]+3, bbox[2]+3, bbox[3]+3]
    draw.ellipse(shadow_bbox, fill=(0, 0, 0, 40))
    
    # Main body
    draw.ellipse(bbox, fill=body_color)
    
    # Highlight (top-left area)
    hl_w, hl_h = w * 0.35, h * 0.4
    hl_cx = cx - w * 0.12
    hl_cy = cy - h * 0.15
    draw.ellipse([hl_cx - hl_w/2, hl_cy - hl_h/2, hl_cx + hl_w/2, hl_cy + hl_h/2],
                 fill=light_color)

def draw_eyes(draw, cx, cy, eye_spacing, mood, char_id):
    """Draw expressive eyes based on mood"""
    left_x = cx - eye_spacing
    right_x = cx + eye_spacing
    
    eye_r = 14  # eye white radius
    pupil_r = 9
    
    if mood['eye_type'] == 'open':
        for ex in [left_x, right_x]:
            # Eye white
            draw.ellipse([ex-eye_r, cy-eye_r, ex+eye_r, cy+eye_r], fill=(255, 255, 255))
            # Pupil
            draw.ellipse([ex-pupil_r, cy-pupil_r+1, ex+pupil_r, cy+pupil_r+1], fill=(40, 40, 50))
            # Highlight
            draw.ellipse([ex-4, cy-7, ex+2, cy-1], fill=(255, 255, 255))
            # Small secondary highlight
            draw.ellipse([ex+1, cy+1, ex+4, cy+4], fill=(255, 255, 255, 180))
    
    elif mood['eye_type'] == 'happy_squint':
        for ex in [left_x, right_x]:
            # Squinted happy eyes - arc shape
            draw.arc([ex-eye_r, cy-eye_r+2, ex+eye_r, cy+eye_r-2], start=200, end=340,
                     fill=(40, 40, 50), width=4)
    
    elif mood['eye_type'] == 'sad':
        for ex in [left_x, right_x]:
            draw.ellipse([ex-eye_r, cy-eye_r, ex+eye_r, cy+eye_r], fill=(255, 255, 255))
            draw.ellipse([ex-pupil_r, cy-pupil_r+2, ex+pupil_r, cy+pupil_r+2], fill=(40, 40, 50))
            draw.ellipse([ex-4, cy-5, ex+2, cy+1], fill=(255, 255, 255))
            # Sad eyebrows
            draw.arc([ex-eye_r-2, cy-eye_r-8, ex+eye_r+2, cy-2], start=30, end=150,
                     fill=(40, 40, 50), width=3)
    
    elif mood['eye_type'] == 'star':
        for ex in [left_x, right_x]:
            # Star eyes
            draw_star(draw, ex, cy, 14, (255, 200, 50), (255, 220, 80))
    
    # Egg_black special: right eye has eyepatch
    if char_id == 'egg_black':
        ex = right_x
        # Eyepatch
        draw.ellipse([ex-eye_r-3, cy-eye_r-3, ex+eye_r+3, cy+eye_r+3], fill=(30, 30, 30))
        draw.ellipse([ex-eye_r-1, cy-eye_r-1, ex+eye_r+1, cy+eye_r+1], fill=(50, 50, 55))
        # Strap
        draw.line([(ex+eye_r+3, cy), (cx + 60, cy - 45)], fill=(30, 30, 30), width=3)

def draw_star(draw, cx, cy, size, fill_color, inner_color):
    """Draw a star shape"""
    points = []
    for i in range(10):
        angle = math.pi / 2 + i * math.pi / 5
        r = size if i % 2 == 0 else size * 0.45
        x = cx + r * math.cos(angle)
        y = cy - r * math.sin(angle)
        points.append((x, y))
    draw.polygon(points, fill=fill_color)
    # Inner highlight
    inner_points = []
    for i in range(10):
        angle = math.pi / 2 + i * math.pi / 5
        r = size * 0.55 if i % 2 == 0 else size * 0.25
        x = cx + r * math.cos(angle)
        y = cy - r * math.sin(angle)
        inner_points.append((x, y))
    draw.polygon(inner_points, fill=inner_color)

def draw_mouth(draw, cx, cy, mood):
    """Draw mouth based on mood"""
    if mood['mouth_type'] == 'smile':
        draw.arc([cx-12, cy-4, cx+12, cy+12], start=10, end=170, fill=(50, 50, 60), width=3)
    elif mood['mouth_type'] == 'big_smile':
        draw.arc([cx-16, cy-6, cx+16, cy+14], start=10, end=170, fill=(50, 50, 60), width=3)
        # Tongue
        draw.ellipse([cx-5, cy+4, cx+5, cy+12], fill=(255, 140, 140))
    elif mood['mouth_type'] == 'frown':
        draw.arc([cx-12, cy+2, cx+12, cy+16], start=190, end=350, fill=(50, 50, 60), width=3)
    elif mood['mouth_type'] == 'open_smile':
        draw.ellipse([cx-10, cy-2, cx+10, cy+12], fill=(50, 50, 60))
        draw.ellipse([cx-7, cy, cx+7, cy+6], fill=(255, 140, 140))

def draw_feet(draw, cx, cy, body_color, dark_color):
    """Draw small feet at the bottom"""
    foot_w, foot_h = 18, 12
    foot_y = cy + 8
    # Left foot
    draw.ellipse([cx-25-foot_w/2, foot_y-foot_h/2, cx-25+foot_w/2, foot_y+foot_h/2], fill=dark_color)
    # Right foot
    draw.ellipse([cx+25-foot_w/2, foot_y-foot_h/2, cx+25+foot_w/2, foot_y+foot_h/2], fill=dark_color)

def draw_hair_tuft(draw, cx, cy, body_color, light_color):
    """Draw a small hair tuft on top of the egg"""
    # Small rounded bump on top
    tuft_x = cx + 5
    tuft_y = cy - 10
    draw.ellipse([tuft_x-12, tuft_y-15, tuft_x+12, tuft_y+5], fill=body_color)
    # Highlight on tuft
    draw.ellipse([tuft_x-6, tuft_y-12, tuft_x+4, tuft_y-2], fill=light_color)

def generate_character(char_id, char_colors, mood_name, mood, size=512):
    """Generate a single character image"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size/2, size/2 + 15  # Center, slightly lower
    body_w = size * 0.52
    body_h = size * 0.58
    
    # Draw components back to front
    draw_feet(draw, cx, cy + body_h/2 - 10, char_colors['body'], char_colors['body_dark'])
    draw_egg_shape(draw, cx, cy, body_w, body_h, char_colors['body'], char_colors['body_light'], char_colors['body_dark'])
    
    # Cheeks (blush)
    for sign in [-1, 1]:
        cheek_x = cx + sign * body_w * 0.3
        cheek_y = cy + body_h * 0.08
        cheek_r = 14
        draw.ellipse([cheek_x-cheek_r, cheek_y-cheek_r, cheek_x+cheek_r, cheek_y+cheek_r],
                     fill=char_colors['cheek'])
    
    # Eyes
    eye_y = cy - body_h * 0.08 + mood['eye_y_off']
    draw_eyes(draw, cx, eye_y, body_w * 0.16, mood, char_id)
    
    # Mouth
    mouth_y = cy + body_h * 0.12
    draw_mouth(draw, cx, mouth_y, mood)
    
    # Hair tuft
    tuft_y = cy - body_h/2
    draw_hair_tuft(draw, cx, tuft_y, char_colors['body'], char_colors['body_light'])
    
    return img

def generate_mini(char_id, char_colors, size=128):
    """Generate a mini version of the character"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size/2, size/2 + 4
    body_w = size * 0.48
    body_h = size * 0.55
    
    # Simple body
    draw.ellipse([cx-body_w/2, cy-body_h/2, cx+body_w/2, cy+body_h/2], fill=char_colors['body'])
    # Highlight
    hl_w, hl_h = body_w * 0.3, body_h * 0.35
    draw.ellipse([cx-body_w*0.15-hl_w/2, cy-body_h*0.18-hl_h/2,
                  cx-body_w*0.15+hl_w/2, cy-body_h*0.18+hl_h/2], fill=char_colors['body_light'])
    
    # Simple eyes (dots)
    for sign in [-1, 1]:
        ex = cx + sign * body_w * 0.16
        ey = cy - body_h * 0.06
        draw.ellipse([ex-5, ey-5, ex+5, ey+5], fill=(40, 40, 50))
        draw.ellipse([ex-2, ey-3, ex+1, ey], fill=(255, 255, 255))
    
    # Tiny smile
    draw.arc([cx-7, cy+body_h*0.05, cx+7, cy+body_h*0.15], start=10, end=170, fill=(50, 50, 60), width=2)
    
    # Hair tuft
    tuft_y = cy - body_h/2
    draw.ellipse([cx-6, tuft_y-8, cx+8, tuft_y+2], fill=char_colors['body'])
    
    return img

def create_imageset(char_id, mood_name, img, size):
    """Create .imageset directory with Contents.json and images"""
    imageset_name = f"{char_id}_{mood_name}"
    imageset_dir = os.path.join(OUTDIR, f"{imageset_name}.imageset")
    os.makedirs(imageset_dir, exist_ok=True)
    
    # @1x
    img.save(os.path.join(imageset_dir, f"{imageset_name}.png"))
    # @2x
    img_2x = img.resize((size * 2, size * 2), Image.LANCZOS)
    img_2x.save(os.path.join(imageset_dir, f"{imageset_name}@2x.png"))
    
    # Contents.json
    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x", "filename": f"{imageset_name}.png"},
            {"idiom": "universal", "scale": "2x", "filename": f"{imageset_name}@2x.png"},
            {"idiom": "universal", "scale": "3x"}
        ],
        "info": {"version": 1, "author": "xcode"}
    }
    import json
    with open(os.path.join(imageset_dir, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)

# Generate all characters and moods
for char_id, colors in CHARACTERS.items():
    for mood_name, mood in MOODS.items():
        img = generate_character(char_id, colors, mood_name, mood, size=512)
        create_imageset(char_id, mood_name, img, size=512)
        print(f'  ✅ {char_id}_{mood_name}')
    
    # Mini version
    mini_img = generate_mini(char_id, colors, size=128)
    create_imageset(char_id, 'mini', mini_img, size=128)
    print(f'  ✅ {char_id}_mini')

print(f'\n🎉 All {len(CHARACTERS) * 5} imagesets generated in {OUTDIR}')
