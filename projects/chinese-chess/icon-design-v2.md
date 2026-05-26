# ChineseChess.app 图标设计方案 v2

> 版本：v2（洪涛反馈后重新设计） | 作者：Alex | 日期：2025-05-24

---

## 1. 设计目标变更

v1 方案被否决，核心问题：元素堆叠过多、红色饱和度过高、字体风格不统一、小尺寸下杂乱。

**v2 设计哲学：简约大气，一个焦点，Apple 设计语言。**

- 去掉所有多余元素：不再有多枚棋子堆叠、不再有网格线、不再有楚河汉界文字
- 只保留一颗"帅"棋子作为绝对焦点
- 配色从高饱和红 `#CC0000` 改为朱砂红 `#9B2335`，克制温润
- 统一使用一种书法字体
- 留白呼吸感

---

## 2. 配色方案

### 2.1 主色板

| 角色 | 色值 | 说明 |
|------|------|------|
| **朱砂红** | `#9B2335` RGB(155,35,53) | 主色，棋子边框和文字。替代 v1 的 #CC0000 |
| **木色亮** | `#DEB887` RGB(222,184,135) | 棋盘背景，与游戏 UI 一致 |
| **木色暗** | `#D2AA78` RGB(210,170,120) | 背景渐变中点 |
| **深棕** | `#4A3728` RGB(74,55,40) | 极简装饰线条 |
| **棋子米黄** | `#FFF5E1` RGB(255,245,225) | 棋子底色亮部 |
| **棋子暗色** | `#E8D5B5` RGB(232,213,181) | 棋子底色暗部 |

### 2.2 配色变化对比

| 元素 | v1 | v2 | 变更理由 |
|------|----|----|----------|
| 红色 | #CC0000 | #9B2335 | 降低饱和度，温润中国风，与木色和谐 |
| 棋子底色亮 | #FFFDE6 | #FFF5E1 | 略微降低亮度，避免数码感 |
| 棋子底色暗 | #DCC8AA | #E8D5B5 | 提亮暗部，渐变更柔和 |
| 黑方棋子 | #1A1A1A | 已移除 | v2 不使用黑方棋子 |

### 2.3 Dark Mode 评估

- 朱砂红 `#9B2335` 在深色桌面上比高饱和红更沉稳，不会刺眼
- 木色 `#DEB887` 明度约 75%，在深色桌面对比充足
- 棋子米黄 `#FFF5E1` 略微降低亮度后，在深色桌面不会过亮
- **结论：无需 Dark Mode 变体**

### 2.4 色彩空间

- 输出 sRGB，嵌入 sRGB ICC profile（Pillow `ImageCms.createProfile("sRGB")`）

---

## 3. 构图方案

### 3.1 核心理念

**一颗棋子，居中，足矣。**

参考 Apple 地图、备忘录、播客等系统应用的图标风格——一个清晰的主图形 + 简洁背景，没有任何多余装饰。

### 3.2 构图描述

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                                     │
│           ┌───────────────┐         │
│           │               │         │
│           │      帅       │         │
│           │               │         │
│           └───────────────┘         │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘

元素清单：
- 背景：木色渐变（全幅）
- 主棋子"帅"：居中，占图标宽度约 50-55%
- 底部装饰：2-3 条极淡水平线（棋盘纹路暗示，optional）
```

### 3.3 主棋子"帅"绘制规格

- **位置**：精确居中（水平 + 垂直均居中）
- **直径**：图标宽度的 52%（1024px → 约 532px 直径）
- **底色**：径向渐变 `#FFF5E1`（中心）→ `#E8D5B5`（边缘）
- **外圈**：朱砂红 `#9B2335` 实线圆环，宽度 = 直径的 3%（约 16px）
- **内圈**：朱砂红 `#9B2335` 实线圆环，宽度 = 外圈的 40%（约 6px），距离外圈内侧 8px
- **文字"帅"**：
  - 颜色：朱砂红 `#9B2335`
  - 字号：棋子直径的 48%（约 256px）
  - 字体：**方正楷体简体**（统一使用这一种字体，见 §4）
  - 粗细：Bold（通过 stroke_width 增强笔画）
  - stroke_width = 字号的 4%（约 10px），stroke_fill 同色
- **投影**：
  - 方向：右下偏移 (12, 12)
  - 颜色：黑色 `#000000`，opacity 15%（比 v1 的 20% 更轻柔）
  - 模糊半径：24px

### 3.4 背景层

