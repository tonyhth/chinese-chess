# Phase 2a: AI 基础设施

> **通用设计见 v2-common.md**,本文件仅包含 Phase 2a 特定的设计细节和交付物。

- **Phase**: 2a — AI 基础设施
- **依赖**: Phase 1（数据模型）
- **验证**: `swift build` + `swift test`（AI 基础设施单元测试通过）
- **工期**: 3 天

---

## Phase 2a 交付物

1. `ZobristHash.swift` + `TranspositionTable.swift`
2. `MoveOrderer.swift`(将军 > 吃子 > 威胁 > 其他)
3. `OpeningBook.swift` + openings.json(10-20 个开局变化)
4. `AIEngine.swift` 重写:新手/初级/中级难度完整实现
5. AI 基础设施单元测试(置换表命中、开局库匹配、走法排序)

## 验证标准

- 新手/初级/中级三级 AI 可完成完整对局
- 中级 AI 使用开局库+置换表+alpha-beta
- 置换表命中率 > 0（标准中局测试）
- 开局库前 10 步匹配正确

---

## 3. AI 引擎升级方案（Phase 2a: 3.1-3.4）

### 3.1 难度等级定义

将 `AIDifficulty` 从 3 级扩展为 5 级:

```swift
enum AIDifficulty: String, CaseIterable {
    case beginner   // 新手
    case easy       // 初级
    case medium     // 中级
    case hard       // 高级
    case master     // 大师
}
```

#### 3.1.1 新手(Beginner)

**算法**:随机走法 + 基础安全过滤

**逻辑**:
1. 生成所有合法走法
2. 过滤掉"送大子"的走法:如果走后己方价值 ≥ 400(车/炮/马)的子被对方无条件吃掉,则排除
3. 从剩余走法中随机选择
4. 如果过滤后无走法,回退到纯随机

**实现细节**:
- 不需要搜索树
- "送大子"判定:执行走法后,检查对方是否有合法走法能吃掉该子(只看 1 层,不做 minimax)
- 简单高效,响应时间 < 10ms

**实现位置**:`AIEngine.swift` 中新增 `safeRandomMove(for:)` 方法

#### 3.1.2 初级(Easy)

**算法**:Minimax depth=2 + Alpha-Beta + MVV-LVA 走法排序

**逻辑**:
1. 使用 Minimax 搜索,固定深度 2 层
2. Alpha-Beta 剪枝(上下界裁剪)
3. 走法排序用 MVV-LVA(吃子优先,按 captured.baseValue * 10 - piece.baseValue 排序)
4. 评估函数沿用 v1.0 的子力价值 + 位置权重
5. 无开局库、无置换表、无时间限制

**实现**:`AIEngine.swift` 中 `heuristicSearch(for:depth:)`,添加 alpha-beta 参数

#### 3.1.3 中级(Medium)

**算法**:Minimax depth=4 + Alpha-Beta + 开局库 + 将军优先排序

**逻辑**:
1. 前 10 步优先查开局库(`OpeningBook`),命中则直接返回
2. 搜索深度 4 层
3. 走法排序使用 `MoveOrderer`:将军走法 > 吃子(MVV-LVA) > 其他
4. 使用 `ZobristHash` + `TranspositionTable` 避免重复搜索
5. 评估函数同初级

**新增依赖**:OpeningBook, MoveOrderer, ZobristHash, TranspositionTable

### 3.2 开局库设计(OpeningBook.swift)

#### 数据结构

```swift
struct OpeningEntry: Codable {
    let name: String              // "中炮对屏风马"
    let moves: [String]           // ICCS 格式走法序列 ["h2e2", "b9c7", ...]
}

struct OpeningBook {
    // 用 Zobrist hash 做 key,与 TranspositionTable 共享同一套 hash 体系
    private let positionIndex: [UInt64: (moveIndex: Int, entryIndex: Int)]
    private let entries: [OpeningEntry]
    // 每个 entry 对应的各步 Zobrist hash(在 init 时从 moves 预计算)
    private let entryHashes: [[UInt64]]  // entryHashes[entryIndex][moveIndex]

    /// 查找当前局面的推荐走法。传入当前局面的 Zobrist hash。
    func lookup(zobristHash: UInt64) -> String?
}
```

**优势**:
- 与 `TranspositionTable` 共享 `ZobristHash` 体系,零额外开销
- `UInt64` 查找 vs FEN 字符串查找:Dict 查 O(1) vs 字符串比较
- 中级及以上难度已经会计算 Zobrist hash,开局库直接复用
- 无需每步生成 FEN 字符串(FEN 序列化开销不小)

#### 开局库内容(10-20 个变化)

| 编号 | 开局名称 | 变化数 |
|------|---------|--------|
| 1 | 中炮对屏风马 | 3 |
| 2 | 中炮对反宫马 | 2 |
| 3 | 飞相对士角炮 | 2 |
| 4 | 飞相对过宫炮 | 2 |
| 5 | 仙人指路对卒底炮 | 2 |
| 6 | 仕角炮对右中炮 | 1 |
| 7 | 过宫炮对左中炮 | 1 |
| 8 | 起马对挺卒 | 2 |
| 9 | 顺炮直车对横车 | 1 |
| 10 | 列炮 | 1 |

每个变化覆盖前 8-12 步,总计约 100-150 个局面节点。

#### 匹配逻辑

1. 每步走完后计算当前 Zobrist hash(与置换表共享,无额外开销)
2. 用 hash 在 `positionIndex` 中查找
3. 命中则返回对应的下一步走法(ICCS 格式)
4. 未命中则回退到 minimax 搜索
5. 前 10 步启用,之后自动关闭

