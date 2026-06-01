# v1.17.0 角色素材升级方案

> 版本：v1.1（Vera 审查修复版）| 作者：Alex | 日期：2025-06-09

---

## 一、现状分析

### 1.1 当前画风
现有 30 张角色图（6 色 × 5 状态）采用**极简 Q 版风格**：
- 纯色椭圆蛋形 + 简单表情（圆点眼/星星眼/弧线嘴）
- 无渐变、无高光、无腮红，几乎没有光影层次
- 看起来像平面矢量图，缺乏体积感和质感

### 1.2 目标画风
参考网易蛋仔派对官方宣传图，核心视觉特征：
- **圆润蛋形体态**，底部宽顶部窄，有微小手足
- **大眼睛**（占面部 30-40%），虹膜有渐变色，多层高光点
- **粉色圆形腮红**，柔和边缘
- **" vinyl toy " 质感**：表面有高光反射，像搪胶玩具
- **颜色饱满**，饱和度高但不刺眼，主体有渐变
- **轮廓线**：细而柔和，颜色与填充色同色系（不是纯黑描边）

**差距**：当前素材在光影、质感、表情精细度上与目标差距很大，不是微调能解决的，需要整体重绘。

---

## 二、素材来源方案评估

### 方案 A：从官方宣传图抠图

| 维度 | 评估 |
|------|------|
| 可行性 | ❌ 低 |
| 理由 | 官方图有复杂背景、文字、多角色叠加；角色穿着主题装扮（皇冠、翅膀、魔术帽），不是游戏内基础蛋仔造型；抠图后边缘质量差，无法获得干净素材 |
| 质量 | 抠图后残缺，无法保证 6 色一致性；装扮遮挡身体，无法复用 |
| 耗时 | 高（每张需手动精修） |
| 版权风险 | 高——直接使用官方素材，即使抠图也属于衍生使用 |

**结论：排除。** 官方图适合做风格参考，不适合做素材来源。

### 方案 B：AI 图像生成

| 维度 | 评估 |
|------|------|
| 可行性 | ✅ 高 |
| 理由 | 可以用文字精确描述目标画风；AI 图生图工具支持风格一致性控制；透明背景可通过工具后处理或 Inpainting 实现 |
| 质量 | 取决于 prompt 精度和工具选择；主流模型（GPT-4o、Midjourney、Stable Diffusion）对 Q 版角色生成质量已很高 |
| 耗时 | 中等——需要调优 prompt 模板，但批量生成效率高 |
| 版权风险 | 低——AI 生成的新作品不直接复制官方素材 |

**关键挑战**：如何保证 30 张图的风格一致性。解决方式见第 5 节。

### 方案 C：专业插画师手绘

| 维度 | 评估 |
|------|------|
| 可行性 | ⚠️ 中 |
| 理由 | 质量最高，风格一致性最好；但需要找到合适的插画师，沟通成本高，周期长 |
| 质量 | ✅ 最高 |
| 耗时 | 长（通常 1-2 周） |
| 成本 | 高（30 张精致插画，市场价 ¥150-500/张） |

**结论**：作为备选方案。当前团队无人力资源走这条路。

### 决策：采用方案 B（AI 图像生成）

---

## 三、角色设计方案

### 3.1 基础造型（所有角色共用）

所有角色共享统一的基础体型，仅通过**主色调**和**微小配饰差异**区分：

```
┌─────────────────────────┐
│       ○  小圆顶         │
│     ╱    ╲              │
│   ╱   👀 👀   ╲        │  大眼睛（占面部 35%）
│  │    ─○─    │          │  粉色圆形腮红
│  │     ▽     │          │  简单嘴巴
│   ╲        ╱            │
│    ╲──────╱             │  底部圆弧
│     ○○  ○○              │  小短脚
└─────────────────────────┘
```

