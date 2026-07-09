# D1-子1 棋子走法规则审计

**审计人**: Vera（方案审查者）
**审计日期**: 2026-07-16
**审计版本**: v3.9
**项目路径**: `~/DevTeam/projects/chinese-chess/`

## 审计范围

| 文件 | 关注点 |
|------|--------|
| `Models/MoveValidator.swift` | 全部走法验证、候选生成、将军/将死判定 |
| `Models/Board.swift` | execute/undo、棋子管理、snapshot |
| `Models/Piece.swift` | 棋子定义、子力价值 |
| `Models/Position.swift` | 位置工具、九宫格/半场判定 |
| `Models/Move.swift` | 走法结构 |

---

## 逐子对照矩阵

### 对照基准：中国象棋官方规则

| 棋子 | 规则要点 | 关键限制 |
|------|----------|----------|
| 车 | 直线任意距离 | 不能越子 |
| 马 | 日字（2+1） | 蹩马腿：长轴方向相邻格有子则不能跳 |
| 象/相 | 田字（2+2） | 塞象眼：对角中点有子则不能走；不能过河 |
| 士/仕 | 九宫内斜走一格 | 不出九宫 |
| 将/帅 | 九宫内直走一格 | 飞将：双方同列且中间无子时，不能让两将对面 |
| 炮 | 直线移动同车；吃子需恰好翻一个棋子 | 炮架数量恰好为 1 |
| 兵/卒 | 未过河仅前进；过河后可前进或横走 | 永不后退 |

---

### 1. 车（俥/車）

**候选生成** (`candidateMoves` → `.chariot`)：

```swift
for (dr, dc) in [(1,0),(-1,0),(0,1),(0,-1)] {
    var r = from.row + dr
    var c = from.col + dc
    while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
        let t = Position(row: r, col: c)
        targets.append(t)
        if board.hasPiece(at: t) { break }  // 遇到子停止
        r += dr; c += dc
    }
}
```

- 四方向直线延伸，遇子则加入目标后停止。✓
- 己方棋子也会被加入目标，后续由 `isLegal` 过滤（`target.side == piece.side` → reject）。✓

**走法验证** (`isValidChariotMove`)：

```swift
guard from.row == to.row || from.col == to.col else { return false }
return countPiecesBetween(from: from, to: to, on: board) == 0
```

- 直线性检查。✓
- 起止点之间棋子数为 0。✓

**canAttack**：复用 `isValidChariotMove`。✓

**结论：✅ 完全正确。** 无边界条件问题。

---

### 2. 马（傌/馬）

**候选生成**：8 个日字目标 `(±2,±1)` 和 `(±1,±2)`。✓

**走法验证** (`isValidHorseMove`)：

```swift
guard (adr == 2 && adc == 1) || (adr == 1 && adc == 2) else { return false }

if adr == 2 {
    legRow = from.row + (dr > 0 ? 1 : -1)
    legCol = from.col
} else {
    legRow = from.row
    legCol = from.col + (dc > 0 ? 1 : -1)
}
return !board.hasPiece(at: Position(row: legRow, col: legCol))
```

**蹩马腿验证**：

| 走法方向 | dr,dc | 马腿位置 | 代码计算 | 正确？ |
|----------|-------|----------|----------|--------|
| 下偏右 | +2,+1 | (from.r+1, from.c) | legRow=from.r+1, legCol=from.c | ✓ |
| 下偏左 | +2,-1 | (from.r+1, from.c) | legRow=from.r+1, legCol=from.c | ✓ |
| 上偏右 | -2,+1 | (from.r-1, from.c) | legRow=from.r-1, legCol=from.c | ✓ |
| 上偏左 | -2,-1 | (from.r-1, from.c) | legRow=from.r-1, legCol=from.c | ✓ |
| 右偏下 | +1,+2 | (from.r, from.c+1) | legRow=from.r, legCol=from.c+1 | ✓ |
| 右偏上 | -1,+2 | (from.r, from.c+1) | legRow=from.r, legCol=from.c+1 | ✓ |
| 左偏下 | +1,-2 | (from.r, from.c-1) | legRow=from.r, legCol=from.c-1 | ✓ |
| 左偏上 | -1,-2 | (from.r, from.c-1) | legRow=from.r, legCol=from.c-1 | ✓ |

马腿位置 = 长轴方向上与起点相邻的正交格。8 个方向全部正确。✓

**canAttack**：复用 `isValidHorseMove`。✓

**结论：✅ 完全正确。**

---

### 3. 象/相

**候选生成**：4 个田字目标 `(±2,±2)`。✓

**走法验证** (`isValidElephantMove`)：

