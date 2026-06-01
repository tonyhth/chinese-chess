# 中国象棋 v2.0 - 通用设计文档（所有 Phase 共享）

> **适用范围**: 所有 Phase 共享的上下文和约束
> **依赖**: v2-requirements.md + v1.0 源码
> **验证**: `swift build` + `swift test`

---

## 目录

1. [架构总览](#1-架构总览)
2. [文件清单与 v1.0 映射](#2-文件清单与-v10-映射)
7. [跨平台适配](#7-跨平台适配)
11. [测试策略](#11-测试策略)
附录 A/B/C

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

## 附录 A: v1.0 关键设计决策保留

以下 v1.0 设计决策在 v2.0 中继续沿用:

1. **Board 是 @Observable class**:支持快照(snapshot)用于 AI 搜索
2. **DragGesture(minimumDistance: 0)**:macOS 上 onTapGesture 不可靠,此方案经验证有效
3. **AI 在 Task.detached 中运行**:不阻塞 UI 线程
4. **capturedPieces 按位置而非 last 匹配**:v1.0 R2 修复的经验
5. **评估函数内部实现保持黑方视角**(`evaluateRaw`),对外提供相对视角接口 `evaluate(board, for: side)`,v2.0 新增

## 附录 B: 已知风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 开局库数据错误 | AI 前几步走法异常 | 每个开局变化用已知棋谱验证 |
| 棋谱生成消歧义 bug | 棋谱文本不正确 | 充分单元测试,覆盖双车/双马/双炮同列 |
| 置换表碰撞 | 搜索结果偶尔回退 | 深度优先替换策略 + 哈希校验 |
| iOS 字体 fallback | 楚河汉界显示不一致 | 测试 iOS fallback,必要时用系统楷体 |
| 残局 FEN 解析边界 | 特殊局面初始化失败 | 测试覆盖各种极端 FEN |
| pbxproj 文件管理 | 新增文件遗漏 | 丹妮直接管理,编码团队只管源码 |

## 附录 C: 错误处理策略

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
