# v3.3.0 棋盘方向调整设计

> 执黑时棋盘翻转，让黑方在下方（玩家视角）。只影响视觉呈现，不改 Board 模型坐标。
>
> **版本号建议**：棋盘翻转是较大的 UI 改动（坐标映射 + 交互层改造），建议升级到 **v3.3.0**。当前 v3.2.3 包含多个小修改，版本未变；棋盘翻转应作为 minor 版本提升，标记为重要功能更新。

## 当前坐标系

**Board 坐标系**（不变）：
- row 0-9：row 0 黑方底线，row 9 红方底线
- col 0-8：从左到右（红方视角）

**当前渲染**：
- `BoardSizing.posToCGPoint(pos)` → CGPoint(x: padding + col * cellSize, y: padding + row * cellSize)
- row 0 → y = padding（棋盘顶部）
- row 9 → y = padding + 9 * cellSize（棋盘底部）

**执红时**（humanSide == .red）：红方在棋盘底部（row 9），黑方在顶部（row 0）——正常视角，无需翻转。

**执黑时**（humanSide == .black）：红方仍在棋盘底部，黑方仍在顶部——玩家从黑方视角看棋盘，需要翻转，让黑方（row 0）在棋盘底部。

## 翻转方案

---

### 方案 A：rotationEffect 翻转整个棋盘视图（不推荐）

**核心思路**：给整个 ChessBoardView 加 `.rotationEffect(.degrees(180))`（执黑时）。

**SwiftUI 实现**

```swift
ChessBoardView(mode: .playGame(viewModel))
    .rotationEffect(viewModel.humanSide == .black ? .degrees(180) : .degrees(0))
```

**优点**

- ✅ 改动极小（一行代码）
- ✅ 棋盘、棋子、高亮全部翻转

**缺点**

- ❌ 棋子文字倒置（"将"变成倒过来的字）
- ❌ 楚河汉界文字倒置（"楚 河"变倒字）
- ❌ 交互层坐标需要反向转换（点击的 startLocation、拖拽的 offset）
- ❌ 视觉上不自然（文字倒置是明显的缺陷）

---

### 方案 B：坐标映射翻转（推荐）

**核心思路**：在 `BoardSizing` 中增加翻转映射，UI 坐标转换时根据 `isFlipped` 参数映射 row。

**翻转映射**

- 执黑时：row 映射为 `9 - row`
- 执红时：row 不变

```
原始 Position(row: 0, col: 4) → 翻转后显示在 row: 9 的位置（棋盘底部）
原始 Position(row: 9, col: 4) → 翻转后显示在 row: 0 的位置（棋盘顶部）
```

**优点**

- ✅ 棋子文字不倒置（只是位置翻转）
- ✅ 棋盘线条自动对称（网格翻转 180° 视觉相同）
- ✅ 楚河汉界文字需要单独处理位置，但文字不倒置
- ✅ 交互层坐标需要转换，但逻辑清晰（点击 → 翻转 → Position）
- ✅ 更精确控制（只有需要翻转的元素才翻转）

**缺点**

- ⚠️ 改动点较多（posToCGPoint、cgPointToPos、楚河汉界位置、交互层）

---

## 推荐：方案 B

理由：
1. **文字不倒置**——这是决定性因素。棋子文字倒置会严重影响视觉体验
2. **精确控制**——只有需要翻转的元素才翻转，棋盘线条网格本身对称，无需特殊处理
3. **逻辑清晰**——坐标映射是明确的双向转换，便于测试和调试

## 实施设计

### 1. BoardSizing 增加翻转参数

**改动文件**：`BoardSizing.swift`

```swift
/// Position → CGPoint（ZStack 内定位）
/// - Parameters:
///   - pos: Board 坐标
///   - cellSize: 格子尺寸
///   - padding: 边距
///   - flipped: 是否翻转（执黑时 true）
static func posToCGPoint(_ pos: Position, cellSize: CGFloat, padding: CGFloat, flipped: Bool = false) -> CGPoint {
    let displayRow = flipped ? (9 - pos.row) : pos.row
    return CGPoint(
        x: padding + CGFloat(pos.col) * cellSize,
        y: padding + CGFloat(displayRow) * cellSize
    )
}

/// CGPoint → Position（交互层坐标转换）
/// - Parameters:
///   - point: 点击/拖拽坐标（ZStack 本地坐标系）
///   - cellSize: 格子尺寸
///   - padding: 边距
///   - flipped: 是否翻转（执黑时 true）
static func cgPointToPos(_ point: CGPoint, cellSize: CGFloat, padding: CGFloat, flipped: Bool = false) -> Position? {
    let col = Int(round((point.x - padding) / cellSize))
    let displayRow = Int(round((point.y - padding) / cellSize))
    guard col >= 0, col <= 8, displayRow >= 0, displayRow <= 9 else { return nil }
    let row = flipped ? (9 - displayRow) : displayRow
    return Position(row: row, col: col)
}
```

