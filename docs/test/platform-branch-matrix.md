# L2 平台矩阵底料 — `#if os(...)` 分支全量盘点

> 作者：Eric（coder2） | 日期：2026-08-28 | 用途：v6.3 冲刺 Cody 补桩测试直接消费
>
> 盘点口径：`grep -rn '#if os' src/ChineseChess src/ChineseChessTests --include='*.swift'`，主树 m1 @ aa74fe7 时点快照。
> 每条给 `文件:行号`，可核验。覆盖状态三级：
> - ✅ **运行时覆盖**：测试在运行中真实执行到该分支逻辑（macOS 分支为主）
> - 🟡 **静态源码断言**：测试通过读取源码文本断言分支结构（iOS 分支在 macOS test target 编译隔离，只能如此覆盖）
> - 🔴 **零覆盖**：无任何测试触及（含静态断言）
>
> ⚠️ macOS test target 无法编译 iOS 分支 → iOS 分支的"运行时覆盖"只能来自 ChineseChess-iOS/UITests（该目录目前整目录 gitignore，仅 I4I6RegressionUITests.swift 正在收编，见 v6.3-C1）。**故下表所有 iOS 分支的 ✅ 实际上限是 🟡。**

## 总量

- 源码分支：**124 处** `#if os`（iOS 57 / macOS 67），分布于 40 个源文件
- 测试文件中的分支：另有 10+ 处（多为 macOS-only 测试目标自身的编译门禁，不属于本表盘点对象，仅列附录）

---

## 一、Views/（主战场，UI 双平台差异集中区）

### ⭐ 参照案 1：ToolbarView（已逃逸过 — 难度标签案逃逸，优先级依据）

| 分支 | 内容 | 覆盖 | 测试证据 |
|------|------|------|---------|
| `ToolbarView.swift:96` `os(iOS)` | iOS 工具栏 HStack（悔棋/提示左 + 新局右） | 🟡 间接 | IOSToolbarAdaptationTests（VM 层按钮 disabled 逻辑，非该 View 分支本体）；V2215Tests:299 断言 Picker 不再有平台分支 |
| `ToolbarView.swift:227/240/253/266/280` `os(macOS)` ×5 | macOS 快捷键 ⌘N/⌘Z/⌘⇧H/⌘⇧R/⌘⇧L + controlSize | 🔴 零覆盖（本体） | keyboardShortcut 被 PhaseB1Step4_5Tests/V562Batch1Tests 等提到，但断言的是别处快捷键 |

**逃逸史**：短标签→长名案（commit `1189989`，known-issues.md L453）证明该文件的 iOS 分支曾以"macOS 测试绿"假象逃逸。补桩建议：源码静态断言（iOS HStack 结构 + 按钮集合）。

### ⭐ 参照案 3：StatusBarView（已逃逸过 — 徽章案，b19a4ef 引擎类型徽章移除）

| 分支 | 内容 | 覆盖 | 测试证据 |
|------|------|------|---------|
| `StatusBarView.swift:81` `os(iOS)` → `iOSCapturedPiecesSection()` | iOS 被吃棋子精简行 | 🔴 零覆盖 | `iOSCapturedPiecesSection`/`capturedRowHeight` 在测试目录零命中 |
| `StatusBarView.swift:111` `os(iOS)` | capturedRowHeight=24 + section 实现 | 🔴 零覆盖 | 同上 |
| `#else`（:81 的 macOS 段）被吃棋子 HStack | macOS 双列全量文案 | 🟡 间接 | 仅 VM 层 capturedPieces 语义测试（4f0cf64 系列）；渲染本体零断言 |

### DemoControlBar（速度菜单红框案现场，见 v6.4-ui-debt-ledger）

| 分支 | 内容 | 覆盖 |
|------|------|------|
| `:16` `os(iOS)` sheet 配置入口 | 🟡 SmartCommentaryPhase1Tests（DemoConfigSheet 静态断言） |
| `:33` `os(iOS)` `iosControlBar` | 🟡 MacPlayLayoutPolishTests（源码断言） |
| `:135` `os(macOS)` `macosControlBar` | 🟡 UIBugFixSidebarClickTests / MacPlayLayoutPolishTests / V62LayoutTests |
| `:312` `os(macOS)` `DemoConfigPopover` | 🟡 UIBugFixI18nToggleSpeedTests / MacPlayLayoutPolishTests / SmartCommentaryPhase1Tests |
| `:358` `os(iOS)` `DemoConfigSheet` | 🟡 SmartCommentaryPhase1Tests |

