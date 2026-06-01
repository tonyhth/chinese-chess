# Phase 3: 棋谱 + 人人对战 + 统计

> **通用设计见 v2-common.md**,本文件仅包含 Phase 3 特定的设计细节和交付物。

- **Phase**: 3 — 棋谱 + 人人对战 + 统计
- **依赖**: Phase 1（数据模型）
- **验证**: `swift build` + `swift test`（棋谱生成单元测试通过）
- **工期**: 2-3 天

---

## Phase 3 交付物

1. `NotationGenerator.swift`(ICCS 中文坐标法生成)
2. `GameViewModel` 扩展:GameMode 支持、GameMove 记录
3. `RecordPanelView.swift`(棋谱记录面板)
4. `StatsManager.swift`(胜率统计持久化)
5. `StatsViewModel.swift` + `StatsPanelView.swift`
6. `GameMode` 切换 UI
7. 棋谱生成单元测试(重点测试消歧义逻辑)
8. 人人对战完整流程测试

## 验证标准

- NotationGenerator 通过 ≥ 20 个测试用例(含消歧义)
- 人人对战完整对局无崩溃
- 统计数据正确记录和读取
- `swift test` 全部通过

---

## 4. 棋谱数据模型（Phase 3 相关: NotationGenerator）

### 4.3 ICCS 中文坐标法生成算法(NotationGenerator.swift)

#### 规则概述

中国象棋纵线坐标法:
- **红方**纵线从右到左编号:一、二、三、四、五、六、七、八、九(对应列 8→0)
- **黑方**纵线从右到左编号:1、2、3、4、5、6、7、8、9(对应列 0→8)
- 纵线编号即棋子所在列的编号
- 动作:进(向前)、退(向后)、平(横走)
- 步数:直线走子(车/炮/兵/将)用到达行号;斜走子(马/象/士)用步数

#### 前后同线消歧义

当同方同类型棋子在同一纵线时(如双车、双马),需要用"前/后"消歧义:

```swift
struct NotationGenerator {
    /// 生成一步棋的中文坐标法描述
    static func notation(
        for move: Move,
        on board: Board,         // 走之前的棋盘状态
        allPieces: [Piece]       // 走之前的所有棋子
    ) -> String {
        let piece = move.piece
        let from = move.from
        let to = move.to

        // 1. 确定纵线编号
        let fileNumber = fileNumber(for: piece, at: from)

        // 2. 检查同方同类型同纵线的棋子(消歧义)
        let disambiguation = disambiguationPrefix(
            piece: piece, at: from, allPieces: allPieces
        )

        // 3. 确定动作和目标
        let actionAndTarget = actionTarget(
            piece: piece, from: from, to: to
        )

        return disambiguation + pieceName(piece) + fileNumber
               + actionAndTarget
    }

    // 消歧义:检查同列同类型棋子
    private static func disambiguationPrefix(
        piece: Piece, at pos: Position, allPieces: [Piece]
    ) -> String {
        let sameKindSameFile = allPieces.filter {
            $0.kind == piece.kind
            && $0.side == piece.side
            && $0.position.col == pos.col
            && $0.id != piece.id
        }

        guard !sameKindSameFile.isEmpty else { return "" }

        // 同列有同类型棋子,用 "前"/"后" 区分
        // 红方:行号小的在前(靠近黑方 = 前进方向)
        // 黑方:行号大的在前(靠近红方 = 前进方向)
        let isRed = piece.side == .red
        let myRow = pos.row
        let otherRow = sameKindSameFile[0].position.row

        if isRed {
            return myRow < otherRow ? "前" : "后"
        } else {
            return myRow > otherRow ? "前" : "后"
        }
    }
}
```

#### 完整生成流程

```
输入:Move(piece, from, to, captured) + 走前的 board 快照

1. 获取棋子显示名(帅/仕/相/馬/車/炮/兵 或 将/士/象/馬/車/砲/卒)
2. 获取纵线编号(红方用中文数字,黑方用阿拉伯数字)
3. 检查是否需要"前/后"消歧义
4. 判断动作和目标:
   a. 横走(from.col ≠ to.col && from.row == to.row)→ "平" + 目标纵线号
   b. 直线走子(车/炮/兵/将)纵向移动 → "进/退" + 格数(|from.row - to.row|)
   c. 斜线走子(马/象/士)纵向移动 → "进/退" + 目标纵线号
5. 拼接:[前/后] + 棋子名 + 纵线号 + 动作 + 目标
```

