# v2.2.21 iOS Bug 根因分析与修复方案

> **架构师**: Alex  
> **基线**: v2.2.20n (HEAD: c9316fb)  
> **日期**: 2025-06-20  
> **修订**: v3 — 修复 Vera P0-3 / P1-4 / P1-5 / P2-5 / P2-6  

---

## 总览

| # | Bug | 优先级 | 根因类型 | 影响范围 | 复杂度 |
|---|-----|--------|----------|----------|--------|
| 1 | 残局提示有时无位置高亮 | P0 | 设计缺陷 | 通用 | 中 |
| 2 | 残局提示不是中文棋谱 | P0 | 代码缺陷 | 通用 | 低 |
| 3 | 回放棋盘仍然太小 | P0 | 设计缺陷 | iOS | 中 |
| 4 | 顶部按钮布局不合理 | P0 | 设计缺陷 | iOS | 低 |
| 5 | 级别显示不够明显 | P1 | 样式不足 | 通用 | 低 |
| 6 | 通关后残局查看入口 | P1 | 功能缺失 | 通用 | 中 |
| 7 | 棋谱记录格式难看 | P1 | 设计不足 | 通用 | 中 |

---

## Bug 1: 残局提示有时有位置高亮，有时没有

### 根因确认（v2 修订 — 原方案根因判断有误）

**类型：代码缺陷**

**数据现实**：全部 551 个 puzzle 的 `hints` 字段均为 `null`，`solutionType` 全部为 `checkmate`。因此 `showHint()` 的分支 A（hint 类型）和分支 B（文字 hints）**永远不会被触发**。用户走的永远是分支 C（step-by-step solution）。

**真正根因**：`hintIndex` 不跟踪游戏进度。

分支 C 的代码：

```swift
let solIdx = hintIndex - (puzzle.hints?.count ?? 0)  // hintIndex - 0 = hintIndex
let iccs = puzzle.solution[solIdx]
if let move = ICCSParser.parse(iccs, on: board) {
    hintMove = (from: move.from, to: move.to)  // ✅ 高亮
} else {
    hintMove = nil  // ❌ 无高亮
}
```

问题出在 `ICCSParser.parse(iccs, on: board)` —— 这里的 `board` 是**当前棋盘**，但 `solution[hintIndex]` 是**从初始局面开始**的第 hintIndex 步。如果玩家已经走了几步，棋盘状态已推进，`solution[0]` 对应的棋子可能已经移动到其他位置，parse 必然失败。

**触发场景**：

| 场景 | hintIndex | 实际棋盘 | solution[hintIndex] | parse 结果 | 高亮 |
|------|-----------|----------|---------------------|-----------|------|
| 开局直接点提示 | 0 | 初始局面 | solution[0] 在初始局面上合法 | ✅ 成功 | ✅ 有 |
| 走了几步后点提示 | 0 | 已推进 | solution[0] 对应棋子已移动 | ❌ 失败 | ❌ 无 |
| 连续多点 | 0→1→2 | 已推进 | 步步失败 | ❌ 全失败 | ❌ 无 |

这就解释了用户看到的「有时有目的位置提示，有时没有」。

### 影响范围：通用（iOS + macOS）

### 修复方案（v2 重写）

**核心思路**：提示索引基于实际游戏进度，而非 hintIndex 计数器。

**修改文件**：`PuzzleViewModel.swift`

#### 步骤 1：新增 `hintOffsetInSession` 状态

```swift
/// 当前提示会话内的偏移量（每次走棋/悔棋重置为 0）
private var hintOffsetInSession: Int = 0
```

#### 步骤 2：重写 `showHint()` 分支 C

```swift
// 计算当前应提示的 solution 步序号
let baseStep = currentSolutionStep()
let solIdx = baseStep + hintOffsetInSession

if solIdx < puzzle.solution.count {
    // 使用独立棋盘推演获取位置和棋谱（一次推演）
    if let info = getSolutionInfo(at: solIdx) {
        hintMove = (from: info.from, to: info.to)
        currentHint = String(format: L10n.shared.t("puzzle.hintStep"), solIdx + 1, info.notation)
    } else {
        hintMove = nil
        currentHint = L10n.shared.t("puzzle.noMoreHints")
    }
    hintOffsetInSession += 1
} else {
    currentHint = L10n.shared.t("puzzle.noMoreHints")
    hintMove = nil
}
gameState = .showingHint
```