**共通特征**：
- 蛋形身体，宽底窄顶，略微圆润的梨形
- 大眼睛：椭圆形，占面部 ~35%，有 2-3 个白色高光点
- 圆形粉色腮红（每个角色腮红颜色固定）
- 身体有渐变色（上浅下深）+ 左上方一个大高光椭圆
- 细描边（2-3px），颜色与角色主色同色系但更深
- 可爱小短脚
- 无手臂（蛋仔官方风格蛋仔没有手臂，只有圆手在需要时出现）

### 3.2 六色角色差异化设计

| 角色 | 主色 | 渐变色（上→下） | 腮红色 | 独特配饰 | 性格暗示 |
|------|------|----------------|--------|---------|---------|
| **Pink** | 樱花粉 #FFB6C1 → #FF69B4 | 浅粉→深粉 | #FF8FAB | 头顶小蝴蝶结（同色系） | 甜美可爱 |
| **Blue** | 天空蓝 #87CEEB → #4A90D9 | 浅蓝→深蓝 | #FFA0A0 | 头顶小水滴（同色系浅蓝） | 清爽温柔 |
| **Green** | 薄荷绿 #98FB98 → #3CB371 | 浅绿→翠绿 | #FFB0B0 | 头顶一片小叶子 | 活泼自然 |
| **Red** | 珊瑚红 #FF7F7F → #DC3545 | 浅红→深红 | #FF9090 | 头顶小火焰（小面积） | 热情勇敢 |
| **Black** | 深灰 #6B6B6B → #2C2C2C | 灰→近黑 | #E88FA0 | 头顶小恶魔角（两个小凸起） | 酷帅神秘 |
| **Yellow** | 柠檬黄 #FFF176 → #FFC107 | 浅黄→金黄 | #FFA0A0 | 头顶小星星（同色系金色） | 开朗温暖 |

**差异化原则**：
- 配饰极小、极简——不遮挡身体 10% 以上面积
- 配饰颜色与主色同色系，保持视觉统一
- 所有角色的眼睛形状、嘴巴形状在相同表情下完全一致

### 3.3 五种表情状态定义

#### idle（默认 / 待机）
- **眼睛**：大圆眼，微微向右上看（期待感），3 个高光点
- **嘴巴**：小微笑，嘴角微微上扬
- **情绪**：友善、等待
- **体态**：正脸，身体居中

#### happy（开心）
- **眼睛**：闭眼弯月形（> <），弯度大
- **嘴巴**：大笑嘴（D 形），露出小舌头
- **情绪**：满足、幸福
- **体态**：正脸，可微微左倾 5°

#### excited（兴奋）
- **眼睛**：星星眼 ★，瞳孔变为五角星形，保留高光
- **嘴巴**：O 形张嘴（惊喜），不大不小
- **情绪**：惊叹、超级开心
- **体态**：正脸，可微微右倾 5°

#### sad（难过）
- **眼睛**：大圆眼但眉毛下垂（八字眉），眼角有泪滴（1 滴）
- **嘴巴**：倒弧线，微微向下
- **情绪**：委屈、不开心
- **体态**：正脸，身体微微缩小 2-3%

#### mini（迷你版）
- **不是缩小版**，是简化版（Q 版的 Q 版）
- **尺寸**：256×256（实际显示区域可能只有 200×200）
- **简化内容**：
  - 身体同造型但更圆更胖，宽高比约 1:1.05（接近正圆，比标准 idle 的 1:1.3 更胖）
  - 眼睛只有 2 个圆点 + 1 个高光
  - 嘴巴一条弧线
  - 有腮红但只有一个小圆点
  - 无渐变（纯色填充），无配饰
  - 保持高光（1 个大椭圆）
- **表情**：固定为 idle 表情的极简版
- **设计理由**：mini 在 UI 中显示为 60pt 缩略图，细节太多反而糊成一片

---

## 四、产出规格

### 4.1 文件规格

