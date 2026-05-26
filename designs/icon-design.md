# ChineseChess.app 图标设计方案

> 版本：v2（审查修订版） | 作者：Alex | 日期：2025-05-24

---

## 1. 设计目标

为 ChineseChess.app 设计一枚 macOS 应用图标（.icns，1024×1024），要求：

- 中国风视觉语言
- 包含象棋核心元素（棋子 + 棋盘纹路）
- 配色与游戏 UI 一致
- 符合 macOS 图标规范（圆角矩形、多尺寸适配）

---

## 2. UI 配色提取

从现有游戏代码中提取的主色调：

| 角色 | 色值 | 来源 |
|------|------|------|
| 棋盘底色（亮） | `#DEB887` RGB(222,184,135) | BoardView 棋盘背景渐变起点 |
| 棋盘底色（暗） | `#D2AA78` RGB(210,170,120) | BoardView 棋盘背景渐变中点 |
| 棋盘线条/文字 | `#4A3728` RGB(74,55,40) | BoardView 线条、楚河汉界文字 |
| 红方棋子文字 | `#CC0000` RGB(204,0,0) | PieceView 红方 textColor |
| 黑方棋子文字 | `#1A1A1A` RGB(26,26,26) | PieceView 黑方 textColor |
| 棋子底色（亮） | `#FFFDE6` RGB(255,253,230) | PieceView 径向渐变起点 |
| 棋子底色（暗） | `#DCC8AA` RGB(220,200,170) | PieceView 径向渐变终点 |
| 棋子边框 | 与文字同色 | PieceView borderColor |

**设计原则：图标主色调以棋盘木色 `#DEB887` + 红色 `#CC0000` + 深棕 `#4A3728` 为主，与游戏 UI 高度一致。**

---

## 3. 构图方案

### 3.1 整体布局

采用 macOS 标准圆角矩形图标轮廓（superellipse），内部构图分为三层：

```
┌─────────────────────────────────────┐
│                                     │
│    ┌─ 棋盘纹路背景层 ─────────┐     │
│    │  浅木色渐变底色           │     │
│    │  半透明棋盘格线（装饰性） │     │
│    │                           │     │
│   ┌┤      ┌─────────┐          │┐   │
│   ││      │  主角棋子 │          ││   │
│   │車│      │  "帅"    │          │馬│   │
│   ││      │ （居中偏上）│       ││   │
│   ││      └─────────┘          ││   │
│   └┤                           │┘   │
│    │   "楚河 · 汉界" 装饰文字  │     │
│    │                           │     │
│    └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### 3.2 核心元素

#### 主元素：居中棋子——"帅"

选择红方"帅"作为主视觉焦点，理由：
- "帅"是中国象棋最具辨识度的棋子
- 红色 `#CC0000` 作为主色调醒目且有中国风
- 一个大棋子居中，构图简洁有力，在小尺寸下仍可辨识

棋子绘制规格：
- 圆形，棋子底色使用径向渐变 `#FFFDE6` → `#DCC8AA`（与 PieceView 一致）
- 棋子边框使用红色 `#CC0000`，lineWidth 按比例（棋子直径的 ~2%）
- 文字"帅"使用楷体，红色 `#CC0000`，粗体
- 棋子直径约占图标宽度的 55-60%
- 棋子投影：`color: black, opacity: 0.3, radius: 4, offset: (2, 4)`

#### 背景层：棋盘纹路

- 底色：线性渐变 `#DEB887` → `#D2AA78` → `#DEB887`（与 BoardView 完全一致）
- 网格线：深棕 `#4A3728`，绘制简化版棋盘格线（9×10 网格，仅画几条代表性线条即可，避免过于密集）
- 楚河汉界：在棋子下方，用楷体写"楚河 · 汉界"，颜色 `#4A3728`，opacity 0.6，作为装饰元素
- 九宫格斜线：画两条斜线呼应九宫

#### 装饰层（确定包含）