**注意**：
- `posToCGPoint`：渲染时翻转（Board Position → UI CGPoint）
- `cgPointToPos`：交互时逆翻转（UI CGPoint → Board Position）

### 2. ChessBoardView 增加 isFlipped 参数

**改动文件**：`ChessBoardView.swift`

```swift
struct ChessBoardView: View {
    let mode: BoardMode
    var theme: ThemeColors = ThemeManager.shared.colors
    var isFlipped: Bool = false  // 新增参数

    // ...
}
```

**获取 isFlipped 的方式**：
```swift
private var isFlipped: Bool {
    switch mode {
    case .playGame(let vm): return vm.humanSide == .black
    case .playPuzzle(let vm): return vm.playerSide == .black
    }
}
```

或者在 BoardView 传入时计算：
```swift
ChessBoardView(mode: .playGame(viewModel), theme: theme, isFlipped: viewModel.humanSide == .black)
```

### 3. 棋子和高亮位置翻转

**改动文件**：`ChessBoardView.swift` 的 `renderOverlays` 函数

所有 `posToCGPoint(pos, ...)` 调用改为：
```swift
posToCGPoint(pos, cellSize: cellSize, padding: padding, flipped: isFlipped)
```

涉及：
- 被将军高亮（kingPos）
- 提示高亮（hintMove.from / hintMove.to）
- 合法走法提示（legalMoves）
- 拖拽合法走法提示（dragLegalMoves）
- 棋子位置（piece.position）
- 拖拽起始位置（dragStartPosition）
- 拖拽中棋子位置（dragPiece + dragOffset）
- 非法走法提示（illegalTarget）

### 4. 拖拽 offset 方向翻转

**关键前提**：DragGesture 的 `startLocation` 和 `translation` 本身就是相对于 ZStack 本地坐标系的（视图左上角为原点）。翻转操作只改变了 Board Position → UI CGPoint 的映射，不改变 ZStack 本地坐标系本身。

执黑时，拖拽的 offset 方向不需要额外翻转：
- `posToCGPoint(startPos, flipped: true)` 返回的是翻转后的 CGPoint（棋盘底部对应的 UI 位置）
- `dragOffset` 是手指移动的偏移，在 ZStack 本地坐标系中，不需要翻转
- 拖拽棋子的 position 计算方式不变

### 5. 楚河汉界文字位置翻转

**当前实现**：
```swift
private func riverText(width: CGFloat, cellSize: CGFloat, padding: CGFloat) -> some View {
    let y = padding + 4 * cellSize + cellSize / 2  // row 4.5（楚河汉界中间）
    HStack(spacing: cellSize * 2) {
        Text("楚  河")
        Text("汉  界")
    }
    .position(x: width / 2, y: y)
}
```

**翻转后**：
- 楚河汉界位置在 row 4.5（物理中间），翻转后仍在 row 4.5（因为 9 - 4.5 = 4.5）
- **位置不需要改动**——楚河汉界在棋盘正中间，翻转前后位置相同

**文字顺序需要调整**：
- 执红时："楚 河" 在左（col 0-3），"汉 界" 在右（col 5-8）——从红方视角看
- 执黑时：从黑方视角看，左侧是 col 8-5（原"汉 界"区域），右侧是 col 3-0（原"楚 河"区域）
- 文字顺序需要交换："汉 界" 在左，"楚 河" 在右

```swift
private func riverText(width: CGFloat, cellSize: CGFloat, padding: CGFloat) -> some View {
    let y = padding + 4 * cellSize + cellSize / 2
    HStack(spacing: cellSize * 2) {
        if isFlipped {
            Text("汉  界")
            Text("楚  河")
        } else {
            Text("楚  河")
            Text("汉  界")
        }
    }
    .position(x: width / 2, y: y)
}
```

### 6. 交互层坐标转换

**改动文件**：`ChessBoardView.swift` 的 `handleDragChanged` / `handleDragEnded` / `handleTap`

所有 `cgPointToPos(point, ...)` 调用改为：
```swift
cgPointToPos(point, cellSize: cellSize, padding: padding, flipped: isFlipped)
```

涉及：
- 拖拽起始位置检测（`cgPointToPos(startLocation, ...)`）
- 拖拽结束位置检测（`cgPointToPos(finalLocation, ...)`）
- 点击位置检测（`cgPointToPos(point, ...)`）

