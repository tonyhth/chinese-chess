# T-1023-OC-01 D2 — 功能完整性与正确性审计报告（②维）

> 审计人：Tina（tester）| 日期：2026-10-20 | 版本：v1.1
> 工作包：D2 主审 2.0（计划 §四②）+ ②维 D0 基线核销分片（计划 §六 D0）
> 修订记录：v1.2.1 — 2026-10-22 脚注 ※1 补 Alex D7 更新③精确落点（GameViewModel.swift:801-804）与裁决执行口径；v1.2 — 2026-10-22 按丹妮 60 步规则裁决加更正脚注 ※1（50 回合判和阈值域，正文结论行不动）；v1.1 — 2026-10-21 增补 §七 协作位移交项核验（Cody 分片 4 项，含 X-碰撞 P1 入池与和棋检测测试覆盖真伪审计）；v1.0 — 2026-10-20 首版
> 计划依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1
> 方法：复用 v39-d4 链路追踪法（静态代码走查 + 既有测试用例映射），**未跑测试、未编译、未打包**（P2 硬约束全程遵守）
> 轻入场声明：全程定点进入（D0 项与链路清单驱动），无全库通读；grep 均为定点证据采集

## 〇、审计对象锚定

- **代码锚**：main HEAD = `1cfd109`（chore(release): iOS 子工程版本同步 6.4.2；谱系 1cfd109→a26d902→5ce0fa2，即 v6.4.2 定版链）
- **树状态**：tracked 零改动（git status porcelain 仅 2 个 untracked docs 文件：本计划 + Alex ①维报告）
- **基线报告**：docs/audits/v39-d4-feature-completeness.md（2026-07-15，v3.9 审计点，103 文件 ~20,066 行）→ 现规模 400 个 .swift（含测试），@Test 总数 2961
- 代码规模与结构自 v3.9 已大幅演进（Views/ 含 Game、Tutorial、Layout 子目录，新增 StudyHub/Demo/MasterGame/OpeningCoach 等域）

---

## 一、D0 基线核销分片（v39-d4 十二项发现 × 三态标注）

三态口径：已实现 / 部分实现 / 未实现（含"归他维交叉引用"与"维持"两类特殊标注）。

