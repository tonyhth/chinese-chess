# D3 操作性/UX 审计报告

## 审计范围

- `src/ChineseChess/Views/` — BoardView, ChessBoardView, SettingsView, ReplayView, PuzzleSelectView, DailyChallengeView, BoardSizing, PieceView, ReplayControlView, ReplayBoardView, GameOverOverlay, StatusBarView, ToolbarView, RecordPanelView, StatsPanelView, GameHistoryView, ThemePickerView, ChapterSelectView, AchievementView, AnalysisView, CoachModeOverlay, CoachSessionView, OpeningExplorerView, ChessClockView, ImportResultSheet, SourceBadgeView, RankUpView, RankPrivilegeView, PrivacyPolicyView, Tutorial/TutorialView
- `src/ChineseChess/Services/` — SoundEngine, ResourceBundle, StatsManager

## 发现的问题（按严重度 P0-P3 分级）

### P0 — 严重功能性缺陷

#### P0-1: OpeningExplorerView 棋盘预览完全空白
**文件**: `OpeningExplorerView.swift` → `boardPreview`

`boardPreview` 区域只渲染了标题文字、走法路径文字和收藏按钮，**没有放置任何棋盘组件**。`board` 状态变量虽有更新，但从未被用于渲染。用户打开开局探索器后看到的是一块空白区域，核心功能形同虚设。

**影响**: 开局探索功能不可用，用户无法可视化走法路径。

---

#### P0-2: OpeningExplorerView selectNode 路径推演逻辑错误
**文件**: `OpeningExplorerView.swift` → `selectNode(_:)`

```swift
func walkPath(_ n: OpeningTreeNode) {
    if !n.move.isEmpty {
        moveHistory.append(n.moveName)
        if let m = UCIMoveConverter.move(from: n.move, on: current) {
            current.execute(m)
        }
    }
    for child in n.children {
        walkPath(child)   // ← 递归遍历所有后代节点
    }
}
```

`walkPath` 递归遍历选中节点的**全部后代**，而非从根到选中节点的路径。选中一个有多个分支的节点后，所有分支的走法都会被执行，棋盘状态完全错乱。正确做法需要从根节点回溯到选中节点的路径。

**影响**: 即使棋盘预览修复了，显示的局面也是错误的。

---

### P1 — 高优先级 UX 问题

#### P1-1: ReplayBoardView 楚河汉界不随视角翻转
**文件**: `ReplayBoardView.swift` → `riverText()`

`ChessBoardView` 的 `riverText` 根据 `isFlipped` 调整"楚河"和"汉界"的左右顺序，但 `ReplayBoardView` 始终硬编码为"楚河"在左、"汉界"在右。回放黑方视角对局时，楚河汉界方向与实际棋盘方向矛盾。

**影响**: 回放视角不一致，用户产生方向混淆。

---

#### P1-2: ThemePickerView 横向布局不可滚动
**文件**: `ThemePickerView.swift`

主题选择使用 `HStack(spacing: 16)` 布局，没有包裹 `ScrollView(.horizontal)`。随着段位解锁的主题增多（当前已有多个），主题色块会被压缩变形而非滚动展示。

**影响**: 主题数量多时无法正常查看和选择，在窄屏（iPhone SE）上尤其严重。

---

#### P1-3: StatusBarView 和 ChessClockView 的 Timer 永不停止
**文件**: `StatusBarView.swift`, `ChessClockView.swift`

两个视图都使用 `Timer.publish(every: 1, ...).autoconnect()` 作为 `@State` 属性。这些 timer 在视图生命周期内持续触发，即使：
- 对局已结束（`gameState != .playing`）
- 视图不可见（如在 Settings 页面）
- AI 未在思考

每秒都触发 `onReceive` → `updateDisplay()`，浪费 CPU 和电量。

**影响**: 长时间使用下不必要的电量消耗，低端设备可能感知到卡顿。

---

#### P1-4: SoundEngine 缺少 AVAudioSession 管理（iOS）
**文件**: `SoundEngine.swift`

没有任何 `AVAudioSession` 配置代码。在 iOS 上：
- 用户听音乐时打开游戏，音效可能无法播放（session 未激活）
- 或者游戏音效会强制中断背景音频（默认行为可能不理想）
- 静音模式下音效行为不确定

应至少设置 `AVAudioSession.sharedInstance().setCategory(.ambient)` 以尊重静音开关并与背景音频混合。

**影响**: 音效在各种 iOS 音频场景下行为不可预测，影响用户体验。

---

#### P1-5: PuzzlePlayView 使用已废弃的 UIScreen.main 进行布局计算
**文件**: `PuzzleSelectView.swift` → `PuzzlePlayView.bottomAreaMaxHeight`

