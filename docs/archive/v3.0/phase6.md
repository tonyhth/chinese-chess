# Phase 6：可玩性 — 段位系统 + 成就系统

> 路线：**可玩性核心层**
> 周次：Week 2-4
> 依赖：Phase 5 的 `PlayerProfile` 数据模型基础

---

## 目标

1. 段位系统：7 级段位 + 特权解锁机制，提供长期成长目标
2. 成就系统：34 个成就覆盖全玩法，多巴胺释放点

---

## 具体实施内容

### 6.1 段位系统

**段位体系**：

```
学童 → 秀才 → 举人 → 进士 → 翰林 → 国手 → 棋圣
```

**数据模型**：
```swift
enum PlayerRank: Int, Codable, CaseIterable {
    case xuetong = 0    // 学童
    case xiucai = 1     // 秀才
    case juren = 2      // 举人
    case jinshi = 3     // 进士
    case hanlin = 4     // 翰林
    case guoshou = 5    // 国手
    case qisheng = 6    // 棋圣
}
```

**升级条件**（累计制，不降级）：
- 学童：初始
- 秀才：初级获胜 3 局 或 通关 10 局残局
- 举人：中级获胜 3 局 或 通关 30 局残局
- 进士：高级获胜 3 局 或 通关 60 局残局
- 翰林：大师获胜 1 局 或 通关 100 局残局
- 国手：大师获胜 10 局
- 棋圣：大师级获胜 30 局（v3.0 条件）；v3.1 Pikafish 集成后调整为"Pikafish 全力模式获胜 3 局"

> **v3.0 可达性说明**：棋圣段位在 v3.0 中可通过大师级自研引擎获胜 30 局达成（虽然难度较高，但理论上可达）。v3.1 Pikafish 集成后条件调整为更具挑战性的 Pikafish 全力模式。已有棋圣段位的玩家不受影响（累计制不降级）。

**段位特权**（详见 v3.0 方案 §4.1）：
- 装饰性：解锁主题、棋子样式、棋盘纹理
- 玩法层面：解锁 AI 教练、引擎分析、残局创作、开局树等功能
- 每个段位至少解锁 2 个功能/装饰

**UI 设计**：
- 段位徽章：每级有独特视觉设计
- 段位进度条：显示当前段位 → 下一级进度
- 段位特权页：展示各级特权列表（已解锁/未解锁）

### 6.2 成就系统

**成就分类**（34 个）：
- 铜成就 × 8：新手期完成（初出茅庐、残局入门、棋规初知等）
- 银成就 × 8：持续游玩完成（棋力精进、残局高手、连胜 10 局等）
- 金成就 × 8：需要技巧（大师杀手、残局大师、逆转胜等）
- 钻石成就 × 5：极难（棋圣之路、残局全通、完美对局等）
- 隐藏成就 × 5：发现型（天降神兵、闪电战、轮回等）

**数据模型**：
```swift
struct Achievement: Identifiable {
    let id: AchievementID
    let title: String
    let description: String
    let rarity: AchievementRarity  // .bronze, .silver, .gold, .diamond, .hidden
    let condition: AchievementCondition
    let reward: AchievementReward?
}

enum AchievementCondition {
    case totalWins(count: Int)
    case consecutiveWins(count: Int)
    case puzzlesSolved(count: Int)
    case reachRank(PlayerRank)
    case difficultyWins(difficulty: AIDifficulty, count: Int)
    case special(SpecialCondition)
}

enum AchievementReward {
    case unlockTheme(String)
    case unlockFeature(String)
    case achievementPoints(Int)
}
```

**解锁交互**：
- 全屏弹窗 + 特效 + 音效
- 银成就以上附带"分享"按钮
- 钻石成就解锁专属主题
- 成就页面：已解锁/总数 + 进度条

**检测机制**：
- 事件驱动：每次对局结束、残局通关、段位变更时检查成就
- `AchievementManager.checkAll(profile:)` 遍历未解锁成就条件

### 6.3 数据持久化

```swift
@Observable
class PlayerProfile {
    var rank: PlayerRank
    var totalWins: [AIDifficulty: Int]
    var totalPuzzlesSolved: Int
    var unlockedThemes: Set<String>
    var achievements: Set<AchievementID>
    var dailyStreak: Int
    var lastLoginDate: Date?
    var completedTutorials: Set<TutorialID>
    var dailyChallengeHistory: [String: DailyResult]
    var puzzleMistakes: [String]
    var minEvalScore: Int
    var coachLessonsCompleted: Int
    var openingBookmarks: [String]
}
```

**存储方案**：UserDefaults + Codable，年增 ~30KB，UserDefaults 舒适区内。

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `Models/PlayerProfile.swift` | **新增/扩展** | 核心玩家数据模型 |
| `Models/Achievement.swift` | **新增** | 成就数据模型 |
| `Services/PlayerProfileStore.swift` | **新增** | UserDefaults 持久化 |
| `Services/AchievementManager.swift` | **新增** | 成就检测与解锁逻辑 |
| `ViewModels/PlayerProfileViewModel.swift` | **新增** | 段位/成就 UI 状态 |
| `Views/AchievementView.swift` | **新增** | 成就列表页 |
| `Views/RankBadgeView.swift` | **新增** | 段位徽章组件 |
| `Views/Settings/` 相关文件 | **修改** | 接入段位展示 |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| 段位升级 | 7 级段位可正确升降（实际只升不降） | 模拟各种获胜条件 |
| 段位特权 | 每级特权正确解锁对应功能/装饰 | 逐级验证 |
| 成就解锁 | 34 个成就均可正常解锁 | 模拟触发各成就条件 |
| 成就弹窗 | 解锁时有全屏弹窗 + 特效 | 手动触发验证 |
| 数据持久化 | App 重启后段位/成就数据不丢失 | 杀进程后重启验证 |
| UserDefaults 容量 | 年增量 ≤ 50KB | 数据大小测量 |
| 现有测试 | 全部通过 | `swift test` |

---

## 依赖关系

```
Phase 5（新手引导 + PlayerProfile 基础）
  └── Phase 6（本阶段：段位 + 成就）
        ├── 输出 → Phase 7（每日挑战：段位特权解锁每日模式高级版）
        ├── 输出 → Phase 7（残局通关触发成就）
        ├── 输出 → Phase 8（主题经济：段位/成就关联解锁主题）
        └── 可并行 ← Phase 2/3（AI 工作）
```

**并行标记**：
- Phase 6 内部：段位系统先于成就系统（成就条件依赖段位枚举）
- Phase 6 与 AI 工作线完全并行
- Phase 6 依赖 Phase 5 的 `PlayerProfile` 模型基础
