# v1.17.0 角色素材升级 v2 方案

> 版本：v2.2（Vera v2.1 审查修复版）| 作者：Alex | 日期：2025-06-09
> 前置：v1 方案已否决（详见下方失败复盘）

---

## 〇、v1 失败复盘

| 问题 | 严重程度 | 根因 |
|------|---------|------|
| 角色形状为沙漏形/梨形 | 🔴 致命 | prompt 写了 "pear shape, round bottom tapering to round top"，AI 按字面生成了上窄下宽 |
| 像挂件/装饰球 | 🔴 致命 | 无手脚、无立体感，prompt 未强调 3D 渲染和手足 |
| 与官方形象相似度 ~10% | 🔴 致命 | 风格锚定不够——只写了 "kawaii style"，没写 "Eggy Party style" |
| 6 角色同模板换色 | 🟡 严重 | 配饰描述太模糊，AI 没有稳定生成 |
| 缺少视觉审查环节 | 🟡 严重 | 方案没有在关键节点要求丹妮人工确认 |

**教训总结**：
1. Prompt 中的形状描述必须用 **具体比喻 + 负面约束**（"softball shape, NOT hourglass"）
2. 不能让 AI 自由理解"蛋形"——必须精确描述宽高比和对称性
3. 每一步必须有**人工视觉确认**（不是自动检查文件大小就完事）
4. 风格锚定要用具体参考，不能用抽象形容词

---

## 一、目标画风精确定义

### 1.1 网易蛋仔派对官方角色核心特征

基于对官方宣传图的分析，标准蛋仔角色的精确特征：

```
┌──────────────────────────────────────────┐
│              ╭─────────╮                 │
│            ╱             ╲               │
│          │    ●  △  ●     │  ← 大圆眼+高光│
│          │   ☺ 腮红 ☺     │  ← 粉色腮红  │
│          │    微笑         │              │
│           ╲             ╱               │
│             ╰─────┬─────╯               │
│                ╱   ╲                     │
│               ○○   ○○       ← 小短脚    │
└──────────────────────────────────────────┘
```

**精确参数**：

| 特征 | 精确定义 | v1 错误 |
|------|---------|---------|
| **身体形状** | **扁圆球形**（softball/wide pebble），宽 > 高，宽高比约 **1.15:1 到 1.3:1** | v1 写了"pear shape"→ 沙漏形 |
| **上下对称性** | **接近对称**，最宽点在身体中部（不是底部），顶部和底部弧度相似 | v1 无此约束 |
| **手臂** | ⚠️ **无手臂**（CogView-3-Flash 无法稳定生成手臂，丹妮实测 4 轮均失败。接受无手臂设计——角色仍可爱且辨识度高） | v1 写了 "No arms visible" 但未说明是工具限制 |
| **脚** | **有短粗小脚**，底部可见两个小圆/椭圆脚 | — |
| **眼睛** | 占面部约 30-35%，正圆形，有大面积白色高光（2-3 个点） | — |
| **质感** | **3D 渲染感**，有明确的光源（左上方），有高光椭圆和底部阴影，像搪胶玩具（vinyl toy） | — |
| **描边** | 无硬描边，靠阴影和光感塑造轮廓 | v1 写了 "3px outline"（错误） |

### 1.2 最关键的一句话

> **蛋仔是扁圆球体（softball shape），不是鸡蛋形，不是梨形，不是葫芦形。横向比纵向宽。最宽点在身体正中间。**

### 1.3 无手臂设计评估

丹妮用 CogView-3-Flash 测试了 4 轮 prompt，即使明确写了 "stubby arms on both sides"，AI 仍然不生成手臂。

**决策：接受无手臂设计。** 理由：
1. 丹妮实测验证图（`cogview_v4_clean.png`）无手臂但仍然可爱、辨识度高
2. 在 120-150pt 显示尺寸下，手臂会非常小，可能反而显得杂乱
3. 很多成功的 Q 版角色无手臂（Kirby、部分 Sanrio 角色）
4. 继续尝试生成手臂会消耗大量时间且无保障
5. 配饰 + 表情 + 颜色已足够区分 6 个角色

