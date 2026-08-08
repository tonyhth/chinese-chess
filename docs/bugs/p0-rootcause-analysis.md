# P0 问题根因分析报告

> **架构师**: Alex  
> **日期**: 2026-01-24  
> **范围**: 洪涛上报的 5 个 P0 问题  
> **项目**: chinese-chess v5.x

---

## P0-1：开局教练不工作，点击无法进入

### 1. 现象描述

用户在学棋中心点击「开局教练」→ 进入 `OpeningCoachSelectView` → 选择开局线路 → 点击「开始练习」按钮 → **无法跳转到 `CoachGameView`**。

### 2. 根因分析

**文件**: `Views/OpeningCoachSelectView.swift`

**根因**: `NavigationLink` 使用 `isActive` 绑定的方式放在 `.background()` 修饰符中，配合 `EmptyView()` + `.hidden()`。这是 SwiftUI 社区常见的「programmatic navigation」技巧，但在 **iOS 16+ / macOS 13+ 的 `NavigationStack` 环境下失效**。

具体代码（OpeningCoachSelectView.swift）:

```swift
// iOS Layout（约第 81-93 行）
.background(
    NavigationLink(
        destination: CoachGameView(...),
        isActive: $navigateToGame
    ) {
        EmptyView()
    }
    .hidden()
)
```

```swift
// macOS Layout（约第 49-65 行）
.background(
    NavigationLink(
        destination: CoachGameView(...),
        isActive: $navigateToGame
    ) {
        EmptyView()
    }
    .hidden()
)
```

**问题链条**:

1. `StudyHubView` 用 `NavigationLink(destination:)` 推入 `OpeningCoachSelectView`（StudyHubView.swift 第 98-103 行 / 第 135-140 行）。这是在父级的 `NavigationStack` 中推入。
2. `OpeningCoachSelectView` 的「开始练习」按钮设置 `navigateToGame = true`（第 186 行）。
3. `NavigationLink(... isActive: $navigateToGame)` 被放在 `.background()` + `.hidden()` 中。
4. **在 `NavigationStack` 环境下，`isActive`-based `NavigationLink` 已被弃用且行为不稳定**。SwiftUI 在 iOS 16+ / macOS 13+ 推荐使用 `navigationDestination(isPresented:)`。

**额外问题**: macOS 端使用 `HSplitView`，用户在左侧 `List(selection:)` 中选择 category → 右侧 `subcategoryList` 中通过 `List(selection: $selectedSubcategory)` 选择子分类。但点击「开始练习」时检查的是 `selectedSubcategory != nil`——如果用户只在右侧 List 选中了 subcategory，按钮可点击，但 `NavigationLink` 不触发跳转。

### 3. 修复方案

**将 `NavigationLink(isActive:)` 替换为 `navigationDestination(isPresented:)`**:

```swift
// iOS Layout
.navigationDestination(isPresented: $navigateToGame) {
    CoachGameView(
        subcategory: selectedSubcategory ?? OpeningSubcategory(id: "_", name: "", firstMoves: [], gameCount: 0),
        playerSide: playerSide,
        difficulty: difficulty,
        onBack: { navigateToGame = false }
    )
}
```

macOS Layout 同理，放在 `HSplitView` 的 `VStack` 上。

**注意**: `navigationDestination` 必须直接修饰在 `NavigationStack` 内的内容视图上，不是 `.background()`。

### 4. 影响范围

- **文件**: `Views/OpeningCoachSelectView.swift`（iOS + macOS 两处 `.background(NavigationLink...)`）
- **功能**: 开局教练功能完全不可用
- **回归风险**: 低。只改导航机制，不改业务逻辑（`selectedSubcategory`、`playerSide`、`difficulty` 等状态不变）
- **双端**: iOS 和 macOS 都受影响，两处都需修复

### 5. 验证方法

1. iOS：StudyHub → 开局教练 → 选开局 → 选线路 → 点「开始练习」→ 应进入 CoachGameView
2. macOS：同上流程
3. CoachGameView 内「退出」→ 应回到 OpeningCoachSelectView
4. 选不同难度/执黑执红 → 重新进入 CoachGameView → 配置应正确传递

---

## P0-4：iOS 大师棋谱按开局→中炮→子分类无法进入

