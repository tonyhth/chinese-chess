# v1.17 蛋仔形象替换 + 图标重设计 + 多角色系统 + 版本号整理

> 版本：v2 | 作者：Alex | 日期：2025-07-26
> 项目：VocabGame（macOS SwiftUI）| 源码：`~/DevTeam/projects/vocab-game/`

---

## 一、背景与目标

洪涛提出四个整改需求：

| # | 需求 | 核心诉求 |
|---|------|----------|
| 1 | 蛋仔形象替换为网易官方素材 | 当前 SwiftUI 代码手绘（665 行）与官方差距太大，需换成真实图片 |
| 2 | 桌面图标重新设计 | 基于网易官方蛋仔形象重新设计 AppIcon |
| 3 | **多角色系统** | 将蛋仔派对多个官方角色融入背单词 app，作为奖励/解锁/伴侣机制 |
| 4 | 版本号整理 | MARKETING_VERSION 从 1.0.0 更新到 1.17.0，打 git tag |

---

## 二、需求1：蛋仔形象替换方案

### 2.1 当前状况分析

**PetDisplayView.swift（665行）**：
- 用 SwiftUI 原语（Ellipse、Path、Circle 等）手绘蛋仔
- 支持 5 级外观变化：不同体色渐变、Lv.3+ 翅膀、Lv.5 金色光晕
- 4 种表情（mood）：happy / normal / sad / excited → 映射到嘴型变化
- 动画：idle 弹跳、眨眼循环、手臂摇摆、升级发光旋转闪白
- 3 个调用点：HomeView（size=120）、ShopView（size=80）、PetHouseView（size=180）

**PetMiniView.swift（35行）**：
- 极简版迷你蛋仔（椭圆 + 白点眼睛 + 白条嘴巴）
- 定义了但当前无引用，可能预留给未来 TabBar 或通知用

**PetState 模型**：
- `level: Int`（1~5）、`mood: PetMood`（happy/normal/sad/excited）
- `isLevelingUp: Bool`（外部传入的升级动画触发标志）
- `showDizzy: Bool`、`specialOutfit: String?`（彩蛋功能）

### 2.2 素材获取策略

#### 来源
| 来源 | 说明 | 推荐度 |
|------|------|--------|
| 网易蛋仔派对官网 party.163.com | 宣传图、角色立绘 | ⭐⭐⭐ |
| 蛋仔派对百度百科 | 角色形象图、游戏截图 | ⭐⭐⭐ |
| 蛋仔派对 B 站/微博官方号 | 高清宣传图 | ⭐⭐ |
| 蛋仔派对游戏内截图 | 需要截取角色素材 | ⭐ |

> 注意：洪涛已确认仅个人/家庭使用，版权无顾虑。

#### 具体素材需求

**需要提取的角色**：选择蛋仔派对最经典的圆滚滚蛋仔形象（白色/粉色身体、大眼睛的默认主角形象），保持一致的角色身份。

**需要的图片清单**：

| 编号 | 文件名 | 用途 | 尺寸要求 | 说明 |
|------|--------|------|----------|------|
| 1 | `egg_idle.png` | 默认待机 | 512×512pt @1x | 正面站立、中性表情 |
| 2 | `egg_happy.png` | 开心状态 | 512×512pt @1x | 笑脸、双手举起 |
| 3 | `egg_sad.png` | 难过状态 | 512×512pt @1x | 嘴角下垂、眼泪 |
| 4 | `egg_excited.png` | 兴奋状态 | 512×512pt @1x | 星星眼、跳跃姿态 |
| 5 | `egg_levelup.png` | 升级状态 | 512×512pt @1x | 发光/胜利姿态 |
| 6 | `egg_mini.png` | 迷你形象 | 128×128pt @1x | 缩小版正面站立 |

**关于等级外观变化（Lv.1~5）**：
- 当前代码按等级改变体色、添加翅膀/光晕。换图片后有两个选择：
  - **方案 A（推荐）**：所有等级共用同一张基础图片，通过 SwiftUI overlay 添加等级特效（光圈、翅膀图标、颜色滤镜 tint）
  - **方案 B**：为每个等级准备单独图片（5×4=20 张），素材量大，不推荐
- 选择方案 A，保留部分代码绘制的特效层，叠加在官方图片之上

### 2.3 动画策略

**核心原则：静态图片 + SwiftUI 声明式动画修饰，不做逐帧动画。**

逐帧动画需要大量帧图片，制作成本高且加载开销大。SwiftUI 的声明式动画足以实现生动的效果。

