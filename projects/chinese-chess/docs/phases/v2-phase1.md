# Phase 1: 跨平台基础 + 数据模型

> **通用设计见 v2-common.md**,本文件仅包含 Phase 1 特定的设计细节和交付物。

- **Phase**: 1 — 跨平台基础 + 数据模型
- **依赖**: 无
- **验证**: `swift build`（macOS + iOS 双 target 编译通过）
- **工期**: 2-3 天

---

## Phase 1 交付物

1. Xcode 项目结构(.xcodeproj),macOS + iOS 双 target
2. 所有 v1.0 源码迁移到共享目录
3. `Enums.swift` 扩展:5 级 AIDifficulty、GameMode
4. `GameMove.swift`、`GameRecord.swift` 新数据模型
5. `Board.swift` 扩展:FEN 初始化(`FENParser.swift`)
6. App 图标集成
7. macOS 版本编译通过 + 功能与 v1.0 一致
8. iOS 版本编译通过 + 基本棋盘显示

## 验证标准

- macOS target `swift build` 通过,v1.0 所有功能正常
- iOS target `swift build` 通过,棋盘可渲染
- FEN 解析 + 生成 roundtrip 正确

---

## 4. 棋谱数据模型（Phase 1 相关部分）

### 4.1 GameMove

```swift
struct GameMove: Identifiable {
    let id: UUID
    let piece: Piece           // 移动的棋子
    let from: Position         // 起点
    let to: Position           // 终点
    let captured: Piece?       // 被吃棋子

    // v2.0 新增
    let turnNumber: Int        // 回合号(从 1 开始,红黑各走一次 = 1 回合)
    let notation: String       // 棋谱文本,如 "炮二平五"、"马8进7"
    let timestamp: Date        // 走棋时间
    let isCheck: Bool          // 是否将军
    let isCheckmate: Bool      // 是否将死
}
```

### 4.1.1 GameMove 两阶段创建流程

GameMove 的字段分布在走棋前后两个时刻,需要两阶段创建:

**阶段 1(走棋前):构建 PendingMove**

在走棋执行之前,捕获当前 board 快照用于消歧义和棋谱生成:

```swift
struct PendingMove {
    let move: Move              // piece, from, to, captured(待定)
    let boardSnapshot: Board    // 走前的棋盘快照(用于 NotationGenerator)
    let piecesSnapshot: [Piece] // 走前的棋子列表(用于同列消歧义)
    let turnNumber: Int
    let timestamp: Date
}
```

**阶段 2(走棋后):补全 GameMove**

走棋执行完成后,用走后的 board 判断将军/将死,并补全所有字段:

```swift
// GameViewModel 中的流程
func executeAndRecord(from: Position, to: Position) {
    // 1. 走棋前:捕获快照 + 生成棋谱
    let piece = board.piece(at: from)!
    let captured = board.piece(at: to)
    let pending = PendingMove(
        move: Move(piece: piece, from: from, to: to, captured: captured),
        boardSnapshot: board.snapshot(),
        piecesSnapshot: board.pieces.map { $0 },
        turnNumber: board.moveHistory.count / 2 + 1,
        timestamp: Date()
    )
    let notation = NotationGenerator.notation(
        for: pending.move,
        on: pending.boardSnapshot,
        allPieces: pending.piecesSnapshot
    )

    // 2. 执行走法
    board.execute(pending.move)

    // 3. 走棋后:判断将军/将死
    let opponentSide: Side = (piece.side == .red) ? .black : .red
    let isCheck = MoveValidator.isInCheck(opponentSide, on: board)
    let isCheckmate = MoveValidator.isCheckmate(opponentSide, on: board)

    // 4. 构建 GameMove
    let gameMove = GameMove(
        id: UUID(),
        piece: piece,
        from: from, to: to,
        captured: captured,
        turnNumber: pending.turnNumber,
        notation: notation,
        timestamp: pending.timestamp,
        isCheck: isCheck,
        isCheckmate: isCheckmate
    )
    gameMoves.append(gameMove)
}
```

**关键点**:`PendingMove` 是内部临时结构,不暴露给外部。`GameMove` 是面向视图层的不可变记录。AI 搜索内部继续使用 `Move`(轻量),与 `GameMove` 完全解耦。