### 1. 现象描述

iOS 端：大师棋谱 → 浏览模式「按开局」→ 点击「中炮」（有子分类）→ 进入子分类列表 → 点击「中炮对屏风马」→ **列表不显示对局**。

### 2. 根因分析

**文件**: `Views/MasterGameBrowserView.swift`

**根因**: `iosSubcategoryList` 中点击子分类时设置了 `selectedSubcategory` 和 `selectedOpening = nil`，但 **`showSubcategoryList = false` 后的视图渲染逻辑缺少对 `selectedSubcategory` 的处理**。

具体代码分析:

**iosSubcategoryList 中的子分类点击（约第 344-352 行）**:
```swift
ForEach(parent.subcategories) { sub in
    Button(action: {
        selectedSubcategory = sub
        selectedOpening = nil      // ← 清空了 opening
        showSubcategoryList = false // ← 退回分类列表
    }) { ... }
}
```

**browserLayout 的 iOS 分支（约第 125-141 行）**:
```swift
if browseMode == .opening && selectedOpening == nil && !showSubcategoryList {
    iosCategoryList          // ← 一级分类
} else if browseMode == .opening && showSubcategoryList {
    iosSubcategoryList       // ← 子分类列表
} else if browseMode == .player ... {
    ...
} else {
    VStack(spacing: 0) {
        iosBackBar
        listContent            // ← 对局列表
    }
}
```

**条件判断链条**:
1. 点击子分类后：`selectedSubcategory = sub`, `selectedOpening = nil`, `showSubcategoryList = false`
2. 渲染时检查：`selectedOpening == nil && !showSubcategoryList` → **true** → 显示 `iosCategoryList`（一级分类！）
3. 虽然设置了 `selectedSubcategory`，但由于 `selectedOpening == nil && !showSubcategoryList` 先命中，直接回到一级分类列表。

**根因总结**: `browserLayout` 的 iOS 条件分支中，没有判断 `selectedSubcategory != nil` 的情况。当 `selectedSubcategory` 被设置但 `selectedOpening` 为 nil 时，应该进入对局列表，但被第一个条件拦截回到了分类列表。

### 3. 修复方案

**修改 `browserLayout` 的 iOS 条件分支**:

```swift
// 修改前
if browseMode == .opening && selectedOpening == nil && !showSubcategoryList {
    iosCategoryList
}

// 修改后：增加 selectedSubcategory 判断
if browseMode == .opening 
    && selectedOpening == nil 
    && selectedSubcategory == nil    // ← 新增
    && !showSubcategoryList {
    iosCategoryList
}
```

这样当 `selectedSubcategory != nil` 时，不会命中 `iosCategoryList`，而是走到最后的 `else` 分支 → `listContent` → `rebuildCache()`。

**或者**（更清晰的方案）：在 `iosSubcategoryList` 的点击 action 中**不清空 `selectedOpening`**，而是保持 `subcategoryParent`：

```swift
Button(action: {
    selectedSubcategory = sub
    // 不清空 selectedOpening，而是设置为 parent（用于 backBar 显示）
    selectedOpening = subcategoryParent  
    showSubcategoryList = false
}) { ... }
```

**推荐方案一**（增加 selectedSubcategory 判断），因为改动更小、更不容易引入回归。

### 4. 影响范围

- **文件**: `Views/MasterGameBrowserView.swift`（`browserLayout` iOS 分支条件判断）
- **功能**: iOS 端大师棋谱「按开局 → 有子分类的开局」完全不可用
- **回归风险**: 低。只改条件判断逻辑
- **macOS**: 不受影响（macOS 走另一套 `listContent` 分支）

### 5. 验证方法

1. iOS：大师棋谱 → 按开局 → 点「中炮」→ 进入子分类 → 点「中炮对屏风马」→ 应显示对局列表
2. 点「全部」选项 → 应显示中炮全部对局
3. 从对局列表返回 → 应回到子分类列表
4. 从子分类列表返回 → 应回到一级分类列表
5. macOS：验证按开局 → 中炮 → 子分类过滤栏 → 列表（不受影响）

---

## P0-5：复盘分析没看到分析内容，评估曲线没有变化

### 1. 现象描述