| 动画效果 | 实现方式 | 说明 |
|----------|----------|------|
| 弹跳（idle bounce） | `.offset(y:)` + `.animation(.easeInOut.repeatForever)` | 沿用现有实现 |
| 眨眼 | 去掉。用静态图片的固定表情即可 | 换图片后眨眼无意义 |
| 手臂摇摆 | 去掉。图片无独立手臂 | — |
| 升级发光 | `RadialGradient` overlay + `.scaleEffect` 动画 | 保留代码绘制的光圈效果 |
| 升级旋转 | `.rotationEffect` 动画 | 保留 |
| 升级闪白 | 白色 `Circle` overlay + opacity 动画 | 保留 |
| 升级缩放 | `.scaleEffect` spring 动画 | 保留 |
| 点击抚摸 | `.scaleEffect` spring + 粒子效果 | `PettingHeartParticles` 已有，保留 |
| 等级特效 | overlay 层：Lv.3+ 翅膀图标、Lv.5 金色光晕 | 简化为图标叠加 |

**代码改动范围**：

`PetDisplayView.swift` 从 665 行重写为约 150 行：
```swift
struct PetDisplayView: View {
    let petState: PetState
    var size: CGFloat = 160
    var showDizzy: Bool = false
    var specialOutfit: String? = nil
    var isLevelingUp: Bool = false

    @State private var isBouncing = false
    // ... level-up 动画状态保留

    var body: some View {
        ZStack {
            // 升级光圈（保留代码绘制）
            if isLevelingUp { glowOverlay }

            // 主图片
            Image(moodImageName)  // 根据 mood 切换图片
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

            // 等级特效 overlay
            if petState.level >= 3 { wingsOverlay }
            if petState.level >= 5 { goldenGlowOverlay }

            // 特殊装扮 overlay
            if let outfit = specialOutfit { outfitOverlay }

            // 升级闪白
            if levelUpFlashOpacity > 0 { flashOverlay }
        }
        .offset(y: isBouncing ? -4 : 2)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
        .onAppear { isBouncing = true; ... }
    }

    private var moodImageName: String {
        switch petState.mood {
        case .happy:   return "egg_happy"
        case .sad:     return "egg_sad"
        case .excited: return "egg_excited"
        case .normal:  return "egg_idle"
        }
    }
}
```

### 2.4 资源管理

**存放位置**：`Assets.xcassets` 内新建 Image Set

```
Assets.xcassets/
├── AppIcon.appiconset/        ← 图标
├── EggPet/                    ← 新建分组
│   ├── egg_idle.imageset/     ← 默认表情
│   │   ├── egg_idle.png       (1x, 512px)
│   │   ├── egg_idle@2x.png    (2x, 1024px)
│   │   └── Contents.json
│   ├── egg_happy.imageset/
│   ├── egg_sad.imageset/
│   ├── egg_excited.imageset/
│   ├── egg_levelup.imageset/
│   └── egg_mini.imageset/
```

**命名规范**：
- 全小写 + 下划线分隔
- 前缀 `egg_` 标识蛋仔角色
- 图片用 PNG（带 alpha 通道，背景透明）

**Retina 适配**：每张图提供 @1x 和 @2x。@1x 为逻辑尺寸（如 512pt），@2x 为物理像素（1024px）。实际操作：准备一张 1024×1024 的高清源图，缩放导出即可。

### 2.5 状态映射表

| PetMood | 图片资源 | 触发场景 |
|---------|----------|----------|
| `.normal` | `egg_idle` | 默认状态 |
| `.happy` | `egg_happy` | 答题正确、被抚摸、喂食 |
| `.sad` | `egg_sad` | 连续答错、饱腹度过低 |
| `.excited` | `egg_excited` | 经验加成、双倍经验 |

| 特殊状态 | 处理方式 | 触发场景 |
|----------|----------|----------|
| `isLevelingUp=true` | 使用 `egg_idle` + 光圈/旋转/闪白 overlay | 升级瞬间 |
| `showDizzy=true` | 叠加星星 emoji overlay | 彩蛋 |
| `specialOutfit!=nil` | 叠加文字/图标 overlay | 彩蛋 |

> 不单独为 `levelingUp` 状态换图片——升级动画是短暂的（1.5s），切换图片反而会造成闪烁。用 overlay 动画更流畅。

### 2.6 涉及文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Views/PetHouse/PetDisplayView.swift` | **重写** | 从 665 行代码绘制改为图片+动画修饰 |
| `Views/Home/PetMiniView.swift` | **重写** | 从 35 行代码绘制改为 `Image("egg_mini")` |
| `Resources/Assets.xcassets/EggPet/` | **新增** | 6 个 imageset 目录 |
| `Views/Home/HomeView.swift` | **无改动** | 调用接口不变（PetDisplayView 参数签名保持一致） |
| `Views/Shop/ShopView.swift` | **无改动** | 同上 |
| `Views/PetHouse/PetHouseView.swift` | **无改动** | 同上 |

