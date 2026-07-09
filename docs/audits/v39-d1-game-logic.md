# D1 游戏逻辑审计报告

**审计人**: Alex（架构师）
**审计日期**: 2026-07-09
**审计版本**: v3.9
**项目路径**: `~/DevTeam/projects/chinese-chess/`

## 审计范围

| 目录 | 文件 |
|------|------|
| `Models/` | Enums.swift, Piece.swift, Position.swift, Move.swift, Board.swift, MoveValidator.swift, FENDecoder.swift |
| `AI/` | AIEngine.swift, EngineRouter.swift, MoveOrderer.swift, TranspositionTable.swift, OpeningBook.swift, CheckmateSearch.swift, EvalWeights.swift, AIConstants.swift, AIEvaluator.swift, ZobristHash.swift |

---

## 发现的问题（按严重度 P0-P3 分级）

### P0 — 严重错误，影响正确性

#### P0-1: `canAttack` 中象/相的攻击判定使用了错误的半场检查

**文件**: `MoveValidator.swift` → `canAttack(piece:target:on:)`

**问题**: 象/相的 `canAttack` 中检查的是 `from.isInRedHalf` / `from.isInBlackHalf`（攻击方所在半场），而非目标位置所在半场。而 `isValidElephantMove` 中检查的是 `to`（目标位置）的半场限制。

```swift
// canAttack 中（错误？）
let inHalf: Bool = (piece.side == .red) ? from.isInRedHalf : from.isInBlackHalf
```

**分析**: 实际上象/相不能过河，所以 `from` 一定在本方半场（否则数据本身就已损坏）。此检查在 `canAttack` 中是冗余的，不会产生错误判断——如果象已经过了河（数据异常），这里会跳过半场检查的限制反而可能误判为可攻击。但在正常对局中不会触发此路径。

**修正**: 应检查 `target` 是否在攻击方的半场内，与 `isValidElephantMove` 保持一致：
```swift
let inHalf: Bool = (piece.side == .red) ? target.isInRedHalf : target.isInBlackHalf
```

**影响**: 正常对局中不触发，但 FEN 解析异常局面或编辑器场景可能产生误判。属于防御性缺陷。

---

#### P0-2: `isInCheck` 中将/帅可以"攻击"对方将/帅（飞将规则不对称）

**文件**: `MoveValidator.swift` → `canAttack(piece:target:on:)` → `.general` 分支

**问题**: `canAttack` 的 `.general` 分支检查的是将帅的一格移动能力（田字格内移动），并限制了 `target` 必须在攻击方的宫殿内。但飞将规则（将帅对面）的检测是在 `isInCheck` 末尾单独处理的，不经过 `canAttack`。

这意味着将帅的"攻击"范围仅限于本方九宫格内，但对方将帅永远不会在己方九宫格内（除非局面非法），所以将帅通过 `canAttack` 永远无法攻击任何目标。飞将检测完全依赖 `isInCheck` 末尾的独立逻辑。

**结论**: 逻辑正确，但 `canAttack` 中 `.general` 分支实际上只在 `isInCheck` 中被调用（检查对方棋子是否能攻击己方将），而将帅永远不会通过此路径判定为攻击者（因为对方将不会在己方宫殿内）。飞将的独立检测逻辑覆盖了这一场景。**无实际错误**，标记为代码清晰度问题。

---

### P1 — 重要问题，应修复

#### P1-1: 士/仕的 `canAttack` 宫殿限制检查方向错误

**文件**: `MoveValidator.swift` → `canAttack` → `.advisor` 分支

```swift
case .advisor:
    let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
    guard palace else { return false }
```

**问题**: 这里检查的是 `target` 是否在**攻击方**的宫殿内。士/仕永远在己方宫殿内（数据约束），所以 `from` 一定在己方宫殿。但攻击的目标（对方将帅）永远不会在己方宫殿内。