### DemoInfoBar

| 分支 | 覆盖 |
|------|------|
| `:13`/:22 `os(iOS)` `iosInfoBar` | 🔴 零覆盖（`iosInfoBar` 零命中） |
| `:78` `os(macOS)` `macosInfoBar` | 🟡 MacPlayLayoutPolishTests |

### MasterGameBrowserView（11 分支，文件最重）

| 分支 | 内容 | 覆盖 |
|------|------|------|
| `:109` `os(iOS)` `iosPlayLayout` | 🟡 CommentaryOverlayPositionTests |
| `:130`/:192 `os(macOS)` 布局骨架 + `browserTopBar` | 🟡 MasterGameFixTests / MacUXRedesignV4Tests |
| `:448` `os(iOS)` `iosSearchSheet` | 🔴 零覆盖（零命中） |
| `:585` `os(iOS)` `iosCategoryList` | 🟡 Phase1FixTests / MacSidebarRedesignTests |
| `:903`/:961 `os(macOS)` `subcategoryFilterBar` + 条件渲染 | 🟡 MacUXRedesignV4Tests |
| `:1019` `os(macOS)` 搜索模式 | 🔴 零覆盖 |
| `:1088` `os(macOS)` loadIndex 按钮 | 🔴 零覆盖 |
| `:1354` `os(macOS)` `macosPlayLayout`（v6.2 左右布局） | 🟡 V62LayoutTests / MacSidebarRedesignTests / MasterGameFixTests / CommentaryOverlayPositionTests |
| `:1423` `os(macOS)` `.focused` 焦点接管 | 🔴 零覆盖 |

### PuzzleDemoView（8 分支）

| 分支 | 内容 | 覆盖 |
|------|------|------|
| `:39` `os(iOS)` `iosLayout` | 🟡 V62LayoutTests |
| `:81`/:124 `os(macOS)` 骨架 + `categoryFilterBar` | 🟡 MacUXRedesignV4Tests（categoryFilterBar） |
| `:164`/:234 `os(iOS)` `categoryList` / `tacticalGroupList` | 🟡 PhaseA1/A2 + Phase1FixTests / MacSidebarRedesignTests |
| `:291` `os(macOS)` `tacticalGroupFilterBar` | 🔴 零覆盖 |
| `:443` `os(macOS)` `macosLayout`（v6.2 左右布局） | 🟡 V62LayoutTests |
| `:570` `os(macOS)` `.focused` | 🔴 零覆盖 |

### SettingsView（⭐ 参照案 2：假切换案现场）

| 分支 | 内容 | 覆盖 |
|------|------|------|
| `:37` `os(iOS)` 引擎开关 Section（内 `switchEngineIfNeeded`） | 🟡 P1FixVerificationTests / P1FallbackToastTests 等 7 文件覆盖 `switchEngineIfNeeded` 路由逻辑（macOS 运行时），但 iOS 入口本体零断言 |
| `:184` `os(iOS)` navigationBarTitleDisplayMode | 🔴 零覆盖（该修饰符全仓零测试命中） |
| `:187` `os(macOS)` `.frame(width: 320)` | 🔴 零覆盖 |

**逃逸史**：假切换案——引擎开关 macOS 端曾假切换（UI 有开关、实际不生效），修复后入口收进 iOS-only 分支。教训：**平台分支把入口藏起来 ≠ 切换逻辑已在两平台都验过**。

### 其余 Views 一览

