# T-1023-OC-01 D3 报告 — ③ 操作性/UX（v39-d3 基线增量）

> 主审：Ruby（reviewer）| 日期：2026-10-20 | 计划锚：docs/plans/T-1023-OC-01-inspection-plan.md v1.1（D3 工作包）
> 仓库锚：chinese-chess HEAD 1cfd109（v6.4.2 定版链），审查全程只读零改动零编译零测试批
> 方法：轻入场定点走查（grep/awk 按 v39-d3 基线发现项与新增 Views 矩阵定点进入，未全库通读）
> 分级：沿用 v3.9 口径（P0 阻断/P1 主流程/P2 体验/P3 打磨）；无出处结论无效

---

## 一、D0 基线核销分片：v39-d3 发现项三态标注

基线明细逐项核验 20 项（P0×2/P1×5/P2×8/P3×5）。

> ⚠️ 账目备注：基线报告 v39-d3-ux-operability.md 总结表写"共 22 个问题"，明细实列 20 项（P0 2+P1 5+P2 8+P3 5）。本核销以明细 20 项为准；差额 2 项无从对应，登记为基线报告内部账目出入。

### ✅ 已修复（7 项）

| 基线项 | 现态证据 |
|---|---|
| P0-1 开局探索器棋盘预览空白 | OpeningExplorerView.swift:467-472 — boardPreview 实渲染 OpeningBoardPreview(board:)，含走法路径与相关对局入口 |
| P0-2 walkPath 递归全后代执行 | OpeningExplorerView.swift:600-608 — selectNode 已重写（v5.0 注释：PositionSnapshot 重建 Board + parent 指针 pathFromRoot() 回溯），walkPath 已不存在 |
| P1-2 ThemePickerView 横向不可滚动 | ThemePickerView.swift:10-11 — ScrollView(.horizontal) 包裹 HStack(spacing:16) |
| P1-3 Timer 永不停止 | ChessClockView.swift:11-13 timerCancellable（注释：只在游戏进行中连接，结束后自动断开）+ :59 onDisappear；StatusBarView.swift:36 onReceive 已移入 viewModel.isThinking 条件块（不思考时无订阅者） |
| P1-4 SoundEngine 缺 AVAudioSession | SoundEngine.swift:93 MARK「AVAudioSession 管理（仅 iOS）」+ :41 interruptionNotification 监听 |
| P2-3 SettingsView 主题行无预览 | SettingsView.swift:182-204 — themeRow 含 20×20 渐变色块预览（RoundedRectangle+LinearGradient） |
| P3-4 每日挑战占位过多 | DailyChallengeView.swift:42 — 注释「v4.0: 敬请期待 — 单行文案」，7 占位网格已改单行 |

### ⚠️ 部分修复（5 项）

| 基线项 | 现态与残留 |
|---|---|
| P1-1 回放楚河汉界不随视角翻转 | 架构已重构：ReplayBoardView.swift:11-22 薄壳透传 isFlipped→BoardCanvasView（坐标经 BoardSizing.posToCGPoint flipped: 翻转，BoardCanvasView.swift:86）。**残留**：BoardCanvasView.swift:171-182 riverText 固定「楚 河」在左「汉 界」在右，无 isFlipped 分支；对照 ChessBoardView.swift:531-553 同名函数有「翻转时顺序对调」分支。文字顺序不一致依旧，残留立为新发现（见 N-1） |
| P2-2 评估曲线缺标注 | AnalysisView.swift:319-327 — v6.4 B1（②b 洪涛定案：标签为主、图例为辅）已加选中步文字标签（「第 N 手·标签·掉 X 分」形态）；轴刻度（Y 分值线/X 手数）仍无。属定案内取舍，残留登记不立案 |
| P2-7 PuzzlePlayView 小屏标题拥挤 | PuzzleSelectView 经 v6.2/v6.4 LayoutSpec 布局改造，基线描述的标题栏结构未逐字复现；静态不可证，按「无出处结论无效」不立案，建议 P4 实机确认 |
| P3-1 PuzzleSelectView deprecation 标注 | PuzzleSelectView.swift:3 — @available(*, deprecated) 标注保留，message 已更新（「now chapter-internal only」语义澄清）；编译警告面仍在 |
| P3-5 交互元素缺 a11y trait | ChessBoardView.swift:100/171 accessibilityLabel 已有（board/legalMove）；accessibilityAddTraits 全文件零命中，.isButton trait 仍缺 |

### ❌ 仍开放（8 项）

