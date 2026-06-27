# 回放崩溃深度诊断 v2 — 崩溃栈分析

> 审查者：Vera·维拉 | 日期：2026-06-17
> 触发：v2.2.19 三轮修复全部失败，需要从崩溃栈重新定位
> 前两轮诊断结论作废

## 崩溃日志分析

### 基本信息
- 版本：v2.2.19，macOS 15.7.7 (24G720)
- 崩溃类型：`EXC_BAD_INSTRUCTION` (SIGILL) — assertion failure
- 线程：`com.apple.main-thread`
- 二进制：Release 构建，**无应用层符号**（所有 imageIndex 3 = SwiftUICore 的帧无符号）

### 主线程崩溃栈（两份日志一致）

```
_assertionFailure
SwiftUICore (无符号)
SwiftUICore (无符号)
specialized project2 <A, B><A1><A2>(_:) in closure #2 in KeyPath._projectReadOnly(from:)
KeyPath._projectReadOnly(from:)
swift_getAtKeyPath
SwiftUICore (无符号) × 多层
AG::Graph::UpdateStack::update()
AG::Graph::update_attribute()
AG::Graph::input_value_ref_slow()
AGGraphGetValue
SwiftUI (无符号) × 多层嵌套 AG 更新周期
...
+[NSAnimationContext runAnimationGroup:]
NSViewLayout
-[NSView _layoutSubtreeWithOldSize:]_block_invoke
-[NSView _layoutSubtreeIfNeededAndAllowTemporaryEngine:]_block_invoke
-[NSWindow _layoutViewTree]
NSDisplayCycleFlush
CA::Transaction::commit()
CFRunLoop observer
ChineseChessApp.$main()
```

### 关键发现 1：崩溃时机是 NSWindow Layout，不是 sheet transition

前两轮诊断假设崩溃发生在 sheet dismiss→present 过渡中。**崩溃栈证明这是错误的**。

崩溃发生在 `NSWindow._layoutViewTree` → `NSView._layoutSubtreeIfNeededAndAllowTemporaryEngine` → AppKit 的 layout cycle 中。SwiftUI 的 AttributeGraph 在响应 AppKit layout 事件时，尝试更新视图属性依赖图，触发 `KeyPath._projectReadOnly` 的 assertion failure。

这意味着：**即使没有 sheet 过渡，只要 ReplayView 的视图树在 NSWindow layout 中被遍历，就可能触发崩溃。**

### 关键发现 2：第二份日志的次要线程 — 枚举类型遍历栈溢出

第二份崩溃日志的 **thread 8461338** (`com.apple.root.utility-qos`) 有一个独立的崩溃：

```
AG::LayoutDescriptor::Builder::visit_case(AG::swift::metadata const*, ...) ← 枚举 case 处理
AG::swift::metadata::visit(AG::swift::metadata_visitor&)
AG::LayoutDescriptor::make_layout()
AG::(anonymous namespace)::TypeDescriptorCache::fetch()
AG::LayoutDescriptor::Builder::should_visit_fields()
AG::LayoutDescriptor::Builder::visit_element()
AG::swift::metadata_visitor::visit_field()
AG::swift::metadata::visit()
AG::LayoutDescriptor::make_layout()
...（递归 10+ 层）
```

AttributeGraph 在后台线程构建 Swift 类型的 layout descriptor 时，**递归遍历枚举类型的 associated values**。`visit_case` 是 AttributeGraph 处理 enum 类型的专用函数。这个线程崩溃说明：
- AttributeGraph 正在尝试理解某个 **包含 `@Observable` class 引用的 enum 类型** 的内存布局
- 递归深度极大（10+ 层嵌套的 `make_layout` → `fetch` → `visit` → `visit_field`），可能超出了 AttributeGraph 的预期

### 关键发现 3：Release 构建无应用层符号

崩溃栈中 `imageIndex 3` (SwiftUICore) 的所有帧都没有符号。无法定位具体是 ReplayView 的哪个 computed property 或 Binding 触发了 KeyPath 追踪失败。**必须有 Debug 构建才能进一步缩小范围。**

## 新根因假设

### 假设：`BoardMode` enum 的 `@Observable` associated values 导致 AttributeGraph layout descriptor 递归崩溃