#### 步骤 3：新增辅助方法（P1-5 修复：合并推演逻辑）

**`solutionStepIndex` 语义说明**（P0-3 / P1-4 修复）：

`solutionStepIndex` 是 **solution 数组的绝对索引**（从 0 开始）：

| 时机 | solutionStepIndex 值 | 指向的步 |
|------|---------------------|----------|
| 初始 | 0 | solution[0]（玩家第一步） |
| 玩家走对 | +1 | solution[1]（AI 步） |
| AI 应对后 | +1 | solution[2]（玩家第二步） |
| 玩家走错 | 不推进 | 保持指向期望步 |

**关键结论**：走错时 `solutionStepIndex` 就是期望走法在 solution 中的绝对索引，可直接用于棋谱推演。

```swift
/// 当前游戏进度对应的 solution 步序号
private func currentSolutionStep() -> Int {
    if isGuidedMode {
        return solutionStepIndex  // 绝对索引，直接用
    }
    // freePlay：按已走步数推算
    return min(gameMoves.count, puzzle.solution.count)
}

/// 从初始局面推演获取指定步的完整信息（P1-5：合并推演逻辑）
/// 返回：棋子起止位置 + 中文棋谱
/// 不依赖当前 board 状态，避免 parse 失败
private func getSolutionInfo(at step: Int) -> (from: Position, to: Position, notation: String)? {
    var tempBoard = Board(fen: puzzle.initialFEN)
    for (i, iccs) in puzzle.solution.enumerated() {
        guard let move = ICCSParser.parse(iccs, on: tempBoard) else {
            #if DEBUG
            print("[PuzzleViewModel] getSolutionInfo: parse failed at step \(i), iccs=\(iccs)")
            #endif
            return nil
        }
        if i == step {
            let notation = NotationGenerator.notation(for: move, on: tempBoard)
            return (move.from, move.to, notation)
        }
        tempBoard.execute(move)
    }
    return nil
}
```

**设计决策**（P1-5）：合并 `getSolutionPosition` 和 `notationFromICCS` 为单一方法 `getSolutionInfo(at:)`，一次推演同时返回位置和棋谱，避免重复推演和维护性问题。

#### 步骤 4：在走棋和悔棋时重置 `hintOffsetInSession`

在 `movePiece()` 方法末尾添加：
```swift
hintOffsetInSession = 0
```

在 `undoMove()` 方法末尾添加：
```swift
hintOffsetInSession = 0
```

在 `resetPuzzle()` 方法中添加：
```swift
hintOffsetInSession = 0
```

#### 步骤 5：废弃旧的 `hintIndex`

`hintIndex` 不再用于分支 C 的 solution 索引计算。保留 `hintIndex` 仅用于分支 A/B（text hints），在当前数据中分支 A/B 不会触发，但保留兼容性。

### 设计决策说明

1. **为什么用独立棋盘推演而不是当前棋盘？**
   当前棋盘可能因玩家走错回退、自由对弈等偏离 solution 路径。独立推演从初始 FEN 出发，保证 solution 步序的 from/to 永远准确。

2. **为什么用 `solutionStepIndex` 而不是 `gameMoves.count`？**
   guided 模式下 `solutionStepIndex` 精确跟踪 solution 进度（包括 AI 步），比 `gameMoves.count` 更准确。freePlay 模式下玩家可能偏离 solution，用 `gameMoves.count` 作为近似基线。

3. **`hintOffsetInSession` 的语义？**
   每次走棋或悔棋后重置。用户在同一局面连续点提示 N 次，会看到 solution[base]、solution[base+1]、... solution[base+N-1]。走一步后重置，再点提示从新的 base 开始。

