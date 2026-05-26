# 背单词游戏 — 技术方案

> 项目：VocabGame（暂定名）
> 架构师：Alex
> 版本：v1
> 日期：2025-07-15

---

## 1. 项目概述

面向初二女生的趣味背单词 iOS/macOS 应用，融合蛋仔派对（Eggy Party）风格，内置 376 个单词。核心体验：**学习 → 练习 → 测试** 的游戏循环，配合蛋仔宠物养成和闯关机制，让背单词变成"停不下来"的事。

### 设计原则

1. **有趣 > 严谨**：目标是让她愿意打开 app，不是做一个严肃的学习工具
2. **短循环、快反馈**：每局 2-5 分钟，随时随地玩
3. **成就感可感知**：关卡解锁、蛋仔进化、连胜记录，每一步都有奖励
4. **安全简单**：纯本地数据，无需注册/登录/网络，打开即玩

---

## 2. 项目架构

### 2.1 架构模式：MVVM + Repository

```
View (SwiftUI) ──→ ViewModel (ObservableObject) ──→ Repository ──→ Data Store
                                                    ├── WordRepository (单词数据)
                                                    ├── ProgressRepository (学习进度)
                                                    └── PetRepository (宠物状态)
```

**为什么选 MVVM**：SwiftUI 天然适配 MVVM。View 声明式绑定 ViewModel 的 @Published 属性，ViewModel 持有业务逻辑和状态，Repository 封装数据访问。三层职责清晰，Cody 可以按层分工。

**为什么加 Repository 层**：数据源可能从 JSON 文件换成本地数据库（如果后续需要复杂查询），Repository 层隔离了这个变化。ViewModel 不需要知道数据从哪来。

### 2.2 模块划分

| 模块 | 职责 | 关键类型 |
|------|------|----------|
| **Models** | 数据模型定义 | `Word`, `Level`, `Pet`, `GameSession`, `PlayerProfile` |
| **Repositories** | 数据读写 | `WordRepository`, `ProgressRepository`, `PetRepository` |
| **ViewModels** | 业务逻辑 + UI 状态 | `LevelSelectVM`, `GamePlayVM`, `PetHouseVM`, `DailyChallengeVM` |
| **Views** | SwiftUI 视图 | 按 Tab/页面组织 |
| **Services** | 跨模块服务 | `AudioService`, `AnimationService`, `SpacedRepetitionService` |
| **Resources** | 静态资源 | 单词 JSON、音效文件、图片资产 |

### 2.3 数据流

```
用户操作 → View → ViewModel 方法调用
                   ├── 更新 @Published 状态 → View 自动刷新
                   └── 调用 Repository → 更新持久化数据
```

所有状态变更都通过 ViewModel 驱动，View 只做渲染和事件转发。Repository 负责持久化，ViewModel 不知道持久化细节。

---

## 3. 数据模型

### 3.1 Word（单词）

```swift
struct Word: Codable, Identifiable {
    let id: Int          // 编号 1-376
    let text: String     // 英文单词
    let meaning: String  // 中文释义
    let group: Int       // 所属关卡组 (1-25)
}
```

### 3.2 Level（关卡）

```swift
struct Level: Identifiable {
    let id: Int          // 关卡编号 1-25
    let name: String     // 关卡名称，如 "入门小镇"
    let wordIds: [Int]   // 包含的单词 ID（每关 15 个，最后一关 16 个）
    var isUnlocked: Bool // 是否已解锁
    var stars: Int       // 获得星数 0-3
    var bestScore: Int   // 最高分
}
```

376 个单词分成 25 关：前 24 关各 15 个，第 25 关 16 个。关卡线性解锁（通过前一关即可解锁下一关）。

### 3.3 PlayerProfile（玩家档案）

```swift
struct PlayerProfile: Codable {
    var totalStars: Int          // 累计星星
    var totalWordsLearned: Int   // 已学单词数
    var currentStreak: Int       // 当前连续天数
    var bestStreak: Int          // 最佳连续天数
    var lastPlayDate: Date?      // 上次游玩日期
    var totalPlayTime: TimeInterval // 总游玩时长
    var coins: Int               // 金币（用于购买蛋仔装饰）
}
```