| 文件:行 | os | 内容 | 覆盖 |
|------|----|------|------|
| AboutView.swift:51 | iOS | navBarTitle inline | 🔴（仅 V62LayoutTests 文件级引用） |
| AnalysisView.swift:356 | macOS | NSPasteboard 导出 | 🔴 零覆盖（NSPasteboard 全仓测试零命中） |
| AssessmentView.swift:209 | macOS | controlBackgroundColor | 🔴 零覆盖 |
| ChessBoardView.swift:414 | iOS | UIImpactFeedbackGenerator 触感 | 🔴 零覆盖 |
| CommentaryPanel.swift:10 | macOS | 文件级保护 | 🟡 V62LayoutTests T6（文件级 #if os(macOS) 门禁） |
| DemoSidePanel.swift:13 | macOS | 文件级保护 | 🟡 V62LayoutTests T6 |
| ManagedSplitView.swift:23 | macOS | 文件级保护 | 🟡 V62LayoutTests T6 |
| MoveRecordPanel.swift:14 | macOS | 文件级保护 | 🟡 V62LayoutTests T6 |
| GameHistoryView.swift:67/363/410/437 | macOS ×4 | contextMenu + NSPasteboard ×3（含导入读取） | 🔴 零覆盖（NSPasteboard 零命中） |
| GameHistoryView.swift:152/155/177/375 | iOS ×4 | navBar/searchable/底栏/UIPasteboard | 🔴 零覆盖（searchable、UIPasteboard 零命中） |
| GameHistoryView.swift:158 | macOS | searchable→toolbar 搜索栏替代（渲染卡死规避） | 🔴 零覆盖——**高价值：该规避分支回归即卡死** |
| OpeningCoachSelectView.swift:22/30 | iOS/macOS | iOSLayout vs macOSLayout(HSplitView) | 🔴 零覆盖（两符号零命中） |
| OpeningExplorerView.swift:44 | iOS | iOS 上下布局（v5.5.1 fix） | 🔴 零覆盖 |
| PrivacyPolicyView.swift:27 | iOS | navBarTitle inline | 🔴 零覆盖（整文件无测试） |
| PuzzleSelectView.swift:239 | iOS | fullScreenCover 进 PuzzlePlayView | 🟡 PuzzleDemoViewEntryTests 等覆盖 fullScreenCover 模式（间接） |
| PuzzleSelectView.swift:509 | iOS | UIScreen/UIDevice iPad 适配 | 🔴 零覆盖 |
| PuzzleSelectView.swift:691 | macOS | NSPasteboard 导出 | 🔴 零覆盖 |
| RankPrivilegeView.swift:29 | iOS | navBarTitle inline | 🔴 零覆盖 |
| ReplayControlView.swift:38 | iOS | phone/pad 控制条宽度 90/120 | 🔴 零覆盖 |
| ReplayView.swift:108/122 | iOS | fullScreenCover 分析 + navBarTitle | 🟡/🔴 |
| ReplayView.swift:200 | macOS | NSPasteboard | 🔴 |
| StudyHubView.swift:13 | iOS | iOSLayout | 🔴 零覆盖（零命中；StudyHub 相关测试均 VM/数据层） |
| Tutorial/TutorialView.swift:52 | iOS | maxWidth 400 | 🔴 |
| BoardSizing.swift:14/20/40 | macOS + iOS ×2 | maxCellSize 200 / maxBoardWidth 600 / 宽高钳制 | ✅ BoardSizingTests + MacAdaptiveLayoutTests（运行时，公共 API 跨平台） |

## 二、AI/（引擎域，分支多为 CLI 入口）

| 文件:行 | os | 内容 | 覆盖 |
|------|----|------|------|
| SelfPlayRunner.swift:1241/1319/1414/1530/1650/1747 | macOS ×6 | 6 个 CLI 入口（calibrate/paired/selfplay/pfmatch…） | ✅ SelfPlayRunnerTests / CalibrationV3Tests / V60Phase6Tests（核心路径运行时；CLI argv 入口本体为手动验证） |
| EmbeddedPikafishEngine.swift:41 | iOS | NNUE bundle 诊断 | 🔴（V34 系列覆盖引擎本体，非此分支） |
| EmbeddedPikafishEngine.swift:226 | iOS | physicalMemory<2GB 保守策略 | 🟡 V34PhaseABCTest（isIOS:false 路径覆盖 macOS 侧；iOS 侧静态） |
| TranspositionTable.swift:43 | iOS | capacity precondition | 🔴 零覆盖（TTEntry 零命中） |
| CMAESOptimizer.swift:460 | macOS | CLI 入口 | ✅ Batch1P0CMAESTests（算法层） |
| OpeningBookExpander.swift:246 | macOS | CLI 入口 | 🔴（整个 OpeningBookExpander 无直接测试；LazyOpeningBookTests 覆盖消费侧） |