| 状态 | @1x 尺寸 | @2x 尺寸 | 格式 | 背景 |
|------|---------|---------|------|------|
| idle/happy/excited/sad | 512×512 | 1024×1024 | PNG | 透明 |
| mini | 256×256 | 512×512 | PNG | 透明 |

### 4.2 命名规范

```
egg_{color}_{state}.png          # @1x
egg_{color}_{state}@2x.png       # @2x
```

示例：
```
egg_pink_idle.png / egg_pink_idle@2x.png
egg_blue_excited.png / egg_blue_excited@2x.png
egg_green_mini.png / egg_green_mini@2x.png
```

### 4.3 质量标准

| 指标 | 要求 |
|------|------|
| 文件大小（@2x） | 150KB-400KB（太小说明细节不足，太大说明有冗余） |
| 文件大小（@1x） | 40KB-100KB |
| 透明度 | 边缘必须干净，无锯齿毛刺，无白色/灰色杂边 |
| 描边 | 均匀连续，无断裂 |
| 高光 | 有且仅有一个主体高光 + 眼睛高光 |
| 渐变 | 平滑过渡，无色带 |
| 风格一致性 | 同一角色 5 种状态的体型、配色、描边粗细必须一致 |
| 跨角色一致性 | 6 个角色的体型比例、眼睛大小、描边风格必须一致 |

### 4.4 Xcode 资源结构

沿用现有 `.imageset` 目录结构，替换图片文件即可，`Contents.json` 不变：

```
EggCharacters/
├── egg_pink_idle.imageset/
│   ├── Contents.json
│   ├── egg_pink_idle.png         ← 替换
│   └── egg_pink_idle@2x.png     ← 替换
├── egg_pink_happy.imageset/
│   ├── Contents.json
│   ├── egg_pink_happy.png       ← 替换
│   └── egg_pink_happy@2x.png   ← 替换
...
```

---

## 五、Cody 执行方案

### 5.1 工具选择

**推荐方案：GPT-4o（ChatGPT）图像生成**

选择理由：
- GPT-4o 对 Q 版角色生成的质量稳定
- 支持中文 prompt，沟通精确
- 生成速度快（每张 ~30 秒）
- 可以通过 seed/ref 概念保持一致性
- ⚠️ **GPT-4o 无法生成透明背景**，所有输出必须带背景，统一使用**纯白背景**（便于 rembg 处理）
- 生成后需统一走去背景流水线（见 5.4 节）

**备选方案：Midjourney v6+**
- 质量更高但可控性略低
- 同样不支持透明背景，需额外去背景步骤

**备选方案：Stable Diffusion + ControlNet**
- 完全可控但配置复杂
- 需要本地 GPU 或云服务

**最终建议用 GPT-4o**，因为质量和效率的平衡最好。

**失败切换阈值**：如果 Step 1（pink_idle prompt 调优）超过 **2 小时**仍未达到满意效果，应升级到方案 C（专业插画师），避免在 AI 调优上无限投入时间。

### 5.2 Prompt 模板

#### 基础 Prompt 模板（idle 状态）

```
Create a cute chibi egg character, front view, standing upright, kawaii style:

Body: egg-shaped silhouette, round wide bottom tapering to a round top (pear shape), height roughly 1.3x width. {color} body with smooth linear gradient from {light_color} at the top to {dark_color} at the bottom. Two small round stubby feet at the bottom center, each foot is a simple semi-circle in a slightly darker shade of {color}. No arms visible.

Face: centered on upper half of body. Large oval eyes tilted slightly inward (≈35% of face width), with iris gradient from light {eye_color} at top to deeper {eye_color} at bottom. Each eye has exactly 3 white circular highlight dots: one large (top-right of iris), one medium (bottom-left), one tiny (center-top). Small upturned smile mouth (gentle U-curve). Two round {blush_color} blush circles on cheeks, each roughly 15% of face width, placed between eyes and body edge.

Highlight: one large glossy oval highlight on upper-left quadrant of body (vinyl toy reflection), oriented 30° from vertical, roughly 20% of body width.

Accessories: {accessory}.

Outline: uniform {outline_color} stroke, 3px weight, anti-aliased, fully enclosing body and accessories. Outline color must be darker than adjacent fill.

Style: glossy vinyl toy finish, soft cel-shading, no texture, no background elements.

Background: solid pure white (#FFFFFF), no gradients or patterns in background.
Pose: front-facing, centered in frame, body perfectly upright (0° tilt for idle).

Canvas: 1024x1024 pixels, PNG format.
```