**推导示例**:

| # | 走法 | 棋子 | 纵线 | 动作 | 目标 | 标准棋谱 |
|---|------|------|------|------|------|----------|
| 1 | 红炮(7,7)→(7,4) | 炮 | col=7→二 | 平(横走) | col=4→五 | 炮二平五 |
| 2 | 黑马(0,1)→(2,2) | 马 | col=1→8 | 进(斜走) | col=2→7 | 马8进7 |
| 3 | 红马(9,1)→(7,2) | 馬 | col=1→八 | 进(斜走) | col=2→七 | 馬八进七 |
| 4 | 红车(9,0)→(5,0) | 車 | col=0→九 | 进(直线) | 格数=4 | 車九进四 |
| 5 | 红兵(6,4)→(5,4) | 兵 | col=4→五 | 进(直线) | 格数=1 | 兵五进一 |

**纵线编号映射**(已验证):

```swift
// 红方:col 0→九, 1→八, ..., 8→一
private static let redFileNames = ["九","八","七","六","五","四","三","二","一"]

// 黑方:col 0→9, 1→8, ..., 8→1(黑方右侧=棋盘左=col 0→纵线9)
private static let blackFileNames = ["9","8","7","6","5","4","3","2","1"]
```

**注意**:纵线编号映射是棋谱系统中最容易出错的部分,必须写充分的单元测试覆盖。建议 Cody 编写测试时,以这 5 个推导示例作为首批 test case。

#### 纵线编号映射(已验证)

**关键规则**:
- 红方坐北朝南,纵线从右到左编号一至九
- 黑方坐南朝北,纵线从右到左编号 1 至 9
- "从右到左"是**各自视角**的右
- 在棋盘数据结构中:col 0 = 棋盘最左列,col 8 = 棋盘最右列

**红方映射**(红方视角:最右列 = col 8 → 纵线一):
```
col:  0  1  2  3  4  5  6  7  8
纵线: 九 八 七 六 五 四 三 二 一
```

**黑方映射**(黑方视角:最右列 = col 0 → 纵线 9):
```
col:  0  1  2  3  4  5  6  7  8
纵线: 9  8  7  6  5  4  3  2  1
```

```swift
private static let redFileNames = ["九","八","七","六","五","四","三","二","一"]
private static let blackFileNames = ["9","8","7","6","5","4","3","2","1"]
```

---

## 6. 人人对战和胜率统计（Phase 3 相关: StatsManager）

### 6.2 胜率统计存储方案(StatsManager.swift)

```swift
struct GameStats: Codable {
    // 人机对战统计(按难度)
    var vsAI: [AIDifficulty: WinLossDraw] = [:]

    // 人人对战统计
    var pvp: WinLossDraw = WinLossDraw()

    // 残局统计
    var puzzlesCompleted: Int = 0
    var puzzlesTotal: Int = 0
}

struct WinLossDraw: Codable {
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0

    var total: Int { wins + losses + draws }
    var winRate: Double {
        total == 0 ? 0 : Double(wins) / Double(total)
    }
}

final class StatsManager {
    static let shared = StatsManager()

    private let defaults = UserDefaults.standard
    private let statsKey = "chinesechess.stats"

    var stats: GameStats {
        // 读取 + 解码
    }

    func recordWin(for difficulty: AIDifficulty) { ... }
    func recordLoss(for difficulty: AIDifficulty) { ... }
    func recordDraw(for difficulty: AIDifficulty) { ... }
    func recordPVPWin(for side: Side) { ... }
    func reset() { ... }
}
```

**存储格式**:UserDefaults 中存储 JSON 编码的 `GameStats`。

**人人对战统计**:只记录总局数和和棋数。红方胜/黑方胜在本地人人场景下对用户意义不大(两人面对面玩,换边后红黑交替),不如记录总对局数有参考价值。

```swift
struct PVPStats: Codable {
    var totalGames: Int = 0
    var draws: Int = 0
}
```