### 3.4 PetState（蛋仔宠物）

```swift
struct PetState: Codable {
    var level: Int           // 成长等级 1-5
    var exp: Int             // 当前经验值
    var mood: PetMood        // 心情
    var accessories: [String] // 已拥有的装饰
    var currentAccessory: String? // 当前装备的装饰
}

enum PetMood: String, Codable {
    case happy, normal, sad, excited
}
```

宠物等级对应蛋仔的视觉形态变化：
- Level 1：小蛋仔（圆滚滚，大眼睛）
- Level 2：戴帽子
- Level 3：穿衣服
- Level 4：长翅膀
- Level 5：彩虹光效

经验值通过答题获得，答对 +10 exp，连胜 +5 bonus，每日挑战 +30 bonus。升级阈值：100, 250, 500, 1000。

### 3.5 WordProgress（单词学习进度）

```swift
struct WordProgress: Codable {
    let wordId: Int
    var mastery: MasteryLevel
    var correctCount: Int
    var wrongCount: Int
    var lastReviewed: Date
    var nextReviewDate: Date  // 间隔重复算法计算
}

enum MasteryLevel: Int, Codable {
    case new = 0        // 没见过
    case learning = 1   // 见过但还不熟
    case familiar = 2   // 比较熟悉
    case mastered = 3   // 已掌握
}
```

### 3.6 GameSession（游戏会话）

```swift
struct GameSession {
    let gameMode: GameMode
    let levelId: Int?
    let startTime: Date
    var questions: [Question]
    var currentIndex: Int
    var score: Int
    var combo: Int          // 连击数
    var maxCombo: Int
}

enum GameMode: String, CaseIterable {
    case adventure     // 闯关模式
    case spellChallenge // 拼写挑战
    case matchPairs    // 配对消消乐
    case dailyChallenge // 每日挑战
    case mistakeReview // 错词复习
}

struct Question {
    let word: Word
    let type: QuestionType
    var options: [String]  // 选项（选择题用）
    var isCorrect: Bool?   // 用户作答结果
}

enum QuestionType {
    case selectMeaning    // 看单词选释义
    case selectWord       // 看释义选单词
    case spellWord        // 看释义拼单词
    case listenAndSelect  // 听发音选单词（使用 AVSpeechSynthesizer）
}
```

---

## 4. UI/UX 设计思路

### 4.1 整体结构：Tab 导航

```
┌─────────────────────────────────────┐
│  🏠 首页  │  🗺️ 关卡  │  🥚 蛋仔  │  📊 我的  │
└─────────────────────────────────────┘
```

### 4.2 首页（HomeTab）

**布局**：
- 顶部：蛋仔形象 + 问候语（"早上好！今天要背几个单词？"）
- 中部：今日任务卡片（3 个圆形进度环：每日挑战 / 错词复习 / 新关学习）
- 底部：快捷入口（继续上次关卡、每日挑战）

**蛋仔在首页的行为**：
- 待机时左右摇摆、眨眼
- 点击蛋仔会有反应（开心跳起来、说话气泡）
- 答完题回来蛋仔会根据成绩做表情

### 4.3 关卡选择（LevelSelectTab）

**布局**：地图式关卡路径（类似糖果传奇的路径地图）

```
        🏠
       /
   ⭐⭐☆ L3
    |
   ⭐⭐⭐ L2
    |
   ⭐⭐⭐ L1（起始点）
```

- 已通过关卡：显示获得的星星数，可以重玩刷星
- 当前关卡：闪烁动画，蛋仔站在旁边
- 未解锁关卡：灰色锁定状态
- 每关通过后蛋仔在路径上前进

**关卡主题**（25 关，每关一个主题名称，增强代入感）：

