# D1-子3 AI 引擎逻辑审计

**审计人**: Alex（架构师）
**审计日期**: 2026-07-09
**审计版本**: v3.9
**与原 D1 报告关系**: 深化复审，新发现 P0×1、P1×3、P2×4 项

---

## 审计范围

| 文件 | 行数 | 审计重点 |
|------|------|----------|
| `AIEngine.swift` | ~700 | negamax/PVS/ID 框架、LMR、null move |
| `AIEvaluator.swift` | ~80 | 评估函数主入口 |
| `EvalWeights.swift` | ~190 | 权重参数化 |
| `EvalConfigManager.swift` | ~90 | 权重加载/热重载 |
| `MoveOrderer.swift` | ~230 | 走法排序（TT/killer/countermove） |
| `TranspositionTable.swift` | ~140 | 双桶置换表 |
| `AIConstants.swift` | ~110 | 搜索配置（难度映射） |
| `EngineRouter.swift` | ~100 | 引擎切换/fallback |
| `EmbeddedPikafishEngine.swift` | ~250 | Pikafish C API 集成 |
| `TimeManager.swift` | ~110 | 时间管理/复杂度评估 |
| `EndgameEvaluator.swift` | ~170 | 残局精确估值 |
| `KingSafetyEvaluator.swift` | ~200 | 将帅安全 + 机动性 |
| `PositionAnalyzer.swift` | ~160 | 走法质量分析 |
| `PositionTables.swift` | ~130 | 位置权重表 |

补充审查：`PatternRecognizer.swift`（~380 行）、`UCIMoveConverter.swift`（~80 行）、`EngineProtocol.swift`（~50 行）。

---

## 搜索算法验证

### 1. Negamax + Alpha-Beta 核心

**框架正确**。标准 negamax 公式 `score = -negamax(..., alpha: -beta, beta: -alpha, ...)` 符号正确。alpha-bata 剪枝条件 `a >= beta → break` 正确。TT 存储的 flag 判定 `upper/exact/lower` 正确。

### 2. PVS（Principal Variation Search）

rootSearch 和 negamax 中的 PVS 实现均正确：
- 第一步走法用全窗口搜索
- 后续走法用零窗口 `[-a-1, -a]`
- 若零窗口搜索结果 `> a && < beta`，重搜全窗口

**注意**：negamax 中的 PVS 正确使用运行 alpha `a`，而 LMR 的重搜条件使用原始 alpha `alpha`（见 P2-1）。

### 3. Null Move Pruning

```swift
board.toggleTurn()
let nullHash = hash ^ ZobristHash.sideHash
let nullScore = -negamax(board: board, depth: depth - 1 - R,
                          alpha: -beta, beta: -beta + 1, ...)
board.toggleTurn()
if nullScore >= beta { return beta }
```

实现正确。`R` 值自适应（depth≥6 时 R=3，否则 R=2，无 fix 时恒 R=3）。前置检查 `!isInCheck` 和 `shouldDisableNullMove`（子力不足/马跳将军时禁用）合理。

**Zobrist 增量更新正确**：`toggleTurn` 仅影响行走方，异或 `sideHash` 即可。

### 4. Zobrist 增量哈希

`update(hash:piece:from:to:captured:)` 的实现正确：
- XOR 移除旧位置 → XOR 添加新位置 → XOR 被吃棋子 → XOR sideHash
- 走完后 `board.snapshot()` + `ZobristHash.hash()` 全量重算值与增量值一致（代码注释 #7 表明已验证）

---

## 评估函数分析

### 1. 子力价值

| 棋子 | 开局 | 残局 | 评价 |
|------|------|------|------|
| 将/帅 | 10000 | 10000 | ✅ 极高值防丢失 |
| 车 | 900 | 900 | ✅ 标准 |
| 马 | 400 | 450 | ✅ 残局马优于炮 |
| 炮 | 450 | 400 | ✅ 残局炮劣于马 |
| 士 | 200 | 150（×3/4） | ✅ 残局贬值 |
| 象 | 200 | 100（×1/2） | ✅ 残局大幅贬值 |
| 兵（未过河） | 100 | 100-300 | ✅ 合理梯度 |

