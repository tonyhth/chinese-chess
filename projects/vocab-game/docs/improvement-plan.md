# VocabGame 全面改进方案

> ⚠️ **本文档已废弃**，请使用演进版方案：`~/DevTeam/docs/vocab-game-v2-proposal.md` (v1.1)
>
> 本文档 v1.0 的 Vera 审查 P0 已在 v2-proposal v1.1 中统一修复：
> - 成就系统改为事件驱动（AchievementEvent 枚举）
> - 金币经济平衡表补齐
> - 蛋仔方案调整为分步交付（先 Lv.1 基础形态）

> 版本：v1.0（废弃）  
> 基于：当前代码 v1.11 状态（P0 已修复）  
> 目标：UI 升级 + 功能增强 + 操作优化 + 趣味性提升  

---

## 现状总结

**已完成的功能**：闯关 25 关、每日挑战、拼写挑战、配对消消乐、错词复习、宠物养成（5 级）、商店装饰（8 件）、金币经济、星级评分、间隔重复算法、TTS 朗读。

**当前 UI 风格**：糖果粉色系（`#FF6B9D` 主色），圆形按钮，卡片式布局。蛋仔是 `Ellipse` + 白色圆点眼睛 + 白色矩形嘴巴的极简风格，配件用 emoji 叠加。

**核心问题**（基于代码分析）：

| 维度 | 现状 | 痛点 |
|------|------|------|
| UI | 蛋仔是纯几何图形 + emoji 配件 | 缺乏角色感，不够"蛋仔派对"风格 |
| 功能 | 5 种游戏模式 + 宠物 + 商店 | 宠物只有 5 级，商店只有装饰，缺少深度 |
| 操作 | 新手引导只有 emoji + 文字 | 无交互式引导，空状态提示不统一 |
| 趣味 | 连击 combo + 每日挑战 + 成就 | 缺少成就系统、排行榜、社交元素 |

---

## Phase 1：体验打磨（~15h）

> 目标：让现有功能更完整、更好用，不增加新系统。

### 1.1 蛋仔形象重做（P0，大）

**现状分析**：

`PetDisplayView.swift` 和 `PetMiniView.swift` 中的蛋仔：
- 身体：`Ellipse().fill(bodyColor)`（纯色椭圆）
- 眼睛：白色 `Circle` + 黑色 `Circle`（16pt/8pt，无高光）
- 嘴巴：白色 `RoundedRectangle`（14x6pt）
- 腮红：两个半透明白色 `Circle`
- 配件：emoji 文本叠加（"🎩"、"👓"、"🧣"等）
- 翅膀：`Ellipse`（Level 4+）

**目标风格**：网易蛋仔派对风格——圆润蛋形身体、大眼睛（占脸 1/3）、高光瞳孔、可爱微笑、表情丰富、色彩鲜明。

**技术方案**：用 SwiftUI Shape + 渐变重绘，不引入图片资源。原因：保持矢量可缩放、动态换色、动画灵活。

#### 修改文件

**`PetDisplayView.swift`**（蛋仔之家大蛋仔）：

- **身体**：`Ellipse` 改为 `RoundedRectangle(cornerRadius:)` 上窄下宽，加线性渐变（顶部亮、底部暗）
- **眼睛**：放大到 24pt，加白色高光点（4pt Circle，offset 右上），黑色瞳孔改为深棕色 + 高光
- **嘴巴**：改为微笑弧线（`Path` 绘制半圆弧），根据 mood 变换：happy 微笑、normal 平直、sad 下弯、excited 大笑（开嘴）
- **腮红**：改为粉色半透明 Circle（`#FF6B9D` opacity 0.3），位于眼睛下方两侧
- **配件**：emoji 叠加改为 SwiftUI Shape 绘制。帽子用 `RoundedRectangle` + 渐变，围巾用 `Capsule`，蝴蝶结用两个 `Circle` + 中心 `Circle`
- **动画**：加 idle 动画（轻微左右摇晃），mood 变化时表情过渡动画

**`PetMiniView.swift`**（首页小蛋仔）：

- 复用大蛋仔的核心绘制逻辑，提取为 `PetBodyView` 组件
- 小尺寸下简化细节（去掉腮红高光等小元素）

**新增组件 `Views/Components/PetBodyView.swift`**：

```
PetBodyView(
    size: CGFloat,
    level: Int,
    mood: PetMood,
    accessory: String?,
    isAnimating: Bool
)
```

- 封装身体、眼睛、嘴巴、腮红、配件的绘制
- `PetDisplayView` 和 `PetMiniView` 共用
- body 颜色由 level 决定（保持现有逻辑），加渐变增加质感

