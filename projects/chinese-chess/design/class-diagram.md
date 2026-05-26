# 类设计文档 — 中国象棋 macOS 原生应用

> 版本：v2 | 作者：Alex | 日期：2025-07-14

---

## 1. 概览

本文档定义中国象棋应用的全部核心类、它们的属性、方法以及相互关系。所有类型均使用 Swift 实现。

### 设计原则

- **值类型优先**：棋子、位置、走法等不可变数据使用 `struct`
- **引用类型用于状态**：棋盘、ViewModel 等需要共享可变状态的使用 `class`
- **协议抽象**：AI 引擎通过协议抽象，便于测试和扩展
- **无可选第三方依赖**：所有类型均为标准库 + SwiftUI / AVFoundation

---

## 2. 基础类型

### 2.1 `Position`（位置）

```swift
struct Position: Equatable, Hashable {
    let row: Int    // 0..9，0 = 黑方底线，9 = 红方底线
    let col: Int    // 0..8，0 = 最左列
}
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `row` | `Int` | 行号 0-9 |
| `col` | `Int` | 列号 0-8 |

| 方法 | 签名 | 说明 |
|------|------|------|
| 是否在棋盘内 | `static func isValid(_ pos: Position) -> Bool` | row ∈ [0,9] 且 col ∈ [0,8] |
| 是否在红方九宫 | `var isInRedPalace: Bool` | row ∈ [7,9] 且 col ∈ [3,5] |
| 是否在黑方九宫 | `var isInBlackPalace: Bool` | row ∈ [0,2] 且 col ∈ [3,5] |
| 是否在红方半场 | `var isInRedHalf: Bool` | row ∈ [5,9] |
| 是否在黑方半场 | `var isInBlackHalf: Bool` | row ∈ [0,4] |

### 2.2 枚举类型

```swift
// 棋子类型
enum PieceKind: String, CaseIterable {
    case general   // 将/帅
    case advisor   // 士/仕
    case elephant  // 象/相
    case horse     // 马
    case chariot   // 车
    case cannon    // 炮
    case soldier   // 兵/卒
}

// 阵营
enum Side: String {
    case red
    case black
}

// 游戏状态
enum GameState: Equatable {
    case playing
    case redWon
    case blackWon
    case draw
}

// AI 难度
enum AIDifficulty: String, CaseIterable {
    case easy
    case medium
    case hard
}
```

---

## 3. 核心模型类

### 3.1 `Piece`（棋子）

```swift
struct Piece: Equatable, Identifiable {
    let id: UUID
    let kind: PieceKind
    let side: Side
    var position: Position
}
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `id` | `UUID` | 唯一标识 |
| `kind` | `PieceKind` | 棋子类型 |
| `side` | `Side` | 阵营 |
| `position` | `Position` | 当前位置（可变，移动时更新） |

| 计算属性 | 说明 |
|---------|------|
| `displayName: String` | 返回中文名：红方帅/仕/相/马/车/炮/兵，黑方将/士/象/马/车/炮/卒 |
| `baseValue: Int` | 子力基础价值（用于 AI 评估） |

**子力基础价值表**：

| 棋子 | 价值 |
|------|------|
| 将/帅 | 10000 |
| 车 | 900 |
| 马 | 400 |
| 炮 | 450 |
| 士/仕 | 200 |
| 象/相 | 200 |
| 兵/卒 | 100（过河后 200） |

### 3.2 `Move`（走法）

```swift
struct Move: Equatable {
    let piece: Piece          // 移动的棋子（移动前快照）
    let from: Position        // 起点
    let to: Position          // 终点
    let captured: Piece?      // 被吃棋子（无则 nil）
}
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `piece` | `Piece` | 移动的棋子快照 |
| `from` | `Position` | 起始位置 |
| `to` | `Position` | 目标位置 |
| `captured` | `Piece?` | 被吃的棋子，无吃子时为 nil |

### 3.3 `Board`（棋盘）

```swift
@Observable
class Board {
    private(set) var pieces: [Piece]
    private(set) var moveHistory: [Move]
    
    init()  // 初始化标准开局
    init(pieces: [Piece])  // 自定义局面（测试用）
}
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `pieces` | `[Piece]` | 所有存活棋子 |
| `moveHistory` | `[Move]` | 走法历史（用于悔棋） |

| 方法 | 签名 | 说明 |
|------|------|------|
| 初始化棋盘 | `static func initialBoard() -> Board` | 标准开局布局 |
| 获取某位置棋子 | `func piece(at pos: Position) -> Piece?` | 按位置查找 |
| 执行走法 | `func execute(_ move: Move) -> Move` | 更新棋子位置，记录历史 |
| 撤销走法 | `func undoLastMove() -> Move?` | 弹出最后一步并还原 |
| 获取某方所有棋子 | `func pieces(for side: Side) -> [Piece]` | 按阵营筛选 |
| 查找将/帅位置 | `func generalPosition(of side: Side) -> Position?` | 查找主帅位置 |
| 是否存在棋子 | `func hasPiece(at pos: Position) -> Bool` | 位置是否被占用 |
| 获取当前方 | `var currentTurn: Side` | 红先手，交替执行 |