#### 各状态的 Prompt 差异

| 状态 | 眼睛变化 | 嘴巴变化 | 其他 |
|------|---------|---------|------|
| idle | 大圆眼，微右上看 | 小微笑 | 无 |
| happy | 闭眼弯月（> <） | D 形大笑，小舌头 | 身体微左倾 5° |
| excited | 星星眼 ★ | O 形张嘴 | 身体微右倾 5° |
| sad | 八字眉 + 一滴泪珠挂在左眼角 | 倒弧线（小 frown） | 身体微微缩一缩（视觉上比 idle 略小一丁点，不要精确百分比） |
| mini | 2 圆点 + 1 高光 | 简单弧线 | 更圆更胖，无配饰，无渐变，纯色 |

#### 6 色参数表

```
Pink:   color="cherry blossom pink", light_color="#FFD1DC", dark_color="#FF69B4", 
        eye_color="warm pink", blush_color="#FF8FAB", outline_color="#D4567A",
        accessory="tiny ribbon bow on top of head"

Blue:   color="sky blue", light_color="#B8E0F7", dark_color="#4A90D9",
        eye_color="clear blue", blush_color="#FFA0A0", outline_color="#3570A8",
        accessory="tiny water droplet on top of head, same blue tones"

Green:  color="mint green", light_color="#C6F7C6", dark_color="#3CB371",
        eye_color="emerald green", blush_color="#FFB0B0", outline_color="#2D8A56",
        accessory="tiny leaf on top of head"

Red:    color="coral red", light_color="#FFB3B3", dark_color="#DC3545",
        eye_color="warm amber", blush_color="#FF9090", outline_color="#B02A37",
        accessory="tiny flame on top of head"

Black:  color="charcoal dark", light_color="#8A8A8A", dark_color="#2C2C2C",
        eye_color="deep purple", blush_color="#E88FA0", outline_color="#3A3A3A",
        accessory="two tiny devil horns on top of head"

Yellow: color="lemon yellow", light_color="#FFF9C4", dark_color="#FFC107",
        eye_color="warm brown", blush_color="#FFA0A0", outline_color="#D4A00A",
        accessory="tiny five-pointed star on top of head, same golden tones"
```

### 5.3 风格一致性保障策略

**核心思路：先做"标准件"，再用标准件做参照生成全部。**

#### Step 1：生成标准参考图（锚定阶段）
1. 先生成 `pink_idle` @2x 版本，反复调整 prompt 直到满意
   - ⏱️ **时间上限 2 小时**，超时未满意则升级到方案 C
2. 确定最终 prompt 后，用相同模板生成其他 5 色的 idle
3. **6 张 idle 并排对比审查**：体型比例、眼睛大小、描边粗细、高光位置必须一致
4. 审查通过后，6 张 idle 图即为**标准参考图**，后续所有生成以此为锚

#### Step 2：以标准参考图生成其他表情
5. 对每个角色，以 idle 图为参考（image-to-image 或 prompt 中描述），生成 happy/excited/sad
   - **同一角色尽量使用相同 seed**（如果工具支持），确保体型和配饰一致
6. **每生成 5 张做一次横向对比**：表情差异是否明显、体型是否漂移
7. 逐张检查：表情是否到位、体型是否与 idle 一致
8. 不合格的重新生成，最多 3 轮