#### 蛋仔表情设计

| Mood | 眼睛 | 嘴巴 | 腮红 | 特效 |
|------|------|------|------|------|
| happy | 大眼 + 高光 | 微笑弧线 | 粉色 | 无 |
| normal | 正常眼 | 平直短线 | 淡粉 | 无 |
| sad | 半闭眼（扁椭圆） | 下弯弧线 | 无 | 无 |
| excited | 星星眼（五角星 Shape） | 大笑开嘴 | 深粉 + 发光 | 头顶爱心粒子 |

#### 蛋仔配件重设计

| 配件 ID | 现状 | 改进 |
|---------|------|------|
| hat_party | 🎩 emoji | 糖果色锥形帽（`Path` 绘制，多色渐变） |
| hat_crown | 🎩 emoji | 金色皇冠（`Path` + 黄色渐变 + 宝石点缀） |
| hat_beanie | 🎩 emoji | 毛线帽（`RoundedRectangle` + 纹理线条） |
| glasses_round | 👓 emoji | 圆框眼镜（两个 `Circle` + 连接线） |
| glasses_sunglasses | 👓 emoji | 飞行员墨镜（`RoundedRectangle` + 深色渐变） |
| scarf_red | 🧣 emoji | 红围巾（`Capsule` 环绕脖子） |
| bow_pink | 🎀 emoji | 粉色蝴蝶结（两个三角 + 中心圆） |
| cape_super | 🦸 emoji | 红色披风（`Path` 飘动形状） |

**工作量**：~8h（蛋仔绘制 + 配件 + 动画 + PetBodyView 提取）

### 1.2 答题反馈增强（P1，中）

**现状问题**：
- 答对：选项变绿 1 秒后自动下一题，无额外反馈
- 答错：选项变红 1.5 秒后自动下一题，正确答案显示时间太短
- 无"正确答案"文字说明（只有颜色变化）

**改进方案**：

**`GamePlayView.swift`**（`selectAnswer` / `submitSpelling`）：

1. 答对时加 `Text("✓ 太棒了!")` 弹出动画（已有，保持）
2. 答错时显示正确答案 + 解释，延长到 2 秒（从 1.5s 改为 2s）
3. 连击 3x+ 时加屏幕边缘光效（已有 combo 播放音效 ✅，加视觉反馈）

**`DailyChallengeView.swift`**（同上逻辑）：

- 与 GamePlayView 保持一致

**`ResultView.swift`**：

- 答错的题目列表展示（可展开）：哪些题错了、正确答案是什么
- 新增 `wrongAnswers` 计算属性

**工作量**：~3h

### 1.3 空状态和提示优化（P1，小）

**现状问题**：
- 首页统计数据用 emoji + 文字混排（"⭐ 5 · 🔥 3天 · 📚 20词 · 💰 100币"），信息密度高但不够清晰
- 错词复习无错词时只有 `Text("暂无题目数据")`
- 关卡选择器是平面列表，缺乏地图感

**改进方案**：

**`HomeView.swift`**：
- 统计栏改为 4 个小卡片横排（类似 ProfileView 的 StatCard），每个卡片有图标、数值、标签
- 或者用单个横条 `HStack` 拆分为 4 等分，每份一个指标

**`GamePlayView.swift` / `MatchGameView.swift`**：
- 空状态用统一的 `EmptyStateView` 组件（大图标 + 主文案 + 副文案 + 操作按钮）
- 新增 `Views/Components/EmptyStateView.swift`

**`LevelMapView.swift`**（关卡地图）：
- 当前进度显示在地图顶部："已完成 X/25 关，掌握 X 个单词"

**工作量**：~2h

### 1.4 ResultView 改进（P2，中）

**现状**：`ResultView` 只显示总分、星级、最高连击、正确率、金币。缺少答题详情。

**改进方案**：

**`ResultView.swift`**：
- 新增答题详情区（可折叠）：
  - 题目列表，每题显示：题号、题型图标、对/错标记、用户答案 vs 正确答案
  - 答错的题高亮显示
- 蛋仔出现在结果页（小尺寸 PetBodyView），根据星级做不同表情
  - 3 星：excited（星星眼）
  - 2 星：happy（微笑）
  - 1 星：normal
  - 0 星：sad

**工作量**：~2h

---

## Phase 2：功能深化（~20h）

> 目标：增加游戏深度，让用户有持续回来的理由。

### 2.1 成就系统（P0，大）

**现状**：无成就系统。用户完成关卡、达到连击等事件没有记录和奖励。

**设计**：

**新增模型 `Models/Achievement.swift`**：

