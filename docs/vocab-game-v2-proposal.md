# VocabGame V2 — 全面改进方案

> 作者：Alex（架构师） | 目标用户：初二女生 | 风格参考：网易蛋仔派对
> 日期：2025-07-14

---

## 一、现状分析

### 已有能力（Phase 1）
- 25 关线性关卡 + 每日挑战 + 拼写 + 配对 + 错词复习
- 蛋仔宠物系统（SwiftUI 绘制，5 级形态变化）
- 金币商店（装饰品购买/装备）
- 星级评分 + combo + 间隔重复（简化 SM-2）
- 音效/TTS/背景音乐框架
- macOS + iOS 双平台

### 核心问题

| 维度 | 问题 |
|------|------|
| **UI** | 蛋仔形象过于简陋（圆形+圆点眼+方嘴），远不及蛋仔派对的圆润 Q 萌感；配色偏单一，缺乏层次和氛围；关卡地图是纯列表，没有地图探索感 |
| **功能** | 商品种类少（仅帽子/眼镜/围巾/蝴蝶结/披风 5 类 emoji）；宠物互动只有看和买装饰，没有喂养/抚摸/对话；缺乏社交/竞技维度的长期留存机制 |
| **易用性** | 首页 QuickAction 卡片排列过密，信息层级不清晰；答题界面反馈动画单调（只是文字变色）；新用户引导 4 页纯文字+emoji，缺乏吸引力 |
| **趣味性** | 游戏模式本质都围绕"看题→选/写"，缺乏真正不同的游戏体验；combo 系统没有视觉反馈（只看数字涨）；蛋仔养成的成长感和互动感弱 |

---

## 二、改进方案总览

分 4 个 Phase 交付，按优先级排列：

| Phase | 重点 | 预估工时 |
|-------|------|----------|
| **Phase 1** | 蛋仔形象重设计 + UI 视觉升级 + App 图标 | 4 天 |
| **Phase 2** | 功能增强（宠物互动 + 新游戏模式 + 商店扩充） | 4 天 |
| **Phase 3** | 操作易用性 + 动效反馈 + 引导体验 | 2 天 |
| **Phase 4** | 趣味性 + 留存机制（成就系统 + 主题皮肤 + 蛋仔对话） | 3 天 |
| **Phase 5** | 全量回归测试 + 修复 | 1-2 天 |
| **总计** | | **14-15 天** |

---

## 三、Phase 1 — 蛋仔形象重设计 + UI 视觉升级

### 3.1 蛋仔形象设计规范

**目标**：从"程序员画的圆圈"升级为"蛋仔派对风格 Q 萌角色"。

#### 设计原则（参考蛋仔派对）
- **圆润**：所有形状使用大圆角/椭圆，不允许出现尖角
- **大眼睛**：眼睛占头部比例 40%+，带高光点（两个白色圆点）
- **Q 萌表情**：嘴巴小而圆润（微笑/惊讶/开心），配合腮红
- **色彩鲜明**：饱和度高，渐变柔和，每个等级一个主题色带渐变
- **有手脚**：短小圆润的手臂和腿（蛋仔派对风格，不只是一个蛋）

#### 各等级蛋仔设计

| 等级 | 名称 | 主色 | 特征 | 描述 |
|------|------|------|------|------|
| Lv.1 | 蛋蛋 | 🩷 粉色渐变 `#FF9DC4→#FF6B9D` | 圆滚滚身体、大圆眼、小短手、微微摇晃 | 初始形态，Q 萌入门 |
| Lv.2 | 花蛋 | 🧡 橙色渐变 `#FFB347→#FF8C42` | 头顶冒出小芽、脸颊腮红加深 | 开始成长 |
| Lv.3 | 水蛋 | 💚 青绿渐变 `#7EDCD5→#4ECDC4` | 身上出现水波纹、小翅膀萌芽 | 神秘力量 |
| Lv.4 | 星蛋 | 💜 紫色渐变 `#C4A8FF→#A78BFA` | 长出小翅膀、头顶星星光环 | 接近进化 |
| Lv.5 | 龙蛋 | 🌟 金色渐变 `#FFE66D→#FFD700` | 金色皇冠、完整翅膀、光环、粒子特效 | 终极形态 |

#### SwiftUI 绘制方案

```
PetDisplayView 重写为分层绘制：
├── 背景光晕（Lv.5 金色光环 + 粒子）
├── 身体（Ellipse + 渐变填充 + 高光叠加层）
├── 脸部
│   ├── 眼睛（白色椭圆 + 瞳孔 + 双高光点 + 眨眼动画）
│   ├── 嘴巴（根据 mood 切换形状：微笑弧线/张嘴/嘟嘴）
│   └── 腮红（粉色半透明圆形 ×2）
├── 四肢（短圆手臂 ×2，短腿 ×2，带 idle 摇摆动画）
├── 等级特征（小芽/翅膀/皇冠等，各等级不同）
└── 装饰品覆盖层（帽子/眼镜/围巾等）
```

