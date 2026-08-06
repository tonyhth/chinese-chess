# 棋谱自动演示 v2.2 — 通用设计

> 版本：v2.2 | 来源：auto-demo-design.md
> 本文件包含所有 Phase 共享的架构、数据模型、数据管线、分类设计、点评方案、对局信息展示、PGN 解析器、复用策略、ICCS 转换、自动连播状态机。

---

## 1. 背景与目标

中国象棋 App 有两类棋谱数据：
- **残局棋谱**：551 局「适情雅趣」（puzzles.json，ICCS 走法序列）
- **大师对局**：40,711 盘完整 PGN（xqdb_masters_40711_UCI_games.pgn，25.4MB）

核心目标：
- 一键播放任意残局/大师对局，零交互也能看完
- 关键步骤有中文点评，让用户理解"妙在哪"
- 展示对局信息（棋手姓名、赛事、分类）
- 复用现有 PGNImporter 基础设施

## 2. 整体架构

```
┌──────────────────────────────────────────────────────┐
│                   PuzzleDemoView (新)                  │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │ 分类侧边栏    │  │     DemoBoardView            │ │
│  │ ┌──────────┐ │  │    (复用 ReplayBoardView)     │ │
│  │ │残局棋谱   │ │  │                               │ │
│  │ │ 10分类    │ │  ├──────────────────────────────┤ │
│  │ ├──────────┤ │  │  CommentaryOverlay (新)       │ │
│  │ │大师对局   │ │  │  点评气泡 + 对局信息          │ │
│  │ │ 按开局    │ │  ├──────────────────────────────┤ │
│  │ │ 按棋手    │ │  │  DemoControlBar (增强)       │ │
│  │ │ 按赛事    │ │  │  暂停/继续/步进/速度/导航    │ │
│  │ └──────────┘ │  └──────────────────────────────┘ │
│  └──────────────┘                                    │
└──────────────────────────────────────────────────────┘
```

**两套数据体系：**

| 维度 | 残局棋谱 | 大师对局 |
|------|---------|---------|
| 数据源 | puzzles.json | PGN 文件（离线索引） |
| 数量 | 534 局（过滤 freePlay） | 40,711 盘 |
| 对局信息 | 固定"红方/黑方" + 分类 + 难度 | 中文名 + 赛事 + 年份 |
| 走法格式 | ICCS 坐标数组 | PGN 文本（ICCS 走法） |
| 点评 | 规则推断（将军/将死/最后一步） | 规则推断（将军/将死/弃子——对局更长，弃子更多） |
| 典型长度 | 5-15 步 | 平均 82 步 |

**关键决策：新建 PuzzleDemoView，而非增强 ReplayView**

理由：ReplayView 是"复盘"场景，Demo 是"观赏"场景，UI 结构和交互逻辑差异大。

## 3. 数据模型设计

### 3.1 统一演示模型：DemoItem

```swift
enum DemoItem {
    case puzzle(Puzzle)
    case masterGame(MasterGameIndex)
    
    var displayName: String {
        switch self {
        case .puzzle(let p): return p.name
        case .masterGame(let g): return "\(g.redNameCN) vs \(g.blackNameCN)"
        }
    }
    
    var sourceDescription: String {
        switch self {
        case .puzzle(let p): return p.source ?? "残局"
        case .masterGame(let g):
            if let year = g.year {
                return "\(g.event) \(year)"
            }
            return g.event
        }
    }
}

enum DemoPlayState {
    case idle
    case loading
    case ready(GameRecord)
    case failed(String)
}
```

### 3.2 大师对局索引：MasterGameIndex

```swift
struct MasterGameIndex: Codable, Identifiable {
    let id: Int
    let event: String
    let redName: String
    let blackName: String
    let redNameCN: String
    let blackNameCN: String
    let year: Int?
    let firstMove: String
    let firstMoves: [String]
    let moveCount: Int
    let pgnOffset: Int
    let pgnLength: Int
}
```

索引文件 ~6.5MB。

### 3.3 棋手名英中映射：name_map.json

两步处理：
1. **名称归一化**：`name.lower().replace(' ', '')` 作为统一 key，相同 key 合并为出场次数最多的拼写
2. **英中映射**：归一化后的棋手名再通过 name_map.json 映射为中文名

回退策略：name_map 中无映射的棋手名，回退为归一化后的 redName 值。

### 3.4 开局分类：OpeningCategory

```swift
struct OpeningCategory: Identifiable {
    let id: String
    let name: String
    let firstMove: String
    let gameCount: Int
    let description: String
    let subcategories: [OpeningSubcategory]
}

struct OpeningSubcategory: Identifiable {
    let id: String
    let name: String
    let firstMoves: [String]
    let gameCount: Int
}
```

二级分类定义流程：脚本统计 → 人工命名 → opening_subcategories.json → 打入 App Bundle。

### 3.5 点评注释：MoveCommentary

```swift
struct MoveCommentary: Codable {
    let moveIndex: Int
    let type: CommentaryType
    let text: String
}

enum CommentaryType: String, Codable {
    case check
    case checkmate
    case sacrifice
    case keyMove
    case normal
}
```

### 3.6 PuzzleDemoConfig