**如果未来需要手臂**：需换用支持更精细控制的图像生成工具（如 Stable Diffusion + ControlNet），作为 v3 方案考虑。

---

## 二、6 个角色设计方案

### 2.1 共通基础造型

所有角色共享以下基础（仅颜色和配饰不同）：

- 身体：扁圆球形（softball/wide pebble），宽高比 1.15:1-1.3:1，接近对称
- 无手臂
- 面部：位于上半部分（偏上）
- 眼睛：正圆形大眼，白色高光 2-3 个点，占面部 30-35%
- 腮红：两侧圆形粉色腮红（**统一粉色 #FFB0B0**，不按角色区分腮红色——6 色腮红太接近无意义）
- 脚：底部两个短粗小脚，露出身体底部
- 质感：3D 渲染，左上方光源，有高光和阴影
- 无硬描边

### 2.2 六色角色设计

| 角色 | ID | 主体色（Hex） | 独特配饰（精确描述） | 配饰颜色 | 性格 |
|------|-----|-------------|-------------------|---------|------|
| 蛋小黄 | egg_yellow | 明黄 #FFD700 → #FFA500 | **金色小皇冠**，3-5 个尖角，戴在头顶中央，皇冠约头部 1/3 高度 | 金色 | 开朗活泼（默认角色） |
| 蛋小粉 | egg_pink | 粉色 #FFB6C1 → #FF69B4 | **粉色大蝴蝶结**，系在头顶右侧，蝴蝶结两翼张开，约头部 1/2 宽度 | 粉色（深于身体色） | 可爱甜美 |
| 蛋小蓝 | egg_blue | 天蓝 #87CEEB → #4682B4 | **白色帆水手帽**，戴在头顶，帽檐微翘，帽子正中有一个蓝色船锚标志 | 白色+蓝色装饰 | 勇敢冒险 |
| 蛋小绿 | egg_green | 薄荷绿 #98FB98 → #2E8B57 | **两片小草芽**，从头顶长出，嫩绿色，向右倾斜，约头部 1/3 高度 | 嫩绿色 | 自然清新 |
| 蛋小红 | egg_red | 珊瑚红 #FF7F7F → #DC3545 | **金色星星发卡**，别在头顶右侧偏前，五角星形，约眼睛大小 | 金色 | 热情开朗 |
| 蛋小黑 | egg_black | 炭黑 #555555 → #2C2C2C | **两个小恶魔角**，从头顶两侧伸出，深红色弯曲小角，约头部 1/4 高度 | 深红色 | 酷酷神秘 |

**配饰设计原则**：
- 每个角色的配饰**必须占据头部 1/4-1/2 面积**，足够醒目
- 配饰有独立颜色（不全是主色），增加辨识度
- 即使在 mini 版本（缩小简化）中，配饰也应保留（简化为一两个几何形状）
- 配饰位于头顶，不遮挡面部

### 2.3 五种表情状态精确定义

#### idle（默认/待机）
- **眼睛**：正圆形大眼，瞳孔看向正前方略偏右上方（活泼感），有 2-3 个白色高光点
- **嘴巴**：小微笑，嘴角微微上扬，呈温和的 U 形
- **身体**：正面直立
- **情绪**：友好、期待

#### happy（开心）
- **眼睛**：闭眼，变成两条向下弯的弧线（^ ^ 弯月形），弯度大，眼尾下弯
- **嘴巴**：小嘴微张，呈 D 形，露出一点粉色小舌头
- **身体**：正面直立（不要求特殊姿势——无手臂限制了可表达姿势）
- **情绪**：满足、开心

#### excited（兴奋）
- **眼睛**：星星眼，瞳孔变成金色/黄色五角星形 ★，保留白色高光点在星星外
- **嘴巴**：大张嘴，呈圆形 O 形，嘴角上扬（惊喜+开心）
- **身体**：正面直立
- **情绪**：超级兴奋、惊叹