对弈结束后打开复盘分析 → **看不到分析内容**，评估曲线没有变化（空白或无数据）。

### 2. 根因分析

这个问题有 **两个叠加的原因**，需要分别分析：

#### 原因 A：段位门禁阻止显示（高概率）

**文件**: `Views/AnalysisView.swift`（第 26-29 行）

```swift
private var hasBasicAnalysis: Bool {
    profile.isFeatureUnlocked(.openingTreeBrowse)  // 需要 rank >= .scholar（秀才）
}
```

```swift
var body: some View {
    VStack(spacing: 0) {
        headerBar
        if !hasBasicAnalysis {
            lockedView   // ← 如果段位不够，直接显示锁定页
        } else {
            // 棋盘 + 分析 + 曲线
        }
    }
    .task {
        if hasBasicAnalysis {
            await startAnalysis()  // ← 段位不够时不会执行
        }
    }
}
```

**`UnlockedFeature.openingTreeBrowse` 的 `requiredRank` = `.scholar`（秀才）**，新用户 `rank = .student`（学童），**无法使用分析功能**。

但注意：`.openingTreeBrowse` 的语义是「开局树浏览」，用它来门禁「复盘分析」**语义不匹配**。实际应该用 `.engineAnalysis`（`requiredRank = .hanlin` 翰林）。

但代码中 `hasExpertAnalysis` 才用 `.engineAnalysis`，而 `hasBasicAnalysis` 用的是 `.openingTreeBrowse`。这意味着：
- 学童/秀才以下 → 完全锁定
- 秀才以上 → 看到 `lockedView`（实际不应该）
- 翰林以上 → 能看到评估曲线

**结论**: 如果洪涛的段位低于秀才，看到的是 `lockedView`——但洪涛说「没看到分析内容，评估曲线没有变化」，这暗示他**进入了分析页面但内容为空**，说明 `hasBasicAnalysis` 通过了（段位 ≥ 秀才），但分析本身没产出结果。

#### 原因 B：引擎未正确初始化或分析结果为空

**文件**: `ViewModels/AnalysisViewModel.swift`（第 79-97 行）

```swift
func analyzeAll() async {
    guard !moves.isEmpty else { return }
    
    let engine = await EngineRouter.shared.switchEngineIfNeeded()
    if engine as? EmbeddedPikafishEngine == nil {
        analysisUnavailableMessage = L10n.shared.t("analysis.engineUnavailable")
        isAnalyzing = false
        return
    }
    
    // ... 逐步分析
    for (index, move) in moves.enumerated() {
        guard isPlayerMove(at: index) else { continue }
        // ...
        let analysis = await PositionAnalyzer.shared.analyzeMove(...)
        analyses[index] = analysis
    }
    
    // Bug 1 fix: 全 nil 时设置不可用
    if analyses.allSatisfy({ $0 == nil }) {
        analysisUnavailableMessage = L10n.shared.t("analysis.engineUnavailable")
    }
}
```

**可能的失败路径**:

1. **`PositionAnalyzer.getEngine()` 返回 nil**（PositionAnalyzer.swift 第 30-46 行）：
   - `EngineConfigStore.shared.useEmbeddedEngine` 为 false → 返回 nil
   - `switchEngineIfNeeded()` fallback 到 native engine → `embedded.isReady` 为 false → 返回 nil
   
2. **`EngineRouter.switchEngineIfNeeded()` 启动失败**（EngineRouter.swift 第 33-48 行）：
   - `pikafish_init()` 失败（NNUE 文件未找到）→ fallback 到 nativeEngine
   - `engine as? EmbeddedPikafishEngine == nil` → `analysisUnavailableMessage` 被设置

3. **NNUE 文件未正确打包**（EmbeddedPikafishEngine.swift 第 38-50 行有诊断日志）：
   - iOS 端 `Bundle.main.url(forResource: "pikafish", withExtension: "nnue")` 可能返回 nil

**关键发现**: AnalysisView 的 `analysisControls` 部分有显示 `analysisUnavailableMessage`（第 97-108 行），但 **`analysisUnavailableMessage` 被 `hasBasicAnalysis` 的 `lockedView` 挡住了**——如果段位不够，用户根本看不到引擎不可用的错误提示。

