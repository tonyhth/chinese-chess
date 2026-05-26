# AI 算法设计文档 — 中国象棋 macOS 原生应用

> 版本：v2 | 作者：Alex | 日期：2025-07-14

---

## 1. 概览

AI 引擎支持三个难度级别，由 `AIDifficulty` 枚举控制。AI 永远执黑方。

| 难度 | 策略 | 搜索深度 | 目标思考时间 |
|------|------|---------|-------------|
| 初级 | 随机合法走法 | 0 | < 1ms |
| 中级 | 启发式评估 + 贪心搜索 | 2 | < 50ms |
| 高级 | Minimax + Alpha-Beta 剪枝 | ≥ 4（自适应） | < 2s |

---

## 2. 初级难度：随机合法走法

### 2.1 算法

```
randomMove(board):
    moves = MoveValidator.allLegalMoves(for: .black, on: board)
    if moves.isEmpty: return nil
    return moves.randomElement()
```

### 2.2 说明

- 从所有合法走法中均匀随机选取一个
- 无任何评估，纯随机
- 保证走法合法性（不会自杀送将）
- 适合新手学习基本规则

---

## 3. 中级难度：Minimax 深度 2，无 Alpha-Beta 剪枝

### 3.1 策略

使用标准 Minimax 深度 2 搜索（不做 Alpha-Beta 剪枝，深度浅优化收益低）：

1. 生成所有合法走法
2. 对每个走法，执行后评估局面得分（深度 1）
3. 对每个对手回应，评估局面得分（深度 2）
4. 选择最不利于 AI（黑方）最小的最大值（即标准 Minimax）

### 3.2 算法

```
minimaxDepth2(board):
    moves = MoveValidator.allLegalMoves(for: .black, on: board)
    bestMove = nil
    bestScore = -∞
    
    for move in moves:
        board.execute(move)
        
        // Minimax：对手取最小值
        opponentMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        worstCase = +∞
        
        if opponentMoves.isEmpty:
            worstCase = +100000
        else:
            for opMove in opponentMoves:
                board.execute(opMove)
                score = evaluate(board)  // 黑方视角
                worstCase = min(worstCase, score)
                board.undoLastMove()
        
        bestScore = max(bestScore, worstCase)
        if bestScore == worstCase:
            bestMove = move
        
        board.undoLastMove()
    
    return bestMove
```

### 3.3 说明

- 标准 Minimax 搜索，深度固定为 2（AI 一步 + 对手一步）
- 不做 Alpha-Beta 剪枝（深度浅，优化收益低）
- 计算量小，响应快（< 50ms）

---

## 4. 高级难度：Minimax + Alpha-Beta 剪枝

### 4.1 核心算法

标准 Minimax + Alpha-Beta 剪枝：

```swift
func minimax(board: Board, depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
    // 终止条件
    if depth == 0 || isTerminal(board) {
        return evaluate(board)  // 黑方视角
    }
    
    let side: Side = isMaximizing ? .black : .red
    var moves = MoveValidator.allLegalMoves(for: side, on: board)
    moves = orderMoves(moves, on: board)  // 走法排序优化
    
    if isMaximizing {
        var maxEval = Int.min
        for move in moves {
            board.execute(move)
            let eval = minimax(board: board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
            board.undoLastMove()
            maxEval = max(maxEval, eval)
            alpha = max(alpha, eval)
            if beta <= alpha { break }  // 剪枝
        }
        return maxEval
    } else {
        var minEval = Int.max
        for move in moves {
            board.execute(move)
            let eval = minimax(board: board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
            board.undoLastMove()
            minEval = min(minEval, eval)
            beta = min(beta, eval)
            if beta <= alpha { break }  // 剪枝
        }
        return minEval
    }
}
```

### 4.2 最佳走法选择

```
bestMove(board):
    moves = MoveValidator.allLegalMoves(for: .black, on: board)
    moves = orderMoves(moves, on: board)
    bestMove = nil
    bestScore = -∞
    
    for move in moves:
        board.execute(move)
        score = minimax(board: board, depth: maxDepth - 1, alpha: -∞, beta: +∞, isMaximizing: false)
        board.undoLastMove()
        if score > bestScore:
            bestScore = score
            bestMove = move
    
    return bestMove
```

### 4.3 搜索深度策略

| 阶段 | 搜索深度 | 说明 |
|------|---------|------|
| 开局（前 10 回合） | 4 | 走法数量多但局面变化小 |
| 中局（10-30 回合） | 4 | 核心战斗阶段 |
| 残局（30 回合后） | 5 | 棋子少，搜索树小，可加深 |

