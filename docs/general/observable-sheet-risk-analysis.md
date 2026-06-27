# @Observable + sheet 崩溃风险分析

> 审查者：Vera·维拉 | 日期：2026-06-17
> 触发：Ruby 审查回放崩溃 Bug（v2.2.18），发现同类模式未排查
> 参考：[bug-replay-crash-v2218.md](./bug-replay-crash-v2218.md)

## 已知崩溃模式（回放）

`ReplayView` 使用 `@State` 包装 `@Observable` class `ReplayViewModel`，在 `.sheet(item:)` / `.fullScreenCover(item:)` 的 dismiss→present 过渡中，SwiftUI AttributeGraph 持有旧 ViewModel 实例的 KeyPath 观察引用。旧实例释放后 KeyPath 访问触发 assertion failure → `EXC_BAD_INSTRUCTION`。

已修复：`.id(record.id)` + `board.snapshot()` 替换实例。

---

## 排查对象 1：PuzzlePlayView

### 代码位置
`Views/PuzzleSelectView.swift` 第 415 行（内嵌定义）

### 模式分析

```swift
struct PuzzlePlayView: View {
    let puzzle: Puzzle
    @State private var viewModel: PuzzleViewModel  // ← @State + @Observable class

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self._viewModel = State(initialValue: PuzzleViewModel(puzzle: puzzle))
    }
}
```

### sheet 使用情况

**⚠️ PuzzlePlayView 本身就定义在 sheet/fullScreenCover 内**（PuzzleSelectView.swift 第 196-208 行）：

```swift
.fullScreenCover(item: $selectedPuzzle) { puzzle in
    PuzzlePlayView(puzzle: puzzle)  // iOS: fullScreenCover
}
.sheet(item: $selectedPuzzle) { puzzle in
    PuzzlePlayView(puzzle: puzzle)  // macOS: sheet
}
```

**进一步嵌套**：PuzzlePlayView 内部的通关弹窗又弹出了一个 `.sheet(isPresented: $showSolutionReplay)` → `ReplayView`（解法回放），即 sheet 内嵌 sheet，两层 `@State + @Observable`。

### 嵌套 @Observable 分析

`PuzzleViewModel` 持有 `var board: Board`，`Board` 也是 `@Observable` class。`board.execute()` 修改 Board 内部状态但**不替换实例**（PuzzleViewModel 没有像已修复的 ReplayViewModel 那样做 `self.board = board.snapshot()`）。

### 触发条件

**dismiss→present 快速过渡**：
1. 用户在残局列表选中 Puzzle A → fullScreenCover 弹出 PuzzlePlayView
2. 通关或点返回 → dismiss
3. 紧接着选中 Puzzle B → present 新 PuzzlePlayView
4. 新 PuzzlePlayView 创建新 `PuzzleViewModel`，旧实例释放
5. 如果 AttributeGraph 仍持有旧 ViewModel 的 KeyPath 引用（尤其 `viewModel.board` 嵌套追踪）→ 崩溃

**实际触发概率**：低于 ReplayView 崩溃。原因是 `PuzzleSelectView` 用 `item: $selectedPuzzle`（Identifiable binding），SwiftUI 天然在 item 变化时重建内容。但 dismiss→present 的过渡动画期间仍有重叠窗口。

### 风险等级：🟡 中

- 有 `@State + @Observable` + sheet 内使用 ✓
- 有嵌套 `@Observable`（Board）且未替换实例 ✓
- `item:` binding 提供一定保护（item 变化时重建），但 dismiss→present 过渡仍存在窗口
- PuzzlePlayView 自身内部还有一层 sheet（ReplayView），双重嵌套增加风险

### 修复方案

**修复 1（必须）：给 PuzzlePlayView 的 fullScreenCover/sheet 加 `.id(puzzle.id)`**

iOS（PuzzleSelectView.swift 第 196-208 行）：
```swift
.fullScreenCover(item: $selectedPuzzle) { puzzle in
    PuzzlePlayView(puzzle: puzzle)
        .id(puzzle.id)  // ← 新增
}
```

macOS（同文件）：
```swift
.sheet(item: $selectedPuzzle) { puzzle in
    PuzzlePlayView(puzzle: puzzle)
        .frame(minWidth: 520, minHeight: 680)
        .id(puzzle.id)  // ← 新增
}
```

**修复 2（建议）：PuzzleViewModel 的 board.execute() 后替换 Board 实例**

与 ReplayViewModel 同理。但 PuzzleViewModel 中 `board.execute()` 调用点多（`movePiece`、`triggerDefenderMove`、`triggerSolutionDefenderMove`、`undoMove`），改动量大。考虑到 `PuzzleViewModel` 的生命周期与 PuzzlePlayView 绑定（用户不会在同一个残局中反复 dismiss→present），修复 1 已足够。