`AIEvaluator.dynamicValue` 的残局调整逻辑正确，但与 `Piece.baseValue` 的过河兵翻倍存在叠加（见 P2-3）。

### 2. 位置权重表

**兵/卒表异常**（见 P1-3）：`blackSoldierWeightsOpening` 中 row 7 → row 8 的值从 360-2160 暴跌至 30-120，跌幅 18 倍。虽然到达底线附近后机动性下降是合理的，但跌幅过大可能导致 AI 在推进到制胜位置时反而降低评估。

**马/车/炮表**：对称性好，中心高、边缘低，符合中国象棋的位置价值。

### 3. 评估函数组合

```swift
return sign * (Int(Double(materialScore) * w.materialWeight)
    + Int(Double(positionScore) * w.positionWeight)
    + Int(Double(patternBonus) * w.patternWeight)
    + Int(Double(mobilityBonus) * w.mobilityWeight)
    + Int(Double(safetyBonus) * w.safetyWeight))
```

**符号正确**：`sign` 为黑方 +1 / 红方 -1，统一以当前行走方视角返回正值。各分量已分别按黑方-红方差值计算，方向一致。

**潜在问题**：各分量的绝对值范围差异大（material 可达 ±10000，position ±5000，pattern ±5000，mobility ±500，safety ±1000），即使权重都是 1.0，实际贡献比也可能失衡。不过通过 CMA-ES 调参可缓解。

### 4. EndgameEvaluator

50 种残局规则的 `redPattern`/`blackPattern` 匹配使用 `Dictionary<PieceKind, Int>` 计数比较，正确支持多枚同种棋子。

**局限**：纯子力组合匹配，不考虑具体位置。例如"单车胜单将"固定返回 8000，但如果车在角落、将在中路，实际可能需要很多步才能将杀。这会让 AI 在残局中低估某些防守位置。

### 5. PatternRecognizer

30+ 种棋型识别覆盖面广。但部分判定函数（如 `tandemCannonBonus`）不检查中间是否有对方棋子，纯靠位置距离判定，存在误判。

---

## 难度梯度评估

### 搜索深度与优化配置对比

| 特性 | beginner | easy | medium | hard | master |
|------|----------|------|--------|------|--------|
| 搜索深度 | 1 / 随机 | 3 | 6-7 ID | 6-7 ID | 7-10 ID |
| 时间限制 | 无 | 无 | 3s | 5s | 10s |
| QS | ❌ | ❌ | ❌ | ✅ depth=4 | ✅ depth=6 |
| 评估配置 | basic | basic | **basic** | **advanced** | advanced |
| 杀棋搜索 | ❌ | ❌ | ❌ | 12 步 | 16 步 |
| 优化项 | 0 | 2 | 1 | **11** | **12** |

### 断崖分析

medium → hard 是**质变**：

1. **评估配置从 basic 跳到 advanced**：basic 不启动机动性评估（`mobilityWeight=0`），advanced 全面启用。这意味着 medium 的评估只看子力 + 位置 + 棋型 + 王安全，完全不考虑棋子活动空间。两台深度相同的引擎，一台有机动性评估一台没有，棋力差距可达 200-300 Elo。

2. **QS 从无到有**：medium 的搜索末端全是静态评估（horizon effect 严重），hard 的 QS depth=4 能看到 4 步吃子/将军序列。这在战术局面中差距巨大。

3. **优化项从 1 个跳到 11 个**：killer move、check extension、null move fix、LMR、PVS、countermove、futility、razoring、IID——这些优化组合在一起，在相同深度下能多搜索 30-50% 的有效节点（通过更精准的剪枝和排序）。

4. **杀棋搜索**：hard 额外做 12 步连将杀搜索（最多 1.2s），medium 没有。在杀棋局面中 hard 能直接找到杀法，medium 可能错过。