**标准开局布局**：

```
黑方（row 0-4）：
  车(0,0) 马(0,1) 象(0,2) 士(0,3) 将(0,4) 士(0,5) 象(0,6) 马(0,7) 车(0,8)
  炮(2,1) 炮(2,7)
  卒(3,0) 卒(3,2) 卒(3,4) 卒(3,6) 卒(3,8)

红方（row 5-9）：
  兵(6,0) 兵(6,2) 兵(6,4) 兵(6,6) 兵(6,8)
  炮(7,1) 炮(7,7)
  车(9,0) 马(9,1) 相(9,2) 仕(9,3) 帅(9,4) 仕(9,5) 相(9,6) 马(9,7) 车(9,8)
```

---

## 4. 规则校验

### 4.1 `MoveValidator`（走法校验器）

纯静态方法，无状态。所有方法均为 `static func`。

```swift
struct MoveValidator {
    // 主入口：判断走法是否合法
    static func isLegal(_ move: Move, on board: Board) -> Bool
    
    // 生成某棋子所有合法走法
    static func legalMoves(for piece: Piece, on board: Board) -> [Move]
    
    // 生成某方所有合法走法
    static func allLegalMoves(for side: Side, on board: Board) -> [Move]
    
    // 判断某方是否被将军
    static func isInCheck(_ side: Side, on board: Board) -> Bool
    
    // 判断某方是否被将死
    static func isCheckmate(_ side: Side, on board: Board) -> Bool
    
    // 判断某方是否被困毙（无合法走法但未被将军）
    static func isStalemate(_ side: Side, on board: Board) -> Bool
}
```

#### 移动规则实现明细

**将/帅**：
- 九宫格内一步直行（上下左右各一格）
- **将帅对面**：移动后检查同列是否存在对方将/帅且中间无子，若存在则该走法非法

**士/仕**：
- 九宫格内一步斜行（四个对角各一格）

**象/相**：
- 田字对角移动（两步斜线）
- **塞象眼**：田字中心点有子则不可走
- **不过河**：只能在己方半场

**马**：
- 日字移动（一步直行 + 一步斜行）
- **蹩马腿**：直行方向有子则该方向的两个日字走法均不可走
- 共 8 个可能目标位置（但实际受棋盘边界和蹩腿限制）

**车**：
- 直线任意格数（上下左右）
- 路径上不可有其他棋子（不可越子）
- 可吃对方棋子

**炮**：
- 移动：同车，直线不越子
- **吃子**：必须恰好翻越一个棋子（炮架），炮架与目标之间不可有其他棋子

**兵/卒**：
- 未过河：只能前进一步
- 过河后：可前进一步或左右平移一步
- 不可后退

#### 合法性检查流程

```
isLegal(move, board):
  1. 目标位置在棋盘范围内？
  2. 目标位置不是己方棋子？
  3. 该棋子类型的移动规则允许？(type-specific check)
  4. 执行后己方将/帅不被将军？(self-check test)
     → 临时执行，检查 isInCheck
```

#### isInCheck 语义说明

`isInCheck(side, board)` 判断某方是否处于被将军状态，包含以下情况：

1. 对方棋子直接攻击己方将/帅（常规将军）
2. **将帅对面**：己方将/帅与对方将/帅处于同一列，且中间无任何棋子遮挡

**关键**：将帅对面是送将的一种形式，等同于被将军。任何棋子移走后揭开同列将帅的遮挡也属于送将，必须被 `isLegal` 的 step 4（self-check test）拦截。这意味着：

- 将/帅主动移动到与对方将帅同列且无遮挡的位置 → 非法
- 任何其他棋子移走后，导致两将同列无遮挡 → 非法（等同于送将）
- isInCheck 内部必须检查将帅对面条件，而非仅在将/帅的移动规则中检查

---

## 5. AI 引擎

### 5.1 `AIEngineProtocol`（协议）

```swift
protocol AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}
```

### 5.2 `AIEngine`（实现）

```swift
struct AIEngine: AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}
```

| 方法 | 签名 | 说明 |
|------|------|------|
| 最佳走法 | `func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?` | 根据难度返回 AI 走法 |

内部私有方法：

| 方法 | 签名 | 说明 |
|------|------|------|
| 随机走法 | `private func randomMove(for board: Board) -> Move?` | 初级难度 |
| 启发式搜索 | `private func heuristicSearch(for board: Board, depth: Int) -> Move?` | 中级难度 |
| Minimax | `private func minimax(board:depth:alpha:beta:isMaximizing:) -> Int` | 高级难度 |
| 评估函数 | `private func evaluate(_ board: Board) -> Int` | 局面评估 |
| 走法排序 | `private func orderMoves(_ moves: [Move], on board: Board) -> [Move]` | 优化搜索效率 |

详细算法设计见 [ai-algorithm.md](ai-algorithm.md)。

---

## 6. ViewModel

### 6.1 `GameViewModel`