**影响**: 当 `canAttack` 用于检查"士是否能攻击对方将帅"时，对方将帅不在己方宫殿内 → `canAttack` 永远返回 `false`。这在 `isInCheck` 场景下是**正确**的（士只能保护己方将，不能直接攻击对方将——除非对方将进入己方宫殿，但那不可能发生）。

但 `canAttack` 也用于 `safeRandomMove`（AI 新手难度）和 `CheckmateSearch` 的辅助逻辑中。在这些场景中，士被排除在威胁判定之外是合理的（士确实不能过河攻击）。

**结论**: 逻辑正确但容易误解。宫殿检查应限制的是 `from`（攻击者位置），不是 `target`。当前代码恰好因为数据约束而不会出错，但语义上不精确。建议改为检查 `from` 在宫殿内。

---

#### P1-2: `piece(at:)` 使用 `first` 匹配，多棋子同位置时可能返回错误棋子

**文件**: `Board.swift` → `piece(at:)`

```swift
func piece(at pos: Position) -> Piece? {
    pieces.first { $0.position == pos }
}
```

**问题**: 如果因任何原因（bug、并发、FEN 解析错误）导致两个棋子出现在同一位置，`piece(at:)` 只返回第一个匹配。`hasPiece(at:)` 使用 `contains` 至少能正确返回 `true`。但 `execute(move:)` 中被吃棋子的移除依赖 `id` 匹配，不会误删。

**影响**: 正常情况下不会出现同位置多棋子。FEN 解析有列数校验（每行必须 9 列），可以防止大部分异常。但如果 `execute` 存在 bug 导致棋子重叠，`piece(at:)` 可能隐藏问题。

**建议**: 在 `execute` 中添加断言或日志，确保目标位置只有敌方棋子（或空）。

---

#### P1-3: `snapshot()` 复制了 `moveHistory` 引用（值类型数组，浅拷贝安全）

**文件**: `Board.swift` → `snapshot()`

```swift
func snapshot() -> Board {
    let copy = Board(pieces: pieces.map { Piece(kind: $0.kind, side: $0.side, position: $0.position, id: $0.id) })
    copy.moveHistory = moveHistory
    copy.currentTurn = currentTurn
    return copy
}
```

**分析**: `moveHistory` 是 `[Move]`（值类型数组），赋值时发生拷贝。`Move` 包含 `Piece`（结构体，值类型）和 `Position`（结构体，值类型），所以整个拷贝是深拷贝。**安全**。

`pieces` 数组中的 `Piece` 通过 `id` 保持唯一标识。`snapshot` 正确保留了 `id`，使得 `execute` 和 `undoLastMove` 中的 `firstIndex(where: { $0.id == ... })` 能正确工作。

**结论**: 无问题。

---

#### P1-4: 静态搜索（Quiescence Search）中生成全部合法走法来筛选吃子/将军走法，性能隐患

**文件**: `AIEngine.swift` → `quiescenceSearch`

```swift
let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
let captureMoves = allMoves.filter { $0.captured != nil }
let checkMoves = allMoves.filter { move in ... }
```

**问题**: 静态搜索在每个节点都调用 `allLegalMoves`（内部对每个棋子生成候选走法 + `isLegal` 过滤），然后只保留吃子和将军走法。这非常昂贵——`allLegalMoves` 中的 `wouldBeInCheck` 对每个候选走法都做 `snapshot + execute + isInCheck + （隐含的）undo`。

标准做法是只生成吃子走法（和将军走法），不做合法性过滤中的"走完后是否被将军"检查（只在执行该走法时才检查）。

**影响**: 大幅降低搜索深度。在中层（depth=4-6）的静态搜索节点中，这可能消耗 50%+ 的搜索时间。

**建议**: 为静态搜索编写专用的吃子走法生成器，跳过 `wouldBeInCheck` 检查（在 `quiescenceSearch` 内部做合法性验证）。

---

#### P1-5: `MoveOrderer.givesCheck` 和 `MoveOrderer.threatBonus` 直接在传入的 board 上 execute/undo

**文件**: `MoveOrderer.swift` → `givesCheck` / `threatBonus`