| # | v3.9 发现 | 原级 | 现状三态 | 证据（文件:行） |
|---|----------|------|---------|----------------|
| 1 | FirstLaunchDialog 定义但从未调用（孤岛代码） | P0 | **已实现**（v3.9 Phase1 修复落位） | 集成：src/ChineseChess/App/ChineseChessApp.swift:457-470（sheet 挂载）+:509（触发条件）；iOS 壳 ChineseChessiOSApp.swift:64/:100-113/:417 同链；定义 Views/Tutorial/TutorialView.swift:122 |
| 2 | AchievementChecker.checkAfterPuzzle 定义但从未调用（残局成就孤岛） | P0 | **已实现**（v3.9 Phase1 修复落位） | 调用点：ViewModels/PuzzleViewModel.swift:996-1001（含 "P0-2 fix" 注释）；定义：ViewModels/AchievementChecker.swift:148；回归测试：src/ChineseChessTests/Phase1P0Tests.swift:145-164 |
| 3 | iOS 缺 analysis/coach/openingExplorer 三入口（功能不对等） | P1 | **已实现**（全补齐，形态各异） | openingExplorer：Views/StudyHubView.swift:71/:119（iOS App:152 集成 StudyHubView，原 SheetDestination case 注释退役 ChineseChessiOSApp.swift:27）；analysis+coach：Views/ReplayView.swift:104-120（v4.0 Phase4 Batch2 入口；v5.5.1 fix iOS fullScreenCover）+ ReviewCard 联动（ChineseChessiOSApp.swift:353-356/:386-387）；段位门禁同步在位（见链路 7） |
| 4 | 每日挑战 7/10 模式 comingSoon 占位诱导 | P1 | **部分实现**（v4.0 设计内收敛，诱导性已消除） | 白名单：Views/DailyChallengeView.swift:21-24（playableModes 恰 6 项）+:34（仅渲染白名单）+:43（"更多模式敬请期待"文案 daily.view.moreModesComingSoon）；枚举 10 case 含旧中文 rawValue 兼容解码 Models/DailyChallenge.swift:21-45；账目测试锁定 src/ChineseChessTests/DailyChallengeIntegrationTests.swift:28-40（"敬请期待模式: 4 种"+总账 10）；未实现 4 模式（materialAdvantage/defendChallenge/comboKill/horseOnly）全 src 零实现代码 |
| 5 | UI 层 i18n 硬编码 ~38 处（TutorialView 25 处为主） | P1 | **归⑥维交叉引用**（Eric 主查，本维不重复核销） | v39-d4 原文记录；D5I18nAuditVerificationTests.swift / I18nKeyCompletionTests.swift 测试面在 |
| 6 | 残局 guided 走错回退文案未启用（StatusBarView TODO） | P2 | **部分实现**（机制在、集成缺） | TODO 原样：Views/StatusBarView.swift:22（"待 PuzzlePlayView 集成后启用"）；走错机制已落地 ViewModel 层：PuzzleViewModel.swift:87（wrongMove 态，0.8s 自动回退）；失败重试按钮：PuzzleSelectView.swift:979/:1053（common.retry）；StatusBarView 实例化全 src 仅 ChineseChessApp.swift 一处，残局界面确未集成 |
| 7 | 开局树收藏持久化集成不确定 | P2 | **部分实现**（门禁框架在、功能链不存在） | UnlockedFeature.swift:17/:32/:47/:62/:79（openingTreeFavorite 棋圣门禁五处枚举映射，:47 注记 v3.7.2 isImplemented=true）；但全 src favorite 定性 grep：UI/持久化层**零命中**（OpeningExplorerView.swift 无收藏 UI；PlayerProfile.swift 无收藏字段；git log -S favorite 该文件无历史）——isImplemented=true 与现状矛盾，见新发现 P3-3 |
| 8 | CoachModeOverlay 对弈中未集成 | P2 | **部分实现**（定位已变更，原缺口被新体系覆盖） | 现用途：Views/CoachSessionView.swift:79-83（复盘教练步进提示卡）；ChessBoardView/BoardView/CoachGameView 均 0 引用（逐文件计数法核实）；"对弈中即时教练"职能已由开局教练 CoachGameView 承担（B3 Step3：书谱即时+引擎补充双阶段评估、准确率进度条、走法光环，Views/CoachGameView.swift:8-30） |
| 9 | Pikafish C API 深度测试不足 | P2 | **维持**（归⑤维/测试域交叉，本维静态不展开） | — |
| 10 | 金币经济系统未实现 | P3 | **维持**（设计文档标记 optional，非缺陷） | — |
| 11 | 领域语言 i18n 策略未定案 | P3 | **归⑥维交叉引用** | — |
| 12 | EloBaselineTests Intel 超时 | P3 | **维持**（已知环境限制，测试铁律在案） | 项目 DEVTEAM.md/AGENTS.md 测试规则（禁全量 xcodebuild test） |

### phaseb-summary §四 修复计划（18 项）中②维功能面交叉核销