### 验证点
- ✅ 开局直接点提示：baseStep=0, solution[0] on 初始棋盘 → 有高亮
- ✅ 走了几步后点提示：baseStep=实际进度, solution[baseStep] → 有高亮
- ✅ 连续多点：依次显示后续步
- ✅ 走棋后重新点提示：从新局面对应的 solution 步开始
- ✅ guided 模式 + freePlay 模式均正确

---

## Bug 2: 残局提示不是中文棋谱写法

### 根因确认

**类型：代码缺陷**

`PuzzleViewModel.showHint()` 分支 C（step-by-step solution）：

```swift
let iccs = puzzle.solution[solIdx]
currentHint = String(format: L10n.shared.t("puzzle.hintStep"), solIdx + 1, iccs)
//                                                              ↑ 直接用 ICCS 字符串
```

提示文案直接插入 ICCS 格式（如 `h2e2`），未调用 `NotationGenerator` 转换。

同样，走错时的提示也有此问题：

```swift
solutionHint = String(format: L10n.shared.t("puzzle.wrongMove"), stepIndex, expectedICCS)
//                                                              ↑ 直接用 ICCS 字符串
```

### 影响范围：通用（iOS + macOS）

### 修复方案

在显示前将 ICCS 转换为中文棋谱，**只改显示层，不改 NotationGenerator 核心逻辑**：

**修改文件**：`PuzzleViewModel.swift`

1. 新增辅助方法（注意：`notationFromICCS` 需要指定步序号，在推演棋盘上生成棋谱）：

```swift
/// 将 ICCS 字符串转换为当前棋谱格式（默认中文）
/// at: solution 中的步序号，用于在推演棋盘上生成准确棋谱
private func notationFromICCS(_ iccs: String, at step: Int) -> String {
    var tempBoard = Board(fen: puzzle.initialFEN)
    for (i, solIccs) in puzzle.solution.enumerated() {
        guard let move = ICCSParser.parse(solIccs, on: tempBoard) else {
            // 推演中断，fallback 到原始 ICCS（P2-2：加 debug log）
            #if DEBUG
            print("[PuzzleViewModel] notationFromICCS: parse failed at step \(i)")
            #endif
            return iccs
        }
        if i == step {
            return NotationGenerator.notation(for: move, on: tempBoard)
        }
        tempBoard.execute(move)
    }
    return iccs  // fallback
}
```

2. 在 `showHint()` 分支 C 中（已在 Bug 1 修复中集成）：

```swift
let notationStr = notationFromICCS(iccs, at: solIdx)
currentHint = String(format: L10n.shared.t("puzzle.hintStep"), solIdx + 1, notationStr)
```

3. 在 `handleWrongMove()` 中（P0-3 修复：明确用 `solutionStepIndex`）：

```swift
// 走错时 solutionStepIndex 未推进，直接指向期望步
// 用独立推演获取棋谱（不依赖走错后的 board 状态）
if let info = getSolutionInfo(at: solutionStepIndex) {
    solutionHint = String(format: L10n.shared.t("puzzle.wrongMove"), stepIndex, info.notation)
} else {
    solutionHint = String(format: L10n.shared.t("puzzle.wrongMove"), stepIndex, expectedICCS)
}
```

**关键**：走错时 `solutionStepIndex` 直接就是期望步的绝对索引，无需额外计算。

### 验证点
- 提示文案显示 "炮二平五" 而非 "h2e2"
- 走错提示显示 "炮二平五" 而非 "h2e2"
- 如果用户在设置中切换为 ICCS 格式，应显示 ICCS（`NotationGenerator` 已处理）

---

## Bug 3: 回放棋盘仍然太小

### 根因确认

**类型：设计缺陷**

对比 `ChessBoardView` 和 `ReplayBoardView` 的尺寸参数：

| 参数 | ChessBoardView | ReplayBoardView |
|------|---------------|-----------------|
| maxCellSize | 80 | 80 |
| maxBoardWidth (iOS) | 600 | 600 |
| maxBoardHeight (iOS) | 675 | 675 |
| padding 计算 | 相同 | 相同 |

两者棋盘尺寸计算逻辑完全一致。**根因在于上下文空间分配不同**：

