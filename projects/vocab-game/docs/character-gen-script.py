#!/usr/bin/env python3
"""
批量生成蛋仔角色素材（v2）

使用 CogView-3-Flash 生成 → remove_white_bg.py 去白底 → sips 缩放

用法：
  python3 character-gen-script.py --api-key <KEY> [--step <step>] [--color <color>]

  --step:
    generate  - 仅生成 raw 图（默认）
    postproc  - 仅后处理（去白底 + 压缩 + 缩放）
    validate  - 仅验收检查

  --color: yellow/pink/blue/green/red/black（仅 step=generate 时有效）
  --state: idle/happy/excited/sad/mini（仅 step=generate 时有效，不指定则生成全部状态）

  --dry-run: 打印 prompt 不实际调用 API

⚠️  不要使用一键全流程。每个 step 之间需要丹妮人工审查。
     正确用法：generate → 审查 → generate → 审查 → postproc → validate
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
import base64
from pathlib import Path

# ============================================================
# 配置
# ============================================================

PROJECT_ROOT = Path("~/DevTeam/projects/vocab-game").expanduser()
GEN_DIR = PROJECT_ROOT / "character-gen"
RAW_DIR = GEN_DIR / "raw"
NOBG_DIR = GEN_DIR / "nobg"
FINAL_DIR = GEN_DIR / "final"
SCRIPTS_DIR = PROJECT_ROOT / "scripts"

PYTHON_VENV = sys.executable
REMOVE_BG_SCRIPT = SCRIPTS_DIR / "remove_white_bg.py"

API_URL = "https://open.bigmodel.cn/api/paas/v4/images/generations"
MODEL = "cogview-3-flash"
IMAGE_SIZE = "1024x1024"

COLORS = ["yellow", "pink", "blue", "green", "red", "black"]
STATES = ["idle", "happy", "excited", "sad"]
MINI_STATES = ["mini"]

# ============================================================
# 形状约束（丹妮实测验证通过，不要修改）
# ============================================================

SHAPE_CONSTRAINT = """The character is shaped like a SOFTBALL or a WIDE PEBBLE — it is VERY WIDE and NOT VERY TALL. Think of the shape as a circle that has been squashed vertically to about 70% of its width. The widest point is in the MIDDLE of the body, NOT the bottom. The top and bottom are both rounded curves of similar curvature. NOT an egg shape, NOT an hourglass, NOT a pear, NOT a teardrop."""

# ============================================================
# 角色参数
# ============================================================

CHARACTER_PARAMS = {
    "yellow": {
        "name_en": "egg_yellow",
        "name_cn": "蛋小黄",
        "body_color": "bright golden yellow",
        "light_color": "#FFF176",
        "dark_color": "#FFA500",
        "accessory": "A small golden crown on top of the head with 3 to 5 points, about 1/3 head height, centered",
        "accessory_mini": "a small triangle on top (crown)",
    },
    "pink": {
        "name_en": "egg_pink",
        "name_cn": "蛋小粉",
        "body_color": "cherry blossom pink",
        "light_color": "#FFD1DC",
        "dark_color": "#FF69B4",
        "accessory": "A large pink ribbon bow on the right side of the head, bow wings spread wide, about 1/2 head width",
        "accessory_mini": "two small triangles on right side (bow)",
    },
    "blue": {
        "name_en": "egg_blue",
        "name_cn": "蛋小蓝",
        "body_color": "sky blue",
        "light_color": "#B8E0F7",
        "dark_color": "#4682B4",
        "accessory": "A white sailor hat on top of the head with a small blue anchor emblem on the front, brim slightly upturned",
        "accessory_mini": "a small rounded rectangle on top (hat)",
    },
    "green": {
        "name_en": "蛋小绿",
        "name_cn": "egg_green",
        "body_color": "mint green",
        "light_color": "#C6F7C6",
        "dark_color": "#2E8B57",
        "accessory": "Two small grass sprouts growing from the top of the head, light green, tilted slightly right, about 1/3 head height",
        "accessory_mini": "two short lines on top (sprouts)",
    },
    "red": {
        "name_en": "蛋小红",
        "name_cn": "egg_red",
        "body_color": "coral red",
        "light_color": "#FFB3B3",
        "dark_color": "#DC3545",
        "accessory": "A golden five-pointed star hair clip on the right-front side of the head, about the size of one eye",
        "accessory_mini": "a small star shape on right side (clip)",
    },
    "black": {
        "name_en": "蛋小黑",
        "name_cn": "egg_black",
        "body_color": "charcoal dark gray",
        "light_color": "#777777",
        "dark_color": "#2C2C2C",
        "accessory": "Two small curved devil horns protruding from the top sides of the head, dark red color, about 1/4 head height",
        "accessory_mini": "two small bumps on top (horns)",
    },
}

# ============================================================
# 表情模板
# ============================================================

FACE_TEMPLATES = {
    "idle": """Large round eyes (about 30-35% of face width), with colorful irises and 2-3 white highlight dots. Pink circular blush marks (#FFB0B0) on both cheeks. Small gentle U-shaped smile.""",
    "happy": """Eyes closed into downward-curving crescent shapes (^_^), large curve angle. Small open D-shaped mouth with a tiny pink tongue peeking out. Pink circular blush marks (#FFB0B0) on both cheeks.""",
    "excited": """The character has VERY LARGE wide-open round eyes that are much bigger than normal, with HUGE bright white sparkle highlights filling most of the iris area, giving a sparkling amazed look. The eyes are wide with excitement and wonder. The character's mouth is a LARGE wide-open round O shape, much bigger than a normal mouth, showing extreme surprise and joy. The overall expression is clearly THRILLED and EXCITED. Pink circular blush marks (#FFB0B0) on both cheeks.""",
    "sad": """The character is CRYING and UNHAPPY. The eyes have droopy sad eyebrows that angle downward toward the center. The irises are looking downward. There is a large visible blue teardrop falling from the outer corner of the left eye. The mouth is a clear FROWN that curves DOWNWARD at the corners, like an upside-down U shape. The expression is clearly SAD and UPSET, NOT happy. Pink circular blush marks (#FFB0B0) on both cheeks.""",
}