**结论**：medium 与 hard 之间的实际棋力差距估计在 **400-600 Elo**，远超相邻难度级别的合理差距（100-200 Elo）。Vera 在 D2-P1-1 的判断完全正确。

### Pikafish 难度映射对比

| 难度 | Pikafish depth | Pikafish time | 自研 depth |
|------|---------------|---------------|-----------|
| beginner | 2 | 500ms | 1 |
| easy | 5 | 1000ms | 3 |
| medium | 10 | 2000ms | 6-7 |
| hard | 18 | 3000ms | 6-7 |
| master | 24 | 5000ms | 7-10 |

Pikafish 的映射更平滑。当 Pikafish 可用时，难度断崖问题自然缓解（Pikafish depth 10→18 的差距比自研引擎的断崖小得多）。但 fallback 到自研引擎时，断崖问题完全暴露。

---

## 发现的问题（P0-P3 分级）

### P0 — 严重错误，影响搜索正确性

#### P0-1: `isTerminal` 拦截了正确的将死/困毙判定，返回错误的评估值

**文件**: `AIEngine.swift` → `negamax()`

**问题**：negamax 中有两处检查终局：

```swift
// 第一处（约 negamax 入口 +20 行）—— 错误
if isTerminal(board) {
    return evaluator.evaluate(board, config: evalCfg)  // ← 返回材质分！
}

// ... depth <= 0 检查 ...
// ... null move pruning ...

// 第二处（约 negamax 中段）—— 正确但永远不会被到达
var moves = MoveValidator.allLegalMoves(for: side, on: board)
if moves.isEmpty {
    let score = MoveValidator.isInCheck(side, on: board) ? (-100000 - depth) : 0
    // ← 正确：被将死返回极低分，困毙返回 0
    ...
    return score
}
```

`isTerminal(board)` 内部调用 `MoveValidator.allLegalMoves(for: side, on: board).isEmpty`，与第二处检查完全相同。当一方无合法走法时（被将死或困毙），第一处拦截返回 `evaluator.evaluate`（材质分），第二处正确的将死/困毙分数**永远不会执行**。

**后果**：

| 场景 | 正确行为 | 实际行为 |
|------|----------|----------|
| 将死（被将死方视角） | 返回 -100000-depth | 返回材质分（可能为正值） |
| 困毙 | 返回 0 | 返回材质分 |

1. **AI 不知道自己将死了对手**：将死位置返回的只是材质分（如 +300），而非 +100000。AI 可能选择吃子而非将死。
2. **AI 不知道自己被将死**：被将死的位置返回材质分（如 -200），而非 -100000。AI 不会优先防守 forced mate。
3. **TT 污染**：错误的终局分数被存入置换表，影响后续搜索。

**影响范围**：所有启用 TT 的难度（easy 以上）。beginner 不进 negamax（depth=1 直接 rootSearch），但 easy 的 depth=3 已经会触发此 bug。

**修复**：

```swift
// 方案 A：删除 isTerminal 检查（让第二处正确逻辑生效）
// 删除:
// if isTerminal(board) {
//     return evaluator.evaluate(board, config: evalCfg)
// }

// 方案 B：修正 isTerminal 的返回值
if isTerminal(board) {
    let score = MoveValidator.isInCheck(side, on: board) ? (-100000 - depth) : 0
    if useTT {
        transpositionTable.store(hash: hash, depth: depth, score: score, flag: .exact, bestMove: nil)
    }
    return score
}
```

方案 B 更好——保留在 depth ≤ 0 之前的终局检测（让叶子节点也能正确识别将死），同时返回正确的分数。

---

### P1 — 重要问题

#### P1-1: LMR 重搜条件使用原始 alpha 而非运行 alpha，导致不必要的重搜

**文件**: `AIEngine.swift` → `negamax()`

```swift
if shouldReduce {
    let reducedScore = -negamax(..., alpha: -beta, beta: -alpha, ...)
    if reducedScore > alpha {  // ← 应为 > a
        score = -negamax(..., alpha: -beta, beta: -a, ...)
    } else {
        score = reducedScore
    }
}
```