| 基线项 | 现态证据 |
|---|---|
| P1-5 UIScreen.main 废弃 API | PuzzleSelectView.swift:722 — `let screenHeight = UIScreen.main.bounds.height` 原样（Phase2#10 未落地） |
| P2-1 CoachSessionView 无法回看上一步 | CoachSessionView.swift:82 onDismiss: { nextStep() } + :247 仅 nextStep()，无 previousStep/回退入口 |
| P2-4 棋盘无 AI 思考视觉指示 | ChessBoardView.swift:310-311 — isThinking 仅用于 canInteract 交互门控；全文件无遮罩/边框/透明度联动 |
| P2-5 SoundEngine isMuted 竞态 | SoundEngine.swift:8-10 — set 仍 queue.async（get sync/set async 不对称原样） |
| P2-6 macOS 非法走法反馈弱 | ChessBoardView.swift:401-421 — showIllegalHint 有 0.5s 红闪+iOS 触觉（triggerHapticFeedback #if os(iOS)）；SoundEngine 无 playError（playCheck:63/playCheckmate:69 之外无错误音） |
| P2-8 模式切换 disabled 不透明 | PuzzleSelectView.swift:795/812 — disabled(!canSwitchToGuided…) 逻辑原样，无原因解释文案 |
| P3-2 回放进度条精度 | ReplayControlView.swift:93 — Slider 原样；无键盘快捷键（onExitCommand/keyCommand 零命中） |
| P3-3 GameHistory 搜索 workaround 维持 | GameHistoryView.swift:156-166 — .searchable + macOS 手动 TextField 双路维持（:159 注释原样）；ESC 清除/聚焦选中仍缺 |

**核销小结**：已修复 7 / 部分修复 5 / 仍开放 8（共 20）。

---

## 二、增量区发现（新立案）

### N-1 (P2) 回放棋盘楚河汉界文字顺序不随翻转对调（P1-1 残留）

- **证据**：BoardCanvasView.swift:171-182 — riverText 固定 HStack{楚河, 汉界}，无 isFlipped 条件分支
- **对照**：ChessBoardView.swift:531-553 — 同一渲染语义下有 if isFlipped 对调分支（含注释「翻转时顺序对调：汉界在左，楚河在右」）
- **影响**：黑方视角回放时，坐标与棋子已翻转而河界文字方向未翻，与主棋盘行为不一致（基线 P1-1 所述用户方向混淆在回放场景仍存在）
- **修法建议**：将 ChessBoardView 的翻转分支逻辑下沉 BoardCanvasView（两处共用一份 riverText），P3 打磨量级

### N-2 (P2) MasterGameBrowserView 确认按钮硬编码 "OK" ×7

- **证据**：MasterGameBrowserView.swift:246、270、1001、1006、1114、1119、1127 — 均为 `Button("OK") {}` 字面量
- **对照**：同文件 alert 标题均为 l10n key（master.statsUnavailable/demo.loadError/demo.incompleteWarning）；GameHistoryView.swift:256-310 同类确认按钮全部走 common.ok/common.cancel
- **影响**：英文/中文环境下按钮文案不随语言切换；与其他 Views 按钮规范不一致
- **交叉**：⚠️ 转 D6（dim6 i18n 复核）重点核销项——v3.9 §3.2 硬编码集群核销清单未覆盖此处（本文件为 v39 后新增视图）
- **文案原文逐字**：`Button("OK") {}`（7 处一字不差）

### N-3 (P3) 迁移引导气泡 3 秒自动消失偏短

- **证据**：MigrationTooltip.swift:7-9 — 注释「自动显示，点击或 3s 后消失」
- **影响**：迁移类文案（「残局和开局探索已移至学棋」）信息密度下 3s 阅读窗口对新手/老年用户偏紧，错过即无再进入口
- **修法建议**：延长至 5-6s 或首次点击前不自动消失

---

## 三、专项核验（计划指定挂接点）

### 3.1 T-1020-OC-02 工具栏信息架构（只核实施后状态）

实施态与验收结论一致 ✅：
- ToolbarView.swift:21 onStudyHubRequest 内联入口（studyHub 提权入内联）
- ToolbarView.swift:23 + :341-362 overflowItems 溢出菜单（含 .help + accessibilityLabel）
- ToolbarView.swift:297 注释「v6.4 C1：认输/复盘/低频项全部入溢出菜单」
- ToolbarView.swift:375-379 宽度采样遥测（params: overflow 计数 + studyHubInline=1，312d510 LayoutDump 面）
- 认输确认链：ToolbarView.swift:100-107（game.resignConfirm + destructive 确认钮）+ GameViewModel.swift:422-432（认输 MARK）— Phase3#11 落地

### 3.2 教练域（以 T-1021-OC-01 修复后代码态为对照基线）

- CoachGameView.swift:452-455 — T-1021 注释与 makeCoachMove 专用通道在位 ✅
- CoachGameView.swift:85-86 — coach.exit.confirm 退出确认（common.cancel 取消钮本地化）✅
- 交互面残留：P2-1（讲解单向不可回看）仍开放，见 §一