| 关卡 | 名称 | 单词范围 |
|------|------|----------|
| 1 | 新手村庄 | #1-15 |
| 2 | 语言花园 | #16-30 |
| 3 | 认知森林 | #31-45 |
| 4 | 科学小镇 | #46-60 |
| 5 | 自然溪谷 | #61-75 |
| ... | ... | ... |
| 25 | 终极城堡 | #361-376 |

### 4.4 蛋仔之家（PetHouseTab）

**布局**：
- 中央：蛋仔形象（大号），带当前装备的装饰
- 左侧：成长进度条（exp → 下级）
- 右侧：心情气泡（"今天还没学习呢~"）
- 下方：装饰衣柜（已拥有的装饰可切换）

**蛋仔交互**：
- 长按蛋仔 → 蛋仔做表情
- 蛋仔会根据学习数据说话：
  - 有错词未复习："还有 N 个单词需要复习哦！"
  - 连续打卡中："你已经连续 N 天了，继续加油！"
  - 升级时：蛋仔变身动画 + 特效

### 4.5 我的（ProfileTab）

- 学习数据：已掌握 / 学习中 / 未学
- 打卡日历（连续天数高亮）
- 错词本入口
- 设置（音效开关等）

### 4.6 游戏玩法详细设计

#### 4.6.1 闯关模式（Adventure）

**流程**：关卡选择 → 介绍动画（关卡名 + 蛋仔闯入） → 答题（10题） → 结算

**答题界面**：
- 顶部：进度条（第几题/总题数）+ 连击数 + 分数
- 中央：题目区域（单词/释义/听音）
- 底部：选项区域（2x2 网格或拼写输入）
- 蛋仔在屏幕角落，实时反应：
  - 答对：蛋仔跳起来 + 星星特效 + "太棒了！"
  - 答错：蛋仔摇头 + 鼓励文字 + 显示正确答案
  - 连击：蛋仔越来越兴奋

**题型分配**（每关 10 题）：
- 4 题选释义（看英文选中文）
- 3 题选单词（看中文选英文）
- 2 题听音选词
- 1 题拼写挑战

**评分规则**：
- 答对 +100 分
- 连击加成：combo × 20 额外分
- 答错 0 分，连击归零
- 星星评级：≥600 分 ⭐、≥800 分 ⭐⭐、≥900 分 ⭐⭐⭐

#### 4.6.2 拼写挑战（Spell Challenge）

从已学单词中随机出题，看释义拼英文。键盘上方显示提示（首字母或词长）。连续拼对 5 个获得"拼写达人"称号动画。

#### 4.6.3 配对消消乐（Match Pairs）

经典翻牌配对玩法：
- 4×4 网格（8 对单词-释义）
- 翻开两张牌，匹配成功消除 + 特效
- 匹配失败翻回去
- 计时模式，60 秒内消除所有配对
- 用时越短分数越高

#### 4.6.4 每日挑战（Daily Challenge）

- 每天 1 组题（从所有已学单词中随机 15 个）
- 限时 3 分钟
- 题型混合
- 记录历史最高分
- 完成奖励：金币 + 蛋仔经验

#### 4.6.5 错词复习（Mistake Review）

- 自动收录答错的单词
- 采用间隔重复算法安排复习
- 优先推近期出错的词
- 答对 3 次后从错词本移除

---

## 5. SwiftUI 视图层级