```swift
enum BoardMode {
    case playGame(GameViewModel)      // @Observable class
    case playPuzzle(PuzzleViewModel)  // @Observable class
    case replay(ReplayViewModel)      // @Observable class
}
```

AttributeGraph 在首次遇到 `BoardMode` 类型时，需要构建其 layout descriptor 以支持 KeyPath 追踪。`@Observable` class 的 metadata 被 Observation framework 修改过（添加了 `_ObservationTracking` 相关的存储），AttributeGraph 递归遍历 enum associated values 的类型 metadata 时，可能在 `@Observable` 修改过的 metadata 上走入了未预期的路径。

**支持证据**：
1. 次要线程崩溃在 `visit_case`（枚举专用），递归深度异常
2. 主线程崩溃在 `KeyPath._projectReadOnly`（KeyPath 追踪）
3. `ChessBoardView` 的 body 中有大量通过 enum pattern matching 访问 ViewModel 属性的 computed properties（`board`、`selectedPosition`、`legalMoves`、`isInCheck`、`lastMove`、`hintMove`、`canInteract`、`isPlayerPiece`），每个都是 SwiftUI 的 KeyPath 追踪入口
4. 崩溃只在 **macOS** 上发生（macOS 用 NSWindow layout，iOS 用 UIKit layout），两套系统的 AttributeGraph 调用路径不同

### 假设 2：`@Observable` + `private(set)` 属性在 KeyPath 追踪中的兼容性问题

`ReplayViewModel` 有：
```swift
private(set) var board: Board
private(set) var currentIndex: Int = 0
```

`@Observable` 宏为这些属性生成 `_$observationRegistrar` 和 access tracking。`private(set)` 可能在宏展开中产生特殊的 access control 修饰符，影响 AttributeGraph 的 KeyPath projection。

## 修复方案

### 方案 1（推荐）：将 `BoardMode` enum 改为 protocol + 分离 View

**原理**：消除 `BoardMode` enum 的 `@Observable` class associated values，避免 AttributeGraph 递归遍历。

```swift
// 新增 protocol
protocol ChessBoardViewModel: AnyObject {
    var board: Board { get }
    var selectedPosition: Position? { get }
    var legalMovesForSelected: [Position] { get }
    var hintMove: (from: Position, to: Position)? { get }
    var isInCheck: Bool { get }
    func isReadOnly() -> Bool
    func canInteract() -> Bool
    func isPlayerPiece(at pos: Position) -> Bool
    func handleTap(at pos: Position)
}

// 三个 ViewModel 分别 conform
extension GameViewModel: ChessBoardViewModel { ... }
extension PuzzleViewModel: ChessBoardViewModel { ... }
extension ReplayViewModel: ChessBoardViewModel { ... }

// ChessBoardView 改为泛型
struct ChessBoardView<VM: ChessBoardViewModel>: View {
    @ObservedObject var viewModel: VM  // 或 @Bindable
    ...
}
```

**等等**——如果 ViewModel 是 `@Observable`（不是 `ObservableObject`），`@ObservedObject` 不适用。

修正：用 `@Bindable`（iOS 17+/macOS 14+ 的 `@Observable` 配套属性包装器）：

```swift
struct ChessBoardView<VM: ChessBoardViewModel>: View {
    @Bindable var viewModel: VM
    ...
}
```

但 `ChessBoardViewModel` protocol 需要兼容 `@Observable` 的 access tracking。更好的做法：

**最简方案**：ChessBoardView 直接接受 ViewModel 的具体属性，不通过 enum 中转：

```swift
// 方案 1a：ChessBoardView 不再依赖 BoardMode enum
struct ChessBoardView: View {
    // 从外部传入需要的属性，不传整个 ViewModel
    let board: Board
    let selectedPosition: Position?
    let legalMoves: [Position]
    let hintMove: (from: Position, to: Position)?
    let isInCheck: Bool
    let lastMove: (from: Position, to: Position)?
    let isReadOnly: Bool
    let onTap: (Position) -> Void
    let canInteract: Bool
    ...
}
```

**优点**：彻底消除 `BoardMode` enum，AttributeGraph 不需要遍历 enum associated values
**缺点**：ChessBoardView 的调用处需要传入所有参数，改动量大（3 个调用点）