```swift
private func givesCheck(_ move: Move, on board: Board) -> Bool {
    board.execute(move)
    let opponentSide: Side = (move.piece.side == .red) ? .black : .red
    let inCheck = MoveValidator.isInCheck(opponentSide, on: board)
    _ = board.undoLastMove()
    return inCheck
}
```

**问题**: `order` 方法接收的 `board` 是调用方传入的活动棋盘。在排序过程中对 board 做 execute/undo 是危险的——如果排序过程中发生异常或并发访问，board 状态可能被破坏。

注释说"在原 board 上 execute/undo，避免 snapshot 深拷贝开销"，这是性能优化，但牺牲了安全性。

**影响**: 单线程下 execute/undo 配对正确，不会出错。但如果未来引入并发搜索（同时搜索多个子树），此处会产生数据竞争。

**建议**: 当前单线程安全，但应在代码注释中标注"非线程安全，不可并发调用"。

---

#### P1-6: `CheckmateSearch` 的 `maxResponses=8` 剪枝可能导致假阳性

**文件**: `CheckmateSearch.swift` → `dfs`

```swift
let maxResponses = 8
let opponentMovesToCheck: [Move]
if opponentMoves.count > maxResponses {
    opponentMovesToCheck = Array(opponentMoves.sorted { ... }.prefix(maxResponses))
} else {
    opponentMovesToCheck = opponentMoves
}
```

**问题**: 当对方应将走法超过 8 个时，只检查前 8 个。如果第 9+ 个走法能逃脱将杀，引擎会误报找到将杀。

代码注释已承认此问题："此剪枝可能导致假阳性——声称找到将杀，但对方可能存在第 9+ 个走法能逃脱。"

**影响**: 实战中被将时超过 8 个应将走法极罕见，但在残局排局场景中可能出现。假阳性将导致 AI 执行错误的杀法路线，走出败招。

**建议**: 可以接受此权衡，但应在 UI 层给用户提示"引擎宣告将杀可能有误"。或者考虑将阈值提高到 12-16。

---

### P2 — 改进建议

#### P2-1: `wouldBeInCheck` 每次 `isLegal` 调用都做 `snapshot + execute + isInCheck`

**文件**: `MoveValidator.swift` → `wouldBeInCheck`

```swift
private static func wouldBeInCheck(_ move: Move, on board: Board) -> Bool {
    let snapshot = board.snapshot()
    snapshot.execute(move)
    return isInCheck(move.piece.side, on: snapshot)
}
```

**问题**: `isLegal` → `wouldBeInCheck` → `snapshot()` → `execute(move)` → `isInCheck`。对每个候选走法都做一次完整的棋盘快照（深拷贝所有棋子）。这是性能热点。

`allLegalMoves` 对每个棋子的每个候选走法都调用 `isLegal`，假设平均 30 个候选走法，每次快照拷贝 ~32 个 Piece 结构体，总计约 960 次结构体拷贝。对于 AI 搜索中的深层递归，这非常昂贵。

**建议**: 
1. 用 in-place execute/undo 代替 snapshot（注意线程安全）
2. 或在 `candidateMoves` 生成时预先过滤掉自将走法

---

#### P2-2: FEN 解析未校验棋子数量的合法性

**文件**: `FENDecoder.swift` → `parse`

**问题**: FEN 解析只检查行列数和字符合法性，不检查棋子数量。例如以下 FEN 能被成功解析：
- 10 个车、0 个将（应该非法）
- 0 个将（无法判断胜负）
- 双方各有 10 个兵（象棋最多 5 个兵）

**影响**: 不影响正常对局（使用标准开局 FEN），但如果用户通过 FEN 编辑器输入异常局面，可能导致后续逻辑崩溃（如 `generalPosition` 返回 `nil`，`isInCheck` 返回 `true`）。

**建议**: 添加基本合法性校验：每方必须恰好 1 个将/帅，兵不超过 5 个，士不超过 2 个等。

---

#### P2-3: `FENDecoder.generate` 使用线性查找定位棋子