- **对弈页面**（`ChineseChessiOSApp`）：ToolbarView(~52pt) + BoardView(layoutPriority:1) + StatusBarView(~60pt) + 底部 toolbar(navigationStack bottomBar)
- **回放页面**（`ReplayView`）：标题栏(~40pt) + 对局信息栏(~30pt) + ReplayBoardView(layoutPriority:1) + **ReplayControlView(~160pt)**

`ReplayControlView` 包含：Slider + 5个按钮 + 速度选择器 + 步数信息行，占用约 160pt 垂直空间。比对弈页面的 `StatusBarView`（~60pt）多出约 100pt。这直接压缩了棋盘的可用高度。

### 影响范围：iOS（macOS 窗口可调，问题不显著）

### 修复方案

**方案：压缩回放控制栏高度 + 提升棋盘空间利用率**

**修改文件**：`ReplayControlView.swift`、`ReplayBoardView.swift`

1. **ReplayControlView iOS 精简**：合并步数信息行到控制按钮行，减少一行

```swift
// 修改前：VStack(spacing: 8) { Slider; 按钮行; 步数行 }
// 修改后：VStack(spacing: 6) { 按钮行(含步数); Slider }
```

具体：将「当前步信息」合并进控制按钮行的左侧或右侧，去掉独立行。

2. **ReplayBoardView 提升 maxBoardHeight**（不移除，定终值 850）：

```swift
// 修改前：
#if os(iOS)
private let maxBoardWidth: CGFloat = 600
private let maxBoardHeight: CGFloat = 675
#endif

// 修改后：
#if os(iOS)
private let maxBoardWidth: CGFloat = 600
private let maxBoardHeight: CGFloat = 850  // 675 → 850
#endif
```

选择 850 而非移除的理由：iPad Pro 12.9" 横屏高度 1024pt，移除限制后棋盘可能撑满屏幕导致控制栏被挤压。850pt 留出足够空间给控制栏，同时在 iPhone 上不构成实际限制（iPhone 屏幕高度远小于 850）。

3. **ReplayView 合并对局信息栏到标题栏**（P2-5 修复：去掉多余 VStack）：

```swift
HStack {
    Button(l10n.t("common.close")) { dismiss() }
        .foregroundColor(.white)
    Spacer()
    // 对局信息（红方 vs 黑方）放在同一个 HStack 内
    Text(String(format: l10n.t("replay.vsFormat"), viewModel.record.redPlayer.name))
        .font(.caption.weight(.medium))
        .foregroundColor(.red)
        .lineLimit(1)
        .minimumScaleFactor(0.7)  // 小屏适配
    Text(" vs ")
        .font(.caption2)
        .foregroundColor(.gray)
    Text(viewModel.record.blackPlayer.name)
        .font(.caption.weight(.medium))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    Spacer()
    // 占位保持对称
    Color.clear.frame(width: 44)
}
.padding(.horizontal, 16)
.padding(.vertical, 6)
```

**修正**（P2-5）：去掉多余的 VStack，红方、vs、黑方放在同一个 HStack 内，视觉层级正确。

小屏适配说明：iPhone SE（375pt 宽）减去左右 padding（32pt）和退出按钮（44pt）+ 占位（44pt）= 255pt 可用。`minimumScaleFactor(0.7)` + `lineLimit(1)` 确保文字不溢出。

### 验证点
- iOS 回放棋盘与对弈棋盘视觉上同等大小
- 控制栏功能不丢失（播放/暂停/前进/后退/速度/步数）
- macOS 不受影响

---

## Bug 4: 顶部按钮布局不合理，悔棋和新开一局挨太近

### 根因确认

**类型：设计缺陷**

`ToolbarView.swift` iOS 分支：

```swift
HStack(spacing: 0) {
    Button(plus.circle)      // 新开一局 — 44pt
    Button(uturn.backward)   // 悔棋 — 44pt（紧贴上一个）
    Button(lightbulb)        // 提示 — 44pt
}
.padding(.horizontal, 12)
```

三个按钮 `spacing: 0`，紧密排列。`plus.circle`（新开一局）和 `arrow.uturn.backward`（悔棋）功能相反但相邻，极易误触。