### 7. 棋盘线条和星标记

**无需改动**：
- 棋盘线条是网格（横线 10 条、竖线 9 条），翻转 180° 视觉完全相同
- 九宫对角线（黑方九宫 row 0-2 col 3-5，左上角 (0,3)、右下角 (2,5)；红方九宫 row 7-9 col 3-5，左上角 (7,3)、右下角 (9,5)），翻转 180° 后位置互换，但视觉相同
- 星标记（炮位 `(2,1)`, `(2,7)`, `(7,1)`, `(7,7)`；兵卒位 `(3,0-8)`, `(6,0-8)`）对称分布，翻转 180° 后位置互换。翻转后炮位 `(2,1)` 显示在棋盘底部（视觉上变成红方炮位），`(7,1)` 显示在棋盘顶部（视觉上变成黑方炮位）。但因为星标记是"炮位和兵位的定位标记"，无论执红执黑，这些位置的棋子都是炮和兵/卒——所以翻转后视觉相同。

### 8. BoardView 和 ReplayBoardView

**BoardView.swift**：传入 `isFlipped` 参数
```swift
struct BoardView: View {
    let viewModel: GameViewModel
    var theme: ThemeColors = ThemeManager.shared.colors

    var body: some View {
        ChessBoardView(mode: .playGame(viewModel), theme: theme, isFlipped: viewModel.humanSide == .black)
    }
}
```

**ReplayBoardView.swift**：**不改动，回放模式固定红方视角**
- 回放（复盘）模式下用户以旁观者视角观看棋局，不涉及执方切换
- 残局库棋谱通常以红方视角记录，回放时保持红方视角更符合用户预期
- 如需支持回放时切换视角，可作为后续功能，不在本次实现范围内

### 9. GameViewModel/PuzzleViewModel 无需改动

- `humanSide` / `playerSide` 已存在
- `setHumanSide()` 已存在
- Board 坐标系不变，逻辑层无需任何改动

## 改动文件清单

| 文件 | 改动 |
|------|------|
| `BoardSizing.swift` | 增加 `flipped` 参数的 `posToCGPoint` / `cgPointToPos` |
| `ChessBoardView.swift` | 增加 `isFlipped` 参数，**删除私有 cgPointToPos 方法**，修改所有坐标转换调用，修改楚河汉界文字顺序 |
| `BoardView.swift` | 传入 `isFlipped = viewModel.humanSide == .black` |
| `ReplayBoardView.swift` | 不改动（回放模式固定红方视角） |

## 不需要改动的部分

- **Board 模型**：坐标系不变，Piece.position 不变
- **GameViewModel / PuzzleViewModel**：逻辑层不变，humanSide/playerSide 已存在
- **AI 引擎**：走法计算基于 Board 坐标，不受影响
- **棋谱记录**：UCI 坐标基于 Board 坐标，不受影响
- **PieceView**：棋子渲染不变，只是位置不同
- **MoveValidator**：合法走法计算不变
- **提示功能**：hintMove 是 Board 坐标，UI 显示时映射
- **悔棋**：moveHistory 是 Board 坐标，UI 显示棋子位置时映射

## 边界情况

### 1. Puzzle 模式

Puzzle 模式下 `playerSide` 可能是 `.red` 或 `.black`（取决于 puzzle 设计）：
- 如果 puzzle 要求玩家执黑，棋盘应翻转
- ChessBoardView 的 `.playPuzzle(let vm)` 分支中，isFlipped 取 `vm.playerSide == .black`

### 2. 残局库（Replay）

残局回放时，玩家视角可能固定或可切换：
- 如果用户想从黑方视角回放，需要翻转
- 如果用户想从红方视角回放，不翻转
- **建议**：ReplayBoardView 暂不翻转（保持红方视角），后续可增加翻转选项

### 3. 切换执方时棋盘动画

`humanSide` 变化触发翻转，棋盘和棋子位置变化：
- 棋子位置变化：PieceView 已有 `.animation(.spring(...), value: piece.position)`，但 piece.position 不变（Board 坐标不变）
- 翻转触发：是 isFlipped 状态变化 → posToCGPoint 返回不同的 CGPoint → 棋子的 `.position()` modifier 输入变化
- **需要额外添加动画**：棋子 `.position()` modifier 需要添加 `.animation(.spring(), value: isFlipped)` 来响应翻转

具体表现：
- **切换执方时**：所有棋子从原位置平滑移动到翻转后的位置，动画时长约 0.3 秒，使用 spring 动画
- **AI 走法时**：AI 走棋触发的棋子位置变化使用 PieceView 自带的 `.animation(.spring(...), value: piece.position)`
- **两个动画叠加**：切换执方会开新局（`viewModel.newGame()`），棋盘重置 → 所有棋子回到初始位置 → 翻转生效。新局动画和翻转动画同时发生，但棋子初始位置和翻转位置都是初始布局，视觉上是棋子一次性移动到正确位置