```swift
struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String        // SF Symbol name
    let category: AchievementCategory
    let requirement: Int    // 达成条件阈值
    var progress: Int       // 当前进度
    var isUnlocked: Bool
    var unlockedAt: Date?
    let reward: Int         // 金币奖励
}

enum AchievementCategory: String, Codable {
    case learning   // 学习类
    case gameplay   // 游戏类
    case pet        // 宠物类
    case streak     // 坚持类
}
```

**成就列表**：

| ID | 名称 | 描述 | 条件 | 奖励 |
|----|------|------|------|------|
| first_win | 初次通关 | 完成第一个关卡 | 完成 1 关 | 20 |
| star_collector | 星星收藏家 | 累计获得 30 颗星 | 30 星 | 50 |
| perfect_level | 完美通关 | 一关获得 3 星 | 3 星 1 次 | 30 |
| combo_master | 连击大师 | 单局达到 10 连击 | 10 连击 | 40 |
| word_learner | 词汇学徒 | 学会 50 个单词 | 50 词 | 30 |
| word_master | 词汇大师 | 掌握 100 个单词 | 100 词 | 80 |
| daily_warrior | 每日战士 | 连续 7 天完成每日挑战 | 7 天 | 60 |
| streak_7 | 坚持一周 | 连续 7 天学习 | 7 天 | 50 |
| streak_30 | 坚持一月 | 连续 30 天学习 | 30 天 | 200 |
| pet_max | 蛋仔满级 | 蛋仔达到最高等级 | Level 5 | 100 |
| match_speed | 闪电配对 | 30 秒内完成配对 | 完成 1 次 | 40 |
| spell_streak | 拼写达人 | 连续拼写正确 10 个 | 10 连对 | 50 |
| all_levels | 关卡通关 | 完成全部 25 关 | 25 关 | 300 |

**新增 Repository `Repositories/AchievementRepository.swift`**：

- 存储：UserDefaults（与 PetRepository 同模式）
- 方法：`load()`、`save()`、`updateProgress(id:increment:)`、`checkUnlock(id:)`、`allAchievements`

**新增 ViewModel `ViewModels/AchievementViewModel.swift`**：

- 加载成就列表、进度、解锁状态

**新增 View `Views/Profile/AchievementView.swift`**：

- 成就列表页：按分类分组，已解锁高亮、未解锁灰色 + 进度条
- 解锁动画：弹出金币 + 成就图标放大

**集成点**：

- `GamePlayView.advanceToNext()`：检查 `first_win`、`star_collector`、`perfect_level`
- `DailyChallengeViewModel.saveResult()`：检查 `daily_warrior`
- `PetRepository.addExp()`：检查 `pet_max`
- `ProgressRepository.recordPlay()`：检查 `streak_7`、`streak_30`
- `MatchGameViewModel.endGame()`：检查 `match_speed`
- `SpellChallengeViewModel.submit()`：检查 `spell_streak`

**AppCoordinator 扩展**：

```swift
let achievementRepo = AchievementRepository()
```

**ProfileView 改动**：

- 加"成就"入口按钮
- 成就总数摘要："已解锁 X/Y 个成就"

**工作量**：~10h

### 2.2 宠物扩展：互动和进化（P1，大）

**现状**：宠物 5 级，只有 addExp 和换装，无互动。mood 系统已存在但仅在 PetHouseView 显示文字，无视觉反馈。

**改进**：

#### 宠物互动

**`PetDisplayView.swift`**：

- 点击蛋仔播放动画 + 音效：
  - 点击 1 次：蛋仔跳一下 + "吱~"（petTap 音效 ✅ 已有）
  - 连续点击 3 次：蛋仔转圈
  - 长按：蛋仔变大（膨胀）然后弹回 + "惊讶"表情

- 拖拽蛋仔：可以在 PetHouseView 中拖动位置（简单实现：`DragGesture` offset）

#### 宠物进化视觉

**`PetState.swift`** 扩展进化阶段：

```swift
enum PetStage: Int, Codable {
    case egg = 0       // 初始：蛋
    case baby = 1      // Level 1：小蛋仔
    case child = 2     // Level 2：中蛋仔
    case teen = 3      // Level 3：大蛋仔
    case adult = 4     // Level 4：带翅膀蛋仔
    case legend = 5    // Level 5：金色发光蛋仔
}
```

**`PetBodyView.swift`**（Phase 1 新建的组件）：