### 影响范围：iOS（macOS 有文字 Label + spacing: 12，无此问题）

### 修复方案

**方案：重新布局 iOS 顶部工具栏，分散高风险按钮**

**修改文件**：`ToolbarView.swift`

```swift
#if os(iOS)
HStack {
    // 左侧：悔棋 + 提示（对局进行中的操作）
    HStack(spacing: 8) {
        Button(uturn.backward) { viewModel.undoMove() }   // 悔棋
        Button(lightbulb) { viewModel.requestHint() }      // 提示
    }

    Spacer()

    // 右侧：新开一局（高风险操作，远离悔棋）
    Button(plus.circle) { viewModel.newGame() }
}
.padding(.horizontal, 16)
.padding(.vertical, 4)
#endif
```

设计理由：
- **悔棋 + 提示**是「对局辅助」操作，逻辑上归为一组
- **新开一局**是破坏性操作，单独放右侧，避免与悔棋混淆
- 用 `Spacer` 拉开距离，彻底消除误触风险
- 与 iOS `ChineseChessiOSApp` 底部 toolbar 布局风格保持一致（操作分左右两侧）

### 验证点
- 三个按钮间距明显增大，无误触风险
- 新开一局在右侧，悔棋/提示在左侧
- 按钮功能不变，图标不变

---

## Bug 5: 级别选完后显示不够明显

### 根因确认

**类型：样式不足**

`StatusBarView.swift` 中的难度标签：

```swift
Text(viewModel.difficulty.displayName)
    .font(.caption2)                          // ~11pt，太小
    .foregroundColor(.white.opacity(0.9))
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Color.brown.opacity(0.3))     // 透明度低，对比度不足
    .cornerRadius(4)
```

问题：字号太小（caption2 ≈ 11pt），背景对比度低（opacity 0.3），视觉上几乎与环境融为一体。

### 影响范围：通用（iOS + macOS），但 iOS 更明显（无 Toolbar 难度 Picker）

### 修复方案

**修改文件**：`StatusBarView.swift`

```swift
// 难度标签 — 增强可见性
HStack(spacing: 3) {
    Image(systemName: "square.stack.3d.up.fill")
        .font(.caption2)
    Text(viewModel.difficulty.displayName)
        .font(.caption.weight(.semibold))       // caption2 → caption + semibold
}
.foregroundColor(.yellow)                        // white → yellow，更醒目
.padding(.horizontal, 8)                         // 6 → 8
.padding(.vertical, 3)                           // 2 → 3
.background(
    Color.brown.opacity(0.6)                     // 0.3 → 0.6
)
.cornerRadius(6)                                 // 4 → 6，圆角稍大
.overlay(
    RoundedRectangle(cornerRadius: 6)
        .stroke(Color.yellow.opacity(0.3), lineWidth: 0.5)  // 新增描边
)
```

改动要点：
1. **字号**：`caption2` → `caption`（≈13pt），加 `semibold`
2. **颜色**：文字 `white` → `yellow`，在深色背景上更醒目
3. **背景**：`brown.opacity(0.3)` → `0.6`，增强对比
4. **图标**：新增难度图标，视觉锚点
5. **描边**：新增黄色描边，进一步强化层次

### 验证点
- 难度标签在深色背景上一眼可见
- 不破坏 StatusBarView 的整体布局
- macOS 端同样生效

---

## Bug 6: 通关后的残局在哪里查看

### 根因确认

**类型：功能缺失**

`PuzzleSelectView` 当前有分类筛选 + 难度筛选，但**没有通关状态筛选**。

排序逻辑：`未完成排前面`，已通关的排在后面。已通关的有绿色 ✓ 和星级标记。但用户没有快速入口查看已通关列表。

### 影响范围：通用

### 修复方案

**方案：在难度筛选栏旁增加通关状态筛选 + 筛选感知排序**（P2-3 补充排序规则）

**修改文件**：`PuzzleSelectView.swift`、`Localizable.xcstrings`

1. 新增状态变量和枚举：