```
App
├── MainTabView
│   ├── HomeView
│   │   ├── GreetingHeader
│   │   ├── PetMiniView（小型蛋仔展示）
│   │   ├── DailyTaskCards
│   │   └── QuickActions
│   ├── LevelMapView
│   │   ├── MapScrollView（路径地图）
│   │   ├── LevelNodeView（单个关卡节点）
│   │   └── PetOnMapView（蛋仔在地图上的位置）
│   ├── PetHouseView
│   │   ├── PetDisplayView（大号蛋仔 + 动画）
│   │   ├── ExpProgressBar
│   │   ├── MoodBubbleView
│   │   └── WardrobeView（装饰选择）
│   └── ProfileView
│       ├── StatsCardView
│       ├── StreakCalendarView
│       ├── MistakeBookView
│       └── SettingsView
├── GamePlayView（全屏覆盖，跳转进入）
│   ├── AdventureGameView
│   │   ├── GameHeaderView（进度/分数/连击）
│   │   ├── QuestionView（题目展示）
│   │   │   ├── SelectMeaningQuestion
│   │   │   ├── SelectWordQuestion
│   │   │   ├── ListenSelectQuestion
│   │   │   └── SpellQuestion
│   │   ├── OptionsGridView（选项）
│   │   └── PetReactionView（蛋仔反应动画）
│   ├── MatchGameView
│   │   ├── MatchTimerView
│   │   └── CardGridView（4×4 翻牌）
│   └── ResultView（结算页面）
│       ├── ScoreAnimationView
│       ├── StarRatingView
│       ├── PetCelebrationView
│       └── RewardSummaryView
└── Components
    ├── PetView（通用蛋仔渲染组件）
    ├── StarView（星星评级）
    ├── ProgressBar（通用进度条）
    └── ConfettiView（庆祝特效）
```

---

## 6. 本地持久化策略

### 6.1 方案选型：UserDefaults + JSON 文件

**为什么不用 Core Data**：376 个单词的数据量，Core Data 是杀鸡用牛刀。数据关系简单（没有复杂关联查询），用 JSON + UserDefaults 足够。

**存储结构**：

| 数据 | 存储方式 | 说明 |
|------|----------|------|
| 单词数据 | App Bundle JSON 文件 | 只读，编译时打包 |
| 玩家档案 | UserDefaults | 单例，数据量小 |
| 学习进度 | Documents 目录 JSON 文件 | 可变，按需读写 |
| 蛋仔状态 | UserDefaults | 单例 |
| 每日挑战记录 | UserDefaults | 按日期 key 存储 |

### 6.2 数据文件

**wordlist.json**（编译时打包到 Bundle）：
```json
[
  {"id": 1, "text": "resemble", "meaning": "v.像，与…相似", "group": 1},
  {"id": 2, "text": "recognize", "meaning": "v.认出，识别；承认", "group": 1},
  ...
]
```

由构建脚本从 `wordlist.md` 自动生成，Cody 不需要手动维护 JSON。

**progress.json**（运行时写入 Documents 目录）：
```json
{
  "wordProgress": {
    "1": {"mastery": 2, "correctCount": 5, "wrongCount": 1, "lastReviewed": "...", "nextReviewDate": "..."},
    ...
  },
  "levelProgress": {
    "1": {"stars": 3, "bestScore": 950, "isCompleted": true},
    ...
  }
}
```

### 6.3 数据迁移策略

版本号存储在 UserDefaults。未来新增字段时，检测版本号并做增量迁移。首次版本为 1。

---

## 7. 动画方案

### 7.1 设计原则

- 动画要**短**（0.2-0.5 秒），不拖慢节奏
- 使用 SwiftUI 原生动画（`withAnimation`、`.spring()`、`.transition()`）
- 复杂动画用 `Canvas` 或 Lottie（如果需要），优先用 SwiftUI 原生方案

### 7.2 关键动画列表

| 场景 | 动画效果 | 实现方式 |
|------|----------|----------|
| 答对 | 蛋仔弹跳 + 星星粒子 | SwiftUI spring + particle overlay |
| 答错 | 蛋仔摇头 + 画面微抖 | withAnimation shake |
| 连击 | 连击数字放大弹跳 + 火焰特效 | scaleEffect + color overlay |
| 过关 | 蛋仔庆祝 + 礼花 + 星星飞入 | ConfettiView + matchedGeometryEffect |
| 蛋仔升级 | 全屏光芒 + 蛋仔变身 | scale + opacity transition |
| 关卡解锁 | 地图节点闪光解锁 | glow + scale animation |
| 配对成功 | 卡片缩小消失 + 彩色碎片 | scaleEffect(0) + opacity |
| 翻牌 | 3D 翻转效果 | rotation3DEffect |
| 首页蛋仔待机 | 轻微上下浮动 + 随机眨眼 | repeatForever + phaseAnimator |