```swift
let inHalf: Bool = (piece.side == .red) ? to.isInRedHalf : to.isInBlackHalf
guard inHalf else { return false }
guard dr == 2 && dc == 2 else { return false }
let eyeRow = (from.row + to.row) / 2
let eyeCol = (from.col + to.col) / 2
return !board.hasPiece(at: Position(row: eyeRow, col: eyeCol))
```

**逐条检查**：

| 规则 | 代码实现 | 正确？ |
|------|----------|--------|
| 田字走法 (2,2) | `dr == 2 && dc == 2` (abs) | ✓ |
| 不能过河 | `to.isInRedHalf` (row 5-9) / `to.isInBlackHalf` (row 0-4) | ✓ |
| 塞象眼 | 中点 `(from+to)/2` 是否有子 | ✓ |

象眼位置验证：

| 走法方向 | 象眼位置 | 代码计算 | 正确？ |
|----------|----------|----------|--------|
| 右下 | (from.r+1, from.c+1) | ((from.r+to.r)/2, (from.c+to.c)/2) | ✓ |
| 左下 | (from.r+1, from.c-1) | 同上 | ✓ |
| 右上 | (from.r-1, from.c+1) | 同上 | ✓ |
| 左上 | (from.r-1, from.c-1) | 同上 | ✓ |

**过河边界验证**：
- 红象在 row 5（红方河沿），dr=-2 → to.row=3。`to.isInRedHalf` = (3 >= 5) = false → 拒绝。✓
- 黑象在 row 4（黑方河沿），dr=+2 → to.row=6。`to.isInBlackHalf` = (6 <= 4) = false → 拒绝。✓

**canAttack**（⚠️ 有问题）：

```swift
case .elephant:
    let inHalf: Bool = (piece.side == .red) ? from.isInRedHalf : from.isInBlackHalf
    guard inHalf else { return false }
```

`canAttack` 检查的是 `from`（攻击者位置）所在半场，而非 `target`（目标位置）所在半场。`isValidElephantMove` 检查的是 `to`。这是 D1 原报告 P0-1 指出的同一问题。

**具体复现场景**：红方象在 (5,2)（红方河沿），对方棋子在 (3,0)（黑方半场）。象眼 (4,1) 为空。
- `isValidElephantMove`：`to.isInRedHalf` = (3 >= 5) = **false** → 走法非法。✓
- `canAttack`：`from.isInRedHalf` = (5 >= 5) = **true** → 通过半场检查 → 继续 2+2 和象眼检查 → 返回 **true**。❌

**结论：走法验证 ✅ 正确；canAttack ⚠️ 有误报（详见问题清单）。**

---

### 4. 士/仕

**候选生成**：4 个斜向目标 `(±1,±1)`。✓

**走法验证** (`isValidAdvisorMove`)：

```swift
let palace: Bool = (piece.side == .red) ? to.isInRedPalace : to.isInBlackPalace
guard palace else { return false }
return dr == 1 && dc == 1
```

- 目标在己方九宫内。✓
- 斜走一格。✓

**九宫边界验证**：
- 红方九宫：`row >= 7 && row <= 9 && col >= 3 && col <= 5`。✓
- 黑方九宫：`row >= 0 && row <= 2 && col >= 3 && col <= 5`。✓
- 士从 (9,3) 到 (8,2)：`to.isInRedPalace` = (col 2 < 3) = false → 拒绝。✓

**canAttack**（⚠️ 语义不精确）：

```swift
case .advisor:
    let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
    guard palace else { return false }
```

检查 `target` 是否在**攻击方**的九宫内。对方棋子永远不会在己方九宫内（正常对局），所以士的 `canAttack` 对所有外部目标永远返回 false。

这在 `isInCheck` 场景下**结果正确**（士不能攻击对方将，因为对方将不在己方九宫），但语义上检查了错误的属性。详见问题清单。

**结论：走法验证 ✅ 正确；canAttack 语义不精确但功能上无错误。**

---

### 5. 将/帅

**候选生成**：4 个正向目标 `(±1,0)` 和 `(0,±1)`。✓

**走法验证** (`isValidGeneralMove`)：

```swift
let palace: Bool = (piece.side == .red) ? to.isInRedPalace : to.isInBlackPalace
guard palace else { return false }
return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
```

- 目标在己方九宫内。✓
- 直走一格（横或竖）。✓

**飞将检测**（`isInCheck` 末尾）：

```swift
if let otherGeneralPos = board.generalPosition(of: opponent),
   generalPos.col == otherGeneralPos.col {
    var blocked = false
    for r in (minRow + 1)..<maxRow {
        if board.hasPiece(at: Position(row: r, col: generalPos.col)) {
            blocked = true; break
        }
    }
    if !blocked { return true }
}
```