### 3.3 新手引导链（FirstLaunchDialog → 教程 → 引导提示）

链路完整 ✅：
1. ChineseChessApp.swift:207 showFirstLaunchDialog 状态 + :457-465 条件渲染 FirstLaunchDialog（Phase1#3 落地）
2. TutorialView.swift:122-160 FirstLaunchDialog 双钮：tutorial.notFamiliar（borderedProminent）→ onShowTutorial / tutorial.familiar → onSkip，文案全走 l10n
3. MigrationTooltip.swift:7-9 迁移引导气泡（学棋入口迁移提示）— 时长问题见 N-3

### 3.4 错误提示盘点（Views 层 alert 调用点 21 处逐一登记）

| # | 位置 | 标题 key | 按钮本地化 |
|---|---|---|---|
| 1 | ChapterSelectView.swift:81 | chapter.locked.title | — |
| 2 | BoardView.swift:11 | challenge.ruleViolation | — |
| 3 | BoardView.swift:17 | challenge.unavailable | — |
| 4 | BoardView.swift:24 | 挑战结算（challengeResult 分支） | — |
| 5 | CoachGameView.swift:85 | coach.exit.confirm | common.cancel ✅ |
| 6 | ToolbarView.swift:100 | game.resignConfirm | game.resign(destructive) ✅ |
| 7 | ToolbarView.swift:228 | game.sideSwitchConfirmTitle | common.cancel ✅ |
| 8 | MasterGameBrowserView.swift:245 | master.statsUnavailable | **Button("OK") 硬编码 ❌** |
| 9 | MasterGameBrowserView.swift:269 | master.statsUnavailable | **Button("OK") ❌** |
| 10 | MasterGameBrowserView.swift:1000 | demo.loadError | **Button("OK") ❌** |
| 11 | MasterGameBrowserView.swift:1005 | demo.incompleteWarning | **Button("OK") ❌** |
| 12 | MasterGameBrowserView.swift:1113 | demo.loadError | **Button("OK") ❌** |
| 13 | MasterGameBrowserView.swift:1118 | demo.incompleteWarning | **Button("OK") ❌** |
| 14 | MasterGameBrowserView.swift:1126 | demo.loadError(master) | **Button("OK") ❌** |
| 15 | StatsPanelView.swift:94 | stats.reset | common.cancel ✅ |
| 16 | ReplayView.swift:132 | history.rename（含 TextField） | — |
| 17 | GameHistoryView.swift:256 | history.clear | common.cancel/common.clear ✅ |
| 18 | GameHistoryView.swift:266 | history.corruptTitle | common.ok ✅ |
| 19 | GameHistoryView.swift:272 | export.resultTitle | common.ok ✅ |
| 20 | GameHistoryView.swift:278 | history.rename | common.cancel ✅ |
| 21 | GameHistoryView.swift:310 | （第五处确认框） | common.* ✅ |

结论：标题层 l10n 覆盖 21/21；按钮层硬编码 7/21（全部集中在 MasterGameBrowserView，即 N-2）。

---

## 四、新增界面轻走查登记（覆盖面声明）

定点进入并结构核验：StudyHubView（NavigationLink 枢纽，:7/:146/:193）、MasterGameBrowserView（sidebar 搜索 :226 + segmented modePicker :420-428）、CoachGameView/CoachSessionView/CoachResultView/OpeningCoachSelectView（教练域，T-1021 后状态）、AssessmentView、Tutorial/* 五件、MigrationTooltip、BoardCanvasView（共用画布）、ReplayBoardView（薄壳）、Layout/*（LayoutSpec/AdaptiveRailState/CategorySidebar/LayoutDump）。其余 Views 未全量通读（轻入场纪律）。

---

## 五、汇总

| 类别 | 数量 | 明细 |
|---|---|---|
| 基线已修复 | 7 | P0×2、P1×3、P2×1、P3×1 |
| 基线部分修复 | 5 | P1-1/P2-2/P2-7/P3-1/P3-5（残留并入 N-1 或登记） |
| 基线仍开放 | 8 | P1×1、P2×4、P3×3 |
| 新立案 | 3 | N-1(P2)、N-2(P2)、N-3(P3) |

**UX 域当前有效问题清单**（映射 P3 整改条目）：仍开放 8 + 新立案 3 = 11 项（P1×1、P2×6、P3×4；P2-2/P2-7 为登记不立案另计）。

**主判断**：v3.9 后 UX 域修复质量高——两个 P0（开局探索器）彻底修复且方案升级（snapshot 回溯）；引导链、认输、主题预览、占位缩减均落地。当前残留集中在：①回放画布翻转一致性（N-1，架构下沉即可根治）②MasterGameBrowser 按钮本地化（N-2，机械修复）③教练讲解单向导航与思考指示等体验打磨项。
