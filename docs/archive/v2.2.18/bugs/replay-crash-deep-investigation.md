# 回放崩溃深度排查报告

> 审查者：Vera·维拉 | 日期：2026-06-17
> 触发：v2.2.19 回放崩溃，两轮修复（`.id(record.id)` + `board.snapshot()`）无效
> 参考：[bug-replay-crash-v2218.md](./bug-replay-crash-v2218.md)

## 现状

- 5 处 `.id(record.id)` + 2 处 `board.snapshot()` 已全部应用
- 崩溃栈不变：`KeyPath._projectReadOnly` → `swift_getAtKeyPath` → assertion failure
- 崩溃场景：macOS 点击历史棋局列表 → 打开 ReplayView（首次打开即崩溃）

## 前两轮修复为什么无效

### `.id(record.id)` 的致命缺陷

`.id(record.id)` 只在 **record 变化** 时强制 SwiftUI 重建视图树。但崩溃场景的关键路径是：

```
用户点击历史棋局 A → historyReplayRecord = A → sheet(item:) presents ReplayView(A) → .id(A.id) 
```

如果用户关闭后再次点击 **同一个棋局 A**，`.id(A.id)` 的值不变，SwiftUI **不会重建视图树**，而是尝试复用旧的视图层次。此时旧的 `@State viewModel` 已被销毁，AttributeGraph 中的 KeyPath 追踪引用指向已释放的 `ReplayViewModel` 实例 → 崩溃。

**更关键的是**：即使是 **首次打开**，sheet dismiss→present 过渡动画期间存在视图层次重叠窗口。旧视图的 `@State` 释放时机与新视图的创建时机之间的 gap，就是 AttributeGraph assertion failure 的触发窗口。

### `board.snapshot()` 的局限

`board.snapshot()` 解决的是 **嵌套 `@Observable` 的深层属性追踪** 问题（避免 SwiftUI 追踪 `Board` 内部属性变化）。但这是次要问题。**主要问题是 `@State` + `@Observable` class 在 sheet 中的生命周期管理**，不是嵌套追踪。

## 根因分析：三个问题叠加

### 问题 1：`@State` + `@Observable` class 在 sheet 中（核心问题）

```swift
struct ReplayView: View {
    @State private var viewModel: ReplayViewModel  // ← @State 包装 @Observable class

    init(record: GameRecord) {
        self._viewModel = State(initialValue: ReplayViewModel(record: record))
    }
}
```

`@State` 设计初衷是管理 **值类型** 的持久化存储。配合 `@Observable` class 使用时，`@State` 持有的是对象的引用。Sheet dismiss 时 `@State` 释放引用，`ReplayViewModel` 的引用计数归零被释放。但在 dismiss→present 过渡动画中，SwiftUI 的 AttributeGraph 可能仍持有对旧 `ReplayViewModel` 的 KeyPath 追踪条目（尚未清理），此时访问已释放对象 → assertion failure。

**这是已知的 SwiftUI 架构问题**，Apple 尚未提供官方修复方案。

### 问题 2：`BoardMode` enum 关联值持有 `@Observable` class 引用

```swift
enum BoardMode {
    case playGame(GameViewModel)      // @Observable class
    case playPuzzle(PuzzleViewModel)  // @Observable class
    case replay(ReplayViewModel)       // @Observable class
}
```

`ChessBoardView` 通过 `let mode: BoardMode` 持有 ViewModel 引用。Body 中的 computed properties 通过 enum pattern matching 访问 ViewModel 属性：

```swift
private var board: Board {
    case .replay(let vm): return vm.board  // 访问嵌套 @Observable
}
```

这意味着 `ReplayViewModel` 有 **三个强引用持有者**：
1. ReplayView 的 `@State viewModel`
2. ChessBoardView 的 `mode` enum
3. ReplayControlView 的 `let viewModel`

当 sheet dismiss 时，ReplayView 被销毁，`@State` 释放引用。但 ChessBoardView 和 ReplayControlView 的销毁时机可能晚于 ReplayView（SwiftUI 的视图层次销毁是自上而下异步的）。在 ChessBoardView/ReplayControlView 仍存活但 ViewModel 已被其他引用释放的窗口期...

实际上，由于 ChessBoardView 和 ReplayControlView 都持有强引用，ViewModel 不会提前释放。**真正的问题不是释放时序，而是 SwiftUI 的 AttributeGraph 在处理 sheet 过渡时，会尝试通过 KeyPath 更新旧视图的依赖关系，但 KeyPath 的源对象状态已经不一致。**

### 问题 3：嵌套 sheet（history sheet → replay sheet）

```
ChineseChessApp
  └─ .sheet(isPresented: $showHistory)  ← 历史列表
       └─ GameHistoryView
            └─ .sheet(item: $historyReplayRecord)  ← 回放（在 history sheet 之上）
                 └─ ReplayView
```

嵌套 sheet 增加了视图层次的复杂度。Dismiss replay sheet 时，history sheet 仍在底层。SwiftUI 需要处理两层 sheet 的过渡动画，AttributeGraph 的更新窗口更长，KeyPath 追踪条目清理更慢。

## 新修复方案

### 方案 A（推荐）：去掉 `@State`，改用 `.id(UUID())` 强制重建