- 红方"車"从左上角探入，黑方"馬"从右下角探入，形成对角构图
- 小棋子约为大棋子的 40% 大小，opacity 0.7
- 仅露出 60% 面积（被图标边缘裁切），营造"棋局进行中"的意境

---

## 4. 配色方案总结

```
主色板：
  棋盘木色   #DEB887  （背景主色）
  深棕       #4A3728  （线条、装饰文字）
  中国红     #CC0000  （棋子文字、边框、视觉焦点）

辅助色：
  棋子米黄   #FFFDE6  （棋子高光）
  棋子暗色   #DCC8AA  （棋子阴影过渡）
  纯黑       #1A1A1A  （黑方棋子，装饰用）
```

### 4.1 色彩空间

- **输出格式**：所有 PNG 使用 sRGB 色彩空间，嵌入 sRGB IEC61966-2.1 ICC profile
- **实现**：Pillow 生成时通过 `ImageCms.createProfile("sRGB")` 创建 profile 并嵌入
- **理由**：macOS Asset Catalog 接受 sRGB 和 Display P3，sRGB 兼容性最好。图标色彩以暖木色为主，不在 P3 广色域中获益，sRGB 足矣

### 4.2 Dark Mode 评估

- **深色桌面效果**：棋盘木色 `#DEB887` 为暖色中亮度（明度约 75%），在深色桌面上对比充足，不会发灰
- **红色焦点**：`#CC0000` 在深色背景上反而更加突出，视觉焦点更强
- **潜在问题**：浅色棋子底色 `#FFFDE6` 在深色桌面下可能显得过于明亮
- **结论**：无需为 Dark Mode 单独制作变体。macOS 不会自动调整图标色调，当前配色在两种外观下均可接受。如后续用户反馈对比过强，可考虑在棋子底色上略微降亮

---

## 5. macOS 图标规范

### 5.1 图标形状

- 使用 macOS 标准超椭圆（superellipse）圆角矩形
- 圆角半径约为图标尺寸的 22.37%（Apple HIG 标准）
- 图标内容需内缩约 3-4% 安全边距（Apple HIG 建议约 2-3%，考虑超椭圆裁切特性取 3-4%）

### 5.2 尺寸要求

| 尺寸 | 用途 |
|------|------|
| 1024×1024 | App Store / 主设计稿 |
| 512×512 | Finder 等大图标 |
| 256×256 | Finder 列表视图 |
| 128×128 | Launchpad |
| 64×64 | 小图标 |
| 32×32 | Spotlight / 列表视图 |
| 16×16 | 标题栏 / 最小尺寸 |

**实现要求**：以 1024×1024 为主设计，等比缩放生成所有尺寸。16×16 下可能需要简化细节（去掉装饰文字和小棋子）。

### 5.3 适配要点

- 1024px 主设计稿中，棋子文字"帅"字号约 200-240px
- 缩至 16×16 时，"帅"字可能不可读，此时应简化为纯色圆形 + 红色圆环即可
- 建议为 32px 以下单独制作简化版本

---

## 6. 实现要点（给 Cody 的指引）

### 6.1 技术路径

推荐使用 **Python + Pillow** 程序化生成图标：

1. 在 1024×1024 画布上绘制
2. 先画超椭圆 mask（macOS 图标形状）
3. 画棋盘渐变背景
4. 画简化网格线（不必画全 9×10，画 5-6 条线即可，装饰性）
5. 画主棋子（"帅"）：圆形 + 径向渐变 + 红色圆环边框 + 红色"帅"字
6. 画装饰小棋子（红"車"左上、黑"馬"右下）
7. 画"楚河 · 汉界"装饰文字
8. 应用超椭圆 mask 裁切
9. 嵌入 sRGB ICC profile
10. 导出各尺寸 PNG
11. 用 `iconutil` 生成 .icns

### 6.2 字体要求