## 三、App / Helpers / Services / Utils / ViewModels

| 文件:行 | os | 内容 | 覆盖 |
|------|----|------|------|
| ChineseChessApp.swift:1/17 | macOS ×2 | AppKit import + --selfplay argv 路由 | 🟡（多个 sheet/导航测试引用 App 符号；argv 路由本体手动验证） |
| ChineseChessiOSApp.swift:1 | iOS | 整 App 入口 | 🟡 Phase4IOSSheetTests / UnifiedSheetTests / PhaseB1Step1Tests（源码静态断言，注释明说"iOS 代码不可直接访问"） |
| PlatformExtensions.swift:5/17/25 | macOS ×3 | NSColor typealias + controlBackgroundColor/windowBackgroundColor | 🟡 V62SpeedMenuPixelTests 等大量引用（作为基建被广泛静态消费） |
| SoundEngine.swift:15/37/97/114/127 | iOS ×5 | AudioSession 生命周期 + 来电打断处理 | 🔴 **零覆盖 ×5（整个 iOS 音频会话域无任何测试）** |
| FontRegistry.swift:58 | macOS | CTFontManagerRegisterFontsForURL | ✅ FontTests / V211P0Tests（运行时） |
| GameViewModel.swift:8 | iOS | `_isIOS` 编译期标记 | 🟡（isIOS:false 大量引擎测试消费；true 分支仅 iOS target 编译验证） |
| PuzzleViewModel.swift:15 | iOS | 同上 | 🟡 同上 |

## 四、测试文件自身的平台分支（附录，非补桩对象）

- `MacAdaptiveLayoutTests.swift` / `V62SpeedMenuPixelTests.swift` / `UILayoutOptTests.swift` / `BoardLayoutConsistencyTests.swift` 内含 `#if os(macOS)` 测试体——这些是"测试只在该平台跑"的门禁，健康形态。
- `Phase4IOSSheetTests` / `PhaseB1Step1Tests` / `IOSToolbarAdaptationTests` 注释明确记录了"iOS 符号不可访问→源码文本断言"策略——**补桩 iOS 分支时沿用此模式**。

---

## 五、零覆盖热点排行（补桩优先级）

1. 🔴🔴 **SoundEngine iOS ×5**（音频会话/打断，纯运行时行为，XCUITest 才能真覆盖）
2. 🔴🔴 **GameHistoryView 剪贴板 ×5**（NSPasteboard ×4 + UIPasteboard，导出/导入数据完整性，用户可见）
3. 🔴 **GameHistoryView:158 searchable 规避分支**（回归 = 渲染卡死，静态断言即可钉住）
4. 🔴 **StatusBarView iOS 被吃棋子段**（⭐ 参照案 3 现场）
5. 🔴 **ToolbarView:96 iOS 工具栏**（⭐ 参照案 1 现场，逃逸史在案）
6. 🔴 **SettingsView:37 iOS 引擎开关入口**（⭐ 参照案 2 现场，假切换逃逸史在案）
7. 🔴 **OpeningCoachSelectView 双布局**（HSplitView vs iOSLayout，整组件零断言）
8. 🔴 **StudyHubView:13 iOSLayout**（iOS 演示导航链入口，I4I6 用例恰好路过——XCUITest 收编后升级为 🟡）
9. 🔴 **MasterGameBrowserView:448 iosSearchSheet / :1019 搜索模式 / :1088 loadIndex**
10. 🔴 其余 🔴 单点：ChessBoardView:414 触感 / ReplayControlView:38 宽度 / PuzzleSelectView:509 iPad / navBarTitleDisplayMode 系 ×6 / TranspositionTable:43 / OpeningBookExpander:246

## 六、补桩模式建议（沿用既有范式）

- iOS 分支（macOS test target 编译不可见）：**源码文本断言**（IOSToolbarAdaptationTests / V62LayoutTests T6 已有范式：读文件 → 断言 `#if os(iOS)` 块内含关键符号）
- macOS 分支：Swift Testing 运行时断言 + V62LayoutTests T6 式文件级门禁
- 真运行时 iOS 覆盖：等 v6.3 C1 的 UITests 收编扩容（当前仅 I4I6 一例）