- 每个进化阶段有不同外形：
  - egg：纯椭圆，只有眼睛（闭着的），无嘴巴
  - baby：小蛋形，大眼睛，微笑
  - child：蛋形略大，加小手臂（两个圆角矩形）
  - teen：更大的蛋形，手臂 + 腮红
  - adult：完整蛋形 + 翅膀（已有）
  - legend：金色光环 + 粒子特效 + 翅膀

- 升级时播放进化动画：旧形态缩小消失 → 白光闪烁 → 新形态放大出现

**`PetHouseView.swift`**：

- 进化阶段的视觉指示（当前只有文字 "Lv.X"）：加进化进度条 + 下一阶段预览剪影
- mood 系统视觉化：蛋仔表情 + 气泡文字

**工作量**：~8h

### 2.3 每日挑战增强（P1，中）

**现状**：每日挑战固定 15 题、180 秒、4 种题型轮换。完成一次后当天不可再玩。

**改进**：

**`DailyChallengeViewModel.swift`**：

1. **难度递进**：连续完成天数影响难度
   - 1-7 天：12 题、200 秒
   - 8-14 天：15 题、180 秒
   - 15+ 天：18 题、160 秒
   - 难度信息在开始前展示

2. **每日挑战刷新机制**：
   - 完成后显示"今日挑战已完成"（已有 ✅）
   - 增加"再来一局（练习模式）"：可以无限次练习，但不计入每日记录、不给每日奖励（只给少量经验）

3. **每日挑战排行榜**（本地）：
   - `ProgressData` 新增 `dailyChallengeHistory: [String: Int]`（日期 → 最高分）
   - 结果页显示"最近 7 天趋势"：小型折线图（SwiftUI `Path` 绘制）

**`DailyChallengeView.swift`**：

- 开始前新增"每日挑战预告"页：显示今日难度、连续天数、历史最高分

**工作量**：~5h（不含排行榜 UI）

---

## Phase 3：社交与深坑（~20h）

> 目标：增加长期留存动力。

### 3.1 学习数据统计页（P1，大）

**现状**：ProfileView 只有 4 个 StatCard（总星数、已学单词、已掌握、连续天数），无详细统计。

**设计**：

**新增 `Views/Profile/StatsView.swift`**：

- 日历热力图（类似 GitHub 贡献图）：过去 90 天每天是否学习，颜色深浅表示学习量
- 单词掌握分布饼图：生疏 / 学习中 / 熟悉 / 掌握
- 游戏模式偏好统计：各模式游玩次数（条形图）
- 每周学习量趋势（折线图）

**数据来源**：

- `ProgressRepository` 需扩展：新增 `playHistory: [String: PlayRecord]`（日期 → 游玩记录）
- `PlayRecord` 包含：日期、游玩次数、获得的单词数、获得的经验

**`PlayerProfile.swift` 扩展**：

```swift
struct PlayRecord: Codable {
    var playCount: Int = 0
    var wordsLearned: Int = 0
    var expGained: Int = 0
}
// Profile 新增
var playHistory: [String: PlayRecord] = [:]  // key = "yyyy-MM-dd"
```

**ProfileView 改动**：

- 加"学习统计"入口 → StatsView

**工作量**：~8h

### 3.2 自定义词库/收藏功能（P2，大）

**现状**：单词来源固定（25 组内置词汇），用户不能标记或收藏单词。

**设计**：

**`WordProgress.swift` 扩展**：

```swift
var isFavorite: Bool = false
```

**各游戏视图改动**：

- 答题后/结果页：每个单词旁边加收藏按钮（星号图标）
- ProfileView 加"收藏单词"入口

**新增 `Views/Profile/FavoriteWordsView.swift`**：

- 收藏的单词列表
- 可选：只背收藏的单词的模式（复用 SpellChallengeView）

**工作量**：~6h

### 3.3 通知提醒系统（P2，中）

**现状**：无本地通知。用户不打开 app 就没有回访动力。

**设计**：

- 每日提醒：每天固定时间提醒学习（默认 20:00，可在 ProfileView 设置）
- 错词复习提醒：错词数 > 10 时提醒
- 连续打卡提醒：已连续 N 天，提醒保持

**新增 `Services/NotificationService.swift`**：

- `requestPermission()`：首次打开时请求通知权限
- `scheduleDailyReminder(hour:minute:)`：调度每日提醒
- `cancelAll()`：取消所有通知

**`ProfileView.swift`**：

- 新增"学习提醒"开关 + 时间选择器

**`OnboardingView.swift`**：

- 最后一页加"开启学习提醒"选项

**工作量**：~4h

### 3.4 新手引导改进（P2，中）

**现状**：OnboardingView 只有 4 页 emoji + 文字介绍，无交互式引导。

**改进方案**：

**`OnboardingView.swift`** 重设计：