- **底色**：线性渐变 top→bottom，`#DEB887` → `#D2AA78` → `#DEB887`
- **无网格线**（v2 彻底去掉）
- **无楚河汉界文字**（v2 彻底去掉）
- **可选底部装饰**：在图标下方 1/4 处，画 2 条极淡水平线，颜色 `#4A3728` opacity 8%，间距 40px，线宽 1px。这是棋盘纹路的极简暗示，几乎看不到但增加了"棋盘"的潜意识联想。如果效果不好，直接去掉，不影响整体

### 3.5 不包含的元素（明确排除）

| 元素 | v1 有 | v2 | 理由 |
|------|-------|----|------|
| 装饰小棋子（車、馬） | ✅ | ❌ | 破坏焦点，小尺寸下杂乱 |
| 网格线 | ✅ | ❌ | 密集线条在小尺寸下糊成一团 |
| 楚河汉界文字 | ✅ | ❌ | 小尺寸无法辨识，纯装饰噪音 |
| 黑方棋子 | ✅ | ❌ | 增加视觉复杂度，与简约目标矛盾 |

---

## 4. 字体

### 4.1 统一字体

**全图标只用一种字体：方正楷体简体**

- 路径：`~/Library/Fonts/方正楷体简体.TTF`（已安装）
- 备选 1：`/System/Library/Fonts/STKaiti.ttf`
- 备选 2：`/System/Library/Fonts/Supplemental/Songti.ttc`

### 4.2 字体查找逻辑

```python
FONT_PATHS = [
    os.path.expanduser("~/Library/Fonts/方正楷体简体.TTF"),  # 首选
    "/System/Library/Fonts/STKaiti.ttf",                      # 系统
    "/System/Library/Fonts/Supplemental/Songti.ttc",          # fallback
]
```

**v1 的问题**：字体查找优先级把 STKaiti 放在第一位，但 STKaiti 在当前系统不存在，实际 fallback 到了方正楷体。不同字体混用导致风格不统一。v2 明确首选方正楷体简体。

### 4.3 字体统一性保证

- 棋子文字"帅"使用方正楷体
- 如果有装饰文字也使用同一字体（但 v2 没有装饰文字）
- 加载后必须验证字形 `getbbox("帅")` 有效

---

## 5. macOS 图标规范

### 5.1 形状

- 超椭圆（superellipse）圆角矩形，n = 5
- 画布 1024×1024，超椭圆半径 480px
- 安全边距 3-4%（约 30-40px）

### 5.2 超椭圆 Mask

沿用 v1 已验证方案，Pillow polygon 720 点逼近，无需额外依赖：

```python
def superellipse_mask(size=1024, radius=480, n=5, num_points=720):
    cx, cy = size // 2, size // 2
    points = []
    for i in range(num_points):
        t = 2 * math.pi * i / num_points
        cos_t, sin_t = math.cos(t), math.sin(t)
        x = cx + radius * (1 if cos_t >= 0 else -1) * abs(cos_t) ** (2.0 / n)
        y = cy + radius * (1 if sin_t >= 0 else -1) * abs(sin_t) ** (2.0 / n)
        points.append((x, y))
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask
```

### 5.3 尺寸

| 文件 | 像素 |
|------|------|
| icon_16x16.png | 16×16 |
| icon_16x16@2x.png | 32×32 |
| icon_32x32.png | 32×32 |
| icon_32x32@2x.png | 64×64 |
| icon_128x128.png | 128×128 |
| icon_128x128@2x.png | 256×256 |
| icon_256x256.png | 256×256 |
| icon_256x256@2x.png | 512×512 |
| icon_512x512.png | 512×512 |
| icon_512x512@2x.png | 1024×1024 |

### 5.4 小尺寸适配

**v2 简化方案（32px 及以下）**：

- 木色 `#DEB887` 超椭圆背景
- 居中画朱砂红 `#9B2335` 实心圆环
- 圆环内填充 `#FFF5E1`
- 无文字、无装饰线条
- **相比 v1 的改进**：v1 用的是 #CC0000 高饱和红，在 16px 下木色背景上对比过强有数码感。v2 的 #9B2335 更柔和自然

**16px 进一步简化**：
- 木色底 + 朱砂红圆环 + 米黄圆心
- 圆环宽度 1px

---

## 6. 实现要点（给 Cody）

### 6.1 修改策略

**在现有 `generate_icon.py` 基础上修改**，不是重写。主要改动点：