**关键动画**：
- Idle：身体微微上下弹跳（1.5s 循环）+ 手臂轻微摇摆
- 眨眼：每 3-4 秒眨一次，持续 0.15s
- 答对时：跳跃 + 转圈 + 开心表情（嘴巴变大）
- 答错时：身体扁一下 + 难过表情（嘴巴变下弯）+ 摇头
- 升级时：发光 + 旋转 + 粒子爆炸 + 形态变化过渡

### 3.2 App 图标设计

**风格**：蛋仔派对风 — 圆润蛋形主角 + 鲜明渐变背景 + 星星/金币元素

- 主体：Lv.3 水蛋（青绿色），微笑表情，手持一本书
- 背景：渐变 `#FF6B9D→#FFD93D`（粉→黄对角渐变）
- 装饰：右上角 3 颗星星、左下角散落金币
- 文字：无（纯图形图标，Apple 推荐）
- 尺寸：生成 1024×1024 主图，用脚本切片出所有尺寸
- 输出：`AppIcon.appiconset/` 完整目录

### 3.3 配色系统升级

当前配色问题：颜色定义较单一，缺少氛围感和层次。

```swift
// 新增配色
enum VGColors {
    // 现有保持
    static let primary = Color(hex: "FF6B9D")      // 糖果粉
    static let secondary = Color(hex: "FFD93D")     // 明黄
    static let success = Color(hex: "6BCB77")       // 清新绿
    static let error = Color(hex: "FF6B6B")         // 柔红
    
    // 新增
    static let accent = Color(hex: "4ECDC4")        // 薄荷青
    static let purple = Color(hex: "A78BFA")        // 梦幻紫
    static let peach = Color(hex: "FFB5A7")         // 蜜桃色
    static let lavender = Color(hex: "E8DAEF")      // 薰衣草
    
    // 卡片/背景升级
    static let cardShadow = Color(hex: "000000").opacity(0.06)
    static let background = Color(hex: "FFF5F9")    // 保持
    static let card = Color.white
}

// 新增渐变
enum VGGradients {
    // 现有保持
    // 新增
    static let sunset = LinearGradient(...)    // 落日橙粉
    static let ocean = LinearGradient(...)     // 海洋青蓝
    static let candy = LinearGradient(...)     // 糖果彩虹
}
```

### 3.4 首页重设计

**当前**：ScrollView 内纵向排列文字+卡片，信息密度高但视觉单调。

**新首页布局**：

```
┌─────────────────────────────────┐
│  👋 下午好！                    │  ← 个性化问候（大字）
│  ⭐ 42 · 🔥 7天 · 📚 120词     │  ← 数据条（横向滚动标签）
├─────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐      │
│  │  蛋仔   │  │ 每日    │      │  ← 双列卡片
│  │  (大图) │  │ 挑战 ✨ │      │
│  │ Lv.3   │  │ 已完成 ✓ │      │
│  └─────────┘  └─────────┘      │
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │ ▶ 继续上次：第12关      │   │  ← 主 CTA（大按钮）
│  └─────────────────────────┘   │
├─────────────────────────────────┤
│  快捷入口（横向滚动）           │
│  [拼写挑战] [配对消消乐] [错词] │  ← 圆角图标按钮
├─────────────────────────────────┤
│  今日目标进度条                 │  ← 新增：每日目标
│  ████████░░ 8/10 词            │
└─────────────────────────────────┘
```

**关键改动**：
1. 蛋仔从右上角小图 → 左侧大卡片，有弹跳动画
2. 主 CTA 放大突出（"继续上次"或"开始闯关"）
3. 快捷入口改为横向滚动图标卡片
4. 新增"今日目标"进度条（每天背 10 个新词）

### 3.5 关卡地图升级

**当前**：S 形网格布局 + 简单 Path 连线，缺乏地图探索感。

**新关卡地图**：

```
设计方向：蛋仔派对闯关地图风格
- 每个关卡节点设计为可爱的"岛屿/云朵"形状
- 节点间用虚线/星星路径连接（非直线 Path）
- 当前关卡有脉冲光圈动画
- 已通过关卡显示获得的星星数（金色动画）
- 未解锁关卡显示为灰色 + 锁图标
- 背景从浅蓝渐变到不同颜色（随进度变化）

交互：
- 可滚动/缩放的地图视图
- 点击节点弹出关卡信息（名字 + 单词数 + 最佳成绩）
- 解锁新关卡时播放过场动画（蛋仔跳到新节点）
```

---

## 四、Phase 2 — 功能增强

### 4.1 宠物互动系统

#### 4.1.1 互动动作