> **关键设计约束**：PetDisplayView 的公开接口（`petState`、`size`、`showDizzy`、`specialOutfit`、`isLevelingUp`）保持不变，调用方零改动。

---

## 三、需求2：桌面图标重新设计

### 3.1 设计思路

**构图方案**：
- **背景**：柔和渐变（浅粉 → 浅蓝，保持现有配色基调，与游戏整体风格一致）
- **主体**：网易蛋仔官方形象（正面、开心表情），居中放大
- **风格**：圆角矩形（macOS 标准图标形状），主体略超出图标边界营造立体感
- **文字**：不加文字。图标尺寸小，文字会糊

**设计原则**：
- 图标在小尺寸（16×16）下也要可辨识 → 蛋仔轮廓要简洁清晰
- 与 app 内 UI 风格一致 → 保持粉蓝配色系
- macOS 圆角矩形自适应 → 提供正方形源图，系统自动裁切圆角

### 3.2 尺寸清单

macOS App Icon 需要的尺寸（Apple HIG 标准）：

| 用途 | 逻辑尺寸 | @1x px | @2x px |
|------|----------|--------|--------|
| App Store | 1024×1024 | 1024 | — |
| Mac 512pt @1x | 512×512 | 512 | — |
| Mac 512pt @2x | 512×512 | 1024 | — |
| Mac 256pt @1x | 256×256 | 256 | — |
| Mac 256pt @2x | 256×256 | 512 | — |
| Mac 128pt @1x | 128×128 | 128 | — |
| Mac 128pt @2x | 128×128 | 256 | — |
| Mac 32pt @1x | 32×32 | 32 | — |
| Mac 32pt @2x | 32×32 | 64 | — |
| Mac 16pt @1x | 16×16 | 16 | — |
| Mac 16pt @2x | 16×16 | 32 | — |

**实际操作**：只需制作一张 1024×1024 的高质量源图，然后用 sips/脚本批量缩放生成所有尺寸。

### 3.3 Contents.json 配置

当前 `Contents.json` 使用 `universal` + `mac` 平台，只引用 `icon_1024x1024.png`。这是 macOS 项目的简化写法（Xcode 自动缩放），可以保持。

```json
{
  "images": [
    {
      "filename": "icon_1024x1024.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    },
    {
      "filename": "icon_1024x1024.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "512x512"
    },
    {
      "filename": "icon_1024x1024.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "512x512"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

> 保持现有 Contents.json 不变，只需替换 `icon_1024x1024.png` 这一张图片文件。

### 3.4 制作流程

1. **获取素材**：从网易官方素材中提取蛋仔正面形象（透明背景 PNG）
2. **合成图标**：
   - 工具：Python Pillow 或 macOS sips + 脚本自动化
   - 底色：粉色 → 蓝色渐变（与 app 主题色一致）
   - 主体：蛋仔形象居中，占比约 70%
   - 导出 1024×1024 PNG
3. **验证**：替换现有 `icon_1024x1024.png`，Xcode build 后检查 Finder/Dock 显示效果
4. **可选**：如果自动缩放效果不好（小尺寸糊），手工调整小尺寸图标

### 3.5 涉及文件

| 文件 | 变更 |
|------|------|
| `Resources/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png` | 替换 |
| `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | 无改动 |
| 其他尺寸 PNG 文件（icon_16x16.png 等） | 可删除（被 1024 统一引用），保留也不影响 |

---

## 四、需求3：版本号整理

### 4.1 现状

- `project.pbxproj` 中 `MARKETING_VERSION = 1.0.0`（出现 4 次，对应 Debug/Release × macOS/iOS）
- `CURRENT_PROJECT_VERSION = 1`（build number）
- Git 无任何 tag
- 实际已交付 v1.12 ~ v1.16（口头追踪，git 无记录）

### 4.2 版本号更新方案

#### MARKETING_VERSION → 1.17.0

修改 `VocabGame.xcodeproj/project.pbxproj`，将所有 4 处 `MARKETING_VERSION = 1.0.0` 改为 `MARKETING_VERSION = 1.17.0`。

同时将 `CURRENT_PROJECT_VERSION` 递增（建议改为 17，与版本号对应）。

#### Git Tag 策略

**历史版本（v1.12~v1.16）**：
- Git 历史只有 12 个 commit，commit message 未标注版本号
- 无法准确追溯哪个 commit 对应哪个版本
- **结论：不为历史版本打假 tag**。假 tag 比没有 tag 更危险——它会误导未来的代码追溯