| # | 修复任务 | 核销结论 | 证据（文件:行） |
|---|---------|---------|----------------|
| 3 | FirstLaunchDialog 集成 App 入口 | **已核销** | 同上表 1 |
| 4 | checkAfterPuzzle 调用集成 | **已核销** | 同上表 2 |
| 8 | 复盘分析引擎回退时显示错误提示 | **已核销** | ViewModels/AnalysisViewModel.swift:32（消息属性）+:139/:227（引擎不可用时置 L10n analysis.engineUnavailable）；消费：Views/AnalysisView.swift:153/:338 |
| 11 | 认输功能 | **已核销** | ViewModels/GameViewModel.swift:429 confirmResign（:422 MARK 认输）+ Views/ToolbarView.swift:100-107（确认 alert 三键）+:140-149（按钮+无障碍标签）+:297（v6.4 C1 入溢出菜单） |
| 12 | 棋盘 AI 思考视觉指示 | **已核销** | Views/ToolbarView.swift:43-45（ProgressView + game.thinking 文案）+:88-91（isThinking onChange 联动+超时 Task 管理）；门控 Views/ChessBoardView.swift:310-311（走子禁用条件含 !isThinking） |
| 13 | 每日挑战占位模式缩减 | **已核销** | 白名单方案落地（同上表 4） |
| 16 | CoachSessionView 增加上一步按钮 | **已核销** | Views/CoachSessionView.swift:169（backward.end.fill 回到开局）/:175（chevron.left 上一步）/:186（chevron.right 下一步） |

---

## 二、八链路走查（v39-d4 链路追踪法 2.0）

> 每链按"入口 → 逻辑 → 反馈 → 数据"四段取证；行号均为 HEAD=1cfd109 实态。

### 链 1：对局链（含长将/困毙/子力判定）— 判定：完整 ✅

- 终局判定主函数：ViewModels/GameViewModel.swift:735 checkGameState()，判定序：
  1. 将死：:737-745（MoveValidator.isCheckmate → 胜负 + 音效二选一，注释明确不叠加）
  2. 困毙：:746-752（isStalemate → **无子可动方判负**，注释"中国象棋规则：不是和棋"——规则正确）
  3. 长将判负：:754-773（detectPerpetualCheck :830；阈值 6 :117-118；**优先于三次重复判和**，注释明确同循环双触发时判长将负；首次触发解释弹窗 :765-769，UserDefaults 防重 + L10n key game.perpetualCheckMessage）
  4. 长捉判负：:776-787（detectPerpetualChase :854；阈值 6 :119-120，v4.0 Phase 6；同样优先于重复判和）
  5. 三次重复判和：:789-794（positionFingerprints 计数）
  6. 50 回合规则：:796-801（halfmoveClock ≥100 判和）※1
- L10n 抽验：game.perpetualCheckMessage / game.perpetualChaseMessage 两 key 在 Localizable.xcstrings:6101/:6069 实存 ✅
- 教练通道隔离（T-1021 修复后基线态）：GameViewModel.swift:248-261（人类 movePiece 与教练 makeCoachMove :254 共用私有 applyMove :261；执方门剥离注释在位）——与 5ce0fa2 修复及 T-1021-OC-01 验收（8/8 套件）一致
- 终局 UI：GameOverOverlay 双端挂载（ChineseChessApp.swift:428 / ChineseChessiOSApp.swift:94）
- 观察项（P3-1）：**子力不足自动判和无实现**（全 src 无 insufficientMaterial 判和逻辑；子力词命中均为评估权重/残局数据域）。中国象棋竞赛规则无强制子力判和条款，判和依赖双方同意/裁判，故记录为观察项而非缺陷

### 链 2：残局链 — 判定：完整 ✅

- 宿主：Views/PuzzleSelectView.swift:709（@State viewModel）/ :737（PuzzleViewModel(puzzle:isDailyChallenge:) 构造）
- 双模式：PuzzleViewModel.swift:7-8（guided/freePlay）；:97（按 puzzle.effectiveMode 初始化）；:199-220（guided 走对/走错判定；超出 solution 范围按 freePlay 处理）；:122（solutionDegraded 降级保护门）；:331（guided AI 防守按 solution 走棋）
- 走错反馈：:87（wrongMove 态 0.8s 自动回退后回 playing）；失败态重试：PuzzleSelectView.swift:979/:1053
- 完成回调：PuzzleViewModel.swift:996-1001（成就检查，见 D0 表 2）
- 解法回放：PuzzleSelectView.swift:744（savedRecord → ReplayView）
- 章节制入口：ChapterSelectView.swift:27/:42（destination-based NavigationLink → PuzzleDemoView / PuzzleSelectView(chapter:)）

