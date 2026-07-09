# D1-子2 胜负判定审计

## 审计范围

| 文件 | 说明 |
|------|------|
| `MoveValidator.swift` | isInCheck, isCheckmate, isStalemate, canAttack |
| `GameViewModel.swift` | checkGameState, detectPerpetualCheck, gameState 转换 |
| `CheckmateSearch.swift` | 将杀搜索逻辑 |
| `Enums.swift` | GameState 枚举定义 |

## 判定逻辑逐项验证

### 1. 将军判定（isInCheck）

**结论：✅ 正确**

`isInCheck(side, board)` 遍历对方所有棋子，调用 `canAttack(piece, target:generalPos, board)` 检测是否能攻击到将/帅。覆盖了全部 7 种棋子的攻击模式：

- 车（chariot）：直线无阻挡 ✅
- 炮（cannon）：直线隔一子 ✅
- 马（horse）：日字 + 蹩马腿检查 ✅
- 兵/卒（soldier）：未过河只向前，过河可左右 ✅
- 士/仕（advisor）：九宫斜线 ✅
- 象/相（elephant）：田字 + 塞象眼检查 ✅
- 将/帅（general）：九宫直线 ✅

**将帅对面检测**：独立于 `canAttack`，检查同列且中间无子。逻辑正确 ✅

**canAttack 与 isMovePatternValid 的一致性**：`canAttack` 复用了各棋子的移动模式校验函数（如 `isValidHorseMove`、`isValidChariotMove` 等），确保攻击范围与走法一致 ✅

### 2. 将死判定（isCheckmate）

**结论：✅ 基本正确**

```swift
static func isCheckmate(_ side: Side, on board: Board) -> Bool {
    isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
}
```

`allLegalMoves` 通过 `legalMoves(for:)` → `candidateMoves` + `isLegal` 过滤，`isLegal` 包含 `wouldBeInCheck` 检测。这确保了所有三种应将方式都被覆盖：
- 走子避开攻击 ✅
- 吃掉将军子 ✅
- 垫子阻挡攻击线 ✅

`wouldBeInCheck` 使用 snapshot + execute + isInCheck，验证走子后己方是否被将军 ✅

### 3. 困毙判定（isStalemate）

**结论：✅ 正确**

```swift
static func isStalemate(_ side: Side, on board: Board) -> Bool {
    !isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
}
```

未被将军但无合法走法 = 困毙 = 和棋。逻辑正确 ✅

### 4. 长将判负（detectPerpetualCheck）

**结论：🔴 存在 P0 级逻辑缺陷**

```swift
private func detectPerpetualCheck() -> Bool {
    guard gameMoves.count >= perpetualCheckThreshold else { return false }
    let recentMoves = Array(gameMoves.suffix(perpetualCheckThreshold))
    let sides = Set(recentMoves.map { $0.piece.side })
    for side in sides {
        let sideMoves = recentMoves.filter { $0.piece.side == side }
        if sideMoves.count >= 3 && sideMoves.allSatisfy({ $0.isCheck }) {
            return true
        }
    }
    return false
}
```

threshold = 6（半步），取最近 6 步检查是否有一方 ≥3 步全是将军。

**致命缺陷：不检查局面是否重复。**

中国象棋规则中，长将判负的前提是**重复局面下的连续将军**。如果一方在非重复局面下连续将军（这是正常的连将杀战术，并非违规），不应判负。

当前实现只看「最近 6 步中一方有 3 步将军」就触发，完全忽略局面重复。这导致：

- **非重复的合法连将被误判为长将**：玩家执行 5+ 步的强制连将杀序列时，前 3 步将军就会触发 detectPerpetualCheck → 判将军方负。玩家本应赢得对局，反而被判输。
- **实际影响**：残局中连将杀是常见战术，3 步以上的将军序列频繁出现。此 bug 会从根本上破坏中残局体验。

### 5. checkGameState 优先级顺序

**结论：🔴 存在 P0 级优先级错误**