**问题**：`alpha` 是传入的原始值（origAlpha），`a` 是运行中更新的当前最佳值。当 `reducedScore` 大于原始 alpha 但小于当前 `a` 时，说明这步棋比初始阈值好但不如已找到的最佳走法——此时不需要重搜。当前代码会做不必要的全深度搜索。

**对比 PVS**：同一函数中的 PVS 分支正确使用 `nullWindowScore > a`，说明这是笔误而非设计意图。

**影响**：不产生错误结果，但在中局搜索中约 5-10% 的节点会做无用重搜，相当于浪费一层深度。

**修复**：`if reducedScore > a {` 即可。

---

#### P1-2: quiescenceSearch 中 checkMoves 的检测对每个候选走法做 execute/undo

**文件**: `AIEngine.swift` → `quiescenceSearch()`

```swift
let checkMoves = allMoves.filter { move in
    board.execute(move)
    let givesCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
    _ = board.undoLastMove()
    return givesCheck
}
```

**问题**：对所有合法走法（不只是吃子走法）做 execute → isInCheck → undo，性能开销极大。`isInCheck` 内部遍历对方所有棋子做 `canAttack`，每次约 10-15 次棋子检查。假设 35 个合法走法，QS 的前置开销约 35 × 15 = 525 次操作——这还不算 `allLegalMoves` 本身的 `wouldBeInCheck` 开销。

**量化影响**：在 hard 难度的搜索树中，QS 节点约占总节点数的 40-60%。每个 QS 节点浪费的时间约占总时间的 30%。等效于搜索深度减少 0.5-1 层。

**修复建议**：
1. 只对吃子走法检测是否同时将军（而非对所有走法检测将军）
2. 或者完全移除 checkMoves——标准 QS 只搜吃子走法，将军走法的扩展在大多数引擎中是可选的

---

#### P1-3: 兵/卒位置权重表在 row 7→8 断崖式下跌

**文件**: `PositionTables.swift` → `blackSoldierWeightsOpening`

```swift
// row 7（接近对方底线）：360, 660, 1020, 1440, 2160, 1440, 1020, 660, 360
// row 8（对方倒数第二行）：30, 90, 120, 120, 120, 120, 120, 90, 30
```

兵从 row 7 推进到 row 8（更接近对方将帅），位置权重暴跌 18 倍。这意味着 AI 会**主动避免**把兵推进到最后两行，即使在某些局面中这是制胜走法。

**原因分析**：可能模仿"兵到底线价值下降"的国际象棋理念，但中国象棋的兵到底线只是不能前进，仍可横走。且 row 8 距离将帅（row 9 九宫中心）仅一步之遥，威胁巨大。

**修复建议**：row 8 应保持 row 7 的 50-70% 价值（如中心位 800-1200），row 9 可降至 30-50%。

---

#### P1-4: `PositionAnalyzer.analyzeMove` 的 playerEval fallback 逻辑符号错误

**文件**: `PositionAnalyzer.swift` → `analyzeMove()`

```swift
let playerLine = await evaluate(fen: fenBefore, moveHistory: afterHistory)
let playerEval = playerLine?.scoreCp ?? bestEval  // ← fallback 使用 bestEval
let adjustedPlayerEval = -playerEval
```

**问题**：`bestEval` 是走棋前局面的评估（玩家视角），而 `playerEval` 应该是走棋后局面的评估（对手视角）。当 `playerLine` 为 nil 时，fallback 到 `bestEval`（玩家视角），然后取反变成 `-bestEval`（对手视角），这在语义上是"假设玩家没走棋"——但实际上玩家已经走了。

**实际影响**：当 Pikafish 不可用（回退自研引擎）时，`evaluate` 返回 nil，fallback 触发。但此时 `topMoves` 也返回空数组，`guard let bestLine = lines.first` 已提前返回 nil。所以这个 fallback 路径在实际运行中几乎不可达。但如果未来添加了自研引擎的分析接口，此 bug 会暴露。

---

### P2 — 改进建议