- 同列检查。✓
- 中间无子 → 被将军（飞将）。✓
- `wouldBeInCheck` 通过 `snapshot.execute(move)` + `isInCheck` 检测任何暴露两将对面的走法。✓

**canAttack**：

```swift
case .general:
    let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
    guard palace else { return false }
    return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
```

检查目标是否在攻击方的九宫内。对方将永远不会在己方九宫 → 此分支在任何合法局面中永远返回 false。飞将完全由 `isInCheck` 末尾的独立逻辑处理。功能正确，但 `.general` 分支实际上是死代码。

**结论：走法验证 ✅ 完全正确；飞将 ✅ 正确；canAttack .general 分支是死代码（不影响正确性）。**

---

### 6. 炮（炮/砲）

**候选生成** (`candidateMoves` → `.cannon`)：

```swift
var mounted = false
while ... {
    if !mounted {
        if board.hasPiece(at: t) { mounted = true }  // 找到炮架
        else { targets.append(t) }                    // 空位 = 可移动
    } else {
        if board.hasPiece(at: t) { targets.append(t); break }  // 炮架后第一个子 = 吃子目标
    }
}
```

- 无炮架时：空位是移动目标，第一个遇到的子成为炮架。✓
- 有炮架后：跳过空位，第一个遇到的子是吃子目标。✓
- 同方棋子作为吃子目标会被加入，但后续 `isLegal` 过滤。✓

**走法验证** (`isValidCannonMove`)：

```swift
let between = countPiecesBetween(from: from, to: to, on: board)
if target != nil { return between == 1 }  // 吃子：恰好 1 个炮架
else { return between == 0 }               // 移动：无遮挡
```

**炮架数量验证**：

| 场景 | 中间子数 | target | 期望 | 代码 | 正确？ |
|------|----------|--------|------|------|--------|
| 平移到空位 | 0 | nil | 合法 | between == 0 → true | ✓ |
| 平移越子 | 1 | nil | 非法 | between == 0 → false | ✓ |
| 吃子（1 炮架） | 1 | 非 nil | 合法 | between == 1 → true | ✓ |
| 吃子（0 炮架） | 0 | 非 nil | 非法 | between == 1 → false | ✓ |
| 吃子（2 炮架） | 2 | 非 nil | 非法 | between == 1 → false | ✓ |

**canAttack**：

```swift
case .cannon:
    guard from.row == target.row || from.col == target.col else { return false }
    return countPiecesBetween(from: from, to: target, on: board) == 1
```

炮的攻击判定 = 同线 + 中间恰好 1 子。✓ 不区分目标是己方还是敌方（调用方保证 target 是敌方）。

**结论：✅ 完全正确。** 炮架逻辑精确覆盖所有场景。

---

### 7. 兵/卒

**候选生成** (`candidateMoves` → `.soldier`)：

```swift
let forward = (piece.side == .red) ? -1 : 1
let hasCrossed = (piece.side == .red) ? from.row <= 4 : from.row >= 5
// 前进
if Position.isValid(fwd) { targets.append(fwd) }
// 过河后可左右
if hasCrossed {
    if Position.isValid(left) { targets.append(left) }
    if Position.isValid(right) { targets.append(right) }
}
```

**走法验证** (`isValidSoldierMove`)：

```swift
let hasCrossed = (piece.side == .red) ? from.row <= 4 : from.row >= 5
if !hasCrossed {
    return dr == forward && dc == 0                    // 仅前进
} else {
    if dr == forward && dc == 0 { return true }        // 前进
    if dr == 0 && dc == 1 { return true }              // 横走
    return false
}
```

**逐条验证**：

| 规则 | 代码 | 正确？ |
|------|------|--------|
| 红兵未过河仅前进 | `from.row > 4` 时 `dr == -1 && dc == 0` | ✓ |
| 红兵过河后可前进 | `from.row <= 4` 时 `dr == -1 && dc == 0` | ✓ |
| 红兵过河后可横走 | `from.row <= 4` 时 `dr == 0 && dc == 1` (abs) | ✓ |
| 黑卒未过河仅前进 | `from.row < 5` 时 `dr == +1 && dc == 0` | ✓ |
| 黑卒过河后可前进 | `from.row >= 5` 时 `dr == +1 && dc == 0` | ✓ |
| 黑卒过河后可横走 | `from.row >= 5` 时 `dr == 0 && dc == 1` (abs) | ✓ |
| 永不后退 | dr 只允许 `forward` 或 `0`，永远不允许 `-forward` | ✓ |