```
1. isCheckmate → 对方胜
2. isStalemate → 和棋
3. 50回合 → 和棋
4. 三次重复 → 和棋
5. detectPerpetualCheck → 长将方判负
```

**问题：三次重复（和棋）优先于长将判负。**

当真正的长将循环发生时（一方在重复局面下连续将军），同一局面 FEN 出现 3 次 → 三次重复先触发 → 判和。但中国象棋规则要求长将方判负，不是和棋。

这意味着：
- **重复长将** → 三次重复先触发 → 判和 ❌（应判将军方负）
- **非重复将军** → 三次重复不触发 → detectPerpetualCheck 触发 → 判将军方负 ❌（非重复将军是合法的）

**两个方向都判错了。** 正确的优先级应该是：

```
1. isCheckmate
2. isStalemate
3. 50回合
4. 长将判负（需要：重复局面 + 连续将军 两个条件同时满足）
5. 三次重复（无长将的重复 → 和棋）
```

或者更准确地：将长将检测与三次重复合并——重复局面中一方连续将军 → 判将军方负；重复局面中无连续将军 → 判和。

### 6. 三次重复局面

**结论：⚠️ 采用国际象棋规则，不完全符合中国象棋规则**

`boardFingerprint()` 使用完整 FEN（含走子方），`positionFingerprints[fp] >= 3` 判和。

国际象棋中三次重复无条件判和。中国象棋中，重复局面的判罚取决于重复内容：
- 一方连续将军的重复 → 长将判负
- 一方连续捉子（吃子威胁）的重复 → 长捉判负
- 无攻击性的重复 → 和棋

当前实现把所有三次重复都判和，丢失了长将/长捉判负的维度。

### 7. 50 回合规则

**结论：✅ 可接受（非中国象棋传统规则，但作为和棋 safeguard 合理）**

`halfmoveClock >= 100`（半回合数）= 50 个完整回合无吃子无兵移动。中国象棋没有像国际象棋那样的正式 50 回合规则，但加入此规则防止无限对局是合理的实现选择。

### 8. CheckmateSearch（将杀搜索）

**结论：⚠️ 剪枝有假阳性风险，但实际影响可控**

```swift
let maxResponses = 8
if opponentMoves.count > maxResponses {
    opponentMovesToCheck = Array(opponentMoves.sorted { ... }.prefix(maxResponses))
}
```

对方应将走法超过 8 个时，只验证前 8 个（按 moveScore 排序）。如果第 9+ 个走法能逃脱，会误报为将杀。

**风险评估**：被将军时超过 8 个应将走法的情况极为罕见（需要将帅周围有大量己方棋子可以垫或吃）。在常规对局和大多数残局排局中不会触发。但在极端排局场景（如双方大量棋子集中于九宫附近）可能出错。

moveScore 排序维度（吃子值、靠近将帅、阻挡攻击线）与「能否逃脱将杀」没有必然因果关系，剪枝方向可能不是最优。

### 9. 双将 / 闪将

**结论：✅ 隐式覆盖**

代码没有显式的「双将」检测，但通过 `isInCheck` → 遍历所有对方棋子的 `canAttack`，自然检测到两个棋子同时攻击将帅的情况。双将时只有走将帅一种应将方式，`allLegalMoves` 会正确过滤出唯一合法走法。

闪将（移动一个棋子后露出后面的攻击线）通过 `wouldBeInCheck` 的 snapshot 机制检测——走子后的 board 上，移除走子方棋子的位置不再阻挡，后面的攻击线暴露，被 `isInCheck` 捕获 ✅

## 发现的问题（P0-P3 分级）

### P0

#### P0-1: detectPerpetualCheck 不检查局面重复，合法连将被误判为长将

**文件**：`GameViewModel.swift:631-646`

`detectPerpetualCheck()` 只检查最近 6 步中一方是否有 3+ 步全是将军，不检查局面是否重复。导致正常的连将杀战术（3 步以上非重复将军）被判负。

**影响**：中残局连将杀是核心战术，此 bug 会导致玩家执行合法连将时被错误判输。