| 动作 | 触发 | 效果 | 冷却 |
|------|------|------|------|
| **抚摸** | 点击/滑动蛋仔身体 | 蛋仔眯眼微笑 + 爱心粒子 + 经验+5 | 30s |
| **喂食** | 点击"喂食"按钮 | 蛋仔张嘴吃东西动画 + 饱腹度+20 | 2h |
| **玩耍** | 点击"玩耍"按钮 | 蛋仔跳绳/翻滚动画 + 心情变 happy | 4h |
| **对话** | 点击对话气泡 | 蛋仔说一句鼓励语 + 随机单词小贴士 | 无 |

#### 4.1.2 饱腹度系统

```swift
struct PetState: Codable {
    // 现有字段...
    var satiety: Int = 100          // 饱腹度 0-100
    var lastFedTime: Date = Date()  // 上次喂食时间
    var interactionCount: Int = 0   // 今日互动次数
    
    /// 饱腹度每小时自然下降 5 点
    /// 饱腹度 < 30：蛋仔表情变饿（嘴巴下弯 + 肚子叫动画）
    /// 饱腹度 = 0：不惩罚，只是没有食物加成
    /// 饱腹度 > 50：经验 +20% 加成（正向激励）
}
```

#### 4.1.3 食物系统

用金币购买食物来喂养蛋仔：

| 食物 | 价格 | 饱腹度 | 额外效果 |
|------|------|--------|----------|
| 小饼干 | 5 | +15 | 无 |
| 蛋糕 | 15 | +30 | 心情变 happy |
| 彩虹冰淇淋 | 30 | +50 | 经验 +20 |
| 星星糖果 | 50 | +80 | 下次答题双倍经验（1局） |

#### 4.1.4 蛋仔对话系统

蛋仔会根据不同场景说不同的话（气泡对话框显示）：

```swift
enum PetDialogue {
    case greeting        // 打开 App 时
    case preGame         // 进入游戏前
    case postGameGood    // 成绩好
    case postGameBad     // 成绩差
    case idle            // 长时间未操作
    case hungry          // 饱腹度低
    case levelUp         // 升级
    case streak          // 连续打卡
}

// 示例对话（每种场景 5-8 条随机）
greeting: ["今天也要加油哦~", "蛋仔等你好久啦！", "准备好了吗？"]
postGameGood: ["太厉害了！蛋仔好崇拜你！", "满分！蛋仔要向你学习！"]
postGameBad: ["没关系，下次一定行！", "蛋仔陪你一起努力~"]
hungry: ["咕噜咕噜...蛋仔饿了", "想吃饼干..."]
```

### 4.2 新游戏模式 — 听写模式

**区别于现有拼写**：播放发音 → 用户听写，不看释义。

```
流程：
1. 播放单词发音（自动播放 2 遍）
2. 用户在输入框拼写
3. 可花 5 金币"再听一次"
4. 可花 10 金币"显示首字母提示"
5. 提交后显示正确答案 + 释义

计分：
- 首次拼对：150 分（比普通拼写高）
- 用提示后拼对：100 分
- 拼错：0 分

每局 10 个词，从已学但未掌握的词中抽取。
```

### 4.3 新游戏模式 — 单词跑酷

**参考**：打字类跑酷游戏，但换成单词。

```
玩法：
- 屏幕从上方不断落下"单词云"（显示英文）
- 底部有 3 条跑道，显示 3 个不同中文释义
- 用户点击对应跑道接住正确释义的单词
- 接对得分 + combo，接错扣命（3 条命）
- 速度随时间加快
- 持续 60 秒

技术方案：
- 使用 SwiftUI TimelineView + @State 管理动画帧
- 单词下落用 offset 动画
- 碰撞检测用 Y 坐标判断

收益：金币按得分比例，经验固定 +30
```

### 4.4 商店扩充

#### 4.4.1 新商品分类

| 分类 | 商品 | 价格 | 效果 |
|------|------|------|------|
| **食物** | 小饼干/蛋糕/冰淇淋/星星糖果 | 5-50 | 饱腹度 + 特效 |
| **帽子** | 王冠/厨师帽/猫咪耳朵/宇航员头盔 | 20-100 | 外观装饰 |
| **服装** | 斗篷/围裙/超人装/公主裙 | 50-150 | 外观装饰 |
| **场景** | 花园/海滩/星空/城堡 | 100-200 | 蛋仔之家背景 |
| **特效** | 彩虹尾迹/爱心泡泡/星星光环 | 80-120 | 移动/待机粒子特效 |

#### 4.4.2 商品展示方式

商品从现在的列表 → 改为卡片网格 + 分类 Tab + 蛋仔实时预览：

```
┌──────────────────────────────┐
│  🍪食物  🎩帽子  👗服装  🏠场景  │  ← 分类 Tab
├──────────────────────────────┤
│  ┌────────┐  ┌────────┐     │
│  │ 🎂     │  │ 👨‍🍳    │     │  ← 商品卡片
│  │ 蛋糕   │  │ 厨师帽 │     │
│  │ 15 币  │  │ 30 币  │     │
│  └────────┘  └────────┘     │
├──────────────────────────────┤
│       [蛋仔实时预览]         │  ← 装备后即时看到效果
└──────────────────────────────┘
```

