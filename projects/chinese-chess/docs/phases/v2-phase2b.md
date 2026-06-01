# Phase 2b: AI 高级算法

> **通用设计见 v2-common.md**,本文件仅包含 Phase 2b 特定的设计细节和交付物。

- **Phase**: 2b — AI 高级算法
- **依赖**: Phase 2a（Zobrist、置换表、走法排序、开局库）
- **验证**: `swift build` + `swift test`（AI 高级算法单元测试通过）
- **工期**: 3 天

---

## Phase 2b 交付物

1. `CheckmateSearch.swift`(连将杀搜索)
2. `PatternRecognizer.swift`(棋型识别)
3. `EndgameEvaluator.swift`(残局精确估值)
4. `TimeManager.swift`(时间管理)
5. `AIEngine.swift` 补充:高级/大师难度完整实现
6. AI 高级算法单元测试(杀法搜索、残局评估、时间管理)

## 验证标准

- 5 级 AI 全部可完成完整对局
- 高级 AI 能找到基本杀法
- 大师 AI 残局(≤6 子)估值合理
- 时间管理:高级 ≤ 3s,大师 ≤ 5s

---

## 3. AI 引擎升级方案（Phase 2b: 3.5-3.10）

### 3.5 杀法搜索(CheckmateSearch.swift)

**核心思路**:只搜索"连续将军"的走法序列,搜索空间远小于全搜索,可深入 6-8 层。

#### 基础版(高级 + 大师难度)

只搜连将链--攻击方每步必须是将军,找到一条将军链导致对方无合法走法即判定为杀:

```swift
struct CheckmateSearch {
    /// 搜索连将杀。返回杀法走法序列(如果找到),否则 nil。
    static func search(board: Board, for side: Side, maxDepth: Int) -> [Move]?

    /// 内部递归:只扩展将军走法(基础版)
    /// 逻辑:对 side 的每个将军走法,执行后检查对方是否被将死。
    /// 如果对方无合法走法 → 将死,返回成功。
    /// 如果对方有合法走法 → 对每个应将走法,递归继续搜 side 的将军走法。
    /// 注意:基础版中只要找到"存在一条将军链导致将死"即返回,不验证所有应将分支。
    /// 这意味着可能返回"伪杀"(对方有防守但没搜到),但实战中够用。
    private static func dfs(
        board: Board, side: Side, depth: Int, maxDepth: Int, path: inout [Move]
    ) -> Bool
}
```

**参数**:
- 高级:maxDepth = 6,超时 500ms
- 大师:maxDepth = 8,超时 800ms

#### 增强版(大师难度可选,标注为 v2.0 可选增强)

在基础版之上,验证所有应将分支(AND-OR 树搜索):只有对方**所有**应将走法都导致我方成功,才判定为确定杀。深度可达 12 层,但搜索空间显著增大。

```swift
/// 确定杀搜索(大师级增强,可选)
/// 与基础版的区别:基础版搜到一条杀线就返回,确定杀要求所有应将都失败
private static func provenDfs(
    board: Board, side: Side, depth: Int, maxDepth: Int, path: inout [Move]
) -> Bool
```

**建议**:先实现基础版通过测试,增强版作为时间允许的加分项。

**与主搜索的协作**:
1. 主搜索开始前,先执行 `CheckmateSearch`
2. 如果找到杀,直接返回杀法走法
3. 如果没找到或超时,继续主搜索

### 3.6 棋型识别(PatternRecognizer.swift)

识别已知的胜势棋型,给评估函数加分:

```swift
struct PatternRecognizer {
    enum Pattern {
        case singleChariotWin      // 单车胜(车 vs 无防守子)
        case doubleChariotCrush    // 双车错
        case horseCannon           // 马后炮
        case fishingHorse          // 钓鱼马
        case ironGate              // 铁门栓
        case seaBottomMoon         // 海底捞月
    }

    /// 识别当前局面中的棋型,返回加分
    static func bonusPatterns(on board: Board, for side: Side) -> Int {
        var bonus = 0
        // 检查各种棋型...
        return bonus
    }
}
```

**识别逻辑**:
- 按棋子组合过滤:只有场上存在特定子力组合时才检查
- 例如"马后炮":检查是否有马+炮在同一纵线,炮在马后方,对方将/帅在炮后
- 加分范围:+500 到 +2000(根据棋型确定性和距离胜利的接近程度)
- **理由**:车=900、炮=450、马=400 的子力价值尺度下,50-300 的加分几乎不影响 minimax 评估结果(会被一个吃子的价值差覆盖)。500-2000 才能在子力评估的基础上产生明显的引导效果。例如"马后炮"确定杀型 +2000(超过一个车的价值),让 AI 在子力劣势但存在杀型时仍选择进攻;"单车胜"开放局面 +800(接近一个炮的价值),引导 AI 向胜势方向走。
- **降级方案**:如果实测中发现棋型识别加分导致搜索不稳定(偶尔误导),将其降为 P2,大师难度才启用

### 3.7 残局精确估值(EndgameEvaluator.swift)

当场上总子力 ≤ 6 时,启用精确残局评估替代通用评估:

```swift
struct EndgameEvaluator {
    /// 残局精确评估。返回相对于 side 的分数。
    static func evaluate(board: Board, for side: Side) -> Int? {
        let totalPieces = board.pieces.count
        guard totalPieces <= 6 else { return nil }

        // 按双方子力组合匹配残局规则
        let redPieces = classifyPieces(board.pieces(for: .red))
        let blackPieces = classifyPieces(board.pieces(for: .black))

        return lookupScore(red: redPieces, black: blackPieces, board: board, for: side)
    }

    // 内置规则表
    private static let endgameRules: [EndgameRule] = [
        // 车类
        .init(redPattern: [.chariot], blackPattern: [], redScore: 8000),
        .init(redPattern: [.chariot], blackPattern: [.horse], redScore: 6000),
        .init(redPattern: [.chariot], blackPattern: [.cannon], redScore: 5500),
        .init(redPattern: [.chariot], blackPattern: [.advisor, .elephant], redScore: 4000),
        // 马炮类
        .init(redPattern: [.horse, .cannon], blackPattern: [.horse], redScore: 3000),
        // 双车类
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot], redScore: 5000),
        // ... 约 20 条规则
    ]
}
```

**注意**:这是一个规则匹配系统,不是数据库查表。真正的精确残局数据库(如 Syzygy)超出 v2.0 范围。规则匹配已能显著提升残局质量。

### 3.8 时间管理(TimeManager.swift)

```swift
struct TimeManager {
    let timeLimitMs: Int     // 总时间限制
    let startTime: Date

    var elapsedMs: Int { ... }
    var shouldStop: Bool { elapsedMs >= timeLimitMs }

    /// 根据难度创建
    static func forDifficulty(_ difficulty: AIDifficulty) -> TimeManager? {
        switch difficulty {
        case .beginner, .easy: return nil           // 无时间限制
        case .medium:        return nil              // 无时间限制
        case .hard:          return TimeManager(timeLimitMs: 3000)
        case .master:        return TimeManager(timeLimitMs: 5000)
        }
    }
}
```

在迭代加深的每一层开始前检查 `shouldStop`,超时则立即返回当前最优。

### 3.9 AI 评估函数视角约定

**约定:评估函数始终返回相对于传入 `side` 参数的分数。正值 = 该方优势,负值 = 该方劣势。**

v1.0 的 `evaluate(_ board: Board) -> Int` 是黑方视角(正值有利于黑方),在 minimax 中 `isMaximizing=true` 对应黑方。这个约定在人机模式(AI 固定执黑)下没问题。

v2.0 残局模式中 AI 可能执红(防守方),需要统一处理。修改评估函数签名:

```swift
// v1.0 签名(黑方视角,内部使用)
private func evaluateRaw(_ board: Board) -> Int  // 正值有利于黑方

// v2.0 公开接口(相对视角)
func evaluate(board: Board, for side: Side) -> Int {
    let raw = evaluateRaw(board)
    return (side == .black) ? raw : -raw
}
```

**minimax 约定**:`isMaximizing=true` 始终对应 `side` 参数(AI 正在计算的一方):
- 人机模式 AI 执黑 → `isMaximizing=true` 对应黑方 → `evaluateRaw` 正值 ✅
- 残局模式 AI 执红 → `isMaximizing=true` 对应红方 → `evaluate(for: .red)` 取反 → 正值代表红方优势 ✅

**CheckmateSearch 约定**:`search(board:, for: side)` 搜索 side 方的连将杀。评估始终用 `evaluate(board, for: side)`。

**EndgameEvaluator 约定**:返回值相对于传入的 `side` 参数(正值 = side 方优势)。

### 3.10 AIEngine 协议不变

```swift
protocol AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}
```

`AIEngine.bestMove` 内部根据 `AIDifficulty` 分派到不同的搜索策略,外部调用方式不变。

**新增残局重载**(可选):

```swift
protocol AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
    func bestMove(for board: Board, as side: Side, difficulty: AIDifficulty) -> Move?
}
```

第二个重载明确指定 AI 执哪方,残局模式使用。默认实现中 `as side` 版本调整 minimax 的 isMaximizing 语义。

---

### 3.1.4 高级(Hard)（Phase 2b 实现部分）

**算法**:Minimax depth=6 + 迭代加深 + 杀法搜索 + 棋型识别

**逻辑**:
1. 迭代加深:从 depth=2 开始,逐步加深到 depth=6
2. 时间限制 3 秒(`TimeManager`),超时返回当前最优
3. **杀法搜索**:在主搜索前执行 `CheckmateSearch`,如果找到连将杀(depth ≤ 10),直接返回
4. **棋型识别**:`PatternRecognizer` 识别基础杀型(单车胜、马后炮、双车错等),给评估加分
5. 置换表 + 走法排序(将军 > 吃子 > 威胁子力 > 其他)
6. 残局阶段(≤10 子)搜索深度 +1

**新增依赖**:CheckmateSearch, PatternRecognizer, TimeManager

### 3.1.5 大师(Master)（Phase 2b 实现部分）

**算法**:depth=6+ + 深层杀法搜索 + 残局精确估值 + 时间管理

**逻辑**:
1. 基础搜索深度 6,残局(≤10 子)提升到 7-8
2. **杀法搜索** depth 可到 12 层(只搜将军链,搜索空间远小于全搜索)
3. **残局精确估值**(≤6 子):`EndgameEvaluator` 用精确的残局评估替代通用评估
   - 单车对单马/单炮:车方 +300
   - 单马对单士:和棋判定
   - 双车对单车:+500
   - 内置约 20 种常见残局评估规则
4. 时间限制 5 秒
5. 置换表容量加大(大师级独立配置)
6. 迭代加深 + 历史启发(killer move)

**新增依赖**:EndgameEvaluator