#### 初始化流程

`OpeningBook.init()` 在构造时:
1. 从 openings.json 加载 entries
2. 对每个 entry 的每个 variation,从标准开局 FEN 开始,逐步执行 moves,记录每步后的 Zobrist hash
3. 构建 `positionIndex: [UInt64: (moveIndex, entryIndex)]`
4. 缓存 `entryHashes` 供验证

这样运行时查找是 O(1) 的 dict lookup。

#### 数据格式

存储为 `Resources/OpeningBook/openings.json`:

```json
[
  {
    "name": "中炮对屏风马",
    "variations": [
      {
        "moves": ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"]
      }
    ]
  }
]
```

数据文件只含 moves 序列,Zobrist hash 在 `OpeningBook.init()` 中从标准开局 FEN 逐步执行预计算。无需手工维护 fenPositions 字段,消除了数据准备错误风险。

**数据验证**:`OpeningBook.init()` 中增加验证步骤--逐步执行 moves 时检查每步走法的合法性(`MoveValidator.isLegal`)。如果任何一步非法,打印 warning 并跳过该 variation。Debug 模式下断言失败,Release 模式下静默跳过。

ICCS 坐标约定:`a1-i9`(a=最左列,1=红方底线行,9=黑方底线行)。棋谱内部用 ICCS 坐标,显示时由 `NotationGenerator` 转换为中文坐标法。

### 3.3 走法排序优化(MoveOrderer.swift)

```swift
struct MoveOrderer {
    /// 排序优先级:将军 > 吃子(MVV-LVA) > 威胁子力 > 其他
    static func order(_ moves: [Move], on board: Board) -> [Move] {
        moves.map { move in
            var score = 0
            // 1. 将军走法(最高优先级)
            if givesCheck(move, on: board) { score += 50000 }
            // 2. 吃子 MVV-LVA
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }
            // 3. 威胁子力(走到后能威胁对方高价值子)
            score += threatBonus(for: move, on: board)
            return (move, score)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }
}
```

**性能考量**:将军检查需要 `board.snapshot().execute(move)` + `isInCheck`,开销较大。仅在 depth ≥ 3 时启用将军排序,低深度只用 MVV-LVA。

### 3.4 Zobrist 哈希 + 置换表

#### ZobristHash.swift

```swift
struct ZobristHash {
    // 14 种棋子 × 90 个位置 的随机数表
    // PieceKind 7 种 × Side 2 种 = 14
    static let table: [[UInt64]] =预计算 14×90 随机数

    // 行走方 hash
    static let sideHash: UInt64 = 预计算

    static func hash(board: Board) -> UInt64 {
        var h: UInt64 = 0
        for piece in board.pieces {
            let pieceIndex = pieceIndex(piece)  // 0-13
            let posIndex = piece.position.row * 9 + piece.position.col  // 0-89
            h ^= table[pieceIndex][posIndex]
        }
        if board.currentTurn == .black { h ^= sideHash }
        return h
    }

    /// 增量更新(走棋后不需要重算整个 hash)
    static func update(hash: UInt64, move: Move) -> UInt64 {
        var h = hash
        h ^= table[pieceIndex(move.piece)][fromIndex]
        h ^= table[pieceIndex(move.piece)][toIndex]
        if let captured = move.captured {
            h ^= table[pieceIndex(captured)][toIndex]
        }
        h ^= sideHash  // 切换行走方
        return h
    }
}
```

#### TranspositionTable.swift

使用**固定大小数组**,内存可控,O(1) 访问:

```swift
struct TTEntry {
    let hash: UInt64       // 完整 hash,用于校验碰撞
    let depth: Int
    let score: Int
    let flag: TTFlag      // exact / lower / upper
    let bestMove: Move?
    var isValid: Bool     // false = 空槽位
}

enum TTFlag: UInt8 {
    case exact = 0   // 精确值
    case lower = 1   // beta cutoff(下界)
    case upper = 2   // 上界
}

final class TranspositionTable {
    private var table: [TTEntry?]
    private let capacity: Int        // 固定大小
    private var mask: UInt64         // capacity - 1(capacity 必须是 2 的幂)

    // 容量配置:
    // macOS / 大师级:1 << 20(约 100 万条目,~32MB)
    // iOS / 高级级:  1 << 18(约 25 万条目,~8MB)
    // iOS / 大师级:  1 << 19(约 50 万条目,~16MB)
    init(capacity: Int = 1 << 20) {
        precondition((capacity & (capacity - 1)) == 0)  // 必须是 2 的幂
        self.capacity = capacity
        self.mask = UInt64(capacity - 1)
        self.table = Array(repeating: nil, count: capacity)
    }

    private func index(for hash: UInt64) -> Int {
        return Int(hash & mask)
    }

    func lookup(hash: UInt64, depth: Int, alpha: Int, beta: Int) -> TTLookupResult? {
        let idx = index(for: hash)
        guard let entry = table[idx], entry.hash == hash else { return nil }
        guard entry.depth >= depth else { return nil }
        // 根据 flag 和 alpha/beta 判断是否可直接使用...
    }

    func store(hash: UInt64, depth: Int, score: Int, flag: TTFlag, bestMove: Move?) {
        let idx = index(for: hash)
        let existing = table[idx]
        // 替换策略:深度优先。新条目深度 >= 旧条目深度时替换,或旧槽位为空时写入
        if existing == nil || depth >= existing!.depth {
            table[idx] = TTEntry(hash: hash, depth: depth, score: score, flag: flag, bestMove: bestMove, isValid: true)
        }
    }

    func clear() { table = Array(repeating: nil, count: capacity) }
}
```