**当前版本**：
- 在本次改动（形象替换 + 图标 + 版本号）全部完成后，在 HEAD 打 `v1.17.0` tag
- Tag 格式：`v{MAJOR}.{MINOR}.{PATCH}`（语义化版本）
- 打 tag 命令：`git tag -a v1.17.0 -m "v1.17.0: 蛋仔官方形象替换 + 图标重设计"`

#### 后续版本管理规范

| 规则 | 说明 |
|------|------|
| 版本号格式 | `v{MAJOR}.{MINOR}.{PATCH}` |
| 何时更新 MARKETING_VERSION | 每次交付给洪涛前必须更新 |
| 何时打 git tag | 交付时在对应 commit 打 tag |
| MARKETING_VERSION 存放 | `project.pbxproj`（Xcode 原生管理） |
| PATCH 递增 | Bug 修复 |
| MINOR 递增 | 功能新增 |
| MAJOR 递增 | 大版本重构 |

**交付检查清单**（加到 Luke 的流程）：
1. [ ] 确认 MARKETING_VERSION 已更新
2. [ ] 确认 git tag 已打
3. [ ] 确认 `git tag -l` 输出包含本次版本号

### 4.3 涉及文件

| 文件 | 变更 |
|------|------|
| `VocabGame.xcodeproj/project.pbxproj` | MARKETING_VERSION → 1.17.0, CURRENT_PROJECT_VERSION → 17 |

---

## 五、实施分期

### Phase 0：准备工作（Alex 方案完成后 → Vera 审查 → Luke 定稿）
- 方案审查通过
- 素材获取：Cody 从网易官网获取蛋仔形象图片

### Phase 1：素材制作 + 图标（Cody）
1. 获取网易蛋仔官方图片素材
2. 用图片编辑工具提取角色（去除背景，输出透明 PNG）
3. 制作 6 张状态图片（idle/happy/sad/excited/levelup/mini）
4. 制作 1024×1024 AppIcon
5. 放入 Assets.xcassets 对应目录

### Phase 2：代码改动（Cody）
1. 重写 `PetDisplayView.swift`（图片+动画修饰，保持公开接口不变）
2. 重写 `PetMiniView.swift`（改为 Image 引用）
3. 更新 `project.pbxproj` 版本号
4. Build 验证

### Phase 3：验证（Tina）
1. 三个调用点（HomeView/ShopView/PetHouseView）视觉确认
2. 4 种 mood 切换正常
3. 升级动画正常
4. App 图标在 Finder/Dock 正确显示
5. 版本号确认（About/Get Info 显示 1.17.0）

### Phase 4：收尾（Luke）
1. 打 git tag `v1.17.0`
2. 交付

---

## 六、风险与注意事项

| 风险 | 影响 | 应对 |
|------|------|------|
| 网易官方素材质量/角度不合适 | 图片效果不好 | 多渠道获取，B 站官方号/百度百科作为备选 |
| 透明背景提取困难 | 图片有白边 | 使用 macOS Preview 或 Python rembg 去背景 |
| 小尺寸图标辨识度低 | 16×16 看不清 | 测试后如不行，手工绘制小尺寸简化版 |
| PetDisplayView 接口变化导致编译错误 | 调用方报错 | 方案已约束接口不变，Cody 编码时严格保持 |

---

## 七、总结

三个需求的核心改动量：

| 需求 | 改动量 | 复杂度 |
|------|--------|--------|
| 蛋仔形象替换 | 重写 2 个文件（PetDisplayView + PetMiniView），新增 6 张图片 | 中 |
| 图标重设计 | 替换 1 张图片 | 低 |
| 版本号整理 | 修改 1 个文件（pbxproj），打 1 个 git tag | 低 |

整体评估：**低风险、低复杂度**，主要工作量在素材获取和图片处理。代码改动可控，因为公开接口保持不变。

---

## 七-B、需求3：多角色系统设计

### 7B.1 设计目标

将蛋仔派对多个经典角色融入背单词 app，让学习过程更有趣、更有收集动力。不是简单换皮，而是让角色选择影响学习体验。

### 7B.2 角色库设计

从蛋仔派对官方角色中选取 **8 个角色**，覆盖经典基础蛋仔和特色角色，每个角色有独特视觉 + 轻度功能差异。

#### 角色一览