- 棋子文字必须使用楷体
- **字体查找优先级**（按顺序尝试）：
  1. `/System/Library/Fonts/STKaiti.ttf` — macOS 系统楷体
  2. `/Library/Fonts/Kaiti.ttc`
  3. `~/Library/Fonts/方正楷体简体.TTF` — 当前机器已安装
  4. `/System/Library/Fonts/Supplemental/Songti.ttc` — 宋体 fallback
  5. 系统 serif fallback
- 字体加载失败时打印明确错误信息并终止，不使用默认字体

### 6.3 超椭圆 Mask 实现

**方案：Pillow `ImageDraw.polygon()` 逼近（已验证可行）**

```python
import math
from PIL import Image, ImageDraw

def superellipse_mask(size, radius, n=5, num_points=720):
    """生成超椭圆 mask。
    
    已验证：720 个采样点的 polygon 逼近在 1024px 下边缘平滑，
    无可见锯齿。纯 Pillow，无需额外依赖。
    """
    cx, cy = size // 2, size // 2
    points = []
    for i in range(num_points):
        t = 2 * math.pi * i / num_points
        cos_t = math.cos(t)
        sin_t = math.sin(t)
        x = cx + radius * (1 if cos_t >= 0 else -1) * abs(cos_t) ** (2.0 / n)
        y = cy + radius * (1 if sin_t >= 0 else -1) * abs(sin_t) ** (2.0 / n)
        points.append((x, y))
    
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(points, fill=255)
    return mask
```

参数说明：
- `radius = 480`（1024 画布留 32px 边距 × 2 + 40px 超椭圆收窄）
- `n = 5`（Apple 标准超椭圆指数）
- `num_points = 720`（每度 2 个采样点，边缘足够平滑）
- **无需 aggdraw/Cairo 等额外依赖**

### 6.4 中文字体渲染质量

**已验证**：Pillow + FreeType 渲染 200px 楷体"帅"字，效果可接受。

潜在风险和缓解：
- Pillow 使用 FreeType 渲染，200px 大字号下笔画均匀性优于小字号，hinting 影响可忽略
- 如果渲染质量不达标，**备选方案**：用 Cairo + Pango 渲染文字层，叠加到 Pillow 画布上。但这引入额外依赖，建议先试纯 Pillow
- **关键**：字体加载后必须设置 `font.getbbox()` 验证字形可用，避免空字或方块

### 6.5 sRGB ICC Profile 嵌入

```python
from PIL import ImageCms

# 创建 sRGB profile
srgb_profile = ImageCms.createProfile("sRGB")

# 保存时嵌入
img.info['icc_profile'] = ImageCms.ImageCmsProfile(srgb_profile).tobytes()
img.save('output.png', icc_profile=srgb_profile)
```

### 6.6 .icns 生成

```bash
# 1. 生成 iconset 目录结构
mkdir ChineseChess.iconset
# 放入各尺寸 PNG（需包含 @2x 变体）

# 2. 生成 .icns
iconutil -c icns ChineseChess.iconset -o ChineseChess.icns
```

iconset 需要的文件：
```
icon_16x16.png          (16×16)
icon_16x16@2x.png       (32×32)
icon_32x32.png          (32×32)
icon_32x32@2x.png       (64×64)
icon_128x128.png        (128×128)
icon_128x128@2x.png     (256×256)
icon_256x256.png        (256×256)
icon_256x256@2x.png     (512×512)
icon_512x512.png        (512×512)
icon_512x512@2x.png     (1024×1024)
```

### 6.7 简化版（小尺寸）

**32×32 及以下**的图标简化方案：

- **背景**：纯色圆角矩形，填充 `#DEB887`（木色），不用渐变
- **主体**：红色实心圆环 `#CC0000`，圆环宽度约 2px（32px 下）或 1px（16px 下）
- **圆内**：填充 `#FFFDE6`（棋子米黄），模拟棋子底色
- **无文字**、无装饰棋子、无网格线
- **16×16 进一步简化**：红色圆环 + 米黄圆心，确保在小尺寸下保持"圆形棋子"的视觉印象