**最终根因判定**: 

- **如果段位 < 秀才**：`lockedView` 显示，看不到任何分析 → 但用户描述是"没看到分析内容"，更像是能进入但内容空
- **如果段位 ≥ 秀才但引擎不可用**：进入分析页面 → `analyzeAll()` 中引擎检查失败 → `analysisUnavailableMessage` 设置 → UI 显示错误提示 + 重试按钮 → 但如果 `PositionAnalyzer.getEngine()` 的 `useEmbeddedEngine` 检查路径和 `AnalysisViewModel.analyzeAll()` 的检查路径**不一致**，可能导致 `analyzeAll` 通过了引擎检查但 `PositionAnalyzer.analyzeMove` 内部失败

**根因 B 更精确**: `AnalysisViewModel.analyzeAll()` 检查的是 `EngineRouter.shared.switchEngineIfNeeded()` 返回值是否为 `EmbeddedPikafishEngine`。但 `PositionAnalyzer.analyzeMove()` 内部调用的是自己的 `getEngine()`，它额外检查了 `EngineConfigStore.shared.useEmbeddedEngine` 和 `embedded.isReady`。

存在一种竞态：`analyzeAll()` 中 `switchEngineIfNeeded()` 成功返回了 `EmbeddedPikafishEngine`（引擎类型检查通过），但 `PositionAnalyzer.getEngine()` 中 `embedded.isReady` 此时为 false（比如在后台被 shutdown 或初始化不完整），返回 nil → 所有 `analyzeMove` 返回 nil → `analyses` 全 nil → `analysisUnavailableMessage` 设置。

### 3. 修复方案

**修复 1（必须）：UI 层面 — 确保 `analysisUnavailableMessage` 可见**

在 AnalysisView 中，`analysisControls` 已有显示逻辑（第 97-108 行），确保这段代码在 `hasBasicAnalysis == true` 时正确渲染。当前代码结构已经是这样的，所以如果用户能看到分析页面（段位够），错误信息应该能显示。

**修复 2（必须）：确保引擎一致性 — `PositionAnalyzer.getEngine()` 应复用 `EngineRouter` 的判断**

```swift
// PositionAnalyzer.swift 当前代码
private func getEngine() async -> EmbeddedPikafishEngine? {
    let useEmbedded = await MainActor.run {
        EngineConfigStore.shared.useEmbeddedEngine
    }
    guard useEmbedded else { return nil }
    
    let engine = await EngineRouter.shared.switchEngineIfNeeded()
    if let embedded = engine as? EmbeddedPikafishEngine, embedded.isReady {
        return embedded
    }
    return nil
}
```

**问题**: `useEmbeddedEngine` 检查是正确的，但如果 `switchEngineIfNeeded()` 内部启动失败已经 fallback 到 nativeEngine，返回的不是 `EmbeddedPikafishEngine` → 正确返回 nil。

实际上逻辑是正确的，但**引擎可能真的没启动成功**。需要确认 NNUE 文件是否正确打包。

**修复 3（关键）：对 `analyses` 全 nil 的情况，除了设置 `analysisUnavailableMessage`，还应在评估曲线区域显示对应提示**

当前 `evalChart` 在 `sequence.isEmpty` 时显示 "分析中..." 文本，但分析完成且全 nil 时 `evalSequence` 也是空 → 显示 "分析中..." 而不是错误提示。应该区分「正在分析」和「分析失败」。

```swift
// AnalysisView.swift evalChart
if sequence.isEmpty {
    if let msg = analysisVM.analysisUnavailableMessage {
        Text(msg).font(.caption).foregroundColor(.orange)
    } else {
        Text(l10n.t("analysis.analyzing"))...
    }
}
```

### 4. 影响范围

- **文件**: 
  - `Views/AnalysisView.swift`（UI 显示逻辑）
  - `ViewModels/AnalysisViewModel.swift`（分析状态管理）
  - `AI/PositionAnalyzer.swift`（引擎获取）
  - `AI/EngineRouter.swift`（引擎生命周期）
  - `AI/EmbeddedPikafishEngine.swift`（NNUE 加载）