| ID | 名称 | 色系 | 来源 | 人设关键词 | 解锁条件 |
|----|------|------|------|------------|----------|
| `egg_yellow` | 蛋小黄 | 🟡 黄色 | 经典基础角色 | 活泼开朗、元气满满 | 初始解锁（默认角色） |
| `egg_pink` | 蛋小粉 | 🩷 粉色 | 经典基础角色 | 温柔可爱、治愈系 | 金币购买 80 |
| `egg_blue` | 蛋小蓝 | 🔵 蓝色 | 经典基础角色 | 冷静聪明、学霸气质 | 金币购买 80 |
| `egg_green` | 蛋小绿 | 🟢 绿色 | 经典基础角色 | 自然随性、佛系 | 金币购买 80 |
| `egg_black` | 蛋小黑 | ⚫ 黑色 | 经典基础角色 | 酷酷的、反差萌 | 连续打卡 7 天 |
| `egg_red` | 蛋小红 | 🔴 红色 | 经典基础角色 | 热情勇敢、冲劲十足 | 掌握 50 个单词 |
| `devil_egg` | 魔鬼蛋 | 😈 紫黑 | 特色角色 | 有点坏但很可爱 | 完成成就「超级连击」（10 连击） |
| `bear_egg` | 仔仔熊 | 🧸 棕色 | 特色角色 | 暖暖的熊外套 | 在商店累计消费 200 金币 |

**选角理由**：
- **6 个经典蛋仔**（蛋小黄/粉/蓝/绿/黑/红）是蛋仔派对最具辨识度的角色，颜色区分明显，素材好找
- **魔鬼蛋** 和 **仔仔熊** 作为稀有角色，增加收集动力
- 8 个角色不多不少——少了缺乏收集感，多了素材获取和维护成本高

#### 每个角色需要的图片素材

每个角色需要 **5 张状态图 + 1 张迷你图**（与需求 1 的单个角色方案一致）：

| 状态 | 文件名模板 | 说明 |
|------|------------|------|
| idle | `{characterId}_idle.png` | 默认待机 |
| happy | `{characterId}_happy.png` | 开心 |
| sad | `{characterId}_sad.png` | 难过 |
| excited | `{characterId}_excited.png` | 兴奋 |
| levelup | `{characterId}_levelup.png` | 升级 |
| mini | `{characterId}_mini.png` | 迷你 |

**素材总量**：8 角色 × 6 状态 = **48 张图片**（@1x 512px + @2x 1024px）

> 这个量看着多，但实际操作是：每个角色获取 1~2 张高质量源图，然后通过表情编辑/裁切生成不同状态。同一角色的不同状态只是表情/姿势微调，工作量可控。

### 7B.3 功能加成设计

**核心决策：角色有轻度功能加成，但数值影响很小（±5%~10%），不会破坏游戏平衡。**

纯视觉收集容易腻，轻度加成让角色选择有策略感。但加成必须很轻——这是一个背单词 app，不是 RPG。

| 角色 | 加成效果 | 数值 | 设计理由 |
|------|----------|------|----------|
| 蛋小黄 | 无（默认） | — | 初始角色，不设加成 |
| 蛋小粉 | 抚摸回复加倍 | 心情恢复 ×1.5 | 温柔治愈系，多互动有回报 |
| 蛋小蓝 | 经验加成 | 经验 +10% | 学霸气质，帮用户更快升级 |
| 蛋小绿 | 饱腹度下降减慢 | 衰减速度 ×0.8 | 佛系不饿，减少喂食频率 |
| 蛋小黑 | 连击保护 | 答错一次不中断连击计数（每局 1 次） | 酷酷的反差萌，给用户一次容错 |
| 蛋小红 | 限时挑战加时 | 每日挑战 +5 秒 | 勇敢冲劲，给更多时间 |
| 魔鬼蛋 | 金币加成 | 金币奖励 +15% | 有点坏，但帮你赚钱 |
| 仔仔熊 | 饱腹度恢复加成 | 食物饱腹度 +20% | 暖暖的，吃得更饱 |

**加成实现位置**：在 `PetState` 的 `expMultiplier` 和金币计算逻辑中增加条件判断，改动量很小。

### 7B.4 获取/解锁机制

| 解锁类型 | 角色示例 | 说明 |
|----------|----------|------|
| **初始解锁** | 蛋小黄 | 新用户默认获得 |
| **金币购买** | 蛋小粉、蛋小蓝、蛋小绿 | 商店新增「角色」分类，价格 80 金币 |
| **打卡成就** | 蛋小黑（7 天连续打卡） | 利用现有 streak 系统 |
| **学习成就** | 蛋小红（掌握 50 词） | 利用现有 PlayerProfile.totalWordsLearned |
| **特殊成就** | 魔鬼蛋（10 连击） | 利用现有成就系统 |
| **消费成就** | 仔仔熊（累计消费 200 金币） | 新增消费追踪字段 |

**商店扩展**：在现有 ShopCategory 中新增 `.character` 分类