### 4.5 数据模型变更

```swift
// 新增模型

struct Food: Identifiable, Codable {
    let id: String        // "cookie", "cake", "icecream", "starcandy"
    let name: String
    let price: Int
    let satiety: Int      // 饱腹度恢复
    let effect: FoodEffect?
}

enum FoodEffect: String, Codable {
    case none             // 无额外效果
    case happyMood        // 心情变 happy
    case expBoost20       // 经验 +20
    case doubleExp        // 下局双倍经验
}

struct ShopItem: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Int
    let category: ShopCategory  // 新增分类字段
    // ...
}

enum ShopCategory: String, Codable, CaseIterable {
    case food = "食物"
    case hat = "帽子"
    case clothing = "服装"
    case scene = "场景"
    case effect = "特效"
}

// PetState 扩展
struct PetState: Codable {
    // 现有...
    var satiety: Int = 100
    var lastFedTime: Date = Date()
    var lastPlayTime: Date? = nil
    var interactionCount: Int = 0
    var ownedFoods: [String] = []          // 拥有的食物 ID
    var ownedScenes: [String] = []         // 拥有的场景 ID
    var currentScene: String? = nil        // 当前场景
    var ownedEffects: [String] = []        // 拥有的特效 ID
    var currentEffect: String? = nil       // 当前特效
}
```

---

## 五、Phase 3 — 操作易用性 + 动效反馈

### 5.1 答题反馈动画升级

**当前**：选项背景色变化 + 文字提示，过于单调。

**新反馈系统**：

#### 答对时
1. 选项卡片：正确选项弹跳放大 → 绿色 + ✓ 图标
2. 蛋仔动画：在屏幕角落（小型），跳跃 + 开心表情 + 爱心粒子
3. Combo 数字：≥3x 时数字放大弹跳 + "Nice!"/"Amazing!"/"Perfect!" 文字飘过
4. 分数：飘字 "+100" 从答题区飞向顶部分数栏
5. 音效：清脆叮咚声（combo 越高音调越高）

#### 答错时
1. 选项卡片：选错项抖动 + 红色，正确项闪烁 2 次绿色
2. 蛋仔动画：角落的蛋仔扁一下 + 难过表情
3. 文字："正确答案" 用更友好的方式显示（不要只显示红色文字）
4. 音效：轻微的 "boing" 声（不要太刺耳，保护用户情绪）

#### 连击反馈
```
3x combo  → "Nice!" 金色文字
5x combo  → "Amazing!" + 屏幕轻微震动
8x combo  → "Perfect!" + 全屏金色粒子
10x combo → "Legendary!" + 蛋仔从角落跳到屏幕中央庆祝
```

### 5.2 新手引导重设计

**当前**：4 页纯文字 + emoji 的滑动引导页。

**新引导**：

```
第 1 页：蛋仔从蛋中破壳动画（3 秒）
  → 蛋仔："嗨！我是你的学习伙伴蛋仔~"
  
第 2 页：蛋仔带用户完成第 1 道题（交互式教程）
  → 展示一个示例单词，高亮正确选项引导点击
  → 蛋仔："答对了！就是这样~"
  
第 3 页：展示蛋仔之家
  → 蛋仔："这是我们的家，快来一起学习吧！"
  
第 4 页：直接开始第 1 关
  → "准备好了吗？开始冒险！"（大按钮）
```

**核心改变**：从"被动阅读"→"主动体验"，让用户在引导中就完成第一道题。

### 5.3 操作体验优化

| 优化项 | 当前 | 改进 |
|--------|------|------|
| 选项点击 | 点按 | 支持 swipe 左右快速选择（2 选项时） |
| 拼写输入 | TextField + 手动提交 | 回车键自动提交 + 自动聚焦 |
| 关卡选择 | 列表 | 地图节点（3.5 节已述） |
| 结果页 | 静态展示 | 动态分数滚动 + 星星逐个点亮动画 |
| Tab 切换 | 系统默认 TabView | 自定义 TabBar（圆角 + 图标动画） |
| 返回操作 | 左上角 X 按钮 | 支持 iOS 左滑手势返回 |

---

## 六、Phase 4 — 趣味性 + 留存机制

### 6.1 成就系统

```swift
struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String           // emoji 或 SF Symbol
    let category: AchievementCategory
    let requirement: Int       // 达成阈值
    let reward: Int            // 金币奖励
    var isUnlocked: Bool
    var unlockedAt: Date?
}

enum AchievementCategory: String, CaseIterable {
    case learning = "学习"     // 学完 X 个单词
    case streak = "坚持"       // 连续打卡 X 天
    case combo = "连击"        // 达成 X 连击
    case pet = "蛋仔"          // 蛋仔升到 X 级
    case game = "游戏"         // 完成 X 局游戏
    case collection = "收集"   // 收集 X 件装饰
}
```