**补充代码**：
```swift
PieceView(piece: piece, isSelected: isSelected, cellSize: cellSize, theme: theme)
    .position(posToCGPoint(piece.position, cellSize: cellSize, padding: padding, flipped: isFlipped))
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFlipped)  // 新增
    .allowsHitTesting(false)
```

### 4. 拖拽过程中切换执方

**不应发生**：切换执方会自动开新局（`viewModel.newGame()`），棋盘重置，拖拽状态清空。

### 5. 深色模式

翻转不影响颜色和主题，深色模式下棋盘仍然正确渲染。

## 测试要点

1. **执红时棋盘正常**：红方在底部，黑方在顶部
2. **执黑时棋盘翻转**：黑方在底部，红方在顶部
3. **棋子文字不倒置**
4. **楚河汉界文字顺序正确**：执黑时"汉 界"在左
5. **点击位置正确**：点击棋盘底部 → 执红时 row 9，执黑时 row 0
6. **拖拽位置正确**：拖拽棋子到目标位置 → Board 坐标正确
7. **合法走法提示位置正确**：显示在翻转后的正确位置
8. **提示功能位置正确**：hintMove 高亮在翻转后的正确位置
9. **将军高亮位置正确**：被将方的帅/将位置正确显示
10. **AI 走法正确**：AI 走法动画显示在翻转后的正确位置
11. **棋谱记录不变**：UCI 坐标基于 Board，翻转不影响记录
12. **切换执方动画自然**：棋子位置变化动画平滑
---

## Vera 审查记录

### 第一轮审查（方案审查）

**审查人**：Vera（inspector）
**审查日期**：2026-06-25
**结论**：方案 B 技术路线正确，坐标映射公式无误。修复 P0 后可进入实现，不阻塞工期。

#### P0 × 1（阻断级）

1. **实施清单缺失删除步骤**：ChessBoardView 已有私有 `cgPointToPos` 方法，方案 B 新增了带 `flipped` 参数的版本但未说明需要删除旧的私有方法。如果不删除，会导致方法冲突或歧义。

#### P1 × 3（强烈建议修复）

2. **AI 动画处理未说明**：AI 走棋时的棋子位置变化在翻转模式下如何处理未在方案中描述。
3. **ReplayBoardView lastMove 翻转未说明**：虽然方案明确 ReplayBoardView 不改动，但 lastMove 高亮在回放模式下的行为需要补充说明。
4. **拖拽坐标系关系需补充**：方案说拖拽 offset 不需要翻转，但未详细解释 ZStack 本地坐标系与翻转后坐标的关系。执黑时点击棋盘底部对应 row 0（黑方底线），这个映射关系需要在文档中明确。

#### P2 × 3（建议考虑）

5. **九宫描述不精确**：方案说"九宫对角线翻转后视觉相同"，但应明确说明是因为九宫关于棋盘中心点对称。
6. **星标记翻转需解释**：炮位和兵卒位对称分布，翻转后视觉相同，但原因需补充说明。
7. **Puzzle 模式 isFlipped 需明确**：方案提到 `vm.playerSide == .black`，但未说明 Puzzle 模式是否支持执黑。

### 第二轮复审（P0 修复后）

**结论**：P0/P1 全部通过验证，方案可进入实施阶段。

**新发现 P1**：`stopSearch` 线程安全性假设需验证（pikafish_stop() 是否只设置 volatile flag）— 此项为 iOS 外部引擎方案的审查结论，棋盘翻转方案不涉及。

---

## 实施记录（Postscript）

### Tina 测试发现的 P1 Bug

**问题**：执黑时棋子拖拽不工作。
**根因**：`isPlayerPiece` 硬编码 `.red`，执黑时黑方棋子被判定为非玩家棋子，无法启动拖拽。
**修复**：`isPlayerPiece` 改为基于 `viewModel.humanSide` 判断。
**教训**：Vera 第一轮审查 P1 #4"拖拽坐标系关系需补充"已提示了拖拽相关的风险区域，但实施时仍未覆盖到 `isPlayerPiece` 的硬编码问题。如果审查结论在实施文档中可见，开发者可能更早注意到这个风险点。

### 最终交付

- 版本号：v3.3.0
- 门禁验证：7/7 全部通过
- 产物：~/DevTeam/projects/chinese-chess/中国象棋-v3.3.0.app
- 时间戳：Jun 25 18:54:57