#### sad（难过）
- **眼睛**：正圆形大眼，瞳孔向下看（失神），左眼角挂着一颗透明泪珠
- **嘴巴**：倒 U 形，嘴角向下弯
- **身体**：正面直立（**不要求体态变化**——AI 对微妙体态变化执行力不稳定，仅靠表情区分即可）
- **情绪**：委屈、难过

#### mini（迷你简化版）
- **身体**：与 idle 相同的扁圆球形，但更简化
- **眼睛**：两个黑色实心小圆 + 各一个白色高光点（无瞳孔细节）
- **嘴巴**：一条简单弧线（idle 表情）
- **腮红**：两个小粉色圆点
- **配饰**：保留但简化为 1-2 个几何形状
  - 皇冠 → 一个小三角
  - 蝴蝶结 → 两个小三角
  - 帆水手帽 → 一个小圆角矩形
  - 草芽 → 两条短线
  - 星星发卡 → 一个小星形
  - 恶魔角 → 两个小凸起
- **脚**：保留但更简化（两个小圆）
- **表情**：固定为 idle 的简化版
- **尺寸**：@2x 为 512×512（不是 1024×1024）
- **降级预期**：**mini 以颜色为主要区分，配饰为辅**。简化后 Black 的角和 Green 的草芽可能视觉接近，这是可接受的。

---

## 三、产出规格

### 3.1 文件规格

| 状态 | @1x 尺寸 | @2x 尺寸 | 格式 | 背景 |
|------|---------|---------|------|------|
| idle/happy/excited/sad | 512×512 | 1024×1024 | PNG（RGBA） | 透明 |
| mini | 256×256 | 512×512 | PNG（RGBA） | 透明 |

### 3.2 命名规范

```
egg_{color}_{state}.png          # @1x
egg_{color}_{state}@2x.png       # @2x
```

### 3.3 质量标准

| 指标 | 要求 |
|------|------|
| 文件大小（@2x） | **80KB-200KB** |
| 文件大小（@1x） | 25KB-60KB |
| 透明背景 | `file` 命令输出 "PNG image data, RGBA"；放在白色和深色背景上均无杂边 |
| 身体形状 | 扁圆球形，宽 > 高 |
| 脚可见 | 必须有小脚，不能是光溜溜的球 |
| 配饰存在 | 每个角色必须有配饰，不能是纯色球体 |
| 风格一致性 | 6 角色放一起明显同一画风 |
| 表情可辨 | 5 种状态随机抽查，能一眼区分 |

### 3.4 Xcode 资源结构

沿用现有 `.imageset` 目录结构，仅替换图片文件，`Contents.json` 不变。

### 3.5 暗色模式（素材 vs 代码责任边界）

| 层面 | 责任 | 措施 |
|------|------|------|
| **素材层** | Alex/Cody | Black 角色身体用 #555555 浅端（不是纯黑），确保自身有足够反差；所有角色有高光区域 |
| **代码层** | Cody | 如果未来需要暗色模式支持，在代码中加 `ColorScheme` 判断，给 Black 角色加 1px 白色外描边。当前版本不实现，记入 backlog |

---

## 四、图像生成工具

### 4.1 确定方案：智谱 CogView-3-Flash

| 维度 | 详情 |
|------|------|
| API | `https://open.bigmodel.cn/api/paas/v4/images/generations` |
| Model | `cogview-3-flash` |
| 认证 | Bearer token（从 `~/.openclaw/secrets.json` → `models.providers.zai.apiKey` 读取） |
| 成本 | 约 0.1 元/张，30 张 = **3 元** |
| 尺寸 | 1024×1024 ✅ |
| 透明背景 | ❌ 不支持（需后处理） |
| image edit | ❌ 不支持（无法以参照图生成变体） |
| 风格一致性 | 通过 prompt 模板 + 锚定图审查保障 |

### 4.2 后处理工具链