**文件**: `FENDecoder.swift` → `generate`

```swift
for row in 0...9 {
    for col in 0...8 {
        if let piece = pieces.first(where: { $0.position == Position(row: row, col: col) }) {
```

**问题**: 90 次迭代，每次遍历整个 `pieces` 数组（最多 32 个棋子），时间复杂度 O(90 × 32) = O(2880)。虽然对于一次性调用不构成性能问题，但如果频繁调用（如 AI 评估中）需要注意。

**建议**: 先构建 `Position → Piece` 的字典，再按序查找。

---

#### P2-4: 开局库 v1 兼容索引构建依赖 `FENParser` 而非 `FENDecoder`

**文件**: `OpeningBook.swift` → `buildV1Index`

```swift
guard let board = FENParser.parse(fen: FENParser.standardInitial) else { continue }
```

**问题**: 使用了 `FENParser`（未在审计范围内，可能在 Services 层），而不是 `FENDecoder`（Models 层）。这打破了层依赖关系——Models 层不应依赖 Services 层。同时 `ICCSParser` 也是外部引用。

**影响**: 如果 `FENParser` 的解析逻辑与 `FENDecoder` 不一致，开局库索引构建可能产生错误数据。

**建议**: 确认 `FENParser` 和 `FENDecoder` 使用相同的解析逻辑，或直接使用 `FENDecoder`。

---

#### P2-5: `Beginner` 难度的 `safeRandomMove` 直接在传入 board 上 execute/undo

**文件**: `AIEngine.swift` → `safeRandomMove`

```swift
board.execute(move)
let threatened = board.pieces(for: opponentSide).contains { op in
    MoveValidator.canAttack(piece: op, target: targetPos, on: board)
}
_ = board.undoLastMove()
```

**问题**: `bestMove` 入口已经做了 `let workBoard = board.snapshot()`，所以这里操作的是 workBoard，安全。但代码没有明显标注此约束，如果未来有人重构移除 snapshot，此处会产生副作用 bug。

**建议**: 添加注释说明 `board` 参数已是 snapshot。

---

#### P2-6: `Board.toggleTurn()` 暴露为 public 方法，可能被误用

**文件**: `Board.swift` → `toggleTurn()`

```swift
func toggleTurn() {
    currentTurn = (currentTurn == .red) ? .black : .red
}
```

**问题**: 注释说"仅供 AI 空着裁剪内部使用"，但方法是 `internal` 访问级别（Swift 默认），整个模块都能调用。如果误调用（不配合 execute/undo），会导致走棋方状态不一致。

**建议**: 改为 `private(set)` 并通过更安全的方法暴露空着裁剪功能，或者添加 `@available(*, deprecated, message: "仅内部使用")` 标记。

---

### P3 — 微小问题 / 代码风格

#### P3-1: `Piece.displayName` 中红方和黑方的马/车用繁体字"馬"/"車"

红方马显示为"馬"而非"傌"，车显示为"車"而非"俥"。传统中国象棋中，红黑两方的同名棋子使用不同的字（红：帅仕相傌俥炮兵；黑：将士象馬車砲卒）。当前实现中红方和黑方的马/车用了相同的字。

**影响**: 纯显示问题，不影响逻辑。但如果追求传统象棋的视觉规范，应区分。

---

#### P3-2: `EvalWeights.mergeWithDefault` 实际不支持部分字段 fallback

```swift
private static func mergeWithDefault(data: Data) -> EvalWeights {
    do {
        let decoded = try JSONDecoder().decode(EvalWeights.self, from: data)
        return decoded
    } catch {
        return .default
    }
}
```

注释说"缺失字段用默认值填充"，但 `JSONDecoder` 对非可选字段缺失时会抛出错误，直接 fallback 到完全默认值。方法名 `mergeWithDefault` 有误导性。

**建议**: 如果需要真正的部分合并，应使用 `KeyDecodingStrategy` 或手动解码。否则修改注释。

---