### 7.3 ParticleView（粒子特效）

用 SwiftUI `TimelineView` + `Canvas` 实现轻量粒子系统。用于：答对星星、过关礼花、升级光芒。不引入第三方依赖。

---

## 8. 音效方案

### 8.1 音效资源

使用免费音效（freesound.org 或类似来源），要求风格轻快可爱。

| 场景 | 音效 | 说明 |
|------|------|------|
| 答对 | 清脆叮咚声 | 短促、愉悦 |
| 答错 | 柔和的"呜"声 | 不刺耳，鼓励性 |
| 连击 | 递增音阶 | combo 越高音调越高 |
| 过关 | 欢快音乐 | 2-3 秒 |
| 蛋仔互动 | 可爱 "啵" 声 | 点击蛋仔时 |
| 翻牌 | 翻转声 | |
| 配对成功 | 消除音效 | |
| 按钮点击 | 轻微点击声 | |

### 8.2 实现方式

```swift
class AudioService {
    static let shared = AudioService()
    private var audioPlayer: AVAudioPlayer?

    func play(_ sound: SoundEffect) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else { return }
        // 播放音效
    }
}

enum SoundEffect: String {
    case correct, wrong, combo, levelComplete, petTap, flip, match, buttonTap
}
```

- 音效可全局开关（设置页）
- 预加载常用音效，避免延迟
- 使用 `AVAudioPlayer`，简单够用

### 8.3 TTS（发音）

使用系统内置 `AVSpeechSynthesizer` 朗读单词，无需第三方服务。听音选词题型直接用 TTS。

---

## 9. 间隔重复算法

采用简化版 SM-2 算法，用于错词复习安排：

```
如果答对：
  - mastery 升一级（上限 mastered）
  - nextReviewDate 推迟：new → 1天，learning → 3天，familiar → 7天

如果答错：
  - mastery 降一级（下限 new）
  - nextReviewDate 设为 4 小时后
```

不需要复杂的 supermemo 全套，简化版足以应对 376 个单词的复习节奏。

---

## 10. 目录结构