| 步骤 | 工具 | 说明 |
|------|------|------|
| 去白底 | `scripts/remove_white_bg.py`（Pillow） | 丹妮已编写并验证。用法：`~/.local/share/openclaw/venv/office/bin/python3 scripts/remove_white_bg.py input.png output.png [220] [240]` |
| 缩放 @1x | `sips -z 512 512` | macOS 自带 |
| 无损压缩 | `optipng -o7` | 全部 PNG（@1x 和 @2x） |

---

## 五、Prompt 模板

### 5.1 核心设计原则

1. **形状描述放最前、ALL CAPS**——最重要的约束最先被处理
2. **负面约束放后面辅助**——不同模型对 "NOT X" 遵从度不同
3. **锚定图审查是最终防线**——prompt 不是唯一的质量控制手段

### 5.2 形状约束（丹妮实测验证通过的关键措辞）

```
The character is shaped like a SOFTBALL or a WIDE PEBBLE — it is VERY WIDE and NOT VERY TALL.
Think of the shape as a circle that has been squashed vertically to about 70% of its width.
The widest point is in the MIDDLE of the body, NOT the bottom.
The top and bottom are both rounded curves of similar curvature.
NOT an egg shape, NOT an hourglass, NOT a pear, NOT a teardrop, NOT tall and narrow.
```

> ⚠️ 丹妮实测结果："oblate sphere"、"squashed beach ball" 等措辞 CogView 不理解，**只有 "softball/wide pebble" 成功**。不要改这段。

### 5.3 基础 Prompt 模板（idle 状态）

```
A cute chibi egg character in Eggy Party (蛋仔派对) game style, front view, centered in frame.

SHAPE: The character is shaped like a SOFTBALL or a WIDE PEBBLE — it is VERY WIDE and NOT VERY TALL. Think of the shape as a circle that has been squashed vertically to about 70% of its width. The widest point is in the MIDDLE of the body, NOT the bottom. The top and bottom are both rounded curves of similar curvature. NOT an egg shape, NOT an hourglass, NOT a pear, NOT a teardrop.

BODY: {body_color} with a smooth gradient from {light_color} on top to {dark_color} on the bottom. The body has a 3D rendered glossy vinyl toy appearance with soft lighting from the upper left, creating a bright highlight ellipse on the upper-left body and subtle shadow on the lower right.

FEET: Two short stubby cute feet at the bottom of the body, small rounded shapes.

FACE: Located in the upper half of the body. Large round eyes (about 30-35% of face width), with colorful irises and 2-3 white highlight dots. Pink circular blush marks (#FFB0B0) on both cheeks. Small gentle U-shaped smile.

ACCESSORY: {accessory_description} — this accessory MUST be clearly visible and distinctive.

BACKGROUND: Solid pure white background (#FFFFFF), no other elements.

STYLE: 3D rendered, cute, cartoon, vinyl toy aesthetic. Soft cel-shading with glossy highlights. No hard outlines. Character centered with margin.
```

### 5.4 各状态 Prompt 差异

在基础模板上，替换面部描述（body/shape/feet/accessory/style 部分不变）：

#### happy
```
FACE: Eyes closed into downward-curving crescent shapes (^_^), large curve angle.
Small open D-shaped mouth with a tiny pink tongue peeking out.
Pink circular blush marks (#FFB0B0) on both cheeks.
```

#### excited
```
FACE: Eyes are replaced by golden/yellow five-pointed star shapes (★) with small white highlight dots nearby.
Large open round O-shaped mouth, clearly surprised and thrilled.
Pink circular blush marks (#FFB0B0) on both cheeks.
```

#### sad
```
FACE: Large round eyes with downward-gazing irises, glassy/watery reflection.
A single transparent teardrop hanging from the outer corner of the left eye.
Inverted U-shaped frowning mouth.
Pink circular blush marks (#FFB0B0) on both cheeks.
```

#### mini
```
A simplified miniature version of the {color_name} egg character, front view, centered in frame.

SHAPE: Same softball/wide pebble body shape as the full version.
BODY: {body_color}, simpler gradient. Same 3D glossy style but fewer details.
FEET: Two simple small circle feet.
FACE: Two small solid black dot eyes, each with one tiny white highlight.
Simple curved line smile. Two tiny pink dot blush marks.
ACCESSORY: {accessory_mini_description} — simplified to basic shapes but still recognizable.
BACKGROUND: Solid pure white (#FFFFFF).
```