当剩余棋子总数 ≤ 10 时自动将搜索深度 +1。

### 4.4 自适应深度

设置最大搜索时间 2 秒。使用迭代加深：

```
iterativeDeepening(board):
    bestMoveSoFar = nil
    for depth in 2...maxDepth:
        start = Date()
        move = searchAtDepth(board, depth)
        if Date().timeSince(start) > 1.0:
            break  // 时间快到了，不再加深
        bestMoveSoFar = move
    return bestMoveSoFar
```

---

## 5. 评估函数

### 5.1 设计思路

评估函数是 AI 的"眼光"。基础版本采用两因素加权（机动性为优化阶段可选项）：

```
评估分 = 子力价值 + 位置价值
```

所有分值从**黑方视角**计算（正值有利于黑方，负值有利于红方）。

### 5.2 子力价值

| 棋子 | 基础价值 |
|------|---------|
| 将/帅 | 10000 |
| 车 | 900 |
| 炮 | 450 |
| 马 | 400 |
| 士/仕 | 200 |
| 象/相 | 200 |
| 兵/卒（未过河） | 100 |
| 兵/卒（已过河） | 200 |

```
materialScore = Σ(blackPieces.baseValue) - Σ(redPieces.baseValue)
```

### 5.3 位置价值

每种棋子在不同位置有不同价值。使用 10×9 的位置权重表。

**设计原则**：
- 控制中心 > 边缘
- 过河兵/卒价值高于未过河
- 马/炮在开阔位置价值更高
- 车/炮在开放线路上价值更高

**兵/卒位置权重表示例**（黑卒，10×9）：

```
// 黑卒从北向南进攻，row 越大越接近红方底线
row 0:  [0,  0,  0,  0,  0,  0,  0,  0,  0]   // 初始行，未过河
row 1:  [0,  0,  0,  0,  0,  0,  0,  0,  0]
row 2:  [0,  0,  0,  0,  0,  0,  0,  0,  0]
row 3:  [2,  0,  4,  0,  8,  0,  4,  0,  2]   // 初始兵位
row 4:  [6, 12, 18, 18, 20, 18, 18, 12,  6]   // 过河第一线
row 5:  [10, 20, 30, 34, 40, 34, 30, 20, 10]  // 深入红方
row 6:  [14, 26, 42, 60, 80, 60, 42, 26, 14]  // 兵/卒初始位（红方视角对称）
row 7:  [18, 36, 56, 80, 120, 80, 56, 36, 18] // 接近底线
row 8:  [0,  3,  6,  6,  6,  6,  6,  3,  0]   // 底线（价值降低，到底了）
row 9:  [0,  0,  0,  0,  0,  0,  0,  0,  0]   // 无效
```

每种棋子类型都有对应的位置权重表。红方表为黑方表的上下镜像。

```
positionScore = Σ(blackPiece.positionWeight) - Σ(redPiece.positionWeight)
```

### 5.4 机动性（优化阶段可选项）

> ⚠️ 机动性在基础版本中**不实现**。原因：`mobilityScore` 需要调用 `allLegalMoves`（双方），在深度 4-5 搜索中每个叶节点都调用，开销可能超过搜索本身。留作性能调优阶段的可选项。

若后续实现，方案如下：

```
mobilityScore = (黑方合法走法数 - 红方合法走法数) × 5
```

或用"伪合法走法数"（不检查送将）替代完整合法走法数，降低计算成本。

### 5.5 综合评估

```
evaluate(board):
    if 黑方被将死: return -100000
    if 红方被将死: return +100000
    
    material = computeMaterial(board)
    position = computePosition(board)
    
    return material + position
    // 机动性为优化阶段可选项，基础版本不包含
```

### 5.6 评估分值范围

| 因素 | 典型范围 | 说明 |
|------|---------|------|
| 子力价值 | [-10000, +10000] | 最大差距：吃光对方 |
| 位置价值 | [-500, +500] | 所有棋子位置权重之和 |

---

## 6. 走法排序优化

### 6.1 目的

Alpha-Beta 剪枝的效率高度依赖节点搜索顺序。最优走法先搜索可大幅提高剪枝效率。

### 6.2 排序策略

按以下优先级排序：