### 链 3：复盘分析链（v6.3.1 修复后状态）— 判定：完整 ✅

- 引擎回退提示（v3.9 D2-P1-4 修复核销）：AnalysisViewModel.swift:32/:139/:227 → AnalysisView.swift:153/:338 消费展示（用户可见，非静默失效）
- 入口面：macOS 直达 sheet（ChineseChessApp.swift:660 AnalysisView(record:)，.analysis case :170/:336 toolbar 按钮）；回放页入口（ReplayView.swift:110/:114；iOS fullScreenCover :108-115 v5.5.1 fix，macOS sheet 最小 600×700）
- FEN 可选中复制：ReplayView.swift:95-105（textSelection(.enabled)）

### 链 4：教练链（T-1021 修复后状态）— 判定：完整 ✅

- 执方门修复态：GameViewModel.swift:248-261（见链 1）
- 复盘教练：CoachSessionView.swift:79-83（CoachModeOverlay 步进提示）+ :169-186（回放控制三键含上一步）
- 对弈教练（开局教练 B3 体系）：CoachGameView.swift:8-30（双阶段评估：书谱即时+引擎补充；准确率进度条；退出确认；结果卡片；走法光环 glowQuality）；选局入口 OpeningCoachSelectView（StudyHubView.swift:85/:133）
- 入口面：macOS toolbar（ChineseChessApp.swift:323 buildGameRecord → .coach）+ sheet（:665）；iOS ReviewCard 联动（ChineseChessiOSApp.swift:353-356 → :386-387 sheet）+ ReplayView.swift:120
- 段位门禁：aiCoach=国手（UnlockedFeature.swift:20/:31）
- 测试面：CoachExplainerPhase3Tests（60 用例）/ CoachModeOverlayTests / B3S1OpeningCoachTests / B3S2OpeningCoachStrategyTests（T-1021-OC-01 批 8/8 套件验收在案）

### 链 5：开局库/探索器链 — 判定：完整 ✅（v3.9 P0-2 已修复）

- v3.9 P0-2（棋盘空白+路径递归错误）修复核销：OpeningExplorerView.swift:13（真实 Board 初始化）+ :467-469（**OpeningBoardPreview(board:) 实体渲染**）+ :326/:605（**node.pathFromRoot()** 根到节点路径，替代旧 walkPath 递归）+ :584/:602（Board(fen:)/Board(snapshot:) 重建）
- 服务层：Services/OpeningExplorerService.swift:65-195（rootMoves/expandChildren/matchOpeningName/searchByMoveSequence/searchByOpeningName/buildNodePath 六函数齐）
- 入口：StudyHubView.swift:71/:119（双 section 挂载）
- 搜索联动：:627-635（searchByMoveSequence → 路径回放）
- 收藏缺口：见 D0 表 7 与新发现 P3-3

### 链 6：每日挑战链 — 判定：6/10 可玩（设计内收敛）✅

- 模式模型：Models/DailyChallenge.swift:21-45（10 case CaseIterable；init(from:) 兼容旧中文 rawValue——老存档不炸）
- UI 面：DailyChallengeView.swift:21-24（playableModes 白名单 6 项：endgamePuzzle/timeBlitz/masterChallenge/endgameStart/solveMate/cannonOnly）+ :34（仅渲染白名单）+ :43（moreModesComingSoon 文案）+ :280-292（switch 六分支 + default: break 防御）
- 当日模式：:137（manager.todayChallengeMode()）；子模式载入 :207/:223/:238（loadChallenge）
- 测试锁定：DailyChallengeIntegrationTests.swift:28-40（敬请期待 4 种 + 总账 10 断言）
- ⚠️ 小瑕疵（P3-4）：:27 注释"Q4: 三种可玩模式"与实态 6 种不同步（注释滞后）