```swift
@State private var completionFilter: CompletionFilter = .all

enum CompletionFilter: String, CaseIterable {
    case all, completed, uncompleted
}
```

2. 在难度筛选栏下方增加 segmented 筛选：

```swift
Picker("", selection: $completionFilter) {
    Text(l10n.t("puzzle.all")).tag(CompletionFilter.all)
    Text(l10n.t("puzzle.filterUncompleted")).tag(CompletionFilter.uncompleted)
    Text(l10n.t("puzzle.filterCompleted")).tag(CompletionFilter.completed)
}
.pickerStyle(.segmented)
```

3. 在 `filteredPuzzles` 中增加筛选条件：

```swift
switch completionFilter {
case .all: break
case .completed: result = result.filter { progress[$0.id]?.isCompleted == true }
case .uncompleted: result = result.filter { progress[$0.id]?.isCompleted != true }
}
```

4. **筛选感知排序**（P2-3 修复）：

```swift
result.sort { a, b in
    let aDone = progress[a.id]?.isCompleted == true
    let bDone = progress[b.id]?.isCompleted == true
    switch completionFilter {
    case .completed:
        // 已通关列表：按完成时间降序（最近通关的排前面）
        let aDate = progress[a.id]?.completedAt ?? .distantPast
        let bDate = progress[b.id]?.completedAt ?? .distantPast
        return aDate > bDate
    case .uncompleted, .all:
        // 未通关/全部：未完成排前面，再按 id 排序
        if aDone != bDone { return !aDone }
        return a.id < b.id
    }
}
```

5. 新增本地化字符串：
   - `puzzle.filterCompleted`: "已通关" / "Completed"
   - `puzzle.filterUncompleted`: "未通关" / "Uncompleted"

### 验证点
- 筛选切换实时生效
- 已通关列表按完成时间排序（最近通关排前面）
- 未通关列表按 id 排序
- 与分类、难度筛选可叠加使用
- 空列表时显示空状态提示

---

## Bug 7: 棋谱记录格式太难看

### 根因确认

**类型：设计不足**

`RecordPanelView.moveRow()` 当前格式：每步一行，红黑方交替排列：

```
1. 炮二平五+
1. 馬8进7
2. 馬二进三
2. 軍9平8
```

问题：
1. **回合同号**：红黑同一回合都显示 `1.`，视觉冗余
2. **一行一步**：标准棋谱是红黑同一行（`1. 炮二平五 馬8进7`），节省空间
3. **字号偏小**：13pt 在 iOS 上不够清晰
4. **行间距紧**：spacing: 2 太紧凑
5. **红黑区分弱**：仅颜色不同，缺乏结构化区分

### 影响范围：通用（RecordPanelView 在对弈和残局中均使用）

### 修复方案

**方案：红黑同一行 + 增大字号 + 优化间距 + 安全 ForEach**（修复 P1-2, P1-3）

**修改文件**：`RecordPanelView.swift`

1. 回合配对方法（首手感知 + P1-2 黑方先手处理）：

```swift
/// 回合对
struct MovePair: Identifiable {
    let id: UUID                    // 使用第一个 GameMove 的 UUID 作为稳定 id（P1-3 修复）
    let roundNumber: Int
    let first: GameMove             // 先手方走法
    let second: GameMove?           // 后手方走法
    let firstSide: Side             // 先手方颜色
}

private func pairMoves(_ moves: [GameMove]) -> [MovePair] {
    guard !moves.isEmpty else { return [] }
    let firstSide = moves[0].piece.side  // 检测首手方
    var pairs: [MovePair] = []
    var i = 0
    var roundNum = 1
    while i < moves.count {
        let first = moves[i]
        let second = (i + 1 < moves.count) ? moves[i + 1] : nil
        pairs.append(MovePair(
            id: first.id,           // 稳定 id，SwiftUI diff 安全（P1-3 修复）
            roundNumber: roundNum,
            first: first,
            second: second,
            firstSide: firstSide
        ))
        i += 2
        roundNum += 1
    }
    return pairs
}
```

2. 回合行视图（P1-2：黑方先手时用「……」前缀）：