```swift
let screenHeight = UIScreen.main.bounds.height
```

`UIScreen.main` 在 iOS 16+ 已废弃，在多窗口/Stage Manager 场景下返回错误的屏幕尺寸。应使用 `GeometryReader` 获取实际可用空间。

**影响**: iPad Stage Manager 或外接显示器场景下，底部区域高度计算错误，可能挤压棋盘。

---

### P2 — 中等优先级 UX 问题

#### P2-1: CoachSessionView 无法回看上一步讲解
**文件**: `CoachSessionView.swift`

教练讲解的导航是单向的：`onDismiss` → `nextStep()` → 不可逆。用户误触"知道了"后无法回看上一步的讲解内容。

**影响**: 用户错过讲解后无法补救，学习体验打折。

---

#### P2-2: AnalysisView 评估曲线缺少坐标轴标注
**文件**: `AnalysisView.swift` → `evalChart`

评估曲线图只有一条零线，没有：
- Y 轴刻度标注（±多少分值）
- X 轴步数标注
- 当前位置数值的文本提示

用户无法理解曲线高度代表的具体评估值。

**影响**: 评估曲线信息传达不充分，用户难以解读。

---

#### P2-3: SettingsView 主题选择缺少视觉预览
**文件**: `SettingsView.swift` → `themeRow(for:)`

设置页面的主题行只显示图标 + 名称 + 段位要求文字，**没有色块预览**。用户需要切换后才能看到主题样貌。对比之下，`ThemePickerView` 和 `ThemePickerView` 的内联选择器有色块预览——体验不一致。

**影响**: 主题选择体验差，用户需要反复尝试。

---

#### P2-4: 棋盘上无 AI 思考状态的视觉指示
**文件**: `ChessBoardView.swift`

AI 思考时，`canInteract` 返回 `false`，棋盘交互被禁用，但棋盘本身**没有任何视觉变化**提示当前不可操作。状态栏有"AI 思考中"文字，但如果用户注意力在棋盘上，可能困惑为什么点击没有反应。

建议：AI 思考期间棋盘添加半透明遮罩或边框颜色变化。

**影响**: 用户可能误以为点击无效是 bug。

---

#### P2-5: SoundEngine isMuted 设置存在竞态条件
**文件**: `SoundEngine.swift`

```swift
var isMuted: Bool {
    get { queue.sync { _isMuted } }
    set { queue.async { [weak self] in self?._isMuted = newValue } }
}
```

Setter 使用 `async`，意味着设置后立即 get 不一定能读到最新值。在 SettingsView 中切换静音后，紧接着触发的音效可能仍会播放（旧值）或被跳过（新值已生效但 UI 显示旧状态）。

应使用 `queue.sync` 或直接用 atomic 属性。

**影响**: 快速切换静音时可能出现状态不一致。

---

#### P2-6: macOS 无触觉反馈，非法走法提示仅靠视觉
**文件**: `ChessBoardView.swift` → `triggerHapticFeedback()`

```swift
private func triggerHapticFeedback() {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
    #endif
}
```

macOS 端非法走法只有红色叉号视觉提示，没有任何触觉/声音反馈。考虑到 SoundEngine 有 `playCheck` 等音效，可以增加一个"错误音"用于此类反馈。

**影响**: macOS 用户对非法操作的感知较弱。

---

#### P2-7: PuzzlePlayView 标题栏在 iPhone 小屏上拥挤
**文件**: `PuzzleSelectView.swift` → `PuzzlePlayView.gameContent`

标题栏同时放置了：返回按钮、标题、步数/进度、引导/自由模式切换控件。在 iPhone SE（375pt 宽）上，这些元素会严重挤压。模式切换控件本身就有两个按钮 + 文字标签，占用大量水平空间。

**影响**: 小屏设备上标题栏元素重叠或截断。

---

#### P2-8: 残局模式切换 disabled 条件不直观
**文件**: `PuzzleSelectView.swift` → `PuzzlePlayView`

模式切换按钮的 `disabled` 逻辑：
```swift
.disabled(!viewModel.canSwitchToGuided && isFreePlay)   // guided 按钮
.disabled(!viewModel.canSwitchToGuided && !isFreePlay)  // freePlay 按钮
```

`canSwitchToGuided` 的含义对用户不透明。当用户在自由对弈模式下走了若干步后想切回引导模式，按钮可能不可用，但没有解释原因。

**影响**: 用户不理解为什么模式切换被禁用。

---

### P3 — 低优先级改进建议

#### P3-1: PuzzleSelectView deprecation 标注误导
**文件**: `PuzzleSelectView.swift`