```swift
enum ShopCategory: String, Codable, CaseIterable {
    case food = "食物"
    case hat = "帽子"
    case accessory = "服装"
    case scene = "场景"
    case effect = "特效"
    case character = "角色"    // 新增
}
```

### 7B.5 角色切换 UI

在 **宠物屋（PetHouseView）** 新增角色切换入口：

1. PetHouseView 顶部新增「切换角色」按钮
2. 点击弹出角色选择面板（sheet），展示所有角色卡片
3. 每张卡片显示：角色图片、名称、加成效果、解锁状态
4. 未解锁角色灰色遮罩 + 解锁条件文字
5. 已解锁角色点击即可切换为当前伙伴
6. 选中的角色在 PetDisplayView 中显示

### 7B.6 数据模型

#### 新增模型：`EggCharacter`

```swift
/// 蛋仔角色定义
struct EggCharacter: Identifiable, Codable, Equatable {
    let id: String          // "egg_yellow", "egg_pink", ...
    let name: String        // "蛋小黄", "蛋小粉", ...
    let colorTheme: String  // 主题色 hex
    let bonus: CharacterBonus
    let unlockType: UnlockType
    let unlockRequirement: Int  // 对应解锁条件的阈值
    let price: Int?         // 金币购买类角色的价格，其他为 nil

    /// 角色图片资源名前缀
    var imagePrefix: String { id }

    /// 根据 mood 返回对应图片资源名
    func imageName(for mood: PetMood) -> String {
        "\(id)_\(mood.rawValue)"
    }
}

enum CharacterBonus: String, Codable {
    case none              // 蛋小黄
    case moodHealBoost     // 蛋小粉：抚摸心情恢复加倍
    case expBoost10        // 蛋小蓝：经验+10%
    case satietySlowDecay  // 蛋小绿：饱腹度下降减慢
    case comboProtection   // 蛋小黑：连击保护
    case extraTime         // 蛋小红：限时挑战+5秒
    case coinBoost15       // 魔鬼蛋：金币+15%
    case foodSatietyBoost  // 仔仔熊：食物饱腹度+20%
}

enum UnlockType: String, Codable {
    case initial           // 初始解锁
    case coinPurchase      // 金币购买
    case streak            // 连续打卡天数
    case wordsLearned      // 掌握单词数
    case achievement       // 成就解锁
    case totalSpent        // 累计消费金币
}
```

#### 修改模型：`PetState`

```swift
struct PetState: Codable {
    // ... 现有字段保留 ...

    // v1.17 新增：角色系统
    var currentCharacterId: String = "egg_yellow"    // 当前使用角色
    var ownedCharacterIds: Set<String> = ["egg_yellow"] // 已解锁角色
}
```

#### 新增静态角色目录

```swift
extension EggCharacter {
    static let catalog: [EggCharacter] = [
        EggCharacter(id: "egg_yellow", name: "蛋小黄", colorTheme: "FFD700",
                     bonus: .none, unlockType: .initial, unlockRequirement: 0, price: nil),
        EggCharacter(id: "egg_pink", name: "蛋小粉", colorTheme: "FF9DC4",
                     bonus: .moodHealBoost, unlockType: .coinPurchase, unlockRequirement: 0, price: 80),
        EggCharacter(id: "egg_blue", name: "蛋小蓝", colorTheme: "4ECDC4",
                     bonus: .expBoost10, unlockType: .coinPurchase, unlockRequirement: 0, price: 80),
        EggCharacter(id: "egg_green", name: "蛋小绿", colorTheme: "7EDCD5",
                     bonus: .satietySlowDecay, unlockType: .coinPurchase, unlockRequirement: 0, price: 80),
        EggCharacter(id: "egg_black", name: "蛋小黑", colorTheme: "2C2C2C",
                     bonus: .comboProtection, unlockType: .streak, unlockRequirement: 7, price: nil),
        EggCharacter(id: "egg_red", name: "蛋小红", colorTheme: "FF4444",
                     bonus: .extraTime, unlockType: .wordsLearned, unlockRequirement: 50, price: nil),
        EggCharacter(id: "devil_egg", name: "魔鬼蛋", colorTheme: "6B3FA0",
                     bonus: .coinBoost15, unlockType: .achievement, unlockRequirement: 0, price: nil),
        EggCharacter(id: "bear_egg", name: "仔仔熊", colorTheme: "8B5E3C",
                     bonus: .foodSatietyBoost, unlockType: .totalSpent, unlockRequirement: 200, price: nil),
    ]

    static func character(by id: String) -> EggCharacter? {
        catalog.first { $0.id == id }
    }
}
```