```
VocabGame/
├── VocabGame.xcodeproj
├── VocabGame/
│   ├── App/
│   │   ├── VocabGameApp.swift          # @main 入口
│   │   └── AppDelegate.swift           # 如需处理生命周期
│   ├── Models/
│   │   ├── Word.swift
│   │   ├── Level.swift
│   │   ├── PlayerProfile.swift
│   │   ├── PetState.swift
│   │   ├── WordProgress.swift
│   │   └── GameSession.swift
│   ├── Repositories/
│   │   ├── WordRepository.swift        # 加载 JSON 单词数据
│   │   ├── ProgressRepository.swift    # 学习进度读写
│   │   └── PetRepository.swift         # 蛋仔状态读写
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift
│   │   ├── LevelSelectViewModel.swift
│   │   ├── GamePlayViewModel.swift
│   │   ├── PetHouseViewModel.swift
│   │   ├── DailyChallengeViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   └── MistakeReviewViewModel.swift
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── GreetingHeader.swift
│   │   │   ├── DailyTaskCards.swift
│   │   │   └── QuickActions.swift
│   │   ├── LevelSelect/
│   │   │   ├── LevelMapView.swift
│   │   │   ├── LevelNodeView.swift
│   │   │   └── MapScrollView.swift
│   │   ├── Game/
│   │   │   ├── GamePlayView.swift
│   │   │   ├── AdventureGameView.swift
│   │   │   ├── MatchGameView.swift
│   │   │   ├── SpellChallengeView.swift
│   │   │   ├── QuestionViews/
│   │   │   │   ├── SelectMeaningQuestion.swift
│   │   │   │   ├── SelectWordQuestion.swift
│   │   │   │   ├── ListenSelectQuestion.swift
│   │   │   │   └── SpellQuestion.swift
│   │   │   ├── GameHeaderView.swift
│   │   │   ├── OptionsGridView.swift
│   │   │   └── ResultView.swift
│   │   ├── PetHouse/
│   │   │   ├── PetHouseView.swift
│   │   │   ├── PetDisplayView.swift
│   │   │   ├── ExpProgressBar.swift
│   │   │   └── WardrobeView.swift
│   │   ├── Profile/
│   │   │   ├── ProfileView.swift
│   │   │   ├── StatsCardView.swift
│   │   │   ├── StreakCalendarView.swift
│   │   │   ├── MistakeBookView.swift
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       ├── PetView.swift            # 通用蛋仔渲染
│   │       ├── StarRatingView.swift
│   │       ├── ProgressBar.swift
│   │       ├── ConfettiView.swift
│   │       ├── ParticleView.swift
│   │       └── CardFlipView.swift
│   ├── Services/
│   │   ├── AudioService.swift
│   │   ├── SpacedRepetitionService.swift
│   │   └── TTSService.swift
│   ├── Helpers/
│   │   ├── Constants.swift              # 颜色、尺寸、动画常量
│   │   ├── Extensions.swift            # 通用扩展
│   │   └── ColorScheme+VocabGame.swift  # 自定义配色
│   └── Resources/
│       ├── Data/
│       │   └── wordlist.json           # 构建脚本从 wordlist.md 生成
│       ├── Sounds/
│       │   ├── correct.wav
│       │   ├── wrong.wav
│       │   ├── combo.wav
│       │   ├── level_complete.wav
│       │   ├── pet_tap.wav
│       │   ├── flip.wav
│       │   ├── match.wav
│       │   └── button_tap.wav
│       └── Assets.xcassets/            # 蛋仔图片、UI 图片
│           ├── Eggy/
│           │   ├── eggy_level1.imageset
│           │   ├── eggy_level2.imageset
│           │   ├── eggy_level3.imageset
│           │   ├── eggy_level4.imageset
│           │   └── eggy_level5.imageset
│           ├── EggyExpressions/
│           │   ├── eggy_happy.imageset
│           │   ├── eggy_sad.imageset
│           │   ├── eggy_excited.imageset
│           │   └── eggy_cheering.imageset
│           ├── Backgrounds/
│           └── UI/
│               ├── star_filled.imageset
│               ├── star_empty.imageset
│               └── ...
├── scripts/
│   └── generate_wordlist.py            # wordlist.md → wordlist.json 转换脚本
└── README.md
```

---

## 11. 视觉风格指南

### 11.1 配色

蛋仔派对风格 = 高饱和 + 圆角 + 渐变。主色调选择暖色系：

| 角色 | 颜色 | 用途 |
|------|------|------|
| 主色 | `#FF6B9D`（糖果粉） | 按钮、高亮、蛋仔主题色 |
| 辅色 | `#FFD93D`（明黄） | 星星、分数、成就 |
| 成功色 | `#6BCB77`（清新绿） | 答对、通过 |
| 错误色 | `#FF6B6B`（柔红） | 答错（不要太刺眼） |
| 背景色 | `#FFF5F9`（浅粉白） | 全局背景 |
| 卡片色 | `#FFFFFF` | 卡片背景 |

### 11.2 圆角规范

- 按钮：cornerRadius 16
- 卡片：cornerRadius 20
- 选项按钮：cornerRadius 12
- 头像/蛋仔容器：Circle 或 cornerRadius 30+

### 11.3 字体

- 标题：系统 `.title`，bold
- 正文：系统 `.body`
- 分数/数字：系统 `.largeTitle`，heavy
- 保持系统字体即可，不引入第三方字体（减少复杂度）

### 11.4 蛋仔形象

蛋仔用 **SF Symbols + 自定义图片** 结合。5 个等级的蛋仔形态用 PNG/SVG 图片资源，由 Assets Catalog 管理。