- **功能**: 复盘分析完全不可用或显示不正确
- **回归风险**: 中。引擎初始化路径多，需要仔细验证
- **双端**: iOS 和 macOS 都可能受影响。iOS 的 NNUE 打包问题需特别关注

### 5. 验证方法

1. macOS：打开复盘分析 → 检查 Console.app 中是否有 `[Pikafish]` 相关错误日志
2. iOS：打开复盘分析 → 检查是否显示「引擎不可用」提示 + 重试按钮
3. 确认 `EngineConfigStore.shared.useEmbeddedEngine` 为 true
4. 确认 `pikafish.nnue` 文件在 App Bundle Resources 中
5. 检查段位：如果 `rank < .scholar`，分析页面应显示 `lockedView`
6. 对弈一局后复盘 → 分析应逐步显示走法质量 → 评估曲线应有波动

---

## P0-7：AI 点击详解没有反应，且并没有随着每一步有说明

### 1. 现象描述

用户在复盘界面（`ReplayView`）点击「分析」或「教练」按钮 → **没有反应**。另外在演示播放中，**每一步没有说明**。

### 2. 根因分析

需要区分两个场景：

#### 场景 A：ReplayView 中的分析/教练按钮

**文件**: `Views/ReplayView.swift`

分析按钮（第 119-126 行）:
```swift
private var analysisButton: some View {
    Button {
        showAnalysis = true
    } label: {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .foregroundColor(.white)
    }
    .disabled(viewModel.record.moves.isEmpty)
}
```

教练按钮（第 130-137 行）:
```swift
private var coachButton: some View {
    Button {
        showCoach = true
    } label: {
        Image(systemName: "graduationcap.fill")
            .foregroundColor(.white)
    }
    .disabled(viewModel.record.moves.isEmpty)
}
```

这两个按钮**没有段位门禁**——它们只检查 `record.moves.isEmpty`。点击后会触发 `showAnalysis = true` / `showCoach = true`。

**但用户说"没有反应"**，可能的原因:

1. **`record.moves` 为空** → 按钮 disabled → 点击无反应。但如果用户刚下完一盘棋，`moves` 不应该为空。
2. **iOS 的 `.fullScreenCover` / `.sheet` 没有正确触发** → 可能是 SwiftUI bug，但代码看起来是标准的。
3. **用户说的「详解」不是这两个按钮，而是 DemoViewModel 的点评功能**。

#### 场景 B：大师棋谱/残局演示中的点评（更可能）

**用户说「AI 点击详解没有反应」+「每步没有说明」**——这更像是在描述大师棋谱演示（`DemoBoardView` + `DemoControlBar`）中的点评功能。

**文件**: `ViewModels/DemoViewModel.swift`

点评功能由 `showCommentary` 控制（第 68 行）:
```swift
var showCommentary: Bool = true
```

初始化时从 DemoConfig 读取（第 104 行）:
```swift
self.showCommentary = config.showCommentary
```

DemoConfig 默认值（DemoConfig.swift 第 8 行）:
```swift
var showCommentary: Bool = true
```

**点评触发路径**: `boardPlayer.onMoveExecutedHandler` → `handleMoveExecuted` → `updateCommentary`:

```swift
private func updateCommentary(for move: Move, moveIndex: Int) {
    guard showCommentary else { return }  // ← 如果 false，不生成点评
    
    // 1. 弃子点评（预计算）
    if let sacrificeItem = sacrificeCommentaries[moveIndex] {
        showCommentary(sacrificeItem)
        return
    }
    // 2. 规则推断（将军/将死/最后一步）
    if let item = CommentaryEngine.evaluate(move: move, on: board, moveIndex: moveIndex, totalMoves: moves.count) {
        showCommentary(item)
        return
    }
    // 3. 异步智能点评
    analyzeCurrentStep()
}
```

**根因 1 — 同步点评条件苛刻**: `CommentaryEngine.evaluate` 只在以下情况返回非 nil:
- 将军（`MoveValidator.isInCheck` 返回 true）
- 将死
- 最后一步（`moveIndex == totalMoves - 1`）

**绝大多数走法不是将军/将死/最后一步** → 同步点评返回 nil。

**根因 2 — 异步点评默认关闭**: 普通走法依赖 `analyzeCurrentStep()`（第 143 行），但它首先检查:

```swift
private func analyzeCurrentStep() {
    guard smartCommentaryEnabled else { return }  // ← 默认 false!
    // ...
}
```

**`smartCommentaryEnabled` 默认 false**（DemoConfig.swift 第 9 行）:
```swift
var smartCommentaryEnabled: Bool = false
```

**结论**: 大多数走法既不是将军/将死/最后一步，异步智能点评又默认关闭 → **每步没有说明**是预期行为，但对用户来说感觉"没工作"。

#### 用户期望 vs 实际行为

用户期望「每一步有说明」（类似棋谱讲解），但当前设计是：
- 同步点评：仅将军/将死/弃子/最后一步（约 5-10% 的走法）
- 异步点评（智能点评）：需要手动开启设置，默认关闭
- 开启智能点评需要引擎运行，且段位 ≥ 翰林（因为依赖 `PositionAnalyzer` → `EmbeddedPikafishEngine`）

### 3. 修复方案

**方案 1（推荐）：将 `smartCommentaryEnabled` 默认改为 true**

```swift
// DemoConfig.swift
var smartCommentaryEnabled: Bool = true  // 改为默认开启
```

**风险评估**: 
- 性能：每步触发引擎分析（depth=12, timeMs=800），在自动播放时每步间隔 0.33-2s。引擎分析 800ms 可能比播放间隔长，导致点评延迟。
- 需要确认 `MasterGameCommentator` 的节流逻辑（`isAnalyzing` guard）不会导致点评跳过太多。

**方案 2（保守）：保持 `smartCommentaryEnabled` 默认 false，但增加 UI 提示**

在 DemoControlBar 的设置按钮旁边，如果 `smartCommentaryEnabled == false` 且 `showCommentary == true`，显示一个小提示图标或文案：「开启智能点评获得每步讲解」。

**方案 3（折中）：降低异步点评门槛 + 增加轻量级点评**

不依赖引擎的轻量级点评：
- 吃子：检测 materialDelta，大子吃小子时有简短点评
- 攻击：检测下一步是否威胁对方大子
- 这些用规则推断，不依赖引擎，成本极低

**关于 ReplayView 的分析/教练按钮**:

如果确实是按钮不响应（而非用户描述偏差），需要检查:
- iOS 16+ 的 `.fullScreenCover` 是否在 `NavigationStack` 内使用时有 bug
- 是否需要 `.id()` 强制刷新

但根据代码分析，按钮逻辑标准，更可能是**用户描述的是演示播放中的点评**，不是复盘中的分析按钮。

### 4. 影响范围

- **文件**:
  - `Models/DemoConfig.swift`（默认值）
  - `ViewModels/DemoViewModel.swift`（点评逻辑）
  - `Helpers/CommentaryEngine.swift`（同步点评规则）
  - `AI/MasterGameCommentator.swift`（异步点评）
- **功能**: 大师棋谱/残局演示的用户体验
- **回归风险**: 如果改默认值为 true，需要验证引擎并发性能（自动播放 + 引擎分析）
- **双端**: iOS 和 macOS 都受影响

### 5. 验证方法

1. 开启智能点评（设置 → 智能点评 ON）→ 播放大师棋谱 → 每步应有点评气泡
2. 关闭智能点评 → 播放 → 仅将军/将死/最后一步有点评
3. 点评消失后播放应恢复（`pauseOnCommentary` 仅对将死/弃子暂停）
4. iOS 和 macOS 分别测试
5. ReplayView 的分析按钮：对弈后点击 → 应弹出 AnalysisView
6. ReplayView 的教练按钮：点击 → 应弹出 CoachSessionView（段位 ≥ 国手）

---

## P0-9：大师棋谱演示点评没有工作

### 1. 现象描述

大师棋谱播放时，**点评功能完全不起作用**——没有将军提示、没有弃子提示、没有最后一步关键走法提示。

### 2. 根因分析

**这个问题与 P0-7 有交集，但 P0-9 的问题更严重：连同步点评（将军/将死）都不工作。**

**文件**: `ViewModels/DemoViewModel.swift` + `Helpers/CommentaryEngine.swift`

#### 检查同步点评为什么不工作

`handleMoveExecuted` → `updateCommentary`（DemoViewModel.swift 第 155-170 行）:

```swift
private func updateCommentary(for move: Move, moveIndex: Int) {
    guard showCommentary else { return }
    
    // 1. 弃子点评
    if let sacrificeItem = sacrificeCommentaries[moveIndex] {
        showCommentary(sacrificeItem)
        return
    }
    // 2. 规则推断
    if let item = CommentaryEngine.evaluate(move: move, on: board, moveIndex: moveIndex, totalMoves: moves.count) {
        showCommentary(item)
        return
    }
    // 3. 异步
    analyzeCurrentStep()
}
```

**关键**: `CommentaryEngine.evaluate(move:on:moveIndex:totalMoves:)` 需要检查**当前棋盘状态**（`board`）是否正确。

**`board` 的来源**: `DemoViewModel.board` 是从 `boardPlayer.board` 转发的（第 20 行）:
```swift
var board: Board { boardPlayer.board }
```

**`boardPlayer.onMoveExecutedHandler` 的调用时机**（DemoViewModel.swift 第 98-100 行）:
```swift
self.boardPlayer.onMoveExecutedHandler = { [weak self] move, moveIndex in
    self?.handleMoveExecuted(move: move, moveIndex: moveIndex)
}
```

**问题**: `onMoveExecutedHandler` 在 `BoardPlayer` 执行完 `move` **之后**调用，此时 `boardPlayer.board` 已经是执行后的棋盘。传给 `CommentaryEngine.evaluate` 的 `board` 参数就是这个执行后的棋盘。

**验证 `CommentaryEngine.evaluate` 的逻辑**（CommentaryEngine.swift 第 88-101 行）:
```swift
static func evaluate(move: Move, on board: Board, moveIndex: Int, totalMoves: Int) -> CommentaryItem? {
    let currentSide = board.currentTurn  // 下一步走棋方
    if MoveValidator.isInCheck(currentSide, on: board) {
        if MoveValidator.isCheckmate(currentSide, on: board) {
            return CommentaryItem(type: .checkmate(side: currentSide))
        }
        return CommentaryItem(type: .check(side: currentSide))
    }
    
    if moveIndex == totalMoves - 1 {
        return CommentaryItem(type: .keyMove)
    }
    return nil
}
```

**这段逻辑是正确的**：`board` 是执行后的棋盘，`board.currentTurn` 是下一步走棋方（被将军的一方），`isInCheck` 检查的是这一方是否被将军。

**那么为什么不工作？可能的原因**:

#### 原因 A: `showCommentary` 被意外设为 false

`DemoConfig.load()` 从 `UserDefaults` 读取。如果之前保存过 `showCommentary = false`，会持久化。用户可能不小心关闭了设置中的「显示点评」开关。

#### 原因 B: `onMoveExecutedHandler` 没有被调用

需要检查 `BoardPlayer` 是否正确调用了 `onMoveExecutedHandler`。这需要看 `BoardPlayer` 的实现。

#### 原因 C: `CommentaryOverlay` 视图渲染问题

`CommentaryOverlay` 只在 `iosPlayLayout` 中显示（MasterGameBrowserView.swift 第 472-475 行）:
```swift
if viewModel.showCommentary, let commentary = viewModel.currentCommentary {
    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
        .padding(.top, 8)
}
```

**macOS 的 `macosPlayLayout` 中没有 CommentaryOverlay！**（第 458-466 行）:
```swift
private func macosPlayLayout(viewModel vm: DemoViewModel) -> some View {
    VStack(spacing: 0) {
        DemoInfoBar(...)
        DemoBoardView(...)
        DemoControlBar(...)
    }
}
```

**macOS 端完全没有点评 UI！** 这不是一个 bug，而是一个遗漏——macOS 播放布局中缺少 `CommentaryOverlay`。

#### 原因 D: `sacrificeCommentaries` 预计算失败

如果 `DemoMoveConverter.convertGameMoves` 返回的 `moves` 为空或格式错误，`generateSacrificeCommentaries` 会返回空字典。但这不影响同步点评（将军/将死）。

#### 综合判定

**macOS 端根因**: `macosPlayLayout` 缺少 `CommentaryOverlay` → 点评气泡根本不渲染。