- 第 1 页：欢迎 + 选择每日目标（10/20/30 个单词），用户选择后保存到 Profile
- 第 2 页：展示蛋仔（大尺寸），"你的学习伙伴！答题赚经验，蛋仔会升级" + 蛋仔 idle 动画
- 第 3 页：简要玩法介绍（动态卡片轮播：闯关 → 拼写 → 配对 → 每日挑战）
- 第 4 页：设置学习提醒（复用 NotificationService）

**首页首次进入引导**：

- 首次进入 HomeView 时，QuickActionCard 上加 tooltip 气泡提示："点这里开始闯关！"
- 用 `@AppStorage("hasSeenTooltip")` 控制，显示一次后消失

**工作量**：~4h

---

## 分阶段规划总览

### Phase 1：体验打磨（优先级最高）

| 编号 | 改进项 | 优先级 | 工作量 | 修改文件 |
|------|--------|--------|--------|---------|
| 1.1 | 蛋仔形象重做 | P0 | 大（~8h） | PetDisplayView、PetMiniView、新增 PetBodyView |
| 1.2 | 答题反馈增强 | P1 | 中（~3h） | GamePlayView、DailyChallengeView、ResultView |
| 1.3 | 空状态和提示优化 | P1 | 小（~2h） | HomeView、GamePlayView、MatchGameView、新增 EmptyStateView |
| 1.4 | ResultView 改进 | P2 | 中（~2h） | ResultView |

### Phase 2：功能深化

| 编号 | 改进项 | 优先级 | 工作量 | 修改文件 |
|------|--------|--------|--------|---------|
| 2.1 | 成就系统 | P0 | 大（~10h） | 新增 Achievement/Repository/ViewModel/View，改造多个 ViewModel |
| 2.2 | 宠物扩展 | P1 | 大（~8h） | PetDisplayView、PetHouseView、PetState、PetBodyView |
| 2.3 | 每日挑战增强 | P1 | 中（~5h） | DailyChallengeViewModel、DailyChallengeView |

### Phase 3：社交与深坑

| 编号 | 改进项 | 优先级 | 工作量 | 修改文件 |
|------|--------|--------|--------|---------|
| 3.1 | 学习数据统计页 | P1 | 大（~8h） | 新增 StatsView、PlayerProfile、ProgressRepository |
| 3.2 | 自定义词库/收藏 | P2 | 大（~6h） | WordProgress、各游戏 View、新增 FavoriteWordsView |
| 3.3 | 通知提醒系统 | P2 | 中（~4h） | 新增 NotificationService、ProfileView、OnboardingView |
| 3.4 | 新手引导改进 | P2 | 中（~4h） | OnboardingView、HomeView |

---

## 风险与注意事项

1. **蛋仔重做的工作量**：用 SwiftUI Shape 绘制比 emoji 复杂得多。建议先用简化版（保留 emoji 配件，只重做身体/眼睛/嘴巴），后续迭代逐步替换配件为 Shape。
2. **成就系统的集成点**：分布在多个 ViewModel 中，需注意不要让成就检查逻辑散落各处。建议在 AppCoordinator 或独立的 `AchievementChecker` 中集中处理，ViewModel 只上报事件。
3. **数据模型扩展**：`PlayerProfile` 新增字段、`WordProgress` 新增字段都要注意 Codable 向后兼容（Optional + 默认值）。
4. **Phase 2/3 的新增 Repository**：考虑统一存储层——当前 ProgressRepository 用 JSON 文件，PetRepository 用 UserDefaults，AchievementRepository 也用 UserDefaults。长期应统一为一种存储方式。
5. **性能**：蛋仔动画（idle 摇晃、表情切换、配件动画）在多个页面同时展示时注意性能。PetMiniView 应该简化动画。
6. **App 图标**：当前项目没有自定义 App 图标。Phase 1 应同步设计并集成 `AppIcon.appiconset`。

---

## App 图标设计要求

**风格**：糖果色系 + 蛋仔形象，与 app 内 UI 一致。

**设计方向**：
- 圆角方形背景（`#FF6B9D` 主色渐变）
- 中央蛋仔剪影（圆润蛋形 + 大眼睛 + 微笑）
- 可能加一顶小帽子或一颗星星作为点缀
- 整体感觉：可爱、温暖、有游戏感

**技术规格**：
- Apple HIG App Icon 规格
- 1024x1024 主尺寸，自动缩放到其他尺寸
- 输出 `AppIcon.appiconset/` 目录，含 `Contents.json` + 各尺寸 PNG

**时机**：Phase 1 编码前完成，确保 Cody 编码时项目已包含图标。