### 6.8 错误处理

脚本必须处理以下异常场景：

| 场景 | 处理方式 |
|------|----------|
| 楷体字体未找到 | 打印所有尝试路径及失败原因，终止并提示安装字体 |
| Pillow 版本 < 9.1.0 | 打印版本要求，终止（需要 `ImageCms.createProfile` 支持） |
| iconutil 命令失败 | 检查是否在 macOS 上运行，打印 stderr，终止 |
| 输出目录不存在 | 自动 `os.makedirs` 创建 |
| 图标尺寸非标准 | 校验尺寸列表，不匹配时报错 |

### 6.9 工期评估

| 任务 | 预估 |
|------|------|
| generate_icon.py 脚本编写 | 2-3 小时 |
| 调试 + 各尺寸验证 | 1-2 小时 |
| iconutil 打包 + 集成到项目 | 0.5 小时 |
| **合计** | **半天（4-6 小时）** |

---

## 7. 视觉 Mockup

> **注意**：以下为程序生成的验证稿，用于确认构图方向。最终图标由 Cody 根据 generate_icon.py 产出。

图标的核心视觉 = **一枚居中的中国象棋"帅"棋子，叠加在木纹棋盘背景上，两颗小棋子从对角探入。**

参考关键词：
- 中国象棋棋子：圆形、木质底色、红色/黑色汉字
- 木质棋盘：暖黄褐色、网格线
- 中国风配色：红 + 金/木色

最终效果应该是一个人在 Dock 栏扫一眼就能认出"这是象棋应用"的图标。

### 验证稿产出

Cody 实现 generate_icon.py 后，**先运行一次产出 1024px 验证稿**，由 Luke/洪涛确认视觉方向后再打包 .icns。避免做完所有尺寸后返工。

---

## 8. 交付物

| 产出 | 说明 |
|------|------|
| `generate_icon.py` | 图标生成脚本（含 mockup 验证模式） |
| `ChineseChess.iconset/` | 各尺寸 PNG 文件（含 sRGB ICC profile） |
| `ChineseChess.icns` | macOS 图标文件 |

**路径**：
- 脚本：`~/DevTeam/projects/chinese-chess/src/tools/generate_icon.py`
- 图标输出：`~/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Assets.xcassets/AppIcon.appiconset/`
- **前置条件**：Cody 开始前需确认 `AppIcon.appiconset/` 目录存在，不存在则脚本自动创建

---

## 附录：Vera 审查清单处理记录

| # | 级别 | 问题 | 处理 |
|---|------|------|------|
| 1 | P0 | 缺少色彩空间定义 | §4.1 补充 sRGB + ICC profile 嵌入方案 |
| 2 | P0 | 超椭圆实现未验证 | §6.3 补充已验证的 polygon 逼近代码 + 验证结论 |
| 3 | P0 | 缺少视觉稿 | §7 补充 mockup 流程，Cody 先出验证稿再定稿 |
| 4 | P1 | Pillow 中文字体渲染质量 | §6.4 已验证 + 补充备选方案 |
| 5 | P1 | 装饰小棋子无决策标准 | §3.2 从"可选"改为"确定包含"，固定构图 |
| 6 | P1 | 小尺寸简化方案模糊 | §6.7 重写，补充具体配色和构图描述 |
| 7 | P1 | 缺少 dark mode 评估 | §4.2 补充评估结论 |
| 8 | P2 | 无工期评估 | §6.9 补充半天（4-6 小时）评估 |
| 9 | P2 | 安全边距 10% 偏大 | §5.1 修正为 3-4% |
| 10 | P2 | 交付物路径未确认存在 | §8 补充前置条件，脚本自动创建目录 |
| 11 | P2 | 缺少错误处理指引 | §6.8 补充异常场景处理表 |