**iOS 端根因**: 需要进一步确认。如果 iOS 也不显示，可能是：
1. `showCommentary` 被设为 false（UserDefaults 持久化）
2. `BoardPlayer.onMoveExecutedHandler` 回调时机问题
3. `CommentaryEngine.evaluate` 的 `MoveValidator.isInCheck` / `isCheckmate` 在某些棋盘状态下的 edge case

### 3. 修复方案

**修复 1（macOS，必须）：在 `macosPlayLayout` 中添加 `CommentaryOverlay`**

```swift
private func macosPlayLayout(viewModel vm: DemoViewModel) -> some View {
    VStack(spacing: 0) {
        DemoInfoBar(...)
        
        ZStack(alignment: .top) {
            DemoBoardView(...)
            if vm.showCommentary, let commentary = vm.currentCommentary {
                CommentaryOverlay(commentary: commentary, speed: vm.speed)
                    .padding(.top, 8)
            }
        }
        .aspectRatio(...)
        
        DemoControlBar(...)
    }
}
```

**修复 2（iOS，排查步骤）：**

a. 确认 `DemoConfig.load().showCommentary` 为 true（让用户在设置中检查「显示点评」是否开启）
b. 在 `updateCommentary` 方法中添加日志，确认 `onMoveExecutedHandler` 是否被调用
c. 在 `CommentaryEngine.evaluate` 返回 nil 的分支添加日志

**修复 3（增强）：在设置中增加点评测试**

在 `DemoConfigSheet` / `DemoConfigPopover` 中增加一个「测试点评」按钮，手动触发一条测试点评，验证 UI 渲染是否正常。

### 4. 影响范围

- **文件**:
  - `Views/MasterGameBrowserView.swift`（`macosPlayLayout` 添加 CommentaryOverlay）
  - `ViewModels/DemoViewModel.swift`（排查日志）
  - `Helpers/CommentaryEngine.swift`（可能需要 edge case 修复）
- **功能**: 大师棋谱演示体验
- **回归风险**: 低（macOS 添加 overlay 不影响其他功能）
- **双端**: macOS 确定有 bug（CommentaryOverlay 缺失），iOS 需进一步确认

### 5. 验证方法

1. macOS：播放大师棋谱 → 到将军步 → 应显示「将军！」点评气泡
2. macOS：播放到最后一步 → 应显示「关键一步！」
3. iOS：确认设置中「显示点评」= ON → 播放 → 到将军步 → 应显示点评
4. iOS：开启「智能点评」→ 播放 → 普通步应有点评
5. 关闭「显示点评」→ 播放 → 无点评气泡
6. 残局演示同样验证

---

## 总结：5 个 P0 问题的优先级和修复建议

| 编号 | 问题 | 根因类型 | 修复难度 | 优先修复 |
|------|------|---------|---------|---------|
| P0-1 | 开局教练无法进入 | SwiftUI API 弃用 | 低（改导航 API） | ✅ 第一个 |
| P0-4 | iOS 子分类无法进入 | 条件分支逻辑遗漏 | 低（加一个判断） | ✅ 第二个 |
| P0-9 | 大师棋谱点评不工作 | macOS 缺少 UI + iOS 待查 | 中（macOS 易修，iOS 需查） | ✅ 第三个 |
| P0-5 | 复盘分析内容为空 | 引擎初始化 + UI 反馈 | 高（引擎链路长） | ⚠️ 需排查 |
| P0-7 | 详解/每步说明缺失 | 默认配置 + 设计 vs 期望 | 中（改默认值或加轻量点评） | ⚠️ 需讨论 |

### 共性问题

1. **SwiftUI NavigationStack 迁移不完整**: `NavigationLink(isActive:)` 在新导航栈下不稳定（P0-1）
2. **条件分支覆盖不完整**: iOS 视图切换逻辑缺少对 `selectedSubcategory` 状态的判断（P0-4）
3. **引擎可用性反馈链路断裂**: 引擎初始化失败 → 分析结果为空 → UI 反馈不准确（P0-5）
4. **macOS/iOS 功能不对称**: macOS 播放布局缺少 CommentaryOverlay（P0-9）
5. **默认配置与用户期望偏差**: `smartCommentaryEnabled` 默认 false，但用户期望每步有说明（P0-7）