**过河边界验证**：
- 红兵在 row 6（未过河）：`hasCrossed = (6 <= 4) = false` → 仅前进。✓
- 红兵在 row 5（未过河，河沿红侧）：`hasCrossed = (5 <= 4) = false` → 仅前进。✓
- 红兵在 row 4（刚过河）：`hasCrossed = (4 <= 4) = true` → 可横走。✓
- 红兵在 row 0（底线）：`fwd = Position(row: -1, col: c)` → `isValid = false` → 前进被排除。但 `hasCrossed = true` → 仍可横走。✓

**canAttack**：复用 `isValidSoldierMove`。✓

**结论：✅ 完全正确。** 兵卒的过河判定和方向限制均符合规则。

---

## 发现的问题（P0-P3 分级）

### P0 — 严重：影响正确性

**无新增 P0。**

D1 原报告中的 P0-1（象 `canAttack` 半场检查用 `from` 而非 `target`）和 P0-2（将 `canAttack` 飞将规则不对称）经逐行验证确认存在，分析如下：

**D1-子1-P0-1（确认 D1 P0-1）：象 `canAttack` 跨河误报**

```swift
// canAttack — 检查 from（攻击者位置）
let inHalf: Bool = (piece.side == .red) ? from.isInRedHalf : from.isInBlackHalf

// isValidElephantMove — 检查 to（目标位置）
let inHalf: Bool = (piece.side == .red) ? to.isInRedHalf : to.isInBlackHalf
```

具体场景：红方象在 (5,2)（红方河沿），目标在 (3,0)（黑方半场），象眼 (4,1) 为空。
- `isValidElephantMove` → `to.isInRedHalf` = false → **走法非法** ✓
- `canAttack` → `from.isInRedHalf` = true → **返回 true（攻击有效）** ❌

`canAttack` 在三处被调用，影响范围：
1. `isInCheck`：检查对方棋子能否攻击己方将。对方将在九宫格内（row 0-2 或 7-9），象从河沿 (row 5) 的 2 步斜跳最多到 row 3，不会命中九宫格内的将。**对将军判定无影响**。
2. `AIEngine.safeRandomMove`：beginner 难度检查落点是否被威胁。可能误判某格被象"威胁"，导致新手 AI 避开实际上安全的格子。**影响 AI 行为质量**。
3. `CoachExplainer.isSafeCapture`：检查吃子后落点是否受攻击。可能误判某吃子不安全。**影响教练建议准确性**。

**严重度**：对核心游戏规则（走法合法性、将军判定）无影响，但影响 AI 行为和教练功能。

---

### P1 — 重要：应修复

**D1-子1-P1-1（确认 D1 P1-1）：士 `canAttack` 宫殿检查方向语义错误**

```swift
case .advisor:
    let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
    guard palace else { return false }
```

检查 `target` 是否在**攻击方**的九宫内。正确做法应检查 `from`（攻击者）在己方九宫（这是数据约束，恒为 true），或者直接去掉此检查——因为 `dr == 1 && dc == 1` 已保证目标在九宫邻接格内。

当前实现结果正确（对方将永远不会在己方九宫 → 士的 `canAttack` 对外部目标永远返回 false），但逻辑表达有误。

**影响**：无功能性错误。代码可读性和维护性风险。

---

### P2 — 中等：体验/代码质量

**D1-子1-P2-1（新发现）：将 `canAttack` 的 `.general` 分支是事实上的死代码**

```swift
case .general:
    let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
    guard palace else { return false }
    let dr = abs(target.row - from.row)
    let dc = abs(target.col - from.col)
    return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
```

在任何合法局面中，对方棋子（包括对方将）永远不会出现在己方九宫内。因此 `.general` 分支的 `canAttack` 永远返回 false。飞将检测完全由 `isInCheck` 末尾的独立逻辑处理。

这段代码不会产生错误结果，但：
1. 给读者一种"将的攻击范围通过 canAttack 处理"的错觉
2. 如果未来有人试图通过修改 `canAttack` 来调整将的攻击逻辑，会遗漏飞将的独立处理
3. 增加了不必要的代码路径

**建议**：将 `.general` 分支改为 `return false` 并添加注释说明飞将在 `isInCheck` 中独立处理，或直接实现飞将检测。

---

### P3 — 轻微

**D1-子1-P3-1（新发现）：`isValidElephantMove` 不检查 `from` 是否在正确半场**

```swift
let inHalf: Bool = (piece.side == .red) ? to.isInRedHalf : to.isInBlackHalf
guard inHalf else { return false }
```