### 链 7：段位成长链 — 判定：完整 ✅（7 级制实态）

- Rank 枚举：Models/PlayerProfile.swift:6-13（student→scholar→juren→jinshi→hanlin→master→sage 七级，升级条件注释：5胜/15胜/30胜+5残局/50胜+10残局/100胜+20残局/200胜+40残局）；:19-25 旧中文 rawValue 兼容解码
- 升级通知链：Models/Achievement.swift:6（rankPromoted Notification.Name）+ :224（发布点）；ChineseChessApp.swift:479（onReceive）+ :635（RankUpView）；iOS 壳 :334/:390 同链 ✅ 双端齐
- 门禁矩阵：UnlockedFeature.swift:13-25（11 项）+ requiredRank 全映射 :28-40 + isImplemented 全 true :43-54
- ⚠️ 交叉注记（P3-5→归①维）：本计划 §2.2 记"v6.0 统一 10 级段位"，代码实态为 **7 级** Rank——②维如实记录代码实态，文档-代码表述差异请①维矩阵核对（可能系"10 级"表述指难度档位或含子段位的口径差异）

### 链 8：导入导出链 — 判定：完整 ✅

- 导出：Services/PGNExporter.swift:27（export）/:67（exportBatch）/:73（exportBatchSafe 含失败计数）/:89（exportSafe throws）
- 导入：Services/PGNImporter.swift:71（parse→ImportResult）/:145（parseSingleGame）/:231（parseTags）/:260（parseMoves）/:370（parseResult）/:381（parseDate）
- 错误反馈：ViewModels/ImportViewModel.swift:9（failure(String) 态）+:16（fail()）+:33（import.noValidContent L10n 文案）
- 门禁：gameRecordExport=翰林 / gameRecordImport=学童（无限制）（UnlockedFeature.swift:18-19/:37-38，v3.7.0 降档注释在位）
- 残局解法回放复用：PuzzleSelectView.swift:744

---

## 三、用户路径覆盖审查（空态/错误态/反馈面）

| # | 用户操作 | 入口位置 | 反馈/保护 | 证据（文件:行） | 判定 |
|---|---------|---------|----------|----------------|------|
| 1 | 分析时引擎不可用 | AnalysisView | 用户可见提示 analysis.engineUnavailable | AnalysisViewModel.swift:139/:227 + AnalysisView.swift:153/:338 | ✅ |
| 2 | 导入无效内容 | ImportViewModel | failure 态 + L10n 文案 | ImportViewModel.swift:9/:16/:33 | ✅ |
| 3 | 首次触发长将判负 | GameViewModel | 解释弹窗（一次性）+ L10n | GameViewModel.swift:765-769 + xcstrings:6101 | ✅ |
| 4 | 认输 | ToolbarView | 确认 alert（含取消/确认/说明） | ToolbarView.swift:100-107 | ✅ |
| 5 | AI 思考中 | ToolbarView/ChessBoardView | ProgressView+文案+走子禁用 | ToolbarView.swift:43-45/:88-91 + ChessBoardView.swift:310-311 | ✅ |
| 6 | 点击未实现挑战模式 | DailyChallengeView | 白名单不渲染 + "敬请期待"文案兜底 | DailyChallengeView.swift:21-24/:34/:43 | ✅ |
| 7 | 残局 guided 走错 | PuzzleViewModel | 0.8s 自动回退 + 失败 retry 按钮 | PuzzleViewModel.swift:87 + PuzzleSelectView.swift:979/:1053 | ✅ |
| 8 | 残局走错状态栏文案 | StatusBarView | **TODO 悬置，未集成残局界面** | StatusBarView.swift:22 | ❌ P2 |
| 9 | 段位升级 | 双端 App | RankUpView 弹窗 + 竟态防护（pendingReviewRecord） | ChineseChessApp.swift:479/:635 + iOS:334-341/:390 | ✅ |
| 10 | 开局树收藏 | — | **功能不存在**（仅门禁枚举占位） | UnlockedFeature.swift:17 vs 全 src 零命中 | ❌ P3 |