#### 修改 PlayerProfile

```swift
struct PlayerProfile: Codable {
    // ... 现有字段保留 ...

    // v1.17 新增：累计消费金币追踪（用于仔仔熊解锁）
    var totalCoinsSpent: Int = 0
}
```

### 7B.7 PetDisplayView 适配

PetDisplayView 的接口需要小幅扩展以支持多角色：

```swift
struct PetDisplayView: View {
    let petState: PetState
    var size: CGFloat = 160
    var showDizzy: Bool = false
    var specialOutfit: String? = nil
    var isLevelingUp: Bool = false

    // v1.17: 通过 petState.currentCharacterId 自动选择角色图片
    // 接口签名不变！调用方无需修改

    private var character: EggCharacter {
        EggCharacter.character(by: petState.currentCharacterId) ?? .catalog[0]
    }

    private var moodImageName: String {
        character.imageName(for: petState.mood)
    }
}
```

**关键**：`currentCharacterId` 存在 `PetState` 中，PetDisplayView 已经接收 `petState` 参数，所以 **调用方接口完全不变**。HomeView、ShopView、PetHouseView 无需任何修改。

### 7B.8 加成效果接入点

| 加成 | 接入位置 | 改动 |
|------|----------|------|
| expBoost10 | `PetState.addExp()` | 判断 `currentCharacterId == "egg_blue"` 时额外 ×1.1 |
| moodHealBoost | 抚摸逻辑 | `PetHouseViewModel` 中抚摸后心情恢复 ×1.5 |
| satietySlowDecay | `PetState.decaySatiety()` | 判断 `egg_green` 时衰减速度 ×0.8 |
| comboProtection | 答题逻辑 | 连击中断时判断 `egg_black`，允许 1 次豁免 |
| extraTime | 每日挑战 | 挑战开始时判断 `egg_red`，总时间 +5s |
| coinBoost15 | 金币结算 | 答题/挑战完成后金币 ×1.15 |
| foodSatietyBoost | 喂食逻辑 | 食物饱腹度恢复 ×1.2 |

### 7B.9 角色解锁检查逻辑

在 App 启动或关键操作后，检查是否有新角色可解锁：

```swift
func checkCharacterUnlocks(profile: PlayerProfile, petState: PetState, achievements: [Achievement]) -> [String] {
    var newlyUnlocked: [String] = []
    for character in EggCharacter.catalog {
        guard !petState.ownedCharacterIds.contains(character.id) else { continue }
        if isUnlocked(character: character, profile: profile, petState: petState, achievements: achievements) {
            newlyUnlocked.append(character.id)
        }
    }
    return newlyUnlocked
}

func isUnlocked(character: EggCharacter, profile: PlayerProfile, petState: PetState, achievements: [Achievement]) -> Bool {
    switch character.unlockType {
    case .initial: return true
    case .coinPurchase: return false // 通过商店购买
    case .streak: return profile.currentStreak >= character.unlockRequirement
    case .wordsLearned: return profile.totalWordsLearned >= character.unlockRequirement
    case .achievement:
        // 魔鬼蛋 → 需要完成 "超级连击" 成就
        return achievements.first { $0.id == "combo_10" }?.isUnlocked == true
    case .totalSpent: return profile.totalCoinsSpent >= character.unlockRequirement
    }
}
```

### 7B.10 资源目录结构

```
Assets.xcassets/
├── AppIcon.appiconset/
├── EggCharacters/                    ← 新建分组
│   ├── egg_yellow_idle.imageset/
│   ├── egg_yellow_happy.imageset/
│   ├── egg_yellow_sad.imageset/
│   ├── egg_yellow_excited.imageset/
│   ├── egg_yellow_levelup.imageset/
│   ├── egg_yellow_mini.imageset/
│   ├── egg_pink_idle.imageset/
│   ├── ... (每个角色 6 个 imageset)
│   └── bear_egg_mini.imageset/
```

### 7B.11 涉及文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Models/EggCharacter.swift` | **新增** | 角色定义、目录、解锁逻辑 |
| `Models/PetState.swift` | **修改** | 新增 `currentCharacterId`、`ownedCharacterIds` |
| `Models/PlayerProfile.swift` | **修改** | 新增 `totalCoinsSpent` |
| `ViewModels/ShopViewModel.swift` | **修改** | 新增 `.character` 分类，角色商品 |
| `Views/Shop/ShopView.swift` | **修改** | 支持角色类商品展示 |
| `Views/PetHouse/PetDisplayView.swift` | **重写** | 多角色图片支持 |
| `Views/PetHouse/PetHouseView.swift` | **修改** | 新增角色切换入口 |
| `Views/PetHouse/CharacterSelectView.swift` | **新增** | 角色选择面板 |
| `Resources/Assets.xcassets/EggCharacters/` | **新增** | 48 个 imageset |
| 各加成接入点（答题、喂食、金币等） | **小幅修改** | 条件判断 |