MINI_FACE = """Two small solid black dot eyes, each with one tiny white highlight. Simple curved line smile. Two tiny pink dot blush marks."""


def build_prompt(color: str, state: str) -> str:
    """构建完整的生成 prompt"""
    params = CHARACTER_PARAMS[color]

    if state == "mini":
        return f"""A simplified miniature version of the {params['body_color']} egg character, front view, centered in frame.

SHAPE: {SHAPE_CONSTRAINT}

BODY: {params['body_color']}, simpler gradient from {params['light_color']} to {params['dark_color']}. Same 3D glossy vinyl toy style but with fewer details.

FEET: Two simple small circle feet.

FACE: {MINI_FACE}

ACCESSORY: {params['accessory_mini']} — simplified to basic shapes but still recognizable.

BACKGROUND: Solid pure white (#FFFFFF), no other elements.

STYLE: 3D rendered, cute, cartoon, vinyl toy aesthetic. Soft cel-shading with glossy highlights. No hard outlines."""

    return f"""A cute chibi egg character in Eggy Party game style, front view, centered in frame.

SHAPE: {SHAPE_CONSTRAINT}

BODY: {params['body_color']} with a smooth gradient from {params['light_color']} on top to {params['dark_color']} on the bottom. The body has a 3D rendered glossy vinyl toy appearance with soft lighting from the upper left, creating a bright highlight ellipse on the upper-left body and subtle shadow on the lower right.

FEET: Two short stubby cute feet at the bottom of the body, small rounded shapes.

FACE: {FACE_TEMPLATES[state]}

ACCESSORY: {params['accessory']} — this accessory MUST be clearly visible and distinctive.

BACKGROUND: Solid pure white background (#FFFFFF), no other elements.

STYLE: 3D rendered, cute, cartoon, vinyl toy aesthetic. Soft cel-shading with glossy highlights. No hard outlines. Character centered with margin."""