缺失项汇总：#8（P2，v3.9 P2-1 原样悬置）、#10（P3，功能移除/未落地待定性）。

---

## 四、本轮新发现（增量池）

> v3.9 基线 12 项之外，本轮走查新登记 + §七 协作位移交核验并入。无 P0；P1×2（协作位移入，实证核验属实）。

| # | 发现 | 级别 | 证据 | 整改建议（供 P3 打包） |
|---|------|------|------|----------------------|
| **P1-N1** | **PuzzleViewModel boardFingerprint X-碰撞（修复不对称）**：五种子类折叠为"X"致三次重复/长将检测假阳性域 | **P1**（协作位移入，本维实证核验属实） | PuzzleViewModel.swift:556-557（`general→K/chariot→R/其余→X` 映射在位）+ checkDraw :561-572 消费该指纹判和；对照 Game 侧已换完整 FEN（GameViewModel.swift:815-817 "P0-1"注释）；源文档 draw-detection-analysis.md §2.3 自评"应在 P0 中最优先修复（已有 bug 影响线上用户）" | 与 Game 侧同构换 FENParser.generate（含走子方）；P4 验证标准见 P1-N4 测试补齐 |
| **P1-N2** | **AI 飞将搜索层 bug（known-issues 2026-07-30 active·未修复）**：hard 难度 AI 可输出飞将（将帅对脸）非法走法 | **P1**（协作位移入，本维核验属实） | known-issues.md:29-34（现象/根因：MoveValidator.isLegal 正确但搜索层未调用）；v3.9 口径=规则错误输出入主流程 | AI 搜索层走法生成后统一过 MoveValidator.isLegal 过滤；P4 补飞将回归用例 |
| P3-N1 | CheckmateSearch maxResponses=8 排序剪枝假阳性 residual（v3.9 D1 P1-6） | P3 | CheckmateSearch.swift:71-74（prefix(8) 剪枝，代码注释自认） | 杀法应对方全量校验或提高上限；边缘场景非阻断 |
| P3-N2 | 和棋检测测试覆盖结构性盲区（详见 §七.4） | P3（测试债，随 P1-N1 修复同步消除） | PuzzleViewModel.checkDraw/boardFingerprint 全测试目录零触达；DrawDetectionRealTests.swift:77-78/:91-93/:131-132 LogicReview 注释式测试 + :170-178 自留 TODO 未落地 | X-碰撞修复同批补 Puzzle 侧真覆盖 + LogicReview 三测试改真实驱动 |
| P3-1 | 子力不足自动判和未实现（Game 侧；Puzzle 侧有粗略版 checkDraw:568-570 无进攻子力判和） | P3（观察项） | 全 src 无 insufficientMaterial 判和；GameViewModel.swift:735-801 判定序无此分支；两侧不对称 | 中国象棋竞规无强制条款；如需对齐两侧统一策略，P4 可选项 |
| P3-2 | iOS 无 AnalysisView 直达入口（需经 ReplayView 中转两跳；macOS toolbar 直达） | P3（打磨） | AnalysisView 实例化仅 ChineseChessApp.swift:660 + ReplayView.swift:110/:114；iOS SheetDestination 无 analysis case（ChineseChessiOSApp.swift:17-27） | iOS 可在 StudyHub 或工具栏加直达项；现状可用非阻断 |
| P3-3 | openingTreeFavorite 门禁 isImplemented=true 与 UI 零实现矛盾 | P3（需定性） | UnlockedFeature.swift:17/:47（v3.7.2 注记"已实现"）vs 全 src favorite UI/持久化零命中（含 git log -S 无历史） | ①维矩阵核对文档承诺；若已决策移除收藏则门禁枚举与 RankPrivilege 展示面同步清理；若遗漏则补实现 |
| P3-4 | DailyChallengeView:27 注释"三种可玩模式"滞后实态 6 种 | P3（打磨） | DailyChallengeView.swift:27 vs :21-24 | 注释随码修 |
| P3-5 | 计划文档"v6.0 统一 10 级段位" vs 代码 7 级 Rank 表述差异 | 归①维 | PlayerProfile.swift:6-13（7 case） | ①维矩阵核对口径（难度档位 vs 段位层级），非②维缺陷 |