### 7B.12 与需求 1 的关系

需求 1（形象替换）是需求 3（多角色系统）的子集。实现多角色系统时，PetDisplayView 的重写自然覆盖了形象替换的需求。

**优先级**：
1. 先完成 EggCharacter 模型和 PetDisplayView 重写（需求 1 + 3 共用）
2. 再扩展商店和角色选择 UI
3. 最后接入加成效果

---

## 八、实施分期（更新版）

### Phase 0：准备工作
- 方案审查（Vera）→ 修改（Alex）→ 定稿（Luke）
- 素材获取：Cody 从网易官网获取蛋仔角色图片

### Phase 1：素材制作 + 图标（Cody）
1. 获取网易蛋仔官方图片素材（至少 6 个基础蛋仔 + 2 个特色角色）
2. 用图片编辑工具提取角色（去除背景，输出透明 PNG）
3. 为每个角色制作 5 张状态图 + 1 张迷你图（共 48 张 @1x + @2x）
4. 制作 1024×1024 AppIcon（基于蛋小黄）
5. 放入 Assets.xcassets 对应目录

### Phase 2：模型 + 核心代码（Cody）
1. 新增 `EggCharacter.swift` 模型
2. 修改 `PetState`、`PlayerProfile` 新增字段
3. 重写 `PetDisplayView`（多角色图片 + 动画修饰）
4. 修改 `ShopViewModel` 支持角色商品
5. 新增 `CharacterSelectView`
6. 更新 `project.pbxproj` 版本号
7. Build 验证

### Phase 3：功能加成接入（Cody）
1. 接入 7 种角色加成效果
2. 实现角色解锁检查逻辑
3. 新增 `totalCoinsSpent` 追踪
4. ShopView 新增角色分类

### Phase 4：验证（Tina）
1. 角色切换正常（8 个角色均可显示）
2. 4 种 mood × 8 角色图片正确
3. 商店角色购买流程
4. 成就/打卡解锁角色
5. 加成效果验证（经验、金币、连击保护等）
6. 升级动画正常（所有角色）
7. App 图标正确
8. 版本号确认（1.17.0）
9. 数据迁移验证（已有用户 PetState 新字段默认值正确）

### Phase 5：收尾（Luke）
1. 打 git tag `v1.17.0`
2. 交付

---

## 九、风险与注意事项（更新版）

| 风险 | 影响 | 应对 |
|------|------|------|
| 网易官方素材质量/角度不合适 | 图片效果不好 | 多渠道获取，B 站官方号/百度百科作为备选 |
| 48 张图片制作量大 | 工期拉长 | 基础蛋仔间差异小（只换颜色），可用批量调色处理 |
| 透明背景提取困难 | 图片有白边 | 使用 macOS Preview 或 Python rembg 去背景 |
| 小尺寸图标辨识度低 | 16×16 看不清 | 测试后如不行，手工绘制小尺寸简化版 |
| PetDisplayView 接口变化导致编译错误 | 调用方报错 | currentCharacterId 走 PetState，接口签名不变 |
| 数据迁移 | 已有用户数据缺少新字段 | Codable 新字段都有默认值，安全 |
| 加成效果影响游戏平衡 | 太强破坏体验 | 所有加成 ≤15%，且互相不叠加 |
| 角色素材与学习场景不符 | 出戏 | 选取的都是蛋仔本体（圆滚滚），风格统一 |

---

## 十、总结（更新版）

四个需求的核心改动量：

| 需求 | 改动量 | 复杂度 |
|------|--------|--------|
| 蛋仔形象替换 | 重写 PetDisplayView | 中 |
| 图标重设计 | 替换 1 张图片 | 低 |
| **多角色系统** | **新增模型 + 48 张图片 + 商店扩展 + UI + 加成逻辑** | **高** |
| 版本号整理 | 修改 pbxproj + git tag | 低 |

整体评估：**需求 3（多角色系统）是 v1.17 的主要工作量**。素材制作（48 张图片）和功能接入（加成 + 商店 + 解锁）是两个大头。建议分期交付：

- **v1.17.0**：角色素材 + PetDisplayView 多角色支持 + 角色选择 UI + 商店角色分类（纯视觉收集）
- **v1.17.1**：功能加成效果接入（如果 v1.17.0 工期紧张）

这样可以先把核心体验（官方形象 + 多角色选择）交付出去，加成作为锦上添花跟上。