```swift
@ViewBuilder
private func roundRow(_ pair: MovePair) -> some View {
    HStack(spacing: 8) {
        // 回合号
        Text("\(pair.roundNumber).")
            .font(.footnote.monospaced())
            .foregroundColor(.secondary)
            .frame(width: 28, alignment: .trailing)

        // 先手方走法
        // 如果先手是黑方，按中文棋谱惯例加「……」前缀
        if pair.firstSide == .black {
            Text("……")
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 20)
        }

        moveText(pair.first)

        Spacer().frame(width: 12)

        // 后手方走法（如有）
        if let second = pair.second {
            moveText(second)
        }
    }
    .padding(.vertical, 3)  // 2 → 3，增大行间距
}

@ViewBuilder
private func moveText(_ gm: GameMove) -> some View {
    Text(gm.notation)
        .font(.custom(FontRegistry.bestAvailableFontName, size: 14))  // 13 → 14
        .foregroundColor(gm.piece.side == .red ? .red : .white)
        + Text(gm.isCheckmate ? " #" : (gm.isCheck ? " +" : ""))
            .font(.footnote.weight(.bold))
            .foregroundColor(.yellow)
}
```

3. 主列表渲染（P1-3：稳定 id）：

```swift
// 修改前：ForEach(gameMoves) { gm in moveRow(gm).id(gm.id) }
// 修改后：
let pairs = pairMoves(gameMoves)
ForEach(pairs) { pair in
    roundRow(pair)
}
// ForEach 使用 MovePair.id（基于 GameMove.id），SwiftUI diff 安全
```

### 验证点
- 标准棋谱格式：`1. 炮二平五  馬8进7`（红方先手）
- 黑方先手：`1. …… 馬8进7  炮二平五`（P1-2 修复）
- 字号 14pt 清晰可读
- ForEach 使用稳定 id，悔棋/重走无渲染异常（P1-3 修复）
- 将军/将杀标记位置正确
- 奇数步（最后一回合单步）正确处理

**P2-6 补充：`MovePair.id` 删除动画取舍说明**

当前设计使用 `first.id` 作为 pair 的 id。悔掉第二手时：
- pair 内容从 `(A, B)` 变成 `(A, nil)`
- id 不变（仍为 `A.id`），SwiftUI 认为是同一个 item
- 视觉效果：item 内部内容变化，无滑动删除动画

**取舍决策**：接受现状。原因：
1. 残局/对弈场景中，悔棋是用户主动操作，用户知道发生了什么，“内容消失”动画足够清晰
2. 如果需要删除动画，需用复合 id（如 `"\(first.id)-\(roundNumber)"`），但这会增加复杂度，收益不明显
3. 添加新步时动画正常（新增 pair 有新 id）

方案已明确此取舍，Cody 实现时无需额外处理。

---

## 文件修改清单汇总

| 文件 | Bug | 改动类型 |
|------|-----|----------|
| `ViewModels/PuzzleViewModel.swift` | #1, #2 | 重写 showHint 索引逻辑 + 新增 getSolutionInfo（合并推演） + handleWrongMove 用 solutionStepIndex |
| `Views/ReplayBoardView.swift` | #3 | iOS maxBoardHeight 675→850 |
| `Views/ReplayView.swift` | #3 | 合并对局信息栏到标题栏 |
| `Views/ReplayControlView.swift` | #3 | iOS 精简布局，合并步数行 |
| `Views/ToolbarView.swift` | #4 | iOS 工具栏重新布局 |
| `Views/StatusBarView.swift` | #5 | 难度标签样式增强 |
| `Views/PuzzleSelectView.swift` | #6 | 新增通关状态筛选 + 筛选感知排序 |
| `Views/RecordPanelView.swift` | #7 | 棋谱红黑配行（MovePair 结构体）+ 字号14 + 首手感知 |
| `Resources/Localizable.xcstrings` | #6 | 新增 2 条本地化字符串（已通关/未通关） |

## 修复分期建议

### 第一批（P0，4 个）
Bug 1 → Bug 2 → Bug 4 → Bug 3