#### Step 3：生成 mini 版本
9. mini 用独立的简化 prompt 模板
10. 以 idle 为参考，生成简化版
11. 检查：简化后是否还认得出对应角色

#### Step 4：去背景流水线
12. 统一用 `rembg` 去背景：
    ```bash
    # 推荐模型：u2net（通用物品，效果好且快）
    pip install rembg[gpu]  # 有 GPU 加速，无 GPU 则 pip install rembg
    for f in raw_*.png; do
      rembg i -m u2net "$f" "nobg_$f"
    done
    ```
13. **描边保护**：rembg 可能削掉 1-2px 描边。缓解方式：
    - prompt 中生成时让角色四周留 10-15% 边距
    - 去背景后用 ImageMagick 检查描边完整性：
      ```bash
      # 对比去背景前后边界像素差异
      compare raw.png nobg.png diff.png
      ```
14. **alpha 边缘检查**：逐张验证透明度过渡不超过 2px，无白边/灰边
    ```bash
    # 检测边缘是否有白色残留
    identify -verbose nobg.png | grep "opacity"
    ```

#### Step 5：压缩 + 缩放 + 重命名
15. 用 `optipng` 无损压缩所有 @2x 图：
    ```bash
    brew install optipng
    optipng -o5 *.png
    ```
16. 缩放生成 @1x 版本（从 @2x 缩放）：
    ```bash
    for f in *@2x.png; do
      base="${f%@2x.png}"
      sips -z 512 512 "$f" --out "${base}.png"
    done
    ```
    mini 版本额外缩放：
    ```bash
    for f in *mini@2x.png; do
      base="${f%@2x.png}"
      sips -z 256 256 "$f" --out "${base}.png"
    done
    ```
17. 如果压缩后文件仍超 400KB，用 `pngquant` 有损压缩（质量 85%+）：
    ```bash
    pngquant --quality=85-95 --ext .png --force *.png
    ```
18. 重命名为标准命名 `egg_{color}_{state}[@2x].png`

### 5.4 去背景处理（详见 Step 4）

所有 AI 生成的图**一定带有白色背景**（prompt 中已指定纯白背景以获得最佳去背景效果）。去背景流程已整合到 Step 4，核心要点：

- **工具**：`rembg`，模型 `u2net`（对纯色背景的 Q 版角色效果最好）
- **描边保护**：生成时留 10-15% 边距，去背景后检查描边完整性
- **alpha 边缘**：透明度过渡不超过 2px，无白边灰边
- **不做手动去背景**，全流程脚本化

### 5.5 执行步骤总结

| 步骤 | 内容 | 预计耗时 |
|------|------|---------|
| 1 | 调优 pink_idle prompt（⏱️ 上限 2 小时，超时升级方案 C） | 30-120 min |
| 2 | 生成 6 色 idle | 30 min |
| 3 | 审查 idle 一致性（6 张并排对比） | 15 min |
| 4 | 生成 6×3=18 张表情图（happy/excited/sad） | 1-1.5 hr |
| 5 | 每 5 张横向对比 + 重做不合格图 | 30-45 min |
| 6 | 生成 6 张 mini 版本 | 20 min |
| 7 | 去背景处理（rembg u2net） | 30 min |
| 8 | 描边完整性 + alpha 边缘检查 | 15 min |
| 9 | optipng 压缩 + 缩放 @1x + 重命名 | 20 min |
| 10 | 自动化验收脚本检查 | 10 min |
| 11 | 替换到 Xcode 项目 | 10 min |
| 12 | 真机测试显示效果 | 15 min |
| **总计** | | **4.5-5.5 小时** |

---