**修复方向**：detectPerpetualCheck 应同时检查「连续将军」和「局面重复」两个条件。可以复用 `positionFingerprints` 判断当前局面是否已出现 2+ 次。

#### P0-2: checkGameState 优先级导致重复长将判和而非判负

**文件**：`GameViewModel.swift:548-615`

三次重复（优先级 4）在长将判负（优先级 5）之前检查。当真正的长将循环导致局面重复时，三次重复先触发判和，而中国象棋规则要求判将军方负。

**影响**：长将循环中，将军方本应判负，却判为和棋。

**修复方向**：将长将检测提到三次重复之前，或在三次重复检测中加入将军方判断。

### P1

#### P1-1: CheckmateSearch maxResponses=8 剪枝有假阳性风险

**文件**：`CheckmateSearch.swift:73-78`

对方应将走法超过 8 个时只验证前 8 个。极端排局中第 9+ 个走法可能逃脱，但搜索声称找到将杀。

**影响**：常规对局无影响，极端残局排局可能误报将杀。

#### P1-2: 长捉（perpetual chase）未实现

中国象棋规则中，长捉（连续捉子但不吃子，且局面重复）也判负。当前实现完全没有长捉检测。

**影响**：符合中国象棋规则的严格程度降低。但对一般玩家体验影响不大——长捉比长将罕见得多，且检测难度极高（需要判断「捉」的定义）。

### P2

#### P2-1: 三次重复采用国际象棋规则（无条件判和），不完全符合中国象棋规则

**文件**：`GameViewModel.swift:578-582`

中国象棋的重复判罚应区分长将/长捉/无攻击性重复。当前实现一律判和。

**影响**：与竞技规则有偏差，但对休闲游戏体验可接受。

### P3

#### P3-1: detectPerpetualCheck threshold=6 的合理性

threshold=6 半步 = 3 个完整回合。这是中国象棋长将判罚的常见标准（3 次重复将军循环）。threshold 本身合理，但配合「不检查重复」的缺陷，使得阈值变得无意义——任何 6 步窗口内 3 步将军都会触发。

## 与 D1 原报告对比（新发现 vs 已知）

| 问题 | D1 原报告 | 本次发现 |
|------|-----------|----------|
| detectPerpetualCheck 不检查重复 | ❌ 未提及 | ✅ **新发现 P0** |
| checkGameState 优先级错误 | ❌ 未提及 | ✅ **新发现 P0** |
| CheckmateSearch maxResponses=8 剪枝 | ✅ 已提及 | ✅ 确认，评级一致（P1） |
| 长捉未实现 | ❌ 未提及 | ✅ 新发现 P1 |
| 三次重复用国际象棋规则 | ❌ 未提及 | ✅ 新发现 P2 |

D1 原报告聚焦在 CheckmateSearch 的剪枝风险上，遗漏了 detectPerpetualCheck 和 checkGameState 优先级两个更严重的问题。

## 总结

| 维度 | 评分 | 说明 |
|------|------|------|
| 将军检测（isInCheck） | ★★★★★ | 覆盖全部棋子 + 将帅对面，逻辑严密 |
| 将死检测（isCheckmate） | ★★★★★ | 三种应将方式全覆盖 |
| 困毙检测（isStalemate） | ★★★★★ | 正确 |
| 长将判负 | ★☆☆☆☆ | 不检查局面重复，方向判错，优先级错误 |
| 和棋规则 | ★★★☆☆ | 50回合合理，三次重复不完全符合中国象棋 |
| 将杀搜索 | ★★★★☆ | 剪枝有假阳性风险，实际影响可控 |

**核心风险**：detectPerpetualCheck 的两个 P0 问题会直接影响中残局体验。合法连将杀被判负、真正的长将循环被判和——这是规则实现的根本性错误，优先级高于 CheckmateSearch 的剪枝问题。

| 严重度 | 数量 |
|--------|------|
| P0 | 2 |
| P1 | 2 |
| P2 | 1 |
| P3 | 1 |