# ============================================================
# API 调用
# ============================================================

def call_cogview(api_key: str, prompt: str) -> bytes:
    """调用 CogView-3-Flash API，返回 PNG bytes"""
    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "size": IMAGE_SIZE,
    }).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"  ❌ API HTTP {e.code}: {body[:200]}", file=sys.stderr)
        raise
    except urllib.error.URLError as e:
        print(f"  ❌ Network error: {e.reason}", file=sys.stderr)
        raise

    # 解析响应
    data_list = result.get("data", [])
    if not data_list:
        print(f"  ❌ API 返回空 data: {result}", file=sys.stderr)
        raise ValueError("Empty data from API")

    item = data_list[0]
    url = item.get("url", "")

    if url:
        # 从 URL 下载图片
        print(f"  ⬇️  下载图片...")
        with urllib.request.urlopen(url, timeout=60) as img_resp:
            return img_resp.read()

    # base64 编码的图片
    b64 = item.get("b64_image", "")
    if b64:
        return base64.b64decode(b64)

    print(f"  ❌ API 返回无图片: {item}", file=sys.stderr)
    raise ValueError("No image in API response")


# ============================================================
# 后处理
# ============================================================

def remove_bg(input_path: Path, output_path: Path):
    """调用 remove_white_bg.py 去白底"""
    subprocess.run(
        [str(PYTHON_VENV), str(REMOVE_BG_SCRIPT), str(input_path), str(output_path), "220", "240"],
        check=True,
    )


def resize_1x(input_2x: Path, output_1x: Path, size: int):
    """缩放 @2x 到 @1x"""
    subprocess.run(
        ["sips", "-z", str(size), str(size), str(input_2x), "--out", str(output_1x)],
        check=True,
        capture_output=True,
    )


def optipng_compress(directory: Path):
    """无损压缩目录下所有 PNG"""
    pngs = list(directory.glob("*.png"))
    if pngs:
        subprocess.run(
            ["optipng", "-o7"] + [str(f) for f in pngs],
            check=True,
        )


# ============================================================
# 主流程
# ============================================================

def step_generate(api_key: str, color: str = None, state: str = None, dry_run: bool = False):
    """Step: 生成图片"""
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    colors = [color] if color else COLORS
    states = [state] if state else (STATES + MINI_STATES)
    tasks = []
    for c in colors:
        for s in states:
            tasks.append((c, s))

    print(f"🎨 将生成 {len(tasks)} 张图片")
    print(f"   颜色: {', '.join(colors)}")
    print(f"   状态: {', '.join(states)}")
    print()

    for i, (c, s) in enumerate(tasks, 1):
        tag = f"egg_{c}_{s}"
        output = RAW_DIR / f"{tag}@2x.png"

        if output.exists():
            print(f"[{i}/{len(tasks)}] {tag} — 已存在，跳过")
            continue

        prompt = build_prompt(c, s)

        if dry_run:
            print(f"[{i}/{len(tasks)}] {tag} — DRY RUN")
            print(f"  Prompt: {prompt[:100]}...")
            continue

        print(f"[{i}/{len(tasks)}] {tag} — 生成中...")
        try:
            img_bytes = call_cogview(api_key, prompt)
            output.write_bytes(img_bytes)
            kb = len(img_bytes) // 1024
            print(f"  ✅ 已保存 ({kb}KB) → {output}")
        except Exception as e:
            print(f"  ❌ 失败: {e}")
            # 继续下一个，不中断

        # 避免触发速率限制
        if i < len(tasks):
            time.sleep(1)

    print(f"\n🎨 生成完成！图片在 {RAW_DIR}")