**修复 3（可选）：通关弹窗的 sheet 改为 overlay/ZStack 内联**

当前通关弹窗已经是 overlay 模式（ZStack + Color.black.opacity），但"查看解法"按钮弹出 `ReplayView` 用的是 `.sheet`。ReplayView 已有 `.id(record.id)` 保护（来自之前的修复），这里风险低。

### 优先级建议：P2

- **修复 1** 加 `.id()` — 10 分钟，低风险改动
- **修复 2** board 替换 — 可延后，除非实际出现崩溃

---

## 排查对象 2：StatsPanelView

### 代码位置
`Views/StatsPanelView.swift`

### 模式分析

```swift
struct StatsPanelView: View {
    @State private var statsVM = StatsViewModel()  // ← @State + @Observable class
}
```

### sheet 使用情况

StatsPanelView **在 sheet 内被使用**：

**macOS**（ChineseChessApp.swift 第 132-136 行）：
```swift
.sheet(isPresented: Binding(
    get: { activePanel == .stats },
    set: { if !$0 { activePanel = .none } }
)) {
    StatsPanelView()
        .frame(minWidth: 280, minHeight: 180, maxHeight: 400)
}
```

**iOS**（ChineseChessiOSApp.swift 第 164 行）：
```swift
.sheet(isPresented: ...) {
    NavigationStack {
        StatsPanelView()
        ...
    }
}
```

### 嵌套 @Observable 分析

`StatsViewModel` **无嵌套 @Observable**。内部只有 `StatsManager.shared.stats`（通过 `GameStats` struct 访问），没有持有其他 `@Observable` class。这是关键差异。

`StatsViewModel` 用了一个 `private var _refreshTrigger = false` 来手动触发刷新追踪，`stats` computed property 依赖它。没有深层嵌套追踪风险。

### 触发条件

用户反复开关统计面板（dismiss→present）。但因为：
1. `StatsViewModel()` 每次创建新实例（`@State` 初始值），旧实例释放
2. 无嵌套 `@Observable`，AttributeGraph 追踪浅
3. 用的是 `isPresented` 而非 `item:` — 每次打开都是同一个 sheet 重新 present

dismiss→present 过渡中旧 `StatsViewModel` 释放，新实例创建。浅层 `@Observable` 追踪在大多数情况下能正常清理。但理论上，如果 `_refreshTrigger` 在 dismiss 过渡动画期间被访问（如 `onAppear` 中 `statsVM.refresh()`），仍可能触发断言。

**实际触发概率**：极低。StatsViewModel 无嵌套，且 sheet 内容简单。

### 风险等级：🟢 低

- 有 `@State + @Observable` + sheet 内使用 ✓
- **无嵌套 @Observable** — 大幅降低风险
- `isPresented` 模式（非 `item:` 变化），每次都是全新 present
- `onAppear` 中的 `refresh()` 在 sheet 完全就绪后触发

### 修复方案

**修复（可选）：给 StatsPanelView sheet 加标识**

macOS：
```swift
.sheet(isPresented: ...) {
    StatsPanelView()
        .frame(minWidth: 280, minHeight: 180, maxHeight: 400)
        .id(UUID())  // 每次 present 强制重建，但 UUID 每次都不同会破坏动画
```

**注意**：用 `UUID()` 会导致每次 dismiss 后 present 时 SwiftUI 认为是全新视图，**sheet 弹出动画可能受影响**。

**更优方案**：加一个 session 计数器：
```swift
// StatsPanelView 或 App 层
@State private var statsSessionId = 0

.sheet(isPresented: ...) {
    StatsPanelView()
        .id(statsSessionId)
}

// present 时递增
statsSessionId += 1
```

但鉴于风险极低，这个改动收益有限。

### 优先级建议：P3（观察）

- 不需要立即修复
- 如果后续出现统计面板相关崩溃，再加 `.id()`

---

## 汇总

| 排查对象 | 风险等级 | sheet 内使用 | 嵌套 @Observable | 触发场景 | 必须修复 | 优先级 | 工时 |
|----------|---------|-------------|-----------------|---------|---------|-------|------|
| PuzzlePlayView | 🟡 中 | ✅ fullScreenCover/sheet | ✅ Board (未替换实例) | 快速切换残局 | `.id(puzzle.id)` | P2 | 10 min |
| StatsPanelView | 🟢 低 | ✅ sheet | ❌ 无 | 反复开关统计面板 | 无需 | P3 观察 | — |

## 行动建议

1. **PuzzlePlayView 加 `.id(puzzle.id)`** — 立即做，10 分钟改动，与 ReplayView 修复一致
2. **StatsPanelView** — 当前不修复，加入回归测试观察列表
3. **全局建议**：代码规范中增加一条——"`@State` 包装 `@Observable` class 且在 sheet/fullScreenCover 中使用时，必须加 `.id()`"。避免未来新代码再踩这个坑