只验证目标位置（`to`）的半场限制。如果因数据异常（FEN 解析错误、代码 bug）导致象出现在错误半场，验证函数不会拒绝其移动到错误半场内的目标。

实际影响极小：从错误位置出发的 2 步斜跳会落入各种位置，大部分会被半场检查拦截。但严格来说应同时检查 `from` 和 `to`。

**D1-子1-P3-2（新发现）：`countPiecesBetween` 不处理 from == to 的情况**

如果 `from == to`（原地不动），`from.row == to.row` 为 true，`minC == maxC`，循环范围 `(minC+1)..<maxC` 为空 → 返回 0。这意味着"原地不动"会被车和炮的验证通过（视为合法走法）。

实际上 `isLegal` 的入口会经过 `candidateMoves` 生成——`candidateMoves` 永远不会生成 `from == to` 的候选——所以不会触发。但如果未来有代码绕过 `candidateMoves` 直接调用 `isLegal`，这是一个潜在漏洞。

---

## 与 D1 原报告对比（新发现 vs 已知）

| 问题 | D1 原报告 | 本审计 | 状态 |
|------|-----------|--------|------|
| 象 `canAttack` 半场检查用 `from` | P0-1 | D1-子1-P0-1 | **确认**，补充了三处调用点的影响分析 |
| 将 `canAttack` 飞将规则不对称 | P0-2 | — | **确认无实际错误**，归类为 P2 死代码 |
| 士 `canAttack` 宫殿检查方向 | P1-1 | D1-子1-P1-1 | **确认**，功能正确但语义不精确 |
| `piece(at:)` 用 first 匹配 | P1-2 | — | 不在本次范围（Board 层），确认存在 |
| `snapshot()` 安全性 | P1-3 | — | 确认安全 |
| 将 `.general` canAttack 是死代码 | 未提及 | D1-子1-P2-1 | **新发现** |
| 象 `isValidElephantMove` 不检查 `from` 半场 | 未提及 | D1-子1-P3-1 | **新发现** |
| `countPiecesBetween` 不处理 from==to | 未提及 | D1-子1-P3-2 | **新发现** |

### 逐子规则正确性总结

| 棋子 | 候选生成 | 走法验证 | canAttack | 特殊规则 | 总评 |
|------|----------|----------|-----------|----------|------|
| 车 | ✅ | ✅ | ✅ | — | ✅ 完全正确 |
| 马 | ✅ | ✅ | ✅ | 蹩马腿 ✅ | ✅ 完全正确 |
| 象 | ✅ | ✅ | ⚠️ P0-1 | 塞象眼 ✅，不过河 ✅ | ⚠️ canAttack 有跨河误报 |
| 士 | ✅ | ✅ | ⚠️ P1-1 | 九宫限制 ✅ | ⚠️ canAttack 语义不精确 |
| 将 | ✅ | ✅ | ⚠️ P2-1 | 九宫 ✅，飞将 ✅ | ⚠️ canAttack 死代码 |
| 炮 | ✅ | ✅ | ✅ | 炮架数量 ✅ | ✅ 完全正确 |
| 兵 | ✅ | ✅ | ✅ | 过河横走 ✅，不退 ✅ | ✅ 完全正确 |

---

## 总结

七种棋子的**走法验证逻辑**（`candidateMoves` + `isValidXxxMove`）全部正确，符合中国象棋官方规则。逐行验证了关键边界条件：蹩马腿 8 方向、塞象眼 4 方向、炮架数量 0/1/2 三种场景、过河兵方向限制、九宫格边界、飞将同列无子检测——均无错误。

问题集中在 **`canAttack` 函数**。这个函数不走 `isMovePatternValid` 的统一路径，而是为每种棋子重新实现了一套攻击判定逻辑，引入了三处与走法验证不一致的行为：

1. 象：半场检查用 `from` 而非 `target`（D1 已知，确认 P0）
2. 士：宫殿检查检查了错误的属性（D1 已知，确认 P1）
3. 将：整个分支是死代码（**新发现**）

**根本原因**：`canAttack` 与 `isValidXxxMove` 的逻辑重复但实现不一致。最佳修复方案是让 `canAttack` 复用 `isMovePatternValid`（去掉 `wouldBeInCheck` 检查，因为 `canAttack` 只判断攻击范围不需要检查自将）。这样可以从根本上消除两套逻辑不一致的问题。

**审计结论**：核心走法规则正确性达标，`canAttack` 的三处偏差不影响正常对局的走子合法性（因为走子走的是 `isLegal` → `isMovePatternValid` 路径），但影响 AI 威胁判定和教练建议准确性。建议优先修复象的 `canAttack` 半场检查（一行改动：`from` → `target`）。