---

## 五、测试用例映射表（链路 ↔ 既有测试套件）

> @Test 总数 2961（src/ChineseChessTests/ 100+ 文件）。按链路给代表套件（轻入场口径，不逐用例展开）：

| 链路 | 代表测试套件（文件） |
|------|---------------------|
| 对局规则/终局 | GameViewModelTests / DrawDetectionTests / DrawDetectionRealTests（⚠️ 覆盖真伪注记见 §七.4：LogicReview 三测试为注释式 + Puzzle 侧零覆盖） / GameResultTests / EdgeCaseTests / BoardTests / ChessClockDirectionTests |
| 教练 | CoachExplainerPhase3Tests / CoachExplainerSafeCaptureTests / CoachModeOverlayTests / B3S1OpeningCoachTests / B3S2OpeningCoachStrategyTests / SelectionConsistencyTests |
| 残局/成就 | Phase1P0Tests（checkAfterPuzzle 存在性+签名 :145-164）/ Batch3V39Tests |
| 每日挑战 | DailyChallengeIntegrationTests（模式账目 :24-40） |
| 分析/评估 | AnalysisPersistenceTests / EvalChartScaleTests / EvalWeightsTests |
| 开局/名手 | B3S3RubyFixTests / B3S4MasterGameSearchTests / OpeningPracticeStore 系 |
| 导入导出/FEN | FENBoundaryTests / FENRebuilder 系 / Bug4FENRenderTests |
| 段位/难度 | DifficultyV21Tests / DifficultyV42Tests / AchievementChecker（Phase1P0Tests 内） |
| i18n | D5I18nAuditVerificationTests / I18nKeyCompletionTests（⑥维交叉） |
| iOS 平台 | IOSToolbarAdaptationTests |

---

## 六、结论

1. **②维总判定：核心用户链路完整。** 八链路（对局/残局/复盘分析/教练/开局探索/每日挑战/段位成长/导入导出）全部走通，终局判定序完整且符合中国象棋规则（困毙判负、长将优先于重复判和、50 回合判和※1），T-1021 教练执方门修复态与 v6.4.2 定版一致。
2. **D0 基线核销：v39-d4 十二项中，2×P0 全部核销（已实现）；P1 两项实质核销（iOS 入口全补齐、每日挑战设计内收敛）、一项归⑥维；P2 四项中认输/思考指示/上一步/占位缩减全核销，StatusBar TODO 部分实现，收藏链与 overlay 集成为部分实现/定位变更；P3 三项维持或归⑥维。phaseb §四 抽取的 7 个②维功能面任务全部核销。**
3. **新发现池：P0=0、P1×2（协作位移入并经本维实证核验：X-碰撞修复不对称 P1-N1、AI 飞将搜索层 P1-N2）、P2=1（StatusBar 残局文案 TODO 悬置，承自 v3.9 P2-1）、P3×7（观察项 5 + 协作位移入 2）。**
4. **v3.9 → v6.4.2 功能面演进结论：** 基线报告的两大 P0 孤岛（FirstLaunchDialog/checkAfterPuzzle）均已修复并带回归测试；v4.0 系（学习中心 StudyHub/开局教练/每日挑战收敛/长捉判负）、v5.5.1（iOS 分析空间）、v6.x（工具栏 C1 溢出/教练执方门）增量均在位且有测试面覆盖。
5. 本报告全部结论带文件:行 出处；抽验失效条目按规范整条作废回炉（§五.4）。