**成就示例**：

| ID | 名称 | 条件 | 奖励 |
|----|------|------|------|
| first_word | 第一个单词 | 学完 1 个词 | 10 |
| word_master_50 | 词汇达人 | 掌握 50 个词 | 50 |
| streak_7 | 坚持一周 | 连续 7 天 | 30 |
| combo_10 | 超级连击 | 10 连击 | 20 |
| pet_max | 满级蛋仔 | 蛋仔升到 Lv.5 | 100 |
| collector_10 | 收藏家 | 拥有 10 件商品 | 50 |
| speed_demon | 速度之星 | 配对游戏 30s 内完成 | 40 |

**成就展示**：
- "我的"页面新增"成就墙"入口
- 成就墙用网格展示所有成就（已解锁/未解锁）
- 解锁新成就时：全屏弹窗 + 蛋仔庆祝动画 + 金币雨

### 6.2 每日目标系统

```swift
struct DailyGoal: Codable {
    var targetWords: Int = 10         // 每日目标：10 个新词
    var learnedToday: Int = 0         // 今日已学
    var isCompleted: Bool = false     // 是否完成
    var completedDate: Date? = nil    // 完成日期
    var bonus: Int = 20               // 完成奖励金币
}
```

- 首页显示"今日目标"进度条
- 完成时蛋仔跳舞 + 金币奖励 + 连续完成有额外奖励
- 连续完成 7 天：奖励 100 金币 + 特殊头像框

### 6.3 主题皮肤系统

蛋仔之家和首页可以切换不同主题背景：

| 主题 | 解锁条件 | 效果 |
|------|----------|------|
| 默认（粉色花园） | 初始 | 粉色渐变 + 花朵装饰 |
| 海滩夏日 | 200 金币购买 | 蓝色渐变 + 波浪 + 贝壳 |
| 星空幻想 | 通过第 15 关 | 深蓝渐变 + 星星粒子 + 月亮 |
| 糖果王国 | 通过第 25 关 | 彩虹渐变 + 糖果装饰 |
| 蛋仔派对 | 成就"收藏家"解锁 | 蛋仔派对经典场景 |

### 6.4 惊喜彩蛋

- 在特定日期（生日/节假日）蛋仔会穿特殊服装
- 连续答对 20 题触发隐藏的"蛋仔跳舞"动画
- 在蛋仔之家快速连点蛋仔 10 次，蛋仔会晕倒（搞笑动画）

---

## 七、技术选型与数据模型

### 7.1 数据模型变更汇总

```
新增文件：
  Models/Food.swift              — 食物模型
  Models/Achievement.swift       — 成就模型  
  Models/DailyGoal.swift         — 每日目标模型
  Models/PetDialogue.swift       — 蛋仔对话数据

修改文件：
  Models/PetState.swift          — 新增饱腹度/互动/场景字段
  Models/PlayerProfile.swift     — 新增成就/目标字段
  Repositories/PetRepository.swift — 新增喂食/互动/对话逻辑
  Repositories/ProgressRepository.swift — 新增成就/目标追踪
  ViewModels/ShopViewModel.swift — 新增分类/食物/场景/特效
  ViewModels/HomeViewModel.swift — 新增每日目标/蛋仔对话
  Services/AudioService.swift    — 新增更多音效

新增 View：
  Views/Game/WordRunnerView.swift      — 单词跑酷
  Views/Game/DictationView.swift       — 听写模式
  Views/Achievement/AchievementWall.swift — 成就墙
  Views/Components/PetDialogueBubble.swift — 对话气泡
  Views/Components/ComboText.swift     — Combo 文字动效
```

### 7.2 存储方案

所有数据继续使用本地 JSON 文件持久化（与现有架构一致），不引入数据库。

```
progress.json   — 新增 achievements[], dailyGoal, petInteractionCount
pet.json        — 新增 satiety, lastFedTime, ownedFoods[], ownedScenes[], currentScene
```

向后兼容：新字段都有默认值，老数据加载不会崩溃。

### 7.3 动画性能考量

- 蛋仔绘制和动画保持使用 SwiftUI 原生动画（不引入第三方库）
- 粒子效果用 Canvas 或 TimelineView 手动绘制（保持轻量）
- 跑酷游戏的帧动画用 TimelineView + @State，不引入 SpriteKit（保持项目简洁）
- 所有动画使用 `drawingGroup()` 优化渲染

---

## 八、分期交付计划

### Phase 1（4 天）— 视觉升级 + 图标
| 天数 | 任务 |
|------|------|
| D1 | 蛋仔形象重绘（Lv.1 基础形态 + idle + 眨眼 + 表情系统）；App 图标设计 |
| D2 | 蛋仔 Lv.2-5 逐级添加特征 + 配色系统更新 |
| D3 | 首页重设计 + 关卡地图升级 |
| D4 | 蛋仔之家 UI 升级 + 视觉 QA + 交付 |

