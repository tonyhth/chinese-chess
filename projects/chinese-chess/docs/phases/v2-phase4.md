# Phase 4: 残局闯关 + 回放

> **通用设计见 v2-common.md**,本文件仅包含 Phase 4 特定的设计细节和交付物。

- **Phase**: 4 — 残局闯关 + 回放
- **依赖**: Phase 1（FEN 解析）+ Phase 3（棋谱记录）
- **验证**: `swift build` + `swift test`（残局 FEN 解析单元测试通过）
- **工期**: 2-3 天

---

## Phase 4 交付物

1. `puzzles.json`(50-100 局残局数据,**由 AI 辅助生成 + 人工验证 FEN 正确性**,作为编码任务的一部分,不单独分配内容制作工时。每个残局必须通过 FEN→Board→验证走法的自动化测试)
2. `PuzzleStore.swift`(残局数据加载)
3. `PuzzleViewModel.swift`(闯关流程状态管理)
4. `PuzzleSelectView.swift`(残局选择界面)
5. 残局闯关完整 UI
6. `ReplayViewModel.swift` + `ReplayControlView.swift`
7. 对局回放功能
8. 残局 FEN 解析单元测试

## 验证标准

- 残局加载、选择、闯关流程完整
- AI 防守方按难度自动应将
- 通关/失败判定正确
- 对局回放控制(前进/后退/跳转/自动播放)正常
- `swift test` 全部通过

---

## 5. 残局数据格式和加载方案（Phase 4 完整内容）

### 5.2 残局数据格式(puzzles.json)

```json
{
  "version": 1,
  "puzzles": [
    {
      "id": "puzzle_001",
      "name": "单车胜双士",
      "category": "单车类",
      "difficulty": 1,
      "stars": 1,
      "description": "红先胜",
      "playerSide": "red",
      "initialFEN": "4k4/4a4/9/9/9/9/9/4R4/9/4K4 w - - 0 1",
      "solution": ["e1e2", "e8d8", "e2e5"],
      "hints": ["车在底线有更大活动空间"],
      "maxMoves": 10
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 唯一标识 |
| name | String | 残局名称 |
| category | String | 分类(单车类、马炮类、双车类...) |
| difficulty | Int | 难度等级 1-4(入门/初级/中级/高级) |
| stars | Int | 显示用星级 1-5 |
| description | String | 简要描述 |
| playerSide | String | 玩家执哪方("red" / "black") |
| initialFEN | String | 初始局面 FEN |
| solution | [String] | 标准答案(ICCS 坐标格式)。中文棋谱由 NotationGenerator 运行时生成,不在数据文件中存储,消除双格式维护不一致风险 |
| hints | [String]? | 走法提示文本 |
| maxMoves | Int | 最长通关步数(超过视为失败) |

### 5.3 残局闯关流程状态管理(PuzzleViewModel.swift)

```swift
@Observable
class PuzzleViewModel {
    let puzzle: Puzzle
    let board: Board                  // 从 FEN 初始化
    let playerSide: Side              // 玩家执哪方

    var moveHistory: [GameMove] = []  // 玩家走法记录
    var gameState: PuzzleState = .playing
    var hintIndex: Int = 0            // 当前提示位置

    enum PuzzleState {
        case playing
        case success                  // 通关
        case failed                   // 超过最大步数或走入死路
        case showingHint              // 显示提示中
    }

    /// 玩家走棋后,AI 自动应将
    func playerMoved(_ move: GameMove) {
        // 1. 执行走法
        // 2. 检查是否将死对方 → success
        // 3. AI(残局的防守方)自动应将
        // 4. 检查是否超过 maxMoves → failed
    }

    /// 残局防守方 AI 算法映射
    /// 残局难度 1-4 对应不同防守强度:
    ///   difficulty 1(入门)→ AIDifficulty.beginner:随机走法,几乎不防守
    ///   difficulty 2(初级)→ AIDifficulty.easy:minimax depth=2,基本防守
    ///   difficulty 3(中级)→ AIDifficulty.medium:depth=4 + 开局库
    ///   difficulty 4(高级)→ AIDifficulty.hard:depth=6 + 杀法搜索
    /// 这样设计的合理性:简单残局的对手也弱,玩家不会觉得"明明是入门题但 AI 疯狂防守"
    private var defenderDifficulty: AIDifficulty {
        switch puzzle.difficulty {
        case 1: return .beginner
        case 2: return .easy
        case 3: return .medium
        case 4: return .hard
        default: return .easy
        }
    }

    /// 无限悔棋
    func undoMove() {
        // 撤销 AI + 玩家各一步
    }

    /// 显示提示
    func showHint() {
        // 根据 hintIndex 从 solution 中取当前步的提示
    }
}
```

#### 答案验证策略

**不要求严格匹配 solution**(因为残局可能有多种解法)。验证逻辑:

1. **成功判定**:玩家走后将死对方 → 通关
2. **失败判定**:超过 maxMoves 未通关 → 失败
3. **提示**:从 solution(ICCS 格式)通过 NotationGenerator 生成中文提示文本,而非验证路径

这样设计允许玩家用不同于标准答案的走法通关,只要最终将死对方即可。

### 5.4 闯关进度持久化

```swift
struct PuzzleProgress: Codable {
    let puzzleId: String
    var isCompleted: Bool
    var bestMoves: Int?          // 最少步数通关
    var completedAt: Date?
}

// 存储在 UserDefaults
// Key: "chinesechess.puzzle_progress"
// Value: [String: PuzzleProgress] (puzzleId → progress)
```

---

## 8. P1 体验提升设计 — 对局回放（Phase 4 相关）

### 对局回放(ReplayViewModel)

```swift
@Observable
class ReplayViewModel {
    let record: GameRecord
    private(set) var board: Board           // 当前棋盘状态
    private(set) var currentIndex: Int = 0  // 当前步数索引(0 = 初始局面)

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < record.moves.count }
    var isAutoPlaying: Bool = false
    var autoPlaySpeed: Double = 1.0         // 秒/步

    func goToStart() { ... }
    func goToEnd() { ... }
    func goForward() { ... }
    func goBack() { ... }
    func toggleAutoPlay() { ... }
    func jumpTo(index: Int) { ... }

    // 内部:根据 record.moves[0..<currentIndex] 从初始 FEN 重建局面
    // 优化:每 20 步存一个 Board 快照,跳转时从最近快照开始重建
    private var snapshots: [Int: Board] = [:]  // index → Board 快照
    private let snapshotInterval = 20

    private func rebuildBoard(upTo index: Int) {
        // 找到最近的快照
        let snapIdx = (index / snapshotInterval) * snapshotInterval
        let startBoard = snapshots[snapIdx] ?? Board(fen: record.initialFEN ?? FENParser.standardInitial)
        // 从 snapIdx 到 index 逐步执行走法
    }

    private func takeSnapshotIfNeeded(at index: Int) {
        if index % snapshotInterval == 0 {
            snapshots[index] = board.snapshot()
        }
    }
}
```

**回放控制条**(`ReplayControlView`):
- 按钮:|← ← ▶/⏸ → →|
- 速度滑块:0.5x / 1x / 2x
- 进度条:可拖拽跳转