```
orderMoves(moves, board):
    scored = moves.map { move -> (Move, Int) in
        var score = 0
        
        // 1. 吃子走法优先（MVV-LVA：最有价值的受害者 - 最低价值的攻击者）
        if let captured = move.captured {
            score += 10000 + captured.baseValue * 10 - move.piece.baseValue
        }
        
        // 2. 将军走法优先
        board.execute(move)
        if MoveValidator.isInCheck(.red, on: board) {
            score += 5000
        }
        board.undoLastMove()
        
        return (move, score)
    }
    
    return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
}
```

### 6.3 排序效果预期

| 优化 | 剪枝率提升 |
|------|----------|
| 无排序 | 基线（几乎无剪枝） |
| 吃子优先 | ~40% 节点剪枝 |
| 吃子 + 将军优先 | ~60% 节点剪枝 |

---

## 7. 性能优化

### 7.1 Make/Unmake 模式

AI 搜索过程中不复制 Board，而是原地修改 + 撤销：

```
// ❌ 避免：每次搜索复制棋盘
let newBoard = board.copy()
newBoard.execute(move)

// ✅ 采用：原地修改 + 撤销
board.execute(move)
// ... 递归搜索 ...
board.undoLastMove()
```

**理由**：深度 4 搜索约需 50,000-200,000 次走法尝试，复制棋盘的开销不可接受。

### 7.2 终止条件优化

```swift
func isTerminal(_ board: Board) -> Bool {
    // 快速检查：某方无将/帅 = 直接结束
    if board.generalPosition(of: .red) == nil { return true }
    if board.generalPosition(of: .black) == nil { return true }
    // 无合法走法 = 结束
    let side = board.currentTurn
    return MoveValidator.allLegalMoves(for: side, on: board).isEmpty
}
```

### 7.3 杀手启发（Killer Heuristic）—— 可选扩展

记录每层导致剪枝的走法（killer move），在同一层的其他分支优先搜索该走法。

**优先级**：Phase 1 不实现，作为性能调优阶段的可选项。

### 7.4 置换表（Transposition Table）—— 可选扩展

使用哈希表缓存已搜索局面的评估值，避免重复计算。

**优先级**：Phase 1 不实现。如高级难度思考时间超过 2 秒，再引入。

**Zobrist 哈希**（预留接口）：

```swift
struct ZobristHash {
    static let table: [[UInt64]]  // [position][pieceType] → 随机数
    // 增量更新：move 执行时 XOR 对应位置
}
```

---

## 8. AI 难度对比总结

| 维度 | 初级 | 中级 | 高级 |
|------|------|------|------|
| 策略 | 纯随机 | Minimax 深度 2 | Minimax + Alpha-Beta |
| 搜索深度 | 0 | 2 | 4-5（自适应） |
| 评估函数 | 无 | 子力 + 位置 | 子力 + 位置 |
| 走法排序 | 无 | 无 | MVV-LVA + 将军优先 |
| 思考时间 | < 1ms | < 50ms | < 2s |
| 棋力 | 新手 | 业余初级 | 业余中级 |
| 适用场景 | 学习规则 | 日常对弈 | 挑战自我 |

---

## 9. 测试策略

### 9.1 评估函数测试

| 测试用例 | 说明 |
|---------|------|
| 初始局面评估 ≈ 0 | 双方对称，评估值应接近 0 |
| 缺车一方评估值下降约 900 | 单子力变化 |
| 黑方多一车，评估值 ≈ +900 | 子力优势反映准确 |

### 9.2 搜索算法测试

| 测试用例 | 说明 |
|---------|------|
| 初级：100 次走法均为合法 | 随机性不影响合法性 |
| 中级：一步杀能找到 | 深度 2 足够发现一步杀 |
| 高级：两步杀能找到 | 深度 4 应能发现两步杀 |
| 高级：不会自杀送将 | 任何走法后己方将/帅安全 |
| 高级：吃子优于不吃子 | 在同等局面下优先吃子 |

### 9.3 性能测试

| 测试用例 | 基准 |
|---------|------|
| 高级难度初始局面思考时间 | < 2s |
| 高级难度残局思考时间 | < 1s |
| 中级难度任意局面 | < 100ms |
| 初级难度 | < 5ms |

### 9.4 经典残局测试

用于验证 AI 搜索正确性：

1. **单车杀王**：车 + 帅 vs 将 → AI 应能在限定步数内将死
2. **马炮联杀**：已知杀局 → AI 应能找到杀招
3. **弃子杀局**：需要牺牲子力换取杀招 → 验证搜索深度足够