如果图片资源制作有困难，第一版可以用纯 SwiftUI 绘制蛋仔（圆形身体 + 眼睛 + 腮红 + 四肢），配合 `@State` 动画实现表情变化。后期替换成正式美术资源。

---

## 12. 实现优先级和分期建议

### Phase 1：核心可玩（最小可玩版本）

**目标**：闯关模式跑通，能看到蛋仔，有基本的答题反馈。

| 任务 | 说明 |
|------|------|
| 项目搭建 | Xcode 项目、目录结构、构建脚本 |
| 数据层 | Models + WordRepository + JSON 数据 |
| 闯关模式 | 关卡选择 → 答题（选释义 + 选单词）→ 结算 |
| 蛋仔展示 | SwiftUI 绘制简单蛋仔，答对弹跳、答错摇头 |
| 持久化 | UserDefaults 存储关卡进度 |
| 基础 UI | MainTabView + 关卡列表（简化版，不做路径地图） |

**预计工作量**：Cody 实现 2-3 天。

### Phase 2：丰富玩法

**目标**：3 种以上游戏模式 + 蛋仔养成 + 音效。

| 任务 | 说明 |
|------|------|
| 听音选词 | AVSpeechSynthesizer TTS |
| 拼写挑战 | 看释义拼单词 |
| 配对消消乐 | 4×4 翻牌配对 |
| 蛋仔养成 | 经验值、升级、5 级形态变化 |
| 音效系统 | AudioService + 8 个基础音效 |
| 每日挑战 | 随机题目 + 计时 |
| 错词本 | 自动收录 + 间隔重复复习 |

**预计工作量**：3-4 天。

### Phase 3：打磨体验

**目标**：视觉升级、蛋仔互动、地图式关卡。

| 任务 | 说明 |
|------|------|
| 路径地图 | 关卡选择改为地图式滚动路径 |
| 蛋仔互动 | 长按反应、对话气泡、心情系统 |
| 粒子特效 | ConfettiView、答对星星、过关礼花 |
| 装饰系统 | 金币 + 蛋仔装饰衣柜 |
| 打卡日历 | 连续天数记录 + 可视化 |
| 关卡主题 | 25 关的名称和背景差异化 |
| macOS 适配 | 窗口大小适配、键盘快捷键 |

**预计工作量**：2-3 天。

---

## 13. 技术风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| 蛋仔形象资源缺失 | 视觉效果打折 | Phase 1 用 SwiftUI 纯绘制，预留替换接口 |
| 间隔重复算法过于简单 | 复习效率不够好 | 先用简化版，后续可升级为 full SM-2 |
| macOS 适配问题 | 需要额外调试 | Phase 3 再处理，iOS 优先 |
| SwiftUI 动画性能 | 低端设备卡顿 | 控制粒子数量，用 `drawingGroup()` 优化 |
| 数据损坏 | 进度丢失 | 每次写入前备份，损坏时自动从备份恢复 |

---

## 14. 测试要点

给 Tina 的测试建议：

1. **数据层**：WordRepository 加载 376 个单词、ProgressRepository 读写进度
2. **游戏逻辑**：分数计算、连击、星星评级、关卡解锁条件
3. **间隔重复**：答对/答错后 mastery 和 nextReviewDate 的变化
4. **边界情况**：最后一关（16 个单词）、全答对/全答错、重复玩同一关
5. **持久化**：杀进程后数据是否完整恢复
6. **UI 交互**：配对消消乐的翻牌逻辑、拼写输入的边界处理

---

## 15. 开放决策（需 Luke/Cody 确认）

1. **蛋仔美术资源**：是用 SwiftUI 纯代码绘制，还是洪涛提供美术素材？如果纯代码绘制，视觉效果会简化但够用。
2. **音效来源**：使用免费音效库还是暂时用系统音效？免费音效需要筛选和裁剪。
3. **macOS 最低版本**：跟随 iOS 版本还是单独设？建议 macOS 14+（对应 SwiftUI 最新特性）。