### Phase 2（4 天）— 功能增强
| 天数 | 任务 |
|------|------|
| D1 | 宠物互动系统（抚摸/喂食/饱腹度）+ 食物模型 |
| D2 | 商店扩充（分类/食物/场景/特效）+ 蛋仔对话系统 |
| D3 | 听写模式 + 单词跑酷 |
| D4 | 功能联调 + 数据兼容性测试 |

### Phase 3（2 天）— 易用性
| 天数 | 任务 |
|------|------|
| D1 | 答题反馈动画升级 + Combo 视觉效果 + 新手引导重设计 |
| D2 | 操作体验优化（TabBar/手势/结果页动画） |

### Phase 4（3 天）— 趣味性
| 天数 | 任务 |
|------|------|
| D1 | 成就系统 + 成就墙 |
| D2 | 每日目标 + 主题皮肤 |
| D3 | 彩蛋 + 蛋仔对话扩充 + 全量 QA |

### Phase 5（1-2 天）— 回归测试
| 天数 | 任务 |
|------|------|
| D1 | 全量功能回归测试 + 数据兼容性验证 |
| D2 | Bug 修复 + 最终交付 |

**总计**：14-15 个工作日

---

## 九、风险与缓解

| 风险 | 概率 | 缓解 |
|------|------|------|
| 蛋仔 SwiftUI 绘制复杂度超预期 | 中 | 先做 Lv.1 基础形态，后续等级复用+叠加特征 |
| 跑酷游戏性能不够流畅 | 低 | 使用 TimelineView + drawingGroup，必要时降低帧率 |
| 数据模型变更导致旧存档不兼容 | 低 | 所有新字段设默认值，加载时用 `decodeIfPresent` |
| 动画过多导致低端设备卡顿 | 中 | 提供"简化动画"开关（Profile 页已有设置入口模式） |
| 商品种类增加后金币通胀 | 低 | 后续可调整金币获取比例，目前先丰富内容 |

---

## 十、不做什么

以下是明确**不在本次改进范围**的事项：

1. **联网功能**：不做排行榜、好友系统、云端同步（保持纯本地）
2. **内购**：不做真实货币交易，金币纯粹通过游戏获取
3. **多语言**：保持中英双语（中文 UI + 英文学习内容）
4. **iPad 适配**：优先 iPhone，macOS 窗口保持可用即可
5. **Widget/通知**：不做桌面小组件和推送通知
6. **AI 功能**：不做 AI 出题或对话（保持确定性）

---

> 方案完毕。请 Vera 审查，有任何 P0/P1 问题我会优先修复。

---

## 审查修订记录

### v1.1 修订（Vera 第一轮审查修复）

#### P0 修复

**P0-1：成就系统改为事件驱动机制**

将散落式成就检查改为集中式事件驱动。ViewModel 只发事件，不解锁逻辑：

```swift
// Models/AchievementEvent.swift（新增）
enum AchievementEvent {
    case wordLearned(totalCount: Int)        // 学会新词（mastery 从 new→learning 或更高）
    case wordMastered(totalCount: Int)       // 掌握单词（mastery → mastered）
    case streakDay(count: Int)               // 连续打卡天数
    case comboReached(count: Int)            // 单局连击数
    case petLevelUp(level: Int)              // 蛋仔升级
    case itemCollected(totalCount: Int)      // 拥有商品总数
    case matchCompleted(remainingSeconds: Int) // 配对完成（剩余秒数）
    case levelCompleted(levelId: Int, stars: Int) // 关卡完成
    case dailyChallengeCompleted(streak: Int) // 每日挑战完成
    case gamePlayed(totalGames: Int)         // 总游戏局数
}
```

```swift
// AchievementRepository 内部
func record(_ event: AchievementEvent) {
    // 更新相关成就进度
    switch event {
    case .wordLearned(let count):
        updateProgress("first_word", to: count, unlockAt: 1)
        updateProgress("word_master_50", to: count, unlockAt: 50)
    case .comboReached(let count):
        updateProgress("combo_10", to: count, unlockAt: 10)
    case .petLevelUp(let level):
        updateProgress("pet_max", to: level, unlockAt: 5)
    case .itemCollected(let count):
        updateProgress("collector_10", to: count, unlockAt: 10)
    case .matchCompleted(let remaining):
        let elapsed = 60 - remaining
        if elapsed <= 30 { unlock("speed_demon") }
    case .streakDay(let count):
        updateProgress("streak_7", to: count, unlockAt: 7)
    default: break
    }
    save()
}
```

**ViewModel 集成方式**（改 6.1 节）：

ViewModel 中只需一行调用：
```swift
// GamePlayView.advanceToNext() 中
app.achievementRepo.record(.levelCompleted(levelId: levelId, stars: stars))
app.achievementRepo.record(.wordLearned(totalCount: progressRepo.totalWordsLearned))

// MatchGameViewModel.endGame() 中
app.achievementRepo.record(.matchCompleted(remainingSeconds: remainingSeconds))
```