### 方案 2（最小改动）：将 ReplayViewModel 从 `@Observable` 改为 `ObservableObject` + `@Published`

**原理**：`ObservableObject` + `@Published` 使用 Combine 的 `objectWillChange` publisher，不依赖 Observation framework 的 metadata 修改，AttributeGraph 的 layout descriptor 遍历不会遇到被修改过的 metadata。

```swift
import Combine

class ReplayViewModel: ObservableObject {
    @Published var board: Board
    @Published private(set) var currentIndex: Int = 0
    @Published var lastMove: (from: Position, to: Position)? = nil
    @Published var isAutoPlaying: Bool = false
    @Published var autoPlaySpeed: Double = 1.0
    
    // ReplayView 和 ReplayControlView 改用 @ObservedObject
}
```

**优点**：改动集中在 ReplayViewModel 和其 Views，不影响其他 ViewModel
**缺点**：`@Observable` 和 `ObservableObject` 的语义不同（细粒度 vs 粗粒度追踪），需要 ReplayView/ReplayControlView 的所有 `@State` 改为 `@StateObject` 或 `@ObservedObject`
**缺点**：BoardMode enum 的 `@Observable` associated value 问题仍存在（GameViewModel、PuzzleViewModel 仍是 `@Observable`），虽然当前只有 replay 崩溃

### 方案 3（最快验证）：去掉 BoardMode，ChessBoardView 针对 replay 场景单独处理

```swift
// ReplayView 中直接构建棋盘，不用 ChessBoardView
struct ReplayView: View {
    @State private var viewModel: ReplayViewModel
    ...
    
    var body: some View {
        VStack {
            ...
            // 直接内联棋盘渲染，不走 ChessBoardView
            ReplayBoardView(viewModel: viewModel)
            ...
        }
    }
}

// 专门为回放场景的轻量棋盘
struct ReplayBoardView: View {
    let viewModel: ReplayViewModel
    var board: Board { viewModel.board }
    ...
}
```

**优点**：完全绕开 `BoardMode` enum，改动范围小
**缺点**：棋盘渲染代码重复

## 推荐行动

| 优先级 | 行动 | 工时 | 目的 |
|--------|------|------|------|
| P0 | **Cody 准备 Debug 构建**，洪涛运行获取带符号崩溃栈 | 15 min | 确认崩溃具体位置 |
| P0-备选 | **方案 3：为 ReplayView 创建独立 ReplayBoardView**，绕开 BoardMode enum | 2h | 如果 Debug 构建确认是 BoardMode 的问题 |
| P1 | **方案 2：ReplayViewModel 改为 ObservableObject** | 1.5h | 如果方案 3 验证有效，彻底规避 @Observable |
| P2 | **方案 1：消除 BoardMode enum，重构为 protocol** | 4h+ | 长期架构改进 |

## 不确定事项（需要 Debug 构建确认）

1. **崩溃具体在哪个 computed property / Binding 的 KeyPath 追踪** — Release 无符号
2. **是否是 `BoardMode` enum 还是 `@Observable` metadata 本身的问题** — 两者都可能导致 `visit_case` 崩溃
3. **为什么只在 macOS 上崩溃** — 可能是 macOS 15.7.7 的 AttributeGraph 6.5.1 特有 bug，也可能是 NSWindow layout cycle 的调用路径差异
4. **为什么 `playGame` 和 `playPuzzle` 模式不崩溃** — 可能是首次 layout 时 GameViewModel/PuzzleViewModel 尚未创建（sheet 未打开），而 replay 场景是 history sheet 内嵌 replay sheet，layout 时机不同

## 结论

前两轮诊断的 `.id()` + `board.snapshot()` 方案针对的是错误的根因。崩溃栈表明问题是 AttributeGraph 在处理包含 `@Observable` class associated values 的 enum 类型时触发的 assertion failure。

**最可能的根因是 `BoardMode` enum 与 `@Observable` 的组合**，而非 `@State` 生命周期问题。

下一步必须先获取 Debug 构建的带符号崩溃栈确认，然后优先尝试方案 3（最小改动绕开 BoardMode）验证。