Bug 1 和 Bug 2 修改同一个文件（PuzzleViewModel），应一起提交。
Bug 4 改动最简单，独立提交。
Bug 3 涉及 3 个文件，最后处理。

### 第二批（P1，3 个）
Bug 5 → Bug 7 → Bug 6

Bug 5 和 Bug 7 都是样式优化，互不影响。
Bug 6 涉及本地化字符串更新，放最后。

## 关键测试用例（P2-4 补充）

### Bug 1 + Bug 2 联合测试

| # | 场景 | 输入 | 预期结果 |
|---|------|------|----------|
| T1 | 开局直接点提示 | 新残局，点击提示 | 文字 + 蓝色高亮，显示中文棋谱（如「炮二平五」） |
| T2 | 走 2 步后点提示 | 玩家走对 1 步 + AI 应对后点击提示 | 文字 + 蓝色高亮，显示 solution[2] 对应的中文棋谱 |
| T3 | 连续点提示 3 次 | 新残局，连续点击 | 依次显示 solution[0]→[1]→[2]，全部有高亮和中文棋谱 |
| T4 | 走错后回退再点提示 | guided 走错→自动回退→点提示 | 从当前 solutionStepIndex 开始，有高亮 |
| T5 | freePlay 模式走任意步后点提示 | freePlay 走 3 步后点击 | 从 gameMoves.count 基线开始提示 |
| T6 | 超出 solution 长度 | 连续点击直到超出 | 显示「暂无更多提示」 |

### Bug 7 配对测试

| # | 场景 | 输入 | 预期结果 |
|---|------|------|----------|
| T7 | 标准红方先手，偶数步 | 4 步棋 | 2 行：`1. 红A 黑B` `2. 红C 黑D` |
| T8 | 标准红方先手，奇数步 | 3 步棋 | 2 行：`1. 红A 黑B` `2. 红C`（第二行只有先手方） |
| T9 | 黑方先手（残局执黑） | 3 步棋，首手黑方 | 2 行：`1. …… 黑A 红B` `2. …… 黑C` |
| T10 | 悔棋后重走 | 走 2 步→悔棋→重走 2 步 | 无渲染异常，回合号正确 |

### Bug 6 筛选测试

| # | 场景 | 操作 | 预期结果 |
|---|------|------|----------|
| T11 | 筛选已通关 | 通关 3 个残局后筛选 | 列表只显示 3 个，按完成时间降序 |
| T12 | 筛选未通关 | 同上 | 列表排除这 3 个 |
| T13 | 筛选 + 分类叠加 | 选分类「车马炮类」+ 已通关 | 该分类下的已通关残局 |
| T14 | 空列表 | 无通关残局时选已通关 | 显示空状态提示 |

## 风险提示

1. **Bug 1 修复**引入 `getSolutionPosition(at:)` 和 `notationFromICCS(at:)` 两个方法都做完整棋盘推演（O(n)），solution 平均长度 12 步，性能不是问题。但如果未来 solution 长度超过 100，可考虑缓存推演结果。

2. **Bug 3 修复**将 `maxBoardHeight` 提升到 850。iPad Pro 12.9" 横屏（1366×1024pt）实测：可用高度 ≈ 1024 - 标题栏(36) - 控制栏(120) = 868pt > 850，棋盘高度被限制在 850，cellSize ≈ 850/9 ≈ 94pt，合理。

3. **Bug 7 修复**的 `MovePair.id` 使用第一个 GameMove 的 UUID。悔棋时 `gameMoves.removeLast()` 会移除该 id，SwiftUI ForEach 正确处理删除动画。

4. **本地化字符串**（Bug 6）修改 `Localizable.xcstrings` 后，需执行 `swift build` 让 SPM 重新生成 bundle，打包时注意手动复制 xcstrings 文件（见 known-issues.md）。

5. **Bug 2 的 `handleWrongMove`** 中 `notationFromICCS(_:at:)` 的 step 参数需要正确传入当前玩家步序号。走错时 board 尚未回退，需用 `solutionStepIndex` 或从 gameMoves 推算，Cody 实现时注意边界条件。