**解锁定时检查**：由 AchievementRepository 内部统一处理，新增加成就只改 Repository。

---

**P0-2：饱腹度衰减的时间计算机制**

明确饱腹度衰减实现：

```swift
// PetState 新增
mutating func decaySatiety(now: Date = Date()) {
    let hoursSinceLastFed = max(0, now.timeIntervalSince(lastFedTime) / 3600)
    satiety = max(0, satiety - Int(hoursSinceLastFed) * 5)
}
```

**调用时机**：在 `PetRepository.init()` 加载完 petState 后立即调用：
```swift
// PetRepository.init()
petState.decaySatiety()
save()  // 持久化衰减后的值
```

这样确保每次打开 App 都会计算离线期间的衰减。不会变成负数（`max(0, ...)`）。

**饱腹度惩罚改为正向激励**（Vera P1 同步修复）：

原方案"饱腹度=0 经验减半"改为：
- 饱腹度 > 50：经验 +20% 加成
- 饱腹度 > 0：正常经验
- 饱腹度 = 0：正常经验（不惩罚）

这样不喂食的用户不受惩罚，喂食用户获得额外奖励。对目标用户（初二女生）更友好。

---

**P0-3：金币经济平衡分析**

#### 金币获取速率

| 来源 | 每次获取 | 频率 | 日均估计 |
|------|---------|------|----------|
| 冒险模式（10题，~70%正确率） | ~15-19 币 | 2-3 局/天 | 35-55 币 |
| 每日挑战 | 15-30 币 | 1 次/天 | 20 币 |
| 拼写/配对 | 5-15 币 | 1-2 局/天 | 15 币 |
| 成就奖励（一次性） | 10-100 币 | 不定 | 分摊 ~5 币/天 |
| 每日目标完成 | 20 币 | 1 次/天 | 20 币 |
| **日均总计** | | | **~95 币/天** |

#### 金币消费

| 类别 | 商品数 | 单价范围 | 总价 |
|------|--------|---------|------|
| 食物（消耗品） | 4 种 | 5-50 币 | 持续消费 ~20 币/天 |
| 帽子（永久） | 4 种 | 20-100 币 | 260 币 |
| 服装（永久） | 4 种 | 50-150 币 | 400 币 |
| 场景（永久） | 4 种 | 100-200 币 | 600 币 |
| 特效（永久） | 4 种 | 80-120 币 | 400 币 |
| **永久商品总价** | 16 件 | | **1660 币** |

#### 平衡分析

- 永久商品全部买齐需 ~17 天（1660 ÷ 95）
- 考虑每天食物消耗 20 币，实际需 ~22 天
- 成就奖励分摊约 300 币（降低后），实际需 ~14 天
- **结论**：2-3 周可买齐所有永久商品，节奏合理。每日食物消费形成持续金币需求。

**成就奖励调整**（总额从原 1050 币降到 ~300 币）：

| ID | 奖励（调整后） | 原奖励 |
|----|---------------|--------|
| first_word | 10 | 10 |
| word_master_50 | 30 | 50 |
| streak_7 | 20 | 30 |
| combo_10 | 15 | 20 |
| pet_max | 50 | 100 |
| collector_10 | 30 | 50 |
| speed_demon | 25 | 40 |
| **总计** | **~180** | **300** |

减少高价值成就奖励，避免早期金币泛滥。

#### P1 修复

**P1-1：听写模式复用策略**

明确：**复用 SpellChallengeViewModel**，在 SpellChallengeView 中加模式切换，不新建 ViewModel。

```swift
// SpellChallengeViewModel 新增
var isDictationMode: Bool = false  // true = 不显示释义

// SpellChallengeView 中
if !viewModel.isDictationMode {
    Text(word.meaning)  // 只在非听写模式显示释义
}
```

入口：HomeView 新增 QuickActionCard "听写挑战"，设置 `isDictationMode = true`。

**P1-2：每日目标 learnedToday 定义和数据来源**

"学了一个新词"定义：mastery 从 `new` 升级到 `learning` 或更高（首次接触）。

```swift
// ProgressRepository 新增
var dailyWordsLearned: Int = 0
var lastDailyResetDate: Date? = nil

func incrementDailyWordsLearned() {
    // 检查是否需要重置（新的一天）
    if let lastDate = lastDailyResetDate, !Calendar.current.isDateInToday(lastDate) {
        dailyWordsLearned = 0
    }
    dailyWordsLearned += 1
    lastDailyResetDate = Date()
    save()
}
```

调用点：在 `updateWordProgress()` 中检测 mastery 是否从 new 升级：
```swift
func updateWordProgress(_ wp: WordProgress) {
    let oldMastery = data.wordProgress[String(wp.wordId)]?.mastery ?? .new
    data.wordProgress[String(wp.wordId)] = wp
    if oldMastery == .new && wp.mastery.rawValue > oldMastery.rawValue {
        incrementDailyWordsLearned()
    }
    save()
}
```