def step_postproc():
    """Step: 后处理（去白底 + 压缩 + 缩放）"""
    NOBG_DIR.mkdir(parents=True, exist_ok=True)
    FINAL_DIR.mkdir(parents=True, exist_ok=True)

    raw_files = sorted(RAW_DIR.glob("*@2x.png"))
    if not raw_files:
        print("❌ 没有找到 raw 图片，请先运行 generate 步骤")
        return

    print(f"🔄 后处理 {len(raw_files)} 张图片")

    # 1. 去白底
    print("\n📐 去白底...")
    for f in raw_files:
        out = NOBG_DIR / f.name
        if out.exists():
            print(f"  ⏩ {f.name} — 已存在")
            continue
        print(f"  🧹 {f.name}")
        remove_bg(f, out)

    # 2. 压缩
    print("\n📦 压缩...")
    try:
        optipng_compress(NOBG_DIR)
    except FileNotFoundError:
        print("  ⚠️  optipng 未安装，跳过压缩。安装: brew install optipng")

    # 3. 缩放 + 拷贝到 final
    print("\n📏 缩放 @1x + 拷贝 @2x...")
    for f in sorted(NOBG_DIR.glob("*@2x.png")):
        name_2x = f.name
        name_1x = name_2x.replace("@2x", "")

        # 判断是 mini 还是普通
        is_mini = "_mini" in name_2x
        size_1x = 256 if is_mini else 512

        # 拷贝 @2x
        dst_2x = FINAL_DIR / name_2x
        import shutil
        shutil.copy2(f, dst_2x)

        # 缩放 @1x
        dst_1x = FINAL_DIR / name_1x
        resize_1x(f, dst_1x, size_1x)
        print(f"  ✅ {name_1x} ({size_1x}x{size_1x}) + {name_2x}")

    print(f"\n🔄 后处理完成！最终图片在 {FINAL_DIR}")