## 六、风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| AI 生成的 6 色风格不统一 | 角色看起来像不同游戏 | 严格按 Step 1 标准件流程；不合格就重做 |
| 透明背景去不干净 | 图片边缘有白边/杂色 | 用 rembg + 手动抽查；必要时手动修 |
| 表情差异不够明显 | happy 和 idle 看不出区别 | 每个状态的 prompt 要强调差异化特征 |
| 文件过大影响包体积 | App 体积增大 | 用 TinyPNG/optipng 压缩；30 张 @2x 目标 < 10MB |
| AI 工具无法生成透明背景 | 需要额外去背景步骤 | 已在 prompt 中指定纯白背景 + rembg u2net 流程 |
| Black 角色暗色模式不可见 | 深色背景下描边消失 | Black 描边用 #3A3A3A（比纯黑亮）而非 #1A1A1A；深色模式下代码可加 1px 白色外描边 |
| prompt 调优超时 | 无限投入 AI 生成 | 2 小时硬上限，超时升级方案 C |

---

## 七、验收标准

### 7.1 人工视觉验收

1. **风格统一**：6 个角色放一起，明显是同一画风
2. **表情可辨**：5 种状态随机抽查，能一眼区分
3. **画质达标**：@2x 版本放大到 200% 不糊不锯齿
4. **透明干净**：放在白色/黑色/彩色背景上无杂边
5. **项目可用**：替换后 App 正常运行，角色显示正确

### 7.2 自动化验收脚本

Cody 在交付前必须运行以下校验脚本，全部 PASS 才算交付完成：

```bash
#!/bin/bash
# validate_characters.sh
set -e

CHARS_DIR="VocabGame/Resources/Assets.xcassets/EggCharacters"
COLORS=(pink blue green red black yellow)
STATES=(idle happy excited sad)
MINI_STATES=(mini)
PASS=0; FAIL=0

check() {
  local msg="$1" ok="$2"
  if $ok; then echo "✅ $msg"; ((PASS++)); else echo "❌ $msg"; ((FAIL++)); fi
}

# 1. 检查文件存在性 + 命名
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}" "${MINI_STATES[@]}"; do
    for suffix in "" "@2x"; do
      f="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}${suffix}.png"
      check "存在: egg_${c}_${s}${suffix}.png" "[ -f \"$f\" ]"
    done
  done
done

# 2. 检查像素尺寸
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    f="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png"
    w=$(sips -g pixelWidth "$f" | tail -1 | awk '{print $2}')
    h=$(sips -g pixelHeight "$f" | tail -1 | awk '{print $2}')
    check "尺寸: ${c}_${s}@2x = ${w}x${h}" "[ \"$w\" = '1024' ] && [ \"$h\" = '1024' ]"
    f1="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}.png"
    w1=$(sips -g pixelWidth "$f1" | tail -1 | awk '{print $2}')
    h1=$(sips -g pixelHeight "$f1" | tail -1 | awk '{print $2}')
    check "尺寸: ${c}_${s} @1x = ${w1}x${h1}" "[ \"$w1\" = '512' ] && [ \"$h1\" = '512' ]"
  done
  # mini
  f="$CHARS_DIR/egg_${c}_mini.imageset/egg_${c}_mini@2x.png"
  w=$(sips -g pixelWidth "$f" | tail -1 | awk '{print $2}')
  h=$(sips -g pixelHeight "$f" | tail -1 | awk '{print $2}')
  check "尺寸: ${c}_mini@2x = ${w}x${h}" "[ \"$w\" = '512' ] && [ \"$h\" = '512' ]"
done

# 3. 检查文件大小
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    f="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png"
    kb=$(( $(stat -f%z "$f") / 1024 ))
    check "大小: ${c}_${s}@2x = ${kb}KB" "[ $kb -ge 150 ] && [ $kb -le 400 ]"
  done
done

# 4. 检查 alpha 通道存在
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    f="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png"
    has_alpha=$(sips -g hasAlpha "$f" | tail -1 | awk '{print $2}')
    check "Alpha: ${c}_${s}@2x" "[ \"$has_alpha\" = 'yes' ]"
  done
done

echo ""
echo "===== 结果: $PASS PASS, $FAIL FAIL ====="
[ $FAIL -eq 0 ] && exit 0 || exit 1
```