### 5.5 六色参数表

| 角色 | body_color | light_color | dark_color | accessory_description | accessory_mini_description |
|------|-----------|-------------|------------|----------------------|--------------------------|
| Yellow | bright golden yellow | #FFF176 | #FFA500 | A small golden crown on top of the head with 3 to 5 points, about 1/3 head height, centered | a small triangle on top (crown) |
| Pink | cherry blossom pink | #FFD1DC | #FF69B4 | A large pink ribbon bow on the right side of the head, bow wings spread wide, about 1/2 head width | two small triangles on right side (bow) |
| Blue | sky blue | #B8E0F7 | #4682B4 | A white sailor hat on top of the head with a small blue anchor emblem on the front, brim slightly upturned | a small rounded rectangle on top (hat) |
| Green | mint green | #C6F7C6 | #2E8B57 | Two small grass sprouts growing from the top of the head, light green, tilted slightly right, about 1/3 head height | two short lines on top (sprouts) |
| Red | coral red | #FFB3B3 | #DC3545 | A golden five-pointed star hair clip on the right-front side of the head, about the size of one eye | a small star shape on right side (clip) |
| Black | charcoal dark gray | #777777 | #2C2C2C | Two small curved devil horns protruding from the top sides of the head, dark red color, about 1/4 head height | two small bumps on top (horns) |

---

## 六、批量生成流程

### 6.1 总流程图

```
Step 0: 环境准备 + 工具验证
    │
    ▼
Step 1: 生成蛋小黄 idle + happy + excited（锚定图 + 表情区分验证）──→ 丹妮检查 ✅
    │                                    │ ❌ → 调优 prompt，最多 3 轮
    ▼
Step 2: 生成其他 5 色 idle ──→ 丹妮 6 图并排对比检查 ✅
    │                              │ ❌ → 重做不合格的，最多 2 轮
    ▼
Step 3: 每角色生成 happy/excited/sad ──→ 每 2 角色丹妮抽检 ✅
    │                                      │ ❌ → 重做，最多 2 轮
    ▼
Step 4: 生成 6 个 mini 版本 ──→ 丹妮检查 ✅
    │
    ▼
Step 5: 后处理（去白底 + 压缩 + 缩放 + 命名）
    │
    ▼
Step 6: 自动化验收 ──→ 全部 PASS
    │
    ▼
Step 7: 替换 Xcode 资源 + 真机测试
```

### 6.2 生成顺序策略

**按角色分组**（不是按表情分组）：先完成蛋小黄的 4 个状态，再蛋小粉，依此类推。

理由：
- 同角色的不同表情共享相同的体型和配饰，按角色分组更容易发现体型漂移
- 锚定图（idle）作为参照在生成同角色其他表情时 prompt 更一致
- 如果某个角色的配饰始终生成不对，可以集中调整而不是分散在多轮中

### 6.3 详细步骤

#### Step 0：环境准备 + 工具验证（Cody 执行）
1. 创建工作目录：`~/DevTeam/projects/vocab-game/character-gen/{raw,final}`
2. **验证 CogView API 可用**：用 "a cute yellow egg" 生成一张测试图，确认 API 返回正常
3. **验证去白底工具**：对测试图运行 `remove_white_bg.py`，确认输出 RGBA PNG
4. **验证缩放**：对去白底图运行 `sips -z 512 512`，确认尺寸正确
5. 将批量生成脚本部署到 `~/DevTeam/projects/vocab-game/docs/character-gen-script.py`
   > ⚠️ 脚本不提供 `--step all` 模式。Cody 必须逐步执行，每步之间等丹妮审查确认。

#### Step 1：锚定图 + 表情区分验证
1. 用 idle prompt 模板 + yellow 参数生成蛋小黄 idle @2x
   > 💡 脚本用法：`python3 character-gen-script.py --step generate --color yellow --state idle`