```swift
struct PuzzleDemoConfig {
    var speedMultiplier: DemoSpeed = .normal
    var pauseOnCommentary: Bool = true
    var autoNextPuzzle: Bool = true
    var showCommentary: Bool = true
}

enum DemoSpeed: Double, CaseIterable {
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case fastest = 3.0
}
```

## 4. 大师对局数据管线

### 4.1 离线预构建

构建脚本 `build_master_index.py`（二进制模式）从 PGN 生成：
- `master-game-index.json` (~6.5MB)
- `master-stats.json` (~20KB)
- `name_map_template.json` → 人工补全 → `name_map.json`

完整 Python 脚本见 auto-demo-design.md §4.1。

### 4.2 运行时按需解析

用户选择对局时，用 `pgnOffset + pgnLength` 从 PGN 文件定位解析：

```swift
struct MasterGameLoader {
    static func loadGame(_ index: MasterGameIndex) -> ImportResult {
        // FileHandle seek → readData → PGNImporter.parse()
    }
}
```

加载失败 UX：DemoPlayState.failed + 跳到下一局按钮。

### 4.3 索引加载时机

Lazy Load：首次进入 PuzzleDemoView 时加载，非 App 启动。

### 4.4 MasterGameStore

```swift
@MainActor
class MasterGameStore: ObservableObject {
    private(set) var allGames: [MasterGameIndex] = []
    private(set) var isLoaded = false
    
    // 倒排索引 O(1) 查询
    private var playerIndex: [String: [MasterGameIndex]] = [:]
    private var eventIndex: [String: [MasterGameIndex]] = [:]
    private var openingIndex: [String: [MasterGameIndex]] = [:]
    private var subcategoryIndex: [String: [MasterGameIndex]] = [:]
    
    func loadIfNeeded() async throws { ... }
    func byOpening(_ firstMove: String) -> [MasterGameIndex]
    func byPlayer(_ name: String) -> [MasterGameIndex]
    func byEvent(_ event: String) -> [MasterGameIndex]
    func bySubcategory(_ subcategoryId: String) -> [MasterGameIndex]
}
```

二级开局分类倒排索引构建需加长度守卫：
```swift
guard game.firstMoves.count >= sub.firstMoves.count else { return false }
```

## 5. 分类浏览设计

### 5.1 侧边栏结构

- 残局棋谱：10 分类（车马炮类/车炮类/单车主/单炮类/马炮类/单马类/车马类/兵类/双车类/综合类）
- 大师对局：按开局（含二级）/ 按棋手 / 按赛事

### 5.2 对局列表展示

LazyVStack 虚拟化 + 分段加载（每段 200 条）。

## 6. 点评数据来源

Phase 1 规则推断（将军/将死/最后一步），Phase 2 弃子检测+预生成。

## 7. 对局信息展示

### 7.1 残局场景
分类 + 名称 + 难度 + 步数进度

### 7.2 大师对局场景
中文名 + 赛事 + 年份 + 步数进度

### 7.3 DemoInfoBar 统一实现

```swift
struct DemoInfoBar: View {
    let item: DemoItem
    let currentStep: Int
    let totalSteps: Int
    var body: some View { ... }
}
```

## 8. PGN 解析器

### 8.1 复用 PGNImporter

### 8.2 新增 parseSingleAtOffset

```swift
extension PGNImporter {
    static func parseSingleAtOffset(_ offset: Int, length: Int, from pgnURL: URL) -> ImportResult {
        // FileHandle seek → readData → parse(pgnText)
        // 返回 ImportResult（与 parse() 一致，支持部分成功）
    }
}
```

### 8.3 对局结果推导

| 终局状态 | 判定 | 显示 |
|----------|------|------|
| 将死 | board.isCheckmate | 红胜/黑胜 |
| 困毙 | 无合法走法且非将军 | 和棋（困毙） |
| 三次重复 | 走法历史检测 | 和棋（三次重复） |
| 子力不足 | 双方剩余子力无法将死 | 和棋（子力不足） |
| 未终结 | 走完所有步但未到终局 | 对局记录结束 |

## 9. 复用策略

Phase 1：DemoViewModel 内部实现播放逻辑，不抽取 BoardPlayer。用 `// ReplayViewModel-sync` 标记同步点。
Phase 2：抽取 BoardPlayer。

## 10. ICCS→GameMove 转换

DemoMoveConverter：Puzzle.solution (ICCS) → [GameMove]，大师对局无需此转换。

## 11. 自动连播状态机

```
播放中 → 棋局结束 → 关键步暂停(1.5s) → 展示结果(2s) → 加载下一局 → 播放中
- autoNextPuzzle=false 时停留在终局
- 分类最后一局播完后循环回第一局
- 大师对局展示结果时间延长到 3 秒
- 解析失败自动跳到下一局
```

## 12. 风险与对策

见 auto-demo-design.md §13。

## 13. 不做的事

- ❌ AI 实时生成点评文本
- ❌ 全量人工编写点评
- ❌ 修改现有 ReplayView 逻辑
- ❌ Phase 1 实现弃子检测
- ❌ openings.json 继续作为演示数据源
- ❌ 全量解析 PGN 到内存
- ❌ 语音播报点评
- ❌ PGN 数据在线更新
