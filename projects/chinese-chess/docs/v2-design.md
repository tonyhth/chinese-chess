# 中国象棋 v2.0 - 技术设计方案

> 作者:Alex·亚历(架构师)
> 日期:2026-06-01
> 版本:v1.2(二次修复:Vera H 级 + M 级)
> 基于:v2-requirements.md + v1.0 源码分析

---

## 目录

1. [架构总览](#1-架构总览)
2. [文件清单与 v1.0 映射](#2-文件清单与-v10-映射)
3. [AI 引擎升级方案](#3-ai-引擎升级方案)
4. [棋谱数据模型](#4-棋谱数据模型)
5. [残局数据格式和加载方案](#5-残局数据格式和加载方案)
6. [人人对战和胜率统计](#6-人人对战和胜率统计)
7. [跨平台适配](#7-跨平台适配)
8. [P1 体验提升设计](#8-p1-体验提升设计)
9. [图标设计](#9-图标设计)
10. [分阶段实施计划](#10-分阶段实施计划)
11. [测试策略](#11-测试策略)

---

## 1. 架构总览

### 1.1 架构原则

- **保持 MVVM**:Board(Model)→ GameViewModel(ViewModel)→ Views
- **AI 引擎保持 AIEngineProtocol**,方便替换和单元测试
- **新增模块独立文件**,不膨胀现有文件
- **数据与逻辑分离**:棋谱/残局数据以 JSON bundle 内置,与游戏逻辑解耦
- **跨平台共享代码最大化**:Model / ViewModel / AI / Services 放 Shared,Views 按平台适配

### 1.2 模块划分

```
ChineseChess/
├── App/                    # 应用入口(平台特定)
├── Models/                 # 数据模型(共享)
├── AI/                     # AI 引擎(共享)
├── Services/               # 业务服务(共享)
├── ViewModels/             # 视图模型(共享)
├── Views/                  # 视图(按平台拆分适配层)
│   ├── Shared/             # 跨平台共享的 View 组件
│   ├── macOS/              # macOS 特定视图/布局
│   └── iOS/                # iOS 特定视图/布局
├── Resources/              # 资源文件
│   ├── Assets.xcassets/    # 包含 AppIcon
│   ├── Sounds/             # 音效文件
│   ├── Puzzles/            # 残局 JSON 数据
│   └── OpeningBook/        # 开局库数据
└── Helpers/                # 工具类/扩展(共享)
```

### 1.3 数据流

```
┌─────────────────────────────────────────────────┐
│  Views (Shared/macOS/iOS)                       │
│  BoardView / PuzzleSelectView / RecordPanel ... │
└──────────────┬──────────────────────────────────┘
               │ 用户操作
               ▼
┌─────────────────────────────────────────────────┐
│  ViewModels                                     │
│  GameViewModel ←→ PuzzleViewModel               │
│                 ←→ StatsViewModel                │
└──────────────┬──────────────────────────────────┘
               │ 调用
               ▼
┌─────────────────────────────────────────────────┐
│  Models + Services                              │
│  Board / GameMove / GameRecord / AIEngine       │
│  SoundEngine / StatsManager / FENParser         │
│  PuzzleStore / OpeningBook / NotationGenerator  │
└─────────────────────────────────────────────────┘
```

---

## 2. 文件清单与 v1.0 映射

### 2.1 保留文件(v1.0 直接迁移,有改动)

| v1.0 文件 | v2.0 路径 | 改动说明 |
|-----------|----------|---------|
| Models/Board.swift | Models/Board.swift | 新增 FEN 初始化、GameMove 记录 |
| Models/Piece.swift | Models/Piece.swift | 无改动 |
| Models/Move.swift | Models/Move.swift | 保留,GameMove 独立文件 |
| Models/Position.swift | Models/Position.swift | 新增 FEN 相关便捷属性 |
| Models/Enums.swift | Models/Enums.swift | 扩展 AIDifficulty → 5 级,新增 GameMode |
| Models/MoveValidator.swift | Models/MoveValidator.swift | 无大改,新增将军检测优化 |
| AI/AIEngine.swift | AI/AIEngine.swift | 重写核心算法,保持 AIEngineProtocol |
| ViewModels/GameViewModel.swift | ViewModels/GameViewModel.swift | 扩展支持 GameMode/PVP/棋谱 |
| Views/BoardView.swift | Views/Shared/BoardView.swift | 重构为跨平台组件 |
| Views/PieceView.swift | Views/Shared/PieceView.swift | 新增选中动画、主题支持 |
| Views/ToolbarView.swift | Views/macOS/ToolbarView.swift | 按平台适配 |
| Views/StatusBarView.swift | Views/macOS/StatusBarView.swift | 按平台适配 |
| Views/GameOverOverlay.swift | Views/Shared/GameOverOverlay.swift | 微调 |
| Services/SoundEngine.swift | Services/SoundEngine.swift | 扩充音效种类 |
| App/ChineseChessApp.swift | App/ChineseChessApp.swift | macOS 入口重写 |

### 2.2 新增文件

| v2.0 路径 | 职责 |
|----------|------|
| **Models/GameMove.swift** | 扩展走法记录:回合号、棋谱文本、时间戳、将军/将死标记 |
| **Models/GameRecord.swift** | 完整棋谱:标题、日期、双方信息、难度、结果、走法列表 |
| **Models/GameMode.swift** | 对战模式枚举(singlePlayer / localPVP) |
| **AI/OpeningBook.swift** | 开局库:10-20 个经典开局变化,前 N 步查表 |
| **AI/ZobristHash.swift** | Zobrist 哈希计算 + 置换表 |
| **AI/TranspositionTable.swift** | 置换表数据结构(HashTable + 碰撞策略) |
| **AI/CheckmateSearch.swift** | 杀法搜索:专门搜索连将杀链 |
| **AI/EndgameEvaluator.swift** | 残局精确估值:≤6 子时切换评估策略 |
| **AI/MoveOrderer.swift** | 走法排序:将军 > 吃子 > 威胁 > 其他 |
| **AI/TimeManager.swift** | 时间管理:高级/大师级限时搜索 |
| **AI/PatternRecognizer.swift** | 棋型识别:单车胜、马后炮等基础杀型 |
| **Services/NotationGenerator.swift** | ICCS 中文坐标法生成(含前后同线消歧义) |
| **Services/FENParser.swift** | FEN 字符串解析 → Board 初始化 |
| **Services/StatsManager.swift** | 胜率统计:UserDefaults 持久化 |
| **Services/PuzzleStore.swift** | 残局数据加载:JSON → Puzzle 模型 |
| **Services/BoardTheme.swift** | 棋盘主题配置(经典木纹 / 石材水墨) |
| **ViewModels/PuzzleViewModel.swift** | 残局闯关流程状态管理 |
| **ViewModels/StatsViewModel.swift** | 统计面板数据展示 |
| **ViewModels/ReplayViewModel.swift** | 对局回放控制 |
| **Views/Shared/RecordPanelView.swift** | 棋谱记录面板(侧边栏/底部) |
| **Views/Shared/PuzzleSelectView.swift** | 残局选择界面(列表/网格) |
| **Views/Shared/StatsPanelView.swift** | 统计面板 |
| **Views/Shared/ReplayControlView.swift** | 回放控制条 |
| **Views/Shared/ThemePickerView.swift** | 主题选择器 |
| **Views/iOS/MainiOSView.swift** | iOS 主界面布局(NavigationStack) |
| **Views/macOS/MainMacView.swift** | macOS 主界面布局(WindowGroup) |
| **Helpers/PlatformExtensions.swift** | 跨平台条件编译辅助 |
| **Resources/Puzzles/puzzles.json** | 50-100 局残局数据 |
| **Resources/OpeningBook/openings.json** | 开局库数据 |
| **Resources/Assets.xcassets/AppIcon.appiconset/** | 应用图标(各尺寸) |

---

## 3. AI 引擎升级方案

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

#### 3.1.4 高级(Hard)

**算法**:Minimax depth=6 + 迭代加深 + 杀法搜索 + 棋型识别

**逻辑**:
1. 迭代加深:从 depth=2 开始,逐步加深到 depth=6
2. 时间限制 3 秒(`TimeManager`),超时返回当前最优
3. **杀法搜索**:在主搜索前执行 `CheckmateSearch`,如果找到连将杀(depth ≤ 10),直接返回
4. **棋型识别**:`PatternRecognizer` 识别基础杀型(单车胜、马后炮、双车错等),给评估加分
5. 置换表 + 走法排序(将军 > 吃子 > 威胁子力 > 其他)
6. 残局阶段(≤10 子)搜索深度 +1

**新增依赖**:CheckmateSearch, PatternRecognizer, TimeManager

#### 3.1.5 大师(Master)

**算法**:depth=6+ + 深层杀法搜索 + 残局精确估值 + 时间管理

**逻辑**:
1. 基础搜索深度 6,残局(≤10 子)提升到 7-8
2. **杀法搜索** depth 可到 12 层(只搜将军链,搜索空间远小于全搜索)
3. **残局精确估值**(≤6 子):`EndgameEvaluator` 用精确的残局评估替代通用评估
   - 单车对单马/单炮:车方 +300
   - 单马对单士:和棋判定
   - 双车对单车:+500
   - 内置约 20 种常见残局评估规则
4. 时间限制 5 秒
5. 置换表容量加大(大师级独立配置)
6. 迭代加深 + 历史启发(killer move)

**新增依赖**:EndgameEvaluator

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

### 3.5 杀法搜索(CheckmateSearch.swift)

**核心思路**:只搜索"连续将军"的走法序列,搜索空间远小于全搜索,可深入 6-8 层。

#### 基础版(高级 + 大师难度)

只搜连将链--攻击方每步必须是将军,找到一条将军链导致对方无合法走法即判定为杀:

```swift
struct CheckmateSearch {
    /// 搜索连将杀。返回杀法走法序列(如果找到),否则 nil。
    static func search(board: Board, for side: Side, maxDepth: Int) -> [Move]?

    /// 内部递归:只扩展将军走法(基础版)
    /// 逻辑:对 side 的每个将军走法,执行后检查对方是否被将死。
    /// 如果对方无合法走法 → 将死,返回成功。
    /// 如果对方有合法走法 → 对每个应将走法,递归继续搜 side 的将军走法。
    /// 注意:基础版中只要找到"存在一条将军链导致将死"即返回,不验证所有应将分支。
    /// 这意味着可能返回"伪杀"(对方有防守但没搜到),但实战中够用。
    private static func dfs(
        board: Board, side: Side, depth: Int, maxDepth: Int, path: inout [Move]
    ) -> Bool
}
```

**参数**:
- 高级:maxDepth = 6,超时 500ms
- 大师:maxDepth = 8,超时 800ms

#### 增强版(大师难度可选,标注为 v2.0 可选增强)

在基础版之上,验证所有应将分支(AND-OR 树搜索):只有对方**所有**应将走法都导致我方成功,才判定为确定杀。深度可达 12 层,但搜索空间显著增大。

```swift
/// 确定杀搜索(大师级增强,可选)
/// 与基础版的区别:基础版搜到一条杀线就返回,确定杀要求所有应将都失败
private static func provenDfs(
    board: Board, side: Side, depth: Int, maxDepth: Int, path: inout [Move]
) -> Bool
```

**建议**:先实现基础版通过测试,增强版作为时间允许的加分项。

**与主搜索的协作**:
1. 主搜索开始前,先执行 `CheckmateSearch`
2. 如果找到杀,直接返回杀法走法
3. 如果没找到或超时,继续主搜索

### 3.6 棋型识别(PatternRecognizer.swift)

识别已知的胜势棋型,给评估函数加分:

```swift
struct PatternRecognizer {
    enum Pattern {
        case singleChariotWin      // 单车胜(车 vs 无防守子)
        case doubleChariotCrush    // 双车错
        case horseCannon           // 马后炮
        case fishingHorse          // 钓鱼马
        case ironGate              // 铁门栓
        case seaBottomMoon         // 海底捞月
    }

    /// 识别当前局面中的棋型,返回加分
    static func bonusPatterns(on board: Board, for side: Side) -> Int {
        var bonus = 0
        // 检查各种棋型...
        return bonus
    }
}
```

**识别逻辑**:
- 按棋子组合过滤:只有场上存在特定子力组合时才检查
- 例如“马后炮”:检查是否有马+炮在同一纵线,炮在马后方,对方将/帅在炮后
- 加分范围:+500 到 +2000(根据棋型确定性和距离胜利的接近程度)
- **理由**:车=900、炮=450、马=400 的子力价值尺度下,50-300 的加分几乎不影响 minimax 评估结果(会被一个吃子的价值差覆盖)。500-2000 才能在子力评估的基础上产生明显的引导效果。例如“马后炮”确定杀型 +2000(超过一个车的价值),让 AI 在子力劣势但存在杀型时仍选择进攻;“单车胜”开放局面 +800(接近一个炮的价值),引导 AI 向胜势方向走。
- **降级方案**:如果实测中发现棋型识别加分导致搜索不稳定(偶尔误导),将其降为 P2,大师难度才启用

### 3.7 残局精确估值(EndgameEvaluator.swift)

当场上总子力 ≤ 6 时,启用精确残局评估替代通用评估:

```swift
struct EndgameEvaluator {
    /// 残局精确评估。返回相对于 side 的分数。
    static func evaluate(board: Board, for side: Side) Int? {
        let totalPieces = board.pieces.count
        guard totalPieces <= 6 else { return nil }

        // 按双方子力组合匹配残局规则
        let redPieces = classifyPieces(board.pieces(for: .red))
        let blackPieces = classifyPieces(board.pieces(for: .black))

        return lookupScore(red: redPieces, black: blackPieces, board: board, for: side)
    }

    // 内置规则表
    private static let endgameRules: [EndgameRule] = [
        // 车类
        .init(redPattern: [.chariot], blackPattern: [], redScore: 8000),
        .init(redPattern: [.chariot], blackPattern: [.horse], redScore: 6000),
        .init(redPattern: [.chariot], blackPattern: [.cannon], redScore: 5500),
        .init(redPattern: [.chariot], blackPattern: [.advisor, .elephant], redScore: 4000),
        // 马炮类
        .init(redPattern: [.horse, .cannon], blackPattern: [.horse], redScore: 3000),
        // 双车类
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot], redScore: 5000),
        // ... 约 20 条规则
    ]
}
```

**注意**:这是一个规则匹配系统,不是数据库查表。真正的精确残局数据库(如 Syzygy)超出 v2.0 范围。规则匹配已能显著提升残局质量。

### 3.8 时间管理(TimeManager.swift)

```swift
struct TimeManager {
    let timeLimitMs: Int     // 总时间限制
    let startTime: Date

    var elapsedMs: Int { ... }
    var shouldStop: Bool { elapsedMs >= timeLimitMs }

    /// 根据难度创建
    static func forDifficulty(_ difficulty: AIDifficulty) -> TimeManager? {
        switch difficulty {
        case .beginner, .easy: return nil           // 无时间限制
        case .medium:        return nil              // 无时间限制
        case .hard:          return TimeManager(timeLimitMs: 3000)
        case .master:        return TimeManager(timeLimitMs: 5000)
        }
    }
}
```

在迭代加深的每一层开始前检查 `shouldStop`,超时则立即返回当前最优。

### 3.9 AI 评估函数视角约定

**约定:评估函数始终返回相对于传入 `side` 参数的分数。正值 = 该方优势,负值 = 该方劣势。**

v1.0 的 `evaluate(_ board: Board) -> Int` 是黑方视角(正值有利于黑方),在 minimax 中 `isMaximizing=true` 对应黑方。这个约定在人机模式(AI 固定执黑)下没问题。

v2.0 残局模式中 AI 可能执红(防守方),需要统一处理。修改评估函数签名:

```swift
// v1.0 签名(黑方视角,内部使用)
private func evaluateRaw(_ board: Board) -> Int  // 正值有利于黑方

// v2.0 公开接口(相对视角)
func evaluate(board: Board, for side: Side) -> Int {
    let raw = evaluateRaw(board)
    return (side == .black) ? raw : -raw
}
```

**minimax 约定**:`isMaximizing=true` 始终对应 `side` 参数(AI 正在计算的一方):
- 人机模式 AI 执黑 → `isMaximizing=true` 对应黑方 → `evaluateRaw` 正值 ✅
- 残局模式 AI 执红 → `isMaximizing=true` 对应红方 → `evaluate(for: .red)` 取反 → 正值代表红方优势 ✅

**CheckmateSearch 约定**:`search(board:, for: side)` 搜索 side 方的连将杀。评估始终用 `evaluate(board, for: side)`。

**EndgameEvaluator 约定**:返回值相对于传入的 `side` 参数(正值 = side 方优势)。

### 3.10 AIEngine 协议不变

```swift
protocol AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}
```

`AIEngine.bestMove` 内部根据 `AIDifficulty` 分派到不同的搜索策略,外部调用方式不变。

**新增残局重载**(可选):

```swift
protocol AIEngineProtocol {
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
    func bestMove(for board: Board, as side: Side, difficulty: AIDifficulty) -> Move?
}
```

第二个重载明确指定 AI 执哪方,残局模式使用。默认实现中 `as side` 版本调整 minimax 的 isMaximizing 语义。

---

## 4. 棋谱数据模型

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

## 5. 残局数据格式和加载方案

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

### 5.2 残局数据格式(puzzles.json)

```json
{
  "version": 1,
  "puzzles": [
    {
      "id": "puzzle_001",
      "name": "单车胜双士",
      "category": "单车类",
      "difficulty": 1,
      "stars": 1,
      "description": "红先胜",
      "playerSide": "red",
      "initialFEN": "4k4/4a4/9/9/9/9/9/4R4/9/4K4 w - - 0 1",
      "solution": ["e1e2", "e8d8", "e2e5"],
      "hints": ["车在底线有更大活动空间"],
      "maxMoves": 10
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 唯一标识 |
| name | String | 残局名称 |
| category | String | 分类(单车类、马炮类、双车类...) |
| difficulty | Int | 难度等级 1-4(入门/初级/中级/高级) |
| stars | Int | 显示用星级 1-5 |
| description | String | 简要描述 |
| playerSide | String | 玩家执哪方("red" / "black") |
| initialFEN | String | 初始局面 FEN |
| solution | [String] | 标准答案(ICCS 坐标格式)。中文棋谱由 NotationGenerator 运行时生成,不在数据文件中存储,消除双格式维护不一致风险 |
| hints | [String]? | 走法提示文本 |
| maxMoves | Int | 最长通关步数(超过视为失败) |

### 5.3 残局闯关流程状态管理(PuzzleViewModel.swift)

```swift
@Observable
class PuzzleViewModel {
    let puzzle: Puzzle
    let board: Board                  // 从 FEN 初始化
    let playerSide: Side              // 玩家执哪方

    var moveHistory: [GameMove] = []  // 玩家走法记录
    var gameState: PuzzleState = .playing
    var hintIndex: Int = 0            // 当前提示位置

    enum PuzzleState {
        case playing
        case success                  // 通关
        case failed                   // 超过最大步数或走入死路
        case showingHint              // 显示提示中
    }

    /// 玩家走棋后,AI 自动应将
    func playerMoved(_ move: GameMove) {
        // 1. 执行走法
        // 2. 检查是否将死对方 → success
        // 3. AI(残局的防守方)自动应将
        // 4. 检查是否超过 maxMoves → failed
    }

    /// 残局防守方 AI 算法映射
    /// 残局难度 1-4 对应不同防守强度:
    ///   difficulty 1(入门)→ AIDifficulty.beginner:随机走法,几乎不防守
    ///   difficulty 2(初级)→ AIDifficulty.easy:minimax depth=2,基本防守
    ///   difficulty 3(中级)→ AIDifficulty.medium:depth=4 + 开局库
    ///   difficulty 4(高级)→ AIDifficulty.hard:depth=6 + 杀法搜索
    /// 这样设计的合理性:简单残局的对手也弱,玩家不会觉得"明明是入门题但 AI 疯狂防守"
    private var defenderDifficulty: AIDifficulty {
        switch puzzle.difficulty {
        case 1: return .beginner
        case 2: return .easy
        case 3: return .medium
        case 4: return .hard
        default: return .easy
        }
    }

    /// 无限悔棋
    func undoMove() {
        // 撤销 AI + 玩家各一步
    }

    /// 显示提示
    func showHint() {
        // 根据 hintIndex 从 solution 中取当前步的提示
    }
}
```

#### 答案验证策略

**不要求严格匹配 solution**(因为残局可能有多种解法)。验证逻辑:

1. **成功判定**:玩家走后将死对方 → 通关
2. **失败判定**:超过 maxMoves 未通关 → 失败
3. **提示**:从 solution(ICCS 格式)通过 NotationGenerator 生成中文提示文本,而非验证路径

这样设计允许玩家用不同于标准答案的走法通关,只要最终将死对方即可。

### 5.4 闯关进度持久化

```swift
struct PuzzleProgress: Codable {
    let puzzleId: String
    var isCompleted: Bool
    var bestMoves: Int?          // 最少步数通关
    var completedAt: Date?
}

// 存储在 UserDefaults
// Key: "chinesechess.puzzle_progress"
// Value: [String: PuzzleProgress] (puzzleId → progress)
```

---

## 6. 人人对战和胜率统计

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

---

## 7. 跨平台适配

### 7.1 项目结构

```
ChineseChess.xcodeproj/
├── ChineseChess (macOS target)
│   ├── Info.plist
│   └── entitilements (if needed)
├── ChineseChess-iOS (iOS target)
│   └── Info.plist
└── ChineseChessShared/         ← 所有 Swift 源码
    ├── App/
    │   ├── ChineseChessApp.swift   ← @main 入口
    │   └── AppDelegate.swift       ← 如需要
    ├── Models/
    ├── AI/
    ├── Services/
    ├── ViewModels/
    ├── Views/
    │   ├── Shared/                  ← 跨平台共享视图
    │   ├── macOS/                   ← macOS 特定
    │   └── iOS/                     ← iOS 特定
    ├── Helpers/
    └── Resources/
        ├── Assets.xcassets/
        ├── Sounds/
        ├── Puzzles/
        └── OpeningBook/
```

### 7.2 平台差异处理

#### 条件编译

```swift
// Helpers/PlatformExtensions.swift

#if os(macOS)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif
```

#### 视图适配

**共享视图**(`Views/Shared/`):
- `BoardView.swift` - 棋盘核心渲染(Canvas + ZStack),跨平台通用
- `PieceView.swift` - 棋子渲染
- `GameOverOverlay.swift` - 游戏结束弹窗
- `RecordPanelView.swift` - 棋谱面板
- `PuzzleSelectView.swift` - 残局选择

**平台特定视图**:

| 组件 | macOS (`Views/macOS/`) | iOS (`Views/iOS/`) |
|------|----------------------|-------------------|
| 主布局 | `MainMacView.swift` - WindowGroup + 固定窗口 | `MainiOSView.swift` - NavigationStack + TabView |
| 工具栏 | `ToolbarView.swift` - 水平按钮栏 | `ToolbarView.swift` - 底部工具条 |
| 状态栏 | `StatusBarView.swift` - 棋盘上方 | `StatusBarView.swift` - 棋盘下方 |
| 棋盘交互 | DragGesture(minimumDistance: 0) | DragGesture(minimumDistance: 0) |

**交互层方案**:macOS + iOS 统一使用 `DragGesture(minimumDistance: 0)`,不搞平台分支。
理由:v1.0 已在 macOS 上验证此方案可靠(onTapGesture 不可靠的教训);DragGesture(minimumDistance: 0) 在 iOS 上同样有效(SwiftUI 手势系统跨平台一致),无需引入 LongPress+Drag 的额外复杂度。

交互逻辑直接写在 `BoardView`(共享视图)中,不单独拆平台文件。BoardView 负责渲染 + 交互,通过回调将操作传递给 ViewModel。

#### iOS 特殊处理

1. **屏幕适配**:棋盘需适配竖屏(iPhone)和横屏(iPad),用 `GeometryReader` + `aspectRatio`
2. **NavigationStack**:设置页、统计页、残局选择页用 NavigationStack 推入
3. **字体 fallback**:STKaiti 在 iOS 上可能不可用,用系统 font fallback(SwiftUI 自动处理)
4. **底部安全区**:iPhone X+ 需处理 bottom safe area

#### macOS 特殊处理

1. **窗口大小**:保持当前固定窗口(660×780)
2. **WindowGroup**:保持现有结构
3. **菜单栏**:可扩展 Edit/View 菜单

### 7.3 App 入口

两个平台各一个独立 App 入口文件,编译时通过 target membership 选择,避免 body 内 `#if os()` 条件编译的潜在问题:

```
App/
├── ChineseChessApp.swift      ← macOS target only
└── ChineseChessiOSApp.swift   ← iOS target only
```

**macOS 入口**(`ChineseChessApp.swift`,macOS target only):

```swift
import SwiftUI

@main
struct ChineseChessApp: App {
    @State private var gameViewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            MainMacView(viewModel: gameViewModel)
                .frame(minWidth: 600, minHeight: 720)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 660, height: 780)
    }
}
```

**iOS 入口**(`ChineseChessiOSApp.swift`,iOS target only):

```swift
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    @State private var gameViewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            MainiOSView(viewModel: gameViewModel)
        }
    }
}
```

---

## 8. P1 体验提升设计

### 8.1 音效升级

扩展 `SoundEngine`:

```swift
class SoundEngine {
    // v1.0 已有
    func playMove()
    func playCapture()

    // v2.0 新增
    func playCheck()        // 将军 - 急促的金属碰撞音
    func playCheckmate()    // 将死 - 胜利鼓声
    func playUndo()         // 悔棋 - 轻柔的回退音
    func playVictory()      // 胜利 - 欢快的古筝旋律
    func playDefeat()       // 失败 - 低沉的鼓声
}
```

音效文件放在 `Resources/Sounds/`,保持 fallback 策略:
- **Debug 模式**:音效文件缺失时打印 `print("[Sound] missing: \(name).\(ext)")`
- **Release 模式**:静默跳过,不影响游戏流程
- 加载逻辑统一在 `loadSound(name:ext:)` 中处理,返回 nil 时该音效方法为空操作

### 8.2 走子动画

**棋子移动**(已有 `.easeInOut(duration: 0.25)`,增强):

```swift
// PieceView 中
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
```

**吃子消除效果**:

```swift
// 在 BoardView 中,检测到 captured 时
// 被吃棋子播放缩小+淡出动画
.transition(.opacity.combined(with: .scale(scale: 0.5)))
```

**选中棋子效果**(替代当前 scaleEffect):

```swift
// PieceView 中
.overlay(
    Circle()
        .stroke(Color.yellow, lineWidth: 2)
        .frame(width: pieceDiameter + 4, height: pieceDiameter + 4)
        .opacity(isSelected ? 1 : 0)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true),
            value: isSelected
        )
)
```

### 8.3 棋盘主题

```swift
enum BoardTheme: String, CaseIterable {
    case classicWood    // 经典木纹(v1.0 默认)
    case inkStone       // 石材水墨
}

struct ThemeColors {
    let boardBackground: [Color]     // 渐变色
    let lineColor: Color
    let textColor: Color
    let redPieceText: Color
    let blackPieceText: Color
    let pieceFill: [Color]           // 棋子底色渐变

    static func forTheme(_ theme: BoardTheme) -> ThemeColors
}
```

**石材水墨主题**:
- 棋盘底色:灰白渐变(仿石板质感)
- 线条:深灰
- 棋子底色:米白/浅灰(扁平风格,无立体感)
- 红方字色:朱红
- 黑方字色:墨黑
- 楚河汉界:楷体+水墨风

**主题切换**:
- 在设置中添加主题选择器(`ThemePickerView`)
- 存储在 UserDefaults,key = "chinesechess.theme"
- `BoardView` 和 `PieceView` 接受 `ThemeColors` 参数

### 8.4 对局回放

```swift
@Observable
class ReplayViewModel {
    let record: GameRecord
    private(set) var board: Board           // 当前棋盘状态
    private(set) var currentIndex: Int = 0  // 当前步数索引(0 = 初始局面)

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < record.moves.count }
    var isAutoPlaying: Bool = false
    var autoPlaySpeed: Double = 1.0         // 秒/步

    func goToStart() { ... }
    func goToEnd() { ... }
    func goForward() { ... }
    func goBack() { ... }
    func toggleAutoPlay() { ... }
    func jumpTo(index: Int) { ... }

    // 内部:根据 record.moves[0..<currentIndex] 从初始 FEN 重建局面
    // 优化:每 20 步存一个 Board 快照,跳转时从最近快照开始重建
    private var snapshots: [Int: Board] = [:]  // index → Board 快照
    private let snapshotInterval = 20

    private func rebuildBoard(upTo index: Int) {
        // 找到最近的快照
        let snapIdx = (index / snapshotInterval) * snapshotInterval
        let startBoard = snapshots[snapIdx] ?? Board(fen: record.initialFEN ?? FENParser.standardInitial)
        // 从 snapIdx 到 index 逐步执行走法
    }

    private func takeSnapshotIfNeeded(at index: Int) {
        if index % snapshotInterval == 0 {
            snapshots[index] = board.snapshot()
        }
    }
}
```

**回放控制条**(`ReplayControlView`):
- 按钮:|← ← ▶/⏸ → →|
- 速度滑块:0.5x / 1x / 2x
- 进度条:可拖拽跳转

---

## 9. 图标设计

### 9.1 设计方案

**风格**:中国风 + 现代扁平

**概念**:深色木质棋盘背景,一颗精致的红色"帅"棋子居中,金色边框,整体圆形构图。

**配色**:
- 背景:深棕 (#2C1808) 到 (#4A2E1A) 渐变
- 棋子底色:米白 (#FFF5E6)
- 棋子文字:朱红 (#CC0000)
- 边框:金色 (#C9A94E)

**尺寸要求**(AppIcon.appiconset):

| 用途 | 尺寸 (px) |
|------|-----------|
| Mac 512pt @2x | 1024×1024 |
| Mac 512pt @1x | 512×512 |
| Mac 256pt @2x | 512×512 |
| Mac 256pt @1x | 256×256 |
| Mac 128pt @2x | 256×256 |
| Mac 128pt @1x | 128×128 |
| Mac 32pt @2x | 64×64 |
| Mac 32pt @1x | 32×32 |
| Mac 16pt @2x | 32×32 |
| Mac 16pt @1x | 16×16 |
| iPhone 60pt @3x | 180×180 |
| iPhone 60pt @2x | 120×120 |
| iPad 76pt @2x | 152×152 |
| App Store | 1024×1024 |

### 9.2 产出物

- `Resources/Assets.xcassets/AppIcon.appiconset/` 完整目录
- `Contents.json` 正确配置各尺寸
- 图标源文件(1024×1024 master)

### 9.3 时机

Phase 1 编码前完成。Cody 开始编码时项目已包含图标。

---

## 10. 分阶段实施计划

### Phase 1:跨平台基础 + 数据模型(2-3 天)

**目标**:从 SPM 迁移到 Xcode 项目,建立跨平台基础。

**交付物**:
1. Xcode 项目结构(.xcodeproj),macOS + iOS 双 target
2. 所有 v1.0 源码迁移到共享目录
3. `Enums.swift` 扩展:5 级 AIDifficulty、GameMode
4. `GameMove.swift`、`GameRecord.swift` 新数据模型
5. `Board.swift` 扩展:FEN 初始化(`FENParser.swift`)
6. App 图标集成
7. macOS 版本编译通过 + 功能与 v1.0 一致
8. iOS 版本编译通过 + 基本棋盘显示

**依赖**:无

### Phase 2a:AI 基础设施(3 天)

**目标**:Zobrist 哈希 + 置换表 + 走法排序优化 + 开局库 + 初级/中级难度实现。

**交付物**:
1. `ZobristHash.swift` + `TranspositionTable.swift`
2. `MoveOrderer.swift`(将军 > 吃子 > 威胁 > 其他)
3. `OpeningBook.swift` + openings.json(10-20 个开局变化)
4. `AIEngine.swift` 重写:新手/初级/中级难度完整实现
5. AI 基础设施单元测试(置换表命中、开局库匹配、走法排序)

**验证标准**:新手/初级/中级三级 AI 可完成完整对局,中级 AI 使用开局库+置换表+alpha-beta。

**依赖**:Phase 1(数据模型)

### Phase 2b:AI 高级算法(3 天)

**目标**:高级/大师难度 + 杀法搜索 + 棋型识别 + 残局精确估值 + 时间管理。

**交付物**:
1. `CheckmateSearch.swift`(连将杀搜索)
2. `PatternRecognizer.swift`(棋型识别)
3. `EndgameEvaluator.swift`(残局精确估值)
4. `TimeManager.swift`(时间管理)
5. `AIEngine.swift` 补充:高级/大师难度完整实现
6. AI 高级算法单元测试(杀法搜索、残局评估、时间管理)

**验证标准**:5 级 AI 全部可完成完整对局,高级 AI 能找到基本杀法。

**依赖**:Phase 2a

### Phase 3:棋谱 + 人人对战 + 统计(2-3 天)

**目标**:棋谱系统、人人对战、胜率统计。

**交付物**:
1. `NotationGenerator.swift`(ICCS 中文坐标法生成)
2. `GameViewModel` 扩展:GameMode 支持、GameMove 记录
3. `RecordPanelView.swift`(棋谱记录面板)
4. `StatsManager.swift`(胜率统计持久化)
5. `StatsViewModel.swift` + `StatsPanelView.swift`
6. `GameMode` 切换 UI
7. 棋谱生成单元测试(重点测试消歧义逻辑)
8. 人人对战完整流程测试

**依赖**:Phase 1(数据模型)

### Phase 4:残局闯关 + 回放(2-3 天)

**目标**:残局模式 + 对局回放。

**交付物**:
1. `puzzles.json`(50-100 局残局数据,**由 AI 辅助生成 + 人工验证 FEN 正确性**,作为编码任务的一部分,不单独分配内容制作工时。每个残局必须通过 FEN→Board→验证走法的自动化测试)
2. `PuzzleStore.swift`(残局数据加载)
3. `PuzzleViewModel.swift`(闯关流程状态管理)
4. `PuzzleSelectView.swift`(残局选择界面)
5. 残局闯关完整 UI
6. `ReplayViewModel.swift` + `ReplayControlView.swift`
7. 对局回放功能
8. 残局 FEN 解析单元测试

**依赖**:Phase 1(FEN 解析)+ Phase 3(棋谱记录)

### Phase 5:体验提升 + 收尾(2-3 天)

**目标**:音效、动画、主题、测试、iOS 适配收尾。

**交付物**:
1. 音效扩充(将军、将死、悔棋、胜利、失败)
2. 走子动画增强(spring、吃子消除、选中呼吸)
3. `BoardTheme.swift` + 主题切换 UI
4. iOS 适配收尾(NavigationStack、屏幕适配、交互优化)
5. 走法提示功能(P2,如时间允许)
6. 全平台集成测试
7. Bug 修复 + 最终交付

**依赖**:Phase 2a-4

---

## 11. 测试策略

### 11.1 单元测试(ChineseChessTests)

| 模块 | 测试重点 | 最少用例数 |
|------|---------|----------|
| AIEngine | 5 级难度各返回合法走法、AI 不送将、置换表命中 | 25 |
| NotationGenerator | 各种棋子走法的中文名生成、前后同线消歧义、红黑双方 | 20 |
| FENParser | 标准 FEN 解析、生成 roundtrip、非法 FEN 处理 | 10 |
| MoveValidator | v1.0 现有 + 新增边界情况 | 15 |
| OpeningBook | 开局库匹配、未命中回退 | 5 |
| CheckmateSearch | 已知杀法局面能找到 | 5 |
| EndgameEvaluator | 各种残局组合的正确评估 | 10 |
| StatsManager | 记录/读取/重置 | 5 |

### 11.2 集成测试

1. **完整人机对局**:5 级 AI 各完成一局(验证不崩溃、不出非法走法)
2. **完整人人对局**:双方各走 20 步(验证状态切换)
3. **残局闯关流程**:选残局 → 走棋 → 通关 → 返回列表
4. **棋谱回放**:完成一局 → 进入回放 → 各项控制操作
5. **跨平台编译**:macOS + iOS 编译通过

### 11.3 性能基准

- AI 思考时间:新手/初级 < 50ms,中级 < 500ms,高级 < 3s,大师 < 5s
- AI 搜索节点数:以标准测试局面(中局 16 子)为基准
  - 高级 depth=6:目标 ≥ 50,000 nodes/s
  - 大师 depth=6+:目标 ≥ 50,000 nodes/s
  - 单元测试中记录 nodes/s,方便跨设备对比
- 棋盘渲染:60fps 无卡顿(AI 思考在后台线程)
- 内存上限:macOS < 100MB,iOS < 80MB(置换表为主要变量)

---

## 附录 A:v1.0 关键设计决策保留

以下 v1.0 设计决策在 v2.0 中继续沿用:

1. **Board 是 @Observable class**:支持快照(snapshot)用于 AI 搜索
2. **DragGesture(minimumDistance: 0)**:macOS 上 onTapGesture 不可靠,此方案经验证有效
3. **AI 在 Task.detached 中运行**:不阻塞 UI 线程
4. **capturedPieces 按位置而非 last 匹配**:v1.0 R2 修复的经验
5. **评估函数内部实现保持黑方视角**(`evaluateRaw`),对外提供相对视角接口 `evaluate(board, for: side)`,v2.0 新增

## 附录 B:已知风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 开局库数据错误 | AI 前几步走法异常 | 每个开局变化用已知棋谱验证 |
| 棋谱生成消歧义 bug | 棋谱文本不正确 | 充分单元测试,覆盖双车/双马/双炮同列 |
| 置换表碰撞 | 搜索结果偶尔回退 | 深度优先替换策略 + 哈希校验 |
| iOS 字体 fallback | 楚河汉界显示不一致 | 测试 iOS fallback,必要时用系统楷体 |
| 残局 FEN 解析边界 | 特殊局面初始化失败 | 测试覆盖各种极端 FEN |
| pbxproj 文件管理 | 新增文件遗漏 | 丹妮直接管理,编码团队只管源码 |

## 附录 C:错误处理策略

### 错误分级

| 级别 | 定义 | 处理方式 | 示例 |
|------|------|---------|------|
| **致命** | 无法继续运行 | 弹窗提示 + 回到主界面 | FEN 解析失败导致 Board 初始化异常 |
| **可恢复** | 功能降级但不崩溃 | 静默降级 + debug log | 开局库数据损坏 → 跳过开局库直接搜索 |
| **静默** | 用户无感知 | debug 模式打印 warning,release 静默跳过 | 音效文件缺失 |

### 具体场景

| 场景 | 级别 | 处理 |
|------|------|------|
| FEN 解析失败 | 致命 | 弹窗"残局数据异常"+ 返回残局列表 |
| puzzles.json 加载失败 | 致命 | 弹窗"残局库加载失败"+ 隐藏残局模式入口 |
| openings.json 加载失败 | 可恢复 | 跳过开局库,所有难度回退到 minimax |
| AI 超时 | 可恢复 | 返回当前最优走法(已有逻辑) |
| 单个残局数据异常 | 可恢复 | 跳过该残局,在列表中标记不可用 |
| 音效文件缺失 | 静默 | Debug 模式打印 `print("[Sound] missing: \(name)")`,Release 静默 |
| UserDefaults 读取失败 | 可恢复 | 重置统计数据,不影响游戏 |

### 实现约定

```swift
// 统一日志函数
func logError(_ message: String, level: ErrorLevel = .recoverable) {
    #if DEBUG
    switch level {
    case .fatal:        print("[FATAL] \(message)")
    case .recoverable:  print("[WARN] \(message)")
    case .silent:       print("[INFO] \(message)")
    }
    #endif
}
```

---

*v1.2 二次修复完成。Vera H 级 + M 级全部处理。方案定稿,可进入编码阶段。*