2. 去白底处理
3. **丹妮清单式检查 #1a**（锚定图，逐项勾选，不做主观审美判断。审美问题升级洪涛或 Alex）：

| 检查项 | 是否通过 |
|--------|----------|
| 身体是扁圆球形（宽 > 高，最宽点在中间） | ☐ |
| 有两个小短脚 | ☐ |
| 有粉色腮红 | ☐ |
| 有金色小皇冠 | ☐ |
| 有 3D 光泽质感（高光 + 阴影） | ☐ |
| 不是沙漏形/梨形/葫芦形 | ☐ |
| 不是纯色扁平圆（有光影层次） | ☐ |

4. 锚定图通过后，**额外生成 happy 和 excited 各一张**，验证无手臂设计下小尺寸仍能区分
   > 💡 脚本用法：`python3 character-gen-script.py --step generate --color yellow --state happy`
5. **丹妮检查 #1b**（表情区分度）：

| 检查项 | 是否通过 |
|--------|----------|
| happy（闭眼弯月 + D 形嘴）和 excited（星星眼 + O 形嘴）能区分 | ☐ |
| 缩小到 120pt 后仍能区分 | ☐ |

6. 不通过 → 调整 prompt，重新生成，**最多 3 轮**
7. **⏱️ 2 小时硬上限**：超过 2 小时仍未满意 → 升级到方案 C（插画师）

#### Step 2：6 色 idle 批量生成
8. 用相同的 prompt 模板，只替换颜色和配饰参数，生成其他 5 色的 idle
9. **丹妮清单式检查 #2**（6 张并排对比）：

| 检查项 | 是否通过 |
|--------|---------|
| 6 个角色体型一致（胖瘦相同） | ☐ |
| 6 个角色画风统一 | ☐ |
| 每个角色配饰清晰可辨且互不相同 | ☐ |
| 6 色颜色差异明显 | ☐ |
| 不是只换了颜色的同一模板 | ☐ |

10. 不通过 → 重做不合格的角色，最多 2 轮

#### Step 3：表情变体生成（按角色分组）
11. 对蛋小黄：以 idle 的 prompt 为基础，替换面部描述，生成 happy/excited/sad
12. 完成蛋小黄和蛋小粉后 → **丹妮抽检 #3**
13. 继续蛋小蓝、蛋小绿 → **丹妮抽检 #4**
14. 继续蛋小红、蛋小黑 → **丹妮抽检 #5**

每次抽检检查：

| 检查项 | 是否通过 |
|--------|---------|
| 表情差异明显（happy 闭眼 vs excited 星星眼 vs sad 泪珠） | ☐ |
| 体型没有漂移（和 idle 同胖同宽） | ☐ |
| 配饰没有变化或丢失 | ☐ |

16. 不合格 → 重做，最多 2 轮

#### Step 4：mini 版本
17. 用 mini prompt 模板生成 6 个简化版
18. **丹妮检查 #6**：

| 检查项 | 是否通过 |
|--------|---------|
| 简化后仍能通过颜色认出对应角色 | ☐ |
| 配饰简化但存在 | ☐ |
| 扁圆球形体型与全尺寸版一致 | ☐ |

#### Step 5：后处理（Cody 执行，脚本化）

```bash
#!/bin/bash
set -e
PYTHON=~/.local/share/openclaw/venv/office/bin/python3
SCRIPT=scripts/remove_white_bg.py
GEN=character-gen

# 1. 批量去白底
for f in $GEN/raw/*.png; do
  base=$(basename "$f")
  $PYTHON $SCRIPT "$f" "$GEN/nobg/$base" 220 240
done

# 2. 无损压缩（@1x 和 @2x 全部处理）
optipng -o7 $GEN/nobg/*.png

# 3. 生成 @1x（从 @2x 缩放）+ 直接拷贝 @2x
for f in $GEN/nobg/*_idle@2x.png $GEN/nobg/*_happy@2x.png $GEN/nobg/*_excited@2x.png $GEN/nobg/*_sad@2x.png; do
  base=$(basename "${f%@2x.png}")
  sips -z 512 512 "$f" --out "$GEN/final/${base}.png"
  cp "$f" "$GEN/final/$(basename $f)"
done
for f in $GEN/nobg/*_mini@2x.png; do
  base=$(basename "${f%@2x.png}")
  sips -z 256 256 "$f" --out "$GEN/final/${base}.png"
  cp "$f" "$GEN/final/$(basename $f)"
done
```