### 4.2 GameMove 与 v1.0 Move 的关系

**Move(v1.0 保留)**:AI 搜索内部使用的轻量走法记录。只含 piece/from/to/captured,用于 Board.execute/undoLastMove 和 minimax 搜索。

**GameMove(v2.0 新增)**:面向视图层的不可变记录。含棋谱文本、时间戳、将军标记等展示信息。

**并存策略**:
- AI 引擎内部(`AIEngine` / `CheckmateSearch` / minimax)**只用 Move**,不改
- `GameViewModel` 内部 `board.moveHistory` 继续存 `[Move]`,用于悔棋/undo
- `GameViewModel` 新增 `gameMoves: [GameMove]`,用于棋谱面板显示和回放
- AI 返回 `Move?`,GameViewModel 在 `triggerAIMove` 中执行 Move 后,走同样的两阶段流程创建 GameMove
- Move → GameMove 的转换统一在 `GameViewModel.executeAndRecord(from:to:)` 中完成

```swift
@Observable
class GameViewModel {
    var board: Board                    // board.moveHistory: [Move]
    var gameMoves: [GameMove] = []      // 新增:展示用
    // ...
}
```

### 4.3 GameRecord

```swift
struct GameRecord: Identifiable, Codable {
    let id: UUID
    var title: String          // "第 3 局" 或自定义标题
    let date: Date
    let redPlayer: PlayerInfo
    let blackPlayer: PlayerInfo
    let difficulty: AIDifficulty?   // 人机模式有值
    let gameMode: GameMode
    let result: GameState      // redWon / blackWon / draw
    let totalMoves: Int
    let moves: [GameMove]      // 完整走法列表
    let initialFEN: String?    // 非标准开局时记录
}

struct PlayerInfo: Codable {
    let name: String           // "玩家" / "AI-高级" / "红方" / "黑方"
    let isAI: Bool
    let difficulty: AIDifficulty?
}
```

---

## 5. 残局数据格式（Phase 1 相关: FENParser）

### 5.1 FEN 解析(FENParser.swift)

```swift
struct FENParser {
    /// 从 FEN 字符串创建 Board
    /// FEN 格式:rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1
    ///
    /// 棋子编码:
    /// 红方:K=帅, A=仕, B=相, N=馬, R=車, C=炮, P=兵(大写)
    /// 黑方:k=将, a=士, b=象, n=馬, r=車, c=砲, p=卒(小写)
    /// 数字:连续空格数
    /// 行分隔:/
    /// 行走方:w=红方, b=黑方
    static func parse(fen: String) -> Board? {
        // 1. 按 " " 分割,取第 1 段为局面,第 2 段为行走方
        // 2. 按 "/" 分割为 10 行
        // 3. 逐行解析棋子位置
        // 4. 构建 pieces 数组
        // 5. 设置 currentTurn
    }

    /// 从 Board 生成 FEN 字符串
    static func generate(board: Board) -> String
}
```

#### Board 扩展

```swift
extension Board {
    /// 从 FEN 初始化
    convenience init(fen: String) {
        // 调用 FENParser.parse
    }
}
```

---

## 6. 人人对战和胜率统计（Phase 1 相关: GameMode）

### 6.1 GameMode 设计

```swift
enum GameMode: String, CaseIterable, Codable {
    case singlePlayer    // 人机对战
    case localPVP        // 本地人人对战
}
```

**GameViewModel 扩展**:

```swift
// GameViewModel 新增属性
var gameMode: GameMode = .singlePlayer

// 走棋逻辑变更:
// singlePlayer: 红方走完后触发 AI(仅 AI 执黑)
// localPVP: 双方轮流走,不触发 AI

func selectPiece(at pos: Position) {
    // singlePlayer: 只允许红方(board.currentTurn == .red)操作
    // localPVP: 允许当前行走方操作
    if gameMode == .singlePlayer {
        guard board.currentTurn == .red else { return }
    }
    // ... 其余逻辑不变
}
```

**UI 差异**:
- singlePlayer:显示难度选择器、AI 思考状态
- localPVP:隐藏难度选择器,显示"红方走棋"/"黑方走棋"提示、无 AI 思考状态