def step_validate():
    """Step: 自动化验收"""
    COLORS_LIST = COLORS
    STATES_LIST = STATES
    MINI_LIST = MINI_STATES

    PASS = 0
    FAIL = 0

    def check(msg, ok):
        nonlocal PASS, FAIL
        if ok:
            print(f"✅ {msg}")
            PASS += 1
        else:
            print(f"❌ {msg}")
            FAIL += 1

    # 1. 文件存在
    for c in COLORS_LIST:
        for s in STATES_LIST + MINI_LIST:
            for suffix in ["", "@2x"]:
                f = FINAL_DIR / f"egg_{c}_{s}{suffix}.png"
                check(f"存在: egg_{c}_{s}{suffix}.png", f.exists())

    # 2. 像素尺寸
    for c in COLORS_LIST:
        for s in STATES_LIST:
            # @2x: 1024x1024
            f = FINAL_DIR / f"egg_{c}_{s}@2x.png"
            if f.exists():
                r = subprocess.run(
                    ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(f)],
                    capture_output=True, text=True,
                )
                lines = r.stdout.strip().split("\n")
                w = int(lines[0].split(":")[1].strip()) if len(lines) > 0 else 0
                h = int(lines[1].split(":")[1].strip()) if len(lines) > 1 else 0
                check(f"尺寸: {c}_{s}@2x = {w}x{h}", w == 1024 and h == 1024)
            else:
                check(f"尺寸: {c}_{s}@2x", False)

            # @1x: 512x512
            f1 = FINAL_DIR / f"egg_{c}_{s}.png"
            if f1.exists():
                r = subprocess.run(
                    ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(f1)],
                    capture_output=True, text=True,
                )
                lines = r.stdout.strip().split("\n")
                w = int(lines[0].split(":")[1].strip()) if len(lines) > 0 else 0
                h = int(lines[1].split(":")[1].strip()) if len(lines) > 1 else 0
                check(f"尺寸: {c}_{s}@1x = {w}x{h}", w == 512 and h == 512)
            else:
                check(f"尺寸: {c}_{s}@1x", False)

        # mini @2x: 512x512
        f = FINAL_DIR / f"egg_{c}_mini@2x.png"
        if f.exists():
            r = subprocess.run(
                ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(f)],
                capture_output=True, text=True,
            )
            lines = r.stdout.strip().split("\n")
            w = int(lines[0].split(":")[1].strip()) if len(lines) > 0 else 0
            h = int(lines[1].split(":")[1].strip()) if len(lines) > 1 else 0
            check(f"尺寸: {c}_mini@2x = {w}x{h}", w == 512 and h == 512)

        # mini @1x: 256x256
        f1 = FINAL_DIR / f"egg_{c}_mini.png"
        if f1.exists():
            r = subprocess.run(
                ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(f1)],
                capture_output=True, text=True,
            )
            lines = r.stdout.strip().split("\n")
            w = int(lines[0].split(":")[1].strip()) if len(lines) > 0 else 0
            h = int(lines[1].split(":")[1].strip()) if len(lines) > 1 else 0
            check(f"尺寸: {c}_mini@1x = {w}x{h}", w == 256 and h == 256)

    # 3. 文件大小（@2x + @1x）
    for c in COLORS_LIST:
        for s in STATES_LIST:
            # @2x
            f = FINAL_DIR / f"egg_{c}_{s}@2x.png"
            if f.exists():
                kb = f.stat().st_size // 1024
                check(f"大小: {c}_{s}@2x = {kb}KB (80-200)", 80 <= kb <= 200)
            else:
                check(f"大小: {c}_{s}@2x", False)
            # @1x
            f1 = FINAL_DIR / f"egg_{c}_{s}.png"
            if f1.exists():
                kb1 = f1.stat().st_size // 1024
                check(f"大小: {c}_{s}@1x = {kb1}KB (25-60)", 25 <= kb1 <= 60)
            else:
                check(f"大小: {c}_{s}@1x", False)

    # 4. Alpha 通道
    for c in COLORS_LIST:
        for s in STATES_LIST + MINI_LIST:
            f = FINAL_DIR / f"egg_{c}_{s}@2x.png"
            if f.exists():
                r = subprocess.run(["file", str(f)], capture_output=True, text=True)
                has_alpha = "RGBA" in r.stdout or "alpha" in r.stdout.lower()
                check(f"透明: {c}_{s}@2x", has_alpha)
            else:
                check(f"透明: {c}_{s}@2x", False)

    print(f"\n===== 结果: {PASS} PASS, {FAIL} FAIL =====")
    return FAIL == 0


def main():
    parser = argparse.ArgumentParser(description="批量生成蛋仔角色素材 v2")
    parser.add_argument("--api-key", help="CogView API key")
    parser.add_argument("--step", choices=["generate", "postproc", "validate"], default="generate")
    parser.add_argument("--color", choices=COLORS, help="仅生成指定颜色")
    parser.add_argument("--state", choices=STATES + MINI_STATES, help="仅生成指定状态")
    parser.add_argument("--dry-run", action="store_true", help="打印 prompt 不调用 API")
    args = parser.parse_args()

    # 读取 API key
    api_key = args.api_key
    if not api_key:
        # 尝试从 secrets.json 读取
        secrets_path = Path("~/.openclaw/secrets.json").expanduser()
        if secrets_path.exists():
            with open(secrets_path) as f:
                secrets = json.load(f)
            api_key = secrets.get("models", {}).get("providers", {}).get("zai", {}).get("apiKey", "")
        if not api_key:
            print("❌ 未找到 API key。请用 --api-key 参数或配置 secrets.json", file=sys.stderr)
            sys.exit(1)

    if args.step == "generate":
        step_generate(api_key, args.color, args.state, args.dry_run)
    elif args.step == "postproc":
        step_postproc()
    elif args.step == "validate":
        ok = step_validate()
        if not ok:
            sys.exit(1)


if __name__ == "__main__":
    main()