#### Step 6：自动化验收（Cody 执行）

```bash
#!/bin/bash
set -e
FINAL_DIR="character-gen/final"
COLORS=(yellow pink blue green red black)
STATES=(idle happy excited sad)
PASS=0; FAIL=0

check() {
  local msg="$1" ok="$2"
  if $ok; then echo "✅ $msg"; ((PASS++)); else echo "❌ $msg"; ((FAIL++)); fi
}

# 1. 文件存在 + 命名
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}" mini; do
    for suffix in "" "@2x"; do
      f="$FINAL_DIR/egg_${c}_${s}${suffix}.png"
      check "存在: egg_${c}_${s}${suffix}.png" "[ -f \"$f\" ]"
    done
  done
done

# 2. 像素尺寸（@2x + @1x）
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    # @2x
    f="$FINAL_DIR/egg_${c}_${s}@2x.png"
    w=$(sips -g pixelWidth "$f" 2>/dev/null | tail -1 | awk '{print $2}')
    h=$(sips -g pixelHeight "$f" 2>/dev/null | tail -1 | awk '{print $2}')
    check "尺寸: ${c}_${s}@2x = ${w}x${h}" "[ \"$w\" = '1024' ] && [ \"$h\" = '1024' ]"
    # @1x
    f1="$FINAL_DIR/egg_${c}_${s}.png"
    w1=$(sips -g pixelWidth "$f1" 2>/dev/null | tail -1 | awk '{print $2}')
    h1=$(sips -g pixelHeight "$f1" 2>/dev/null | tail -1 | awk '{print $2}')
    check "尺寸: ${c}_${s}@1x = ${w1}x${h1}" "[ \"$w1\" = '512' ] && [ \"$h1\" = '512' ]"
  done
  # mini @2x + @1x
  f="$FINAL_DIR/egg_${c}_mini@2x.png"
  w=$(sips -g pixelWidth "$f" 2>/dev/null | tail -1 | awk '{print $2}')
  h=$(sips -g pixelHeight "$f" 2>/dev/null | tail -1 | awk '{print $2}')
  check "尺寸: ${c}_mini@2x = ${w}x${h}" "[ \"$w\" = '512' ] && [ \"$h\" = '512' ]"
  f1="$FINAL_DIR/egg_${c}_mini.png"
  w1=$(sips -g pixelWidth "$f1" 2>/dev/null | tail -1 | awk '{print $2}')
  h1=$(sips -g pixelHeight "$f1" 2>/dev/null | tail -1 | awk '{print $2}')
  check "尺寸: ${c}_mini@1x = ${w1}x${h1}" "[ \"$w1\" = '256' ] && [ \"$h1\" = '256' ]"
done

# 3. 文件大小（@2x + @1x）
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    # @2x
    f="$FINAL_DIR/egg_${c}_${s}@2x.png"
    kb=$(( $(stat -f%z "$f") / 1024 ))
    check "大小: ${c}_${s}@2x = ${kb}KB" "[ $kb -ge 80 ] && [ $kb -le 200 ]"
    # @1x
    f1="$FINAL_DIR/egg_${c}_${s}.png"
    kb1=$(( $(stat -f%z "$f1") / 1024 ))
    check "大小: ${c}_${s}@1x = ${kb1}KB" "[ $kb1 -ge 25 ] && [ $kb1 -le 60 ]"
  done
done

# 4. Alpha 通道
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}" mini; do
    f="$FINAL_DIR/egg_${c}_${s}@2x.png"
    rgba=$(file "$f" | grep -c "RGBA" || true)
    check "透明: ${c}_${s}@2x has alpha" "[ $rgba -ge 1 ]"
  done
done

echo ""
echo "===== 结果: $PASS PASS, $FAIL FAIL ====="
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

#### Step 7：替换 + 测试（Cody 执行）
1. 备份当前 30 张图到 `character-gen/backup_v1/`
2. 将 final/ 中的图片复制到对应 `.imageset` 目录
3. Xcode build 确认无报错
4. 真机/模拟器运行，确认角色显示正确

### 6.4 时间估算

| 步骤 | 内容 | 耗时 |
|------|------|------|
| Step 0 | 环境准备 + 工具验证 | 15 min |
| Step 1 | 锚定图 + 审查 | 30-120 min |
| Step 2 | 5 色 idle + 审查 | 30-60 min |
| Step 3 | 18 张表情 + 3 次抽检 | 1-2 hr |
| Step 4 | 6 张 mini + 审查 | 20-30 min |
| Step 5 | 后处理（脚本化） | 15 min |
| Step 6 | 自动化验收 | 10 min |
| Step 7 | 替换 + 测试 | 15 min |
| **总计** | | **3-5 hr** |

---

## 七、风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| CogView 仍生成梨形/沙漏形 | 角色形状错误 | prompt 已用丹妮实测通过的 "softball/wide pebble" 措辞 + 锚定图审查 |
| 配饰不稳定 | 每次生成配饰不同 | 6 色配饰描述精确到位置/大小/颜色；锚定图确认配饰 |
| 去白底削掉边缘 | 角色边缘有残缺 | 丹妮已验证 `remove_white_bg.py` 效果；prompt 中角色居中留边距 |
| 风格不统一 | 6 角色画风不一致 | 锚定图机制 + 丹妮并排对比检查 |
| Step 1 超时 | prompt 调优无限循环 | 2 小时硬上限，超时升级插画师 |
| CogView 无 image edit | 30 张图独立生成，仅靠 prompt 控制一致性 | 锚定图审查是最终防线；prompt 模板已精确；不合格就重做 |
| Black 角色去白底误伤 | 阈值 220/240 可能削掉暗色边缘 | 后处理后重点检查 Black 角色，必要时调低阈值重跑 |
| Mini 缩放模糊 | 1024→512 的 50% 缩放可能模糊 | Step 4 检查时关注 mini 清晰度 |
| Black 角色暗色模式 | 深色背景下看不清 | 素材用 #555 浅端；代码层暗色模式记入 backlog |
| sad 表情与 idle 差异不够 | 难过看不出来 | sad 有明确泪珠 + 倒 U 嘴，足够区分 |

---

## 八、与 v1 方案的关键差异总结

| 维度 | v1（失败） | v2（本方案） |
|------|-----------|-------------|
| 身体形状 | "pear shape" → 沙漏形 | "softball/wide pebble"（丹妮实测通过）→ 扁圆球 |
| 手脚 | "No arms visible" | 无手臂（工具限制，已评估接受）；有脚 |
| 风格锚定 | "kawaii style" | "Eggy Party (蛋仔派对) game style" |
| 配饰 | 2 角色无配饰 | 6 角色全部有配饰，描述精确到位置/大小 |
| 描边 | "3px outline" | "no hard outlines, 3D rendered" |
| 透明背景 | 假设 GPT-4o 原生支持 | CogView + `remove_white_bg.py`（丹妮已验证） |
| 视觉审查 | 只有文件大小自动检查 | 6 次清单式检查（丹妮不做审美判断） |
| Prompt 策略 | 正面描述 | 正面 ALL CAPS 在前 + 负面约束辅助 + 锚定图防线 |
| 生成顺序 | 未明确 | 按角色分组（不是按表情分组） |
| 腮红 | 6 色各不同（差异微小） | 统一粉色 #FFB0B0 |
| sad 体态 | "缩小 2-3%" | 仅靠表情区分（泪珠 + 倒 U 嘴） |