---

## 七、协作位移交项核验（Cody 分片，D2 交联，2026-10-21）

> Cody 交联通报 4 项（证据底稿：docs/audits/t1023-dim1-shard-cody.md §六/§九 + t1023-dim5-shard-cody.md §二）。本维逐项独立实证，4/4 吻合；处置如 §四。

1. **X-碰撞（→P1-N1）**：本维独立复读 PuzzleViewModel.swift:555-573——映射行 :556-557 与 checkDraw 消费 :561-572 实证在位；Game 侧对照 GameViewModel.swift:815-817（完整 FEN 含走子方）。**修复不对称成立**。附注：Puzzle 侧 checkDraw 另含无进攻子力判和分支（:568-570），Game 侧无——子力判和两侧不对称一并记入 P3-1。
2. **AI 飞将（→P1-N2）**：known-issues.md:29-34 active·未修复实证（现象/根因/影响面三段在案）。
3. **maxResponses=8（→P3-N1）**：CheckmateSearch.swift:71-74 实证（排序剪枝 prefix(8)，v3.9 D1 P1-6 residual）。
4. **和棋检测测试覆盖真伪（FINAL-012#8 测试面，本维 D0 审计结论）**：**部分伪覆盖，判词如下**——
   - 真覆盖面：FEN 指纹函数本体（DrawDetectionTests.swift:12-46 真调 FENParser.generate）、newGame 状态清空（DrawDetectionTests:258 + DrawDetectionRealTests:28-37 真实 VM 实例）、MoveValidator 三检测（DrawDetectionRealTests:39-76 真实驱动）；
   - **伪覆盖面（LogicReview 注释式）**：DrawDetectionRealTests.swift:77-78（halfmoveClock）/ :91-93（三次重复）/ :131-132（长将）——断言体为"代码审查确认逻辑正确"+行号引用（引用行号停留在旧版本 205-636 区间，现 checkGameState 已在 :735+，注记本身已失锚）；
   - **零覆盖面**：PuzzleViewModel.checkDraw/boardFingerprint/positionHistory 全测试目录零触达（grep 全 ChineseChessTests 仅命中 Game 侧）——**X-碰撞 bug 存活至今与该盲区直接对应**；
   - 自认证据：DrawDetectionRealTests.swift:170-178 注释块"建议在 GameViewModel 添加 internal test 辅助函数"——真覆盖缺口被测试作者自留 TODO 承认且未落地。
   - 处置：入 P3-N2；P1-N1 修复的 P4 验证标准 = Puzzle 侧指纹换 FEN 后补三次重复/长将真驱动用例 + LogicReview 三测试改真实断言。

---

## 更正脚注

**※1（50 回合判和阈值域，丹妮裁决 2026-10-22；Alex D7 更新③裁决执行确认 10-22 转达）**：本报告链 1 与结论 1 所述"50 回合判和"（GameViewModel.swift:796-801 区间，Alex 更新③给精确落点 **:801-804**；halfmoveClock ≥100 判和）系如实记录现行实装态；该阈值经丹妮裁决判定为**对国际象棋 50 步规则的误套**——60 步规则裁决已执行：**采纳 120 半着处方**（draw-detection-analysis.md §2.8，《中国象棋竞赛规则》自然限着口径，60 回合×2），现行 PRD/实装 100 半着判 **P1 规则合规整改项**（落点 GameViewModel.swift:801-804，随 P3 A 包呈洪涛确认；规则语义由 Alex 随 D7 呈洪涛确认）。本报告 v1.0/v1.1 核验执行时参照源为 PRD（非外部权威规则），核验执行本身无过失，本脚注仅修正参照源层级；正文结论行按转办要求不作改动（Eric 正文零触碰纪律同构适用）。

---
*审计红线遵守声明：全程零代码改动、零编译、零测试批、零 commit、零台账写入；仅只读取证 + 本报告落盘。*