#### P2-1: Razoring 实现偏离标准做法

**文件**: `AIEngine.swift` → `negamax()` Razoring 段

当前实现在 `staticEval + margin ≤ alpha` 时返回 QS 分数，但标准 Razoring 应在 depth-1 做一次完整搜索（而非 QS）。当前实现更像"静态 null move pruning"。效果接近，但理论上更不精确。

---

#### P2-2: `TimeManager.positionComplexity` 每次调用 `allLegalMoves`

**文件**: `TimeManager.swift` → `positionComplexity()`

```swift
let moves = MoveValidator.allLegalMoves(for: side, on: board)
let captureCount = moves.filter { $0.captured != nil }.count
```

为计算吃子走法数量，生成了全部合法走法（含 `wouldBeInCheck` 的深拷贝）。这在 `bestMove` 入口调用一次，开销约 10-20ms。可用更轻量的估算（遍历棋盘检查相邻位置）替代。

---

#### P2-3: `Piece.baseValue` 的过河兵翻倍与 `dynamicValue` 的残局翻倍叠加

**文件**: `Piece.swift` + `AIEvaluator.swift`

`Piece.baseValue`：过河兵返回 200（未过河 100）。
`AIEvaluator.dynamicValue`：残局过河兵返回 `base * 2 = 400`。

两层翻倍导致残局过河兵价值 = 400，接近马的价值（450）。这在某些残局中可能高估过河兵的价值。但也可能是有意设计——残局过河兵确实非常强大。**建议确认设计意图**。

---

#### P2-4: `EngineRouter.newGame()` 使用 fire-and-forget Task，存在竞态

**文件**: `EngineRouter.swift` → `newGame()`

```swift
func newGame() {
    Task { await nativeEngine.newGame() }
    if let emb = embeddedEngine {
        Task { await emb.newGame() }
    }
}
```

如果 `bestMove` 在 `newGame` 之后立即调用，`clearHistory()` 可能在 `bestMove` 搜索过程中执行，导致 moveOrderer 的历史表/killer 表在中途被清空。不会产生错误走法（TT hash 验证保护），但会影响走法排序质量。

**修复**：改为 `async func newGame() async`，调用方 await。

---

### P3 — 微小问题

#### P3-1: `lmrReduction` 的 reduction 阈值偏保守

```swift
if depth >= 6 && moveIndex >= 8 { return 3 }
if depth >= 4 && moveIndex >= 6 { return 2 }
if moveIndex >= 4 { return 1 }
return 0
```

标准 LMR 公式通常更激进（如 depth >= 3 && moveIndex >= 3 就开始减）。当前阈值在 depth 4 以下完全不减，可能错过减枝机会。

---

#### P3-2: `MoveOrderer.threatBonus` 炮威胁不计算翻山

```swift
case .cannon:
    for target in opponentPieces where target.baseValue >= 300 {
        if target.position.col == move.to.col || target.position.row == move.to.row {
            bonus += target.baseValue / 10
        }
    }
```

炮的攻击需要炮架，这里只检查同行/同列，不检查中间是否有棋子。会高估炮的威胁范围，导致走法排序偏差。影响极小（只是排序启发）。

---

#### P3-3: Pikafish `mapDifficulty` 的 depth 映射对 beginner 过弱

beginner → Pikafish depth 2。Pikafish depth 2 在中国象棋中基本等于随机走法——可能比自研引擎的 beginner（30% 概率搜索 + 70% 安全随机）还弱。如果用户选 beginner 对战 Pikafish，可能会觉得"太蠢了"。但也可能符合 beginner 的定位（纯新手）。**建议确认体验**。

---

## 性能影响量化

### 原有 D1 发现的问题量化