标记了 `@available(*, deprecated, message: "Use ChapterSelectView...")`，但实际仍作为 `ChapterSelectView` 的子视图正常使用。编译器会对正常流程产生 deprecation 警告。

建议：移除 deprecation 标注，或改为 `internal` 访问级别。

---

#### P3-2: ReplayControlView 进度条在多步对局中精度不足
**文件**: `ReplayControlView.swift`

Slider step 为 1，范围 `0...max(1, moves.count)`。当对局超过 80 步时，拖动精度极差——鼠标移动 1 像素可能跳过 3-4 步。

建议：增加键盘左右箭头快捷键支持（macOS），或改用可缩放的进度条。

---

#### P3-3: GameHistoryView macOS 搜索栏丢失标准 searchable 行为
**文件**: `GameHistoryView.swift`

注释说明 `.searchable` 在 sheet 内的 NavigationStack 中会导致渲染卡死，改用 toolbar 手动实现。但手动实现的搜索栏缺少：
- 聚焦时自动选中文字
- ESC 键清除搜索
- 搜索结果数量提示

**影响**: macOS 搜索体验略逊于标准行为，但属可接受的 workaround。

---

#### P3-4: 每日挑战"敬请期待"模式占位过多
**文件**: `DailyChallengeView.swift`

7 个"敬请期待"模式占据大量屏幕空间（两列网格），稀释了实际可玩内容的视觉比重。用户第一次打开看到大量灰色锁定项，可能产生"内容匮乏"的第一印象。

建议：折叠或缩小占位区域，优先突出 3 个可玩模式。

---

#### P3-5: Accessibility — 部分交互元素缺少 trait 标注
**文件**: `ChessBoardView.swift` 交互层

棋盘交互层使用 `Color.clear` + `DragGesture`，虽有 `accessibilityLabel` 但缺少 `accessibilityAddTraits(.isButton)`，VoiceOver 用户无法得知该区域可交互。合法走法标记的圆点同理。

---

## 建议改进

### 高优先级
1. **修复 OpeningExplorerView**：渲染实际棋盘 + 修正路径推演逻辑（P0-1, P0-2）
2. **统一 ReplayBoardView 的翻转逻辑**：与 ChessBoardView 保持一致的楚河汉界方向（P1-1）
3. **ThemePickerView 加 ScrollView(.horizontal)**：防止主题色块压缩（P1-2）
4. **Timer 生命周期管理**：在 `gameState != .playing` 或 `.onDisappear` 时停止 timer（P1-3）
5. **SoundEngine 配置 AVAudioSession**：iOS 启动时设置 `.ambient` category（P1-4）

### 中优先级
6. **棋盘添加 AI 思考视觉指示**：边框微亮或半透明遮罩（P2-4）
7. **SettingsView 主题行加色块预览**：与 ThemePickerView 保持一致（P2-3）
8. **评估曲线加坐标轴标注**：至少标出 ±200 和 ±500 的分值线（P2-2）
9. **CoachSessionView 增加上一步按钮**（P2-1）
10. **SoundEngine isMuted 改用同步写入**（P2-5）

### 低优先级
11. 减少每日挑战占位模式数量或折叠显示（P3-4）
12. ReplayControlView 增加 macOS 键盘快捷键（P3-2）
13. 清理 PuzzleSelectView deprecation 标注（P3-1）

## 总结

审计覆盖 30 个视图文件和 3 个服务文件，共发现 **22 个问题**：

| 严重度 | 数量 | 概述 |
|--------|------|------|
| P0 | 2 | 开局探索器棋盘预览空白 + 路径推演逻辑错误，功能完全不可用 |
| P1 | 5 | 回放翻转不一致、主题选择不可滚动、Timer 泄漏、音频会话缺失、废弃 API |
| P2 | 8 | 教练导航缺失、评估图无标注、设置无预览、AI 思考无视觉反馈等 |
| P3 | 5 | 废弃标注、精度问题、占位过多、Accessibility 不完整等 |

**核心风险**：开局探索器（P0）是功能性完全损坏的模块，用户进入后会看到空白棋盘+错误局面，应优先修复。其余 P1 问题虽不致命，但 Timer 泄漏和音频会话缺失在长时间使用中会明显影响体验。

棋盘核心交互（点击选子、拖拽走子、非法提示、合法走法标记）实现完整，交互逻辑清晰。残局模块的引导/自由模式切换、通关/失败/和局弹窗等状态覆盖全面。回放控制的播放/暂停/跳转功能齐全。总体操作性框架扎实，问题集中在边缘视图和细节打磨层面。