#### P3-3: `ZobristHash.update` 不更新 `moveHistory` 相关状态

增量哈希只考虑了棋子位置和行走方，没有考虑 `moveHistory`（这不影响哈希正确性，因为 Zobrist 只编码棋盘状态）。但 `Board.execute` / `undoLastMove` 维护了 `moveHistory`，如果哈希计算和 `moveHistory` 不同步（例如手动调用 `toggleTurn`），可能影响开局库查找。

**结论**: 当前逻辑正确，但 `toggleTurn` 的存在增加了状态不一致的风险。

---

## 建议改进

### 1. 性能优化（高优先级）

| 项目 | 当前 | 建议 | 预期收益 |
|------|------|------|----------|
| `wouldBeInCheck` | snapshot 深拷贝 | in-place execute/undo | 减少 ~60% 合法走法生成时间 |
| `quiescenceSearch` | `allLegalMoves` + 过滤 | 专用吃子走法生成器 | 静态搜索节点数翻倍 |
| `FENDecoder.generate` | 线性查找 | Position→Piece 字典 | 生成速度提升 ~10× |

### 2. 健壮性改进（中优先级）

| 项目 | 当前风险 | 建议 |
|------|----------|------|
| FEN 棋子数量校验 | 异常 FEN 可能导致崩溃 | 添加基本棋子数量约束 |
| `toggleTurn` 访问控制 | 可能被误用 | 限制访问级别或重命名 |
| `CheckmateSearch` 剪枝 | 假阳性风险 | 提高 `maxResponses` 或添加注释/警告 |

### 3. 代码质量改进（低优先级）

| 项目 | 建议 |
|------|------|
| `canAttack` 的宫殿/半场检查 | 统一检查 `from` 还是 `target`，保持语义一致 |
| `EvalWeights.mergeWithDefault` | 修正注释或实现真正的部分合并 |
| 红方棋子显示名称 | 按传统区分"傌/俥"等 |

---

## 总结

### 整体评价

游戏逻辑核心（走子规则、将军/将死判定、FEN 编解码）**基本正确**，未发现影响正常对局的 P0 级致命错误。七种棋子的走法验证（车直线、马蹩腿、象塞眼、士九宫斜走、将九宫直走、炮翻山、兵过河可横走）均符合中国象棋规则。将帅对面（飞将）检测逻辑正确。

### 主要风险点

1. **性能瓶颈**：`wouldBeInCheck` 的 snapshot 和 `quiescenceSearch` 的全量走法生成是最大性能隐患，直接影响 AI 搜索深度和响应速度。
2. **`CheckmateSearch` 剪枝**：`maxResponses=8` 的剪枝在残局排局中可能产生假阳性，但实战影响极小。
3. **防御性不足**：FEN 解析缺少棋子数量校验，异常输入可能导致后续逻辑异常。

### 各模块审计结论

| 模块 | 正确性 | 性能 | 健壮性 |
|------|--------|------|--------|
| 走子规则（MoveValidator） | ✅ 正确 | ⚠️ snapshot 开销大 | ✅ 良好 |
| 将军/将死/和棋判定 | ✅ 正确 | ⚠️ `allLegalMoves` 全量生成 | ✅ 良好 |
| FEN 编解码（FENDecoder） | ✅ 正确 | ⚠️ 生成时线性查找 | ⚠️ 缺少数量校验 |
| AI 搜索（AIEngine） | ✅ 正确 | ⚠️ 静态搜索效率低 | ✅ 良好 |
| 置换表（TranspositionTable） | ✅ 正确 | ✅ 双桶策略合理 | ✅ 良好 |
| 开局库（OpeningBook） | ✅ 正确 | ✅ hash 直查高效 | ⚠️ v1 兼容依赖外部解析器 |
| 连将杀搜索（CheckmateSearch） | ⚠️ 有剪枝风险 | ✅ 只扩展将军走法 | ⚠️ 假阳性风险 |
| Zobrist 哈希 | ✅ 正确 | ✅ 增量更新高效 | ✅ 良好 |