| 问题 | 原描述 | 深入量化 |
|------|--------|----------|
| `wouldBeInCheck` snapshot 深拷贝 | "性能热点" | 每次 `isLegal` 调用拷贝全部 32 个 Piece 结构体。以 30 个候选走法、每个做一次 snapshot 计，单次 `allLegalMoves` 约 960 次结构体拷贝。在 depth 6 的搜索树中，`allLegalMoves` 被调用约 50,000-100,000 次，总拷贝约 5000 万次。**估计减少搜索深度 0.5-1 层**。 |
| `quiescenceSearch` 全量走法生成 | "性能瓶颈" | QS 节点占总节点 40-60%。每个 QS 节点的 `allLegalMoves` 开销与普通节点相同（因为 `wouldBeInCheck` 不过滤）。**估计减少搜索深度 0.5 层**。 |

### 新发现问题量化

| 问题 | 估计影响 |
|------|----------|
| P0-1: isTerminal 返回错误分数 | **正确性影响**：AI 不识别 forced mate，可能错过 3-5 步杀。在 TT 中存入错误值，扩散影响范围。 |
| P1-1: LMR 不必要重搜 | **性能影响**：约 5-10% 节点做无用功。等效深度损失约 0.2 层。 |
| P1-2: QS checkMoves 检测 | **性能影响**：每个 QS 节点额外 35 次 execute/undo + isInCheck。等效深度损失约 0.3 层。 |

### 综合深度损失估算

以 hard 难度（目标 depth 6-7）为例：

| 因素 | 深度损失 |
|------|----------|
| wouldBeInCheck snapshot | -0.5 ~ -1.0 |
| QS 全量走法生成 | -0.5 |
| QS checkMoves 检测 | -0.3 |
| LMR 不必要重搜 | -0.2 |
| **合计** | **-1.5 ~ -2.0** |

即理论可达 depth 8-9 的搜索能力，实际只到 depth 6-7。在 medium（无 QS、无 LMR）影响更大——medium 的搜索深度本就只有 6-7，性能损失后可能实际只有 4-5。

---

## 总结

### 搜索算法正确性

| 模块 | 判定 |
|------|------|
| Negamax 框架 | ✅ 正确 |
| PVS | ✅ 正确 |
| Alpha-Beta 剪枝 | ✅ 正确 |
| Null Move Pruning | ✅ 正确 |
| Zobrist 增量哈希 | ✅ 正确 |
| **isTerminal 终局检测** | **❌ P0 错误：返回材质分而非将死分** |
| LMR 重搜条件 | ⚠️ P1：使用原始 alpha 导致多余重搜 |
| Razoring | ⚠️ P2：偏离标准实现 |

### 评估函数正确性

| 模块 | 判定 |
|------|------|
| 子力价值 | ✅ 合理 |
| 残局调整 | ✅ 正确 |
| EndgameEvaluator | ✅ 正确（但仅基于子力组合，不虑位置） |
| 将帅安全评估 | ✅ 全面 |
| **兵/卒位置表 row 7→8** | **⚠️ P1：断崖式下跌不合理** |
| PatternRecognizer | ⚠️ P3：部分判定过于简化 |

### 难度梯度

| 跳跃点 | 问题 | 估计 Elo 差距 |
|--------|------|--------------|
| easy → medium | 从无 ID 到 ID depth 6-7 + killer move | ~150 Elo ✅ 合理 |
| **medium → hard** | **0→11 优化项 + basic→advanced eval + 无 QS→QS depth=4 + 杀棋搜索** | **~400-600 Elo ❌ 断崖** |
| hard → master | depth +1-3 + smartTime + QS depth +2 + 杀棋 12→16 步 | ~200-300 Elo ✅ 合理 |

### 核心风险

**P0-1（isTerminal 返回错误分数）是本次审计最严重的发现**。此 bug 让 AI 无法正确识别将死，在包含 forced mate 的局面中可能走出明显错误的走法。修复成本极低（改 3 行代码），但影响面覆盖所有使用 TT 的难度级别。

性能层面，原 D1 报告的 `wouldBeInCheck` 和 `quiescenceSearch` 问题合计造成约 1-2 层搜索深度损失。如果修复 P0-1 + 优化 QS 走法生成 + 改用 in-place execute/undo，自研引擎的有效搜索深度可提升 1.5-2 层，棋力估计提升 150-300 Elo。
