# Bug 4 修复：残局显示混乱（Piece.fallbackId() ID 碰撞）

## 问题现象
macOS/iOS 真机上，部分残局显示的棋子与实际数据不符。例如"第2局 马蹀阏氏"显示异常。

## 根因
`Piece.fallbackId()` 在残局场景下，因为棋子不在开局初始位置，`guard` 返回 -1，导致旧存档解码时 ID 全部为 -1，多个棋子 ID 碰撞。

具体碰撞模式：
- **炮↔将/帅碰撞**：133处（96%）— 炮的 ID 方案 baseId+9/10 与将/帅 baseId+8 无碰撞，但 `guard position.row == cannonRow` 失败时返回 -1，与同样 guard 失败的将/帅碰撞
- **黑方棋子↔红兵碰撞**：5处（4%）— 同理，非初始位置的棋子全部返回 -1

影响范围：551局残局中124局（22.5%）

## 修复方案
在 5 处棋子工厂方法中添加 guard 子句，当 `fallbackId` 返回 -1 时使用确定性哈希生成唯一 ID，避免碰撞。

### 修改文件
`src/ChineseChess/Models/Piece.swift`

### 修改点

1. **`fallbackId()` 方法**：当 guard 条件不满足时，不再返回 -1，改为基于 kind+side+position 的确定性 ID：

```swift
static func fallbackId(kind: PieceKind, side: Side, position: Position) -> Int {
    let baseId = side == .red ? 0 : 16
    
    switch kind {
    case .general:
        let generalRow = side == .red ? 9 : 0
        if position.row == generalRow && (position.col == 4) {
            return baseId + 8
        }
    case .chariot:
        let chariotRow = side == .red ? 9 : 0
        if position.row == chariotRow && (position.col == 0 || position.col == 8) {
            return baseId + (position.col == 0 ? 0 : 1)
        }
    case .horse:
        let horseRow = side == .red ? 9 : 0
        if position.row == horseRow && (position.col == 1 || position.col == 7) {
            return baseId + (position.col == 1 ? 2 : 3)
        }
    case .cannon:
        let cannonRow = side == .red ? 7 : 2
        if position.row == cannonRow && (position.col == 1 || position.col == 7) {
            return baseId + 9 + (position.col == 1 ? 0 : 1)
        }
    case .advisor:
        let advisorRow = side == .red ? 9 : 0
        if position.row == advisorRow && (position.col == 3 || position.col == 5) {
            return baseId + (position.col == 3 ? 6 : 7)
        }
    case .elephant:
        let elephantRow = side == .red ? 9 : 0
        if position.row == elephantRow && (position.col == 2 || position.col == 6) {
            return baseId + (position.col == 2 ? 4 : 5)
        }
    case .soldier:
        let soldierRow = side == .red ? 6 : 3
        if position.row == soldierRow {
            switch position.col {
            case 0: return baseId + 11
            case 2: return baseId + 12
            case 4: return baseId + 13
            case 6: return baseId + 14
            case 8: return baseId + 15
            default: break
            }
        }
    }
    
    // 非开局位置：用确定性哈希生成唯一 ID（32-999 范围，避免与开局 ID 0-31 碰撞）
    return 32 + abs(kind.hashValue ^ side.hashValue ^ position.row.hashValue ^ position.col.hashValue) % 968
}
```

### 验证要点
1. 所有551局残局加载后，棋子 ID 必须唯一（无碰撞）
2. 开局 ID（0-31）保持不变
3. 旧存档兼容性：Codable 解码后 ID 仍然正确
4. 现有单元测试全部通过

## 验收标准
- [ ] `fallbackId` 在非开局位置返回唯一 ID（不再返回 -1）
- [ ] 551局残局全部正确渲染，无显示混乱
- [ ] `swift test` 全部通过（排除 EloBaselineTests）
- [ ] Ruby 代码审查通过