```swift
@Observable
class GameViewModel {
    var board: Board
    var selectedPosition: Position?
    var legalMoves: [Position]
    var currentTurn: Side
    var capturedPieces: (red: [Piece], black: [Piece])
    var moveHistory: [Move]
    var gameState: GameState
    var isThinking: Bool
    var difficulty: AIDifficulty
    
    init()
}
```

| 方法 | 签名 | 说明 |
|------|------|------|
| 选择棋子 | `func selectPiece(at pos: Position)` | `isThinking` 时忽略 |
| 移动棋子 | `func movePiece(from: Position, to: Position)` | `isThinking` 时忽略 |
| 触发 AI | `func triggerAIMove()` | 异步调用 AIEngine |
| 悔棋 | `func undoMove()` | `isThinking` 时忽略 |
| 新局 | `func newGame()` | `isThinking` 时忽略 |
| 设置难度 | `func setDifficulty(_ difficulty: AIDifficulty)` | 切换 AI 难度 |

#### 线程安全策略

**AI 思考期间 UI 操作禁用**：

- `triggerAIMove()` 执行前设置 `isThinking = true`
- View 层根据 `isThinking` 禁用棋盘点击、悔棋、新局按钮
- AI 走法应用后设置 `isThinking = false`

**AI 搜索使用棋盘深拷贝**：

- `triggerAIMove()` 在调用 `AIEngine.bestMove()` 前，对 `board` 做深拷贝（`board.snapshot()`）
- AI 引擎在拷贝上执行 make/unmake 操作，不影响主棋盘状态
- AI 返回走法结果后，ViewModel 在主棋盘上执行该走法

```swift
func triggerAIMove() {
    isThinking = true
    let snapshot = board.snapshot()  // 深拷贝
    Task.detached {
        let move = AIEngine().bestMove(for: snapshot, difficulty: self.difficulty)
        await MainActor.run {
            if let move = move {
                self.applyAIMove(move)
            }
            self.isThinking = false
        }
    }
}
```

### 6.2 `SettingsViewModel`

```swift
@Observable
class SettingsViewModel {
    var isSoundEnabled: Bool
    var difficulty: AIDifficulty
}
```

---

## 7. 音效服务

### 7.1 `SoundEngine`

```swift
class SoundEngine {
    static let shared = SoundEngine()
    var isMuted: Bool
    
    func playMove()
    func playCapture()
}
```

---

## 8. 类间关系

### 8.1 关系说明

```
GameViewModel ──持有──▶ Board（组合，1:1）
GameViewModel ──持有──▶ AIEngine（组合，1:1）
GameViewModel ──使用──▶ MoveValidator（依赖，静态方法调用）
GameViewModel ──使用──▶ SoundEngine（依赖，单例）
Board ──持有──▶ [Piece]（组合，1:32）
Board ──持有──▶ [Move]（组合，历史记录）
Move ──包含──▶ Piece（关联，移动的棋子 + 被吃棋子）
Piece ──包含──▶ Position（组合，当前位置）
MoveValidator ──依赖──▶ Board + Piece（参数传入）
AIEngine ──依赖──▶ Board + MoveValidator（读取棋盘 + 生成走法）
BoardView ──观察──▶ GameViewModel（SwiftUI 数据绑定）
PieceView ──观察──▶ GameViewModel（SwiftUI 数据绑定）
```

### 8.2 依赖方向

```
View 层 → ViewModel 层 → Model 层
                     ↘ Service 层（SoundEngine）
```

**严格单向依赖**：View 依赖 ViewModel，ViewModel 依赖 Model，Model 不依赖任何上层。

---

## 9. 测试支撑设计

### 9.1 可测试性

| 设计决策 | 支撑的测试类型 |
|---------|--------------|
| `MoveValidator` 全静态方法 | 无需 mock，直接输入输出断言 |
| `Board.init(pieces:)` 支持自定义局面 | 可构造特定残局测试胜负判定 |
| `AIEngineProtocol` 协议 | ViewModel 可注入 mock AI 进行集成测试 |
| `Piece` 是 `Equatable` | 走法结果可直接 `XCTAssertEqual` |
| `Move` 包含 `captured` | 可断言吃子是否正确 |

### 9.2 建议测试用例结构

```
ChineseChessTests/
├── MoveValidatorTests/
│   ├── GeneralMoveTests.swift        // 将/帅移动 + 对面规则
│   ├── AdvisorMoveTests.swift        // 士/仕九宫斜行
│   ├── ElephantMoveTests.swift       // 象/相田字 + 塞象眼 + 不过河
│   ├── HorseMoveTests.swift          // 马日字 + 蹩马腿
│   ├── ChariotMoveTests.swift        // 车直线
│   ├── CannonMoveTests.swift         // 炮移动 + 炮架吃子
│   ├── SoldierMoveTests.swift        // 兵/卒前进 + 过河
│   └── CheckCheckmateTests.swift     // 将军/将死/困毙
├── AIEngineTests/
│   ├── EasyAITests.swift
│   ├── MediumAITests.swift
│   └── HardAITests.swift
└── BoardTests/
    ├── InitialLayoutTests.swift
    ├── ExecuteUndoTests.swift
    └── GameFlowTests.swift
```