**P1-3：跑酷模式性能 fallback**

原方案 TimelineView + @State 的性能确实不确定。分层策略：

1. **优先方案**：Canvas 手动绘制（不触发 body 重绘，性能更好）
2. **Fallback**：如果 Canvas 复杂度太高，降级为"简化跑酷"——同时只有 1 个单词下落，用户左右滑动选择
3. **不引入 SpriteKit**（保持项目简洁）

```swift
// WordRunnerView 使用 Canvas
Canvas { context, size in
    // 绘制下落的单词、跑道、碰撞检测等
}.gesture(DragGesture().onChanged { ... })
```

**P1-4：Phase 1 蛋仔工作量分步**

Phase 1 D1 拆分为：
- D1 上午：Lv.1 基础形态 + idle 弹跳 + 眨眼
- D1 下午：表情系统（4 种 mood）+ 答对/答错动画
- D2 上午：Lv.2-5 逐级添加特征（复用 Lv.1 基础）
- D2 下午：App 图标 + 配色系统

Lv.2-5 不需要完全不同的绘制代码，而是在 Lv.1 基础上叠加特征（小芽、翅膀、皇冠等），工作量可控。

**蛋仔纯 Shape 可行性调整**（Luke 确认的 P0）：

原方案 8 个配件全部用 Path 绘制，工作量不可控（~15-20h）。调整为**分两步**：

- **Step 1（Phase 1 范围内）**：身体/眼睛/嘴巴/腮红/等级特征用 SwiftUI Shape + 渐变重绘，配件**保留 emoji 叠加**。工作量 ~8h 可控。
- **Step 2（后续迭代）**：配件从 emoji 迁移到 Shape 绘制。每个配件 ~1h，8 个配件共 ~8h，可分散在后续 Phase 中逐步完成。

这样做的好处：
1. 蛋仔的核心形象（身体+表情）立即升级，观感大幅改善
2. emoji 配件在小尺寸下效果可接受，不阻塞其他功能
3. 降低 Phase 1 的最大风险项

具体到 3.1 节的绘制方案，"装饰品覆盖层"部分改为：
```
└── 装饰品覆盖层（Phase 1: emoji 文本；后续: Shape 绘制）
```

**P1-5：Phase 间依赖关系图**

```
Phase 1.1（蛋仔重绘）
  ├── Phase 2.1（宠物互动/进化视觉）依赖 PetBodyView
  ├── Phase 3.1（答题反馈蛋仔动画）依赖 PetBodyView
  └── Phase 4.1（成就解锁蛋仔庆祝动画）依赖 PetBodyView

Phase 1.2（首页重设计）
  └── Phase 4.2（每日目标进度条）依赖首页布局

Phase 2.3（跑酷模式）独立风险项，应与听写模式隔离
Phase 4.3（主题皮肤）独立
Phase 3.3（通知服务）本方案不做（见"不做什么"）
```

#### P2 修复

- **通知权限 fallback**：本方案明确不做通知（"不做什么"第 5 条），此条不适用
- **收藏功能 UI 入口**：收藏按钮放在 ResultView 答题详情中（依赖 1.4 完成），或作为单词卡片的长按操作
- **练习模式状态**：DailyChallengeViewModel 新增 `isPracticeMode: Bool`，alreadyCompletedView 中加"再来一局（练习）"按钮
- **图表方案**：使用 iOS 16+ SwiftCharts 框架（系统内置，无需第三方依赖），降低手绘工作量
- **整体回归测试**：Phase 4 后新增 Phase 5（1-2 天）做全量回归
- **蛋仔对话管理**：硬编码为 `static let dialogues: [PetDialogue: [String]]`，30-48 条可维护
- **ShopItem 迁移**：现有 8 件商品的 category 回填为 `.hat` / `.accessory`（围巾/蝴蝶结归入服装），新商品 ID 规范：`{category}_{name}`（如 `food_cookie`、`scene_beach`）
- **工期调整**：总计从 12 天调整为 14-15 天（蛋仔 +2 天，Phase 5 回归 +1 天）

### 调整后交付计划

| Phase | 天数 | 内容 |
|-------|------|------|
| Phase 1 | 4 天 | 蛋仔形象重绘 + 首页 + 地图 + 配色 + 图标 |
| Phase 2 | 4 天 | 宠物互动 + 商店扩充 + 听写 + 跑酷(Canvas) |
| Phase 3 | 2 天 | 答题动画 + 新手引导 + 操作优化 |
| Phase 4 | 3 天 | 成就系统(事件驱动) + 每日目标 + 主题皮肤 + 彩蛋 |
| Phase 5 | 1-2 天 | 全量回归测试 + 修复 |
| **总计** | **14-15 天** | |