1. **颜色常量替换**：`COL_RED` 从 `(204,0,0)` 改为 `(155,35,53)`
2. **棋子底色替换**：亮部 `(255,253,230)` → `(255,245,225)`，暗部 `(220,200,170)` → `(232,213,181)`
3. **删除装饰棋子**：去掉 `draw_piece` 对红"车"和黑"马"的调用
4. **删除网格线**：去掉 `draw_grid_lines` 调用（或调用但设为极淡可选）
5. **删除楚河汉界**：去掉 `draw_river_text` 调用
6. **主棋子居中**：从 `(SIZE//2, SIZE*0.42)` 偏上改为 `(SIZE//2, SIZE//2)` 精确居中
7. **主棋子直径**：从 `SIZE*0.28`（287px）增大到 `SIZE*0.52`（532px）
8. **投影减弱**：opacity 从 20% 降到 15%，模糊半径增大到 24
9. **字体优先级**：方正楷体放在第一位
10. **小尺寸配色**：统一用 `#9B2335` 替代 `#CC0000`

### 6.2 具体参数对照

```python
# v2 颜色常量
COL_VERMILLION = (155, 35, 53)      # 朱砂红 #9B2335（替代 COL_RED）
COL_BOARD_LIGHT = (222, 184, 135)   # 不变
COL_BOARD_DARK = (210, 170, 120)    # 不变
COL_GRID = (74, 55, 40)             # 不变（如保留极淡装饰线）
COL_PIECE_LIGHT = (255, 245, 225)   # #FFF5E1（微调）
COL_PIECE_DARK = (232, 213, 181)    # #E8D5B5（提亮）

# 主棋子参数
MAIN_PIECE_CENTER = (SIZE // 2, SIZE // 2)        # 精确居中
MAIN_PIECE_RADIUS = int(SIZE * 0.26)              # 266px（直径532px）
MAIN_PIECE_BORDER_WIDTH = int(532 * 0.03)          # ~16px
MAIN_PIECE_INNER_BORDER_WIDTH = int(16 * 0.4)      # ~6px
MAIN_PIECE_FONT_SIZE = int(532 * 0.48)             # ~256px
MAIN_PIECE_STROKE_WIDTH = int(256 * 0.04)          # ~10px
MAIN_PIECE_SHADOW_OFFSET = (12, 12)
MAIN_PIECE_SHADOW_OPACITY = int(255 * 0.15)        # ~38
MAIN_PIECE_SHADOW_BLUR = 24

# 字体
FONT_PATHS = [
    os.path.expanduser("~/Library/Fonts/方正楷体简体.TTF"),
    "/System/Library/Fonts/STKaiti.ttf",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
]
```

### 6.3 .icns 生成

同 v1，用 `iconutil -c icns` 打包，嵌入 sRGB ICC profile。

### 6.4 错误处理

同 v1 方案中的错误处理表，增加：
- 旧版 generate_icon.py 备份：修改前 `cp generate_icon.py generate_icon_v1.py.bak`

### 6.5 验证流程

1. 修改 generate_icon.py
2. 运行 `python3 generate_icon.py`（仅生成 1024px 预览）
3. 交 Luke/洪涛确认视觉方向
4. 确认后 `python3 generate_icon.py --full` 打包 .icns

### 6.6 工期

| 任务 | 预估 |
|------|------|
| 修改 generate_icon.py | 1-2 小时 |
| 调试 + 各尺寸验证 | 1 小时 |
| 打包 + 集成 | 0.5 小时 |
| **合计** | **3-4 小时** |

---

## 7. 交付物

| 产出 | 路径 |
|------|------|
| `generate_icon_v1.py.bak` | `~/DevTeam/projects/chinese-chess/src/tools/` |
| `generate_icon.py`（v2） | `~/DevTeam/projects/chinese-chess/src/tools/` |
| `icon-preview-1024.png` | `~/DevTeam/projects/chinese-chess/` |
| `ChineseChess.iconset/` | `~/DevTeam/projects/chinese-chess/` |
| `ChineseChess.icns` | `~/DevTeam/projects/chinese-chess/` |

---

## 8. 设计方案变更记录

| 项目 | v1 | v2 | 理由 |
|------|----|----|------|
| 主色 | #CC0000 高饱和红 | #9B2335 朱砂红 | 洪涛反馈"数码感"，降低饱和度 |
| 构图 | 帅+車+馬三颗棋子 | 仅帅一颗 | 洪涛反馈"堆叠杂乱"，简约优先 |
| 网格线 | 5列×6行+九宫斜线 | 无（或2条极淡线） | 洪涛反馈"小尺寸糊成团" |
| 楚河汉界 | 有 | 无 | 小尺寸无法辨识，去掉 |
| 棋子直径 | 287px (28%) | 532px (52%) | 单棋子需更大才醒目 |
| 棋子位置 | 偏上 (y=42%) | 精确居中 | 单焦点构图居中最稳 |
| 投影 | opacity 20%, blur 16 | opacity 15%, blur 24 | 更轻柔，Apple 风格 |
| 字体 | STKaiti 优先（不存在） | 方正楷体优先 | 统一字体，避免混用 |