**改动 1：ReplayView 去掉 `@State`**

```swift
struct ReplayView: View {
    let viewModel: ReplayViewModel  // ← 改为普通 let，不使用 @State
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord) {
        self.viewModel = ReplayViewModel(record: record)
    }

    @Environment(L10n.self) private var l10n
    // ... body 不变
}
```

**改动 2：调用处加 `.id(UUID())`**

macOS `ChineseChessApp.swift`：

```swift
.sheet(isPresented: $showReplay) {
    if let record = replayRecord {
        ReplayView(record: record)
            .frame(minWidth: 520, minHeight: 680)
            .id(UUID())  // ← 改：每次 present 都重建
    }
}

.sheet(item: $historyReplayRecord) { record in
    ReplayView(record: record)
        .frame(minWidth: 520, minHeight: 680)
        .id(UUID())  // ← 改：每次 present 都重建
}
```

iOS `ChineseChessiOSApp.swift`：同上。

**原理**：
- 去掉 `@State` 后，`ReplayViewModel` 作为普通 `let` 属性，生命周期与 View 绑定。View 被销毁时引用自动释放，无需 `@State` 的额外管理。
- `.id(UUID())` 确保每次 sheet present 时，SwiftUI 视为全新视图树，完全重建。**不存在旧视图复用**，AttributeGraph 不会持有旧 KeyPath 追踪。

**副作用**：sheet 弹出动画每次都是"全新"的，不会播放差异动画。但这本来就是 sheet 的默认行为，无影响。

### 方案 B（保守）：保留 `@State`，用 session counter 作为 `.id()`

如果团队对方案 A 有顾虑（比如 `ReplayControlView` 的 Binding 闭包可能持有 viewModel 引用导致循环），可以用 session counter：

```swift
// App 层
@State private var replaySessionId = 0

.sheet(isPresented: $showReplay) {
    if let record = replayRecord {
        ReplayView(record: record)
            .frame(minWidth: 520, minHeight: 680)
            .id(replaySessionId)
    }
}

// 每次 showReplay = true 时递增
Button(action: {
    replaySessionId += 1  // ← 新增
    showReplay = true
}) { ... }
```

**缺点**：需要修改所有触发 sheet 的地方，容易遗漏。不如方案 A 干净。

### 方案 C（彻底）：重构为 NavigationSplitView / NavigationStack

不用 sheet，改用 NavigationSplitView + NavigationLink 推入 ReplayView。Navigation 不存在 dismiss→present 过渡动画的重叠窗口问题。

**缺点**：改动量大，影响整个 App 导航架构。当前阶段不建议。

## 其他发现

### ReplayControlView 的 Binding 模式

```swift
Slider(
    value: Binding(
        get: { Double(viewModel.currentIndex) },
        set: { viewModel.jumpTo(index: Int($0)) }
    ),
    in: 0...Double(max(1, viewModel.record.moves.count)),
    step: 1
)
```

`ReplayControlView` 持有 `let viewModel: ReplayViewModel`（强引用），Binding 闭包捕获了 `viewModel`。如果 View 被销毁但 Binding 闭包被 SwiftUI 内部持有（Slider 的内部实现），可能延长 ViewModel 的生命周期。这不是崩溃的直接原因，但可能导致内存泄漏。方案 A 自然解决了这个问题（View 销毁时所有引用一起释放）。

### L10n 和 ThemeManager 的 @Observable

- `L10n` 通过 `@Environment` 注入，是全局单例，不参与 sheet 生命周期 → 无风险
- `ThemeManager.shared` 通过 `ThemeManager.shared.colors` 静态访问 → 无风险
- `ChessBoardView` 的 `theme` 参数是 `ThemeColors` struct（值类型）→ 无风险

### BoardMode enum 的长期风险

`BoardMode` 用 enum 关联值持有 `@Observable` class 引用在三种场景中使用。除了 `replay`，`playGame` 和 `playPuzzle` 也有相同模式：

```swift
case playGame(GameViewModel)    // @Observable
case playPuzzle(PuzzleViewModel) // @Observable
```

但这些场景下，GameViewModel 和 PuzzleViewModel 的生命周期等于 App 或页面生命周期，不存在 dismiss→present 过渡。**只有 replay 场景有 sheet 生命周期问题。**

不过作为长期改进，建议考虑用 **protocol + 泛型** 替代 enum 关联值：
```swift
protocol BoardViewModelProtocol: Observable {
    var board: Board { get }
    // ...
}
```
这不是本次修复的范围，但值得 Alex 记录为技术债务。

## 推荐行动

| 优先级 | 行动 | 工时 | 方案 |
|--------|------|------|------|
| P0 | ReplayView 去掉 `@State`，调用处改 `.id(UUID())` | 30 min | 方案 A |
| P0 | 回归测试：macOS 点击历史棋局回放 | 10 min | — |
| P1 | PuzzlePlayView 同步应用方案 A（`.id(UUID())`） | 10 min | — |
| P2 | 代码规范：`@State` 不包装 `@Observable` class in sheet | — | 规范条目 |
| P3 | `BoardMode` enum 重构为 protocol（技术债务） | 2h+ | 长期 |

**总工时估算**：P0 约 40 分钟（改动 + 测试）
