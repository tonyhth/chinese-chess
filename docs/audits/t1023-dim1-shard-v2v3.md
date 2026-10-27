# T-1023-OC-01·P2·D1 分片 — ①文档符合度·v2/v3 系片

> 角色：Eric（分片）| 分片主笔：Alex（t1023-dim1-doc-compliance.md v0.3 类4 v2/v3 系片行）| 日期：2026-10-20 | 树态锚：m1 @ 1cfd109（v6.4.2-1-g1cfd109），零改动零编译
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §三类4/§五四态定义；Alex 分片定义："difficulty 早期系、tutorial-redesign、ui-layout 系、ios-toolbar-adaptation ~15 件"
> 方法：文档→实现单向对照，轻入场（每件头读+定点代码核验，未全量通读未全库扫描）

## 一、分片界定

**核心 9 件（四态全评）**：difficulty-system-v2.md、tutorial-redesign.md、ui-board-layout-optimization.md、ui-entry-points-design.md、ui-layout-polish.md、ui-layout-redesign-v4.md、ui-sidebar-redesign.md、ui-sidebar-v3-design.md、ios-toolbar-adaptation.md

**边界件（不评四态，归属注记）**：
- difficulty-system-v2.2-draft.md：**类3 定稿件（Alex 锚件），本片仅作 D6 规格锚只读引用**，不重复入矩阵
- difficulty-differentiation-analysis.md / lvl2-think-time-evaluation.md / calibration-plan-v3.md：校准域=T-1022 边界（计划 §7.1），归⑤维
- master-game-demo-entry.md / puzzle-demo-entry.md / opening-book-expansion.md / puzzle-difficulty-analysis.md / puzzle-difficulty-rework.md：v4/v5 系片（候派 Cody）
- draw-detection-analysis.md / board-thread-safety-fix.md / ai-engine-improvements.md / ai-search-optimization-phase3.md / engine-gap-analysis-elephanteye.md / bayeselo 系：专项片（候派 Cody）
- **auto-demo-design.md：归属待裁**——docs/archive/v2.x/v2-common-auto-demo.md 系其 v2.x 血统姊妹件，本片或 v4/v5 片均可立，建议 Alex 收敛（裁决建议：其现行实现面已并入 v6.4 演示流，倾向 v4/v5 片轻对照即可）

## 二、四态矩阵（9 件）

四态：已实现 / 部分实现 / 未实现 / 文档过时（实现正确且文档陈述已失效）

| # | 文档 | 版本/日期 | 承诺要点（doc 锚） | 四态 | 实现证据（code/commit） | 处置建议 |
|---|---|---|---|---|---|---|
| 1 | difficulty-system-v2.md | v2.1 2026-08-10 | 数据驱动校准/单调递增/协会等级命名（L11-18） | **文档过时** | 被 v2.2-draft 锁数链→v4.2 remap→v6.0 十级→S2（T-1013-OC-03）→v6.4.1 段位制换轨逐代取代；设计原则延续于 Enums.swift:190（s2Spec 分离注释）+ xcstrings difficulty.lvl1-10 | P3 归档批标注 superseded→v2.2-draft |
| 2 | tutorial-redesign.md | v3.2 2026-08-03 | 12课=2 info+7 走法+3 战术（L7/L24-33）；FEN 合法；hint 每步独立 | **已实现**（形态演进注记） | TutorialViewModel.swift:65（"12 课：2 入门+7 走法+3 战术"原文）、:232（v6.4 C3-5 进度归满）；Views/Tutorial/ 6 文件；112 tutorial.*+20 chapter.* 键；引导链 FirstLaunchDialog（ChineseChessApp.swift:100-104）；FEN 面 tutorial-fen-audit.md+TutorialFENRedGeneralTests 维持 | 无动作；v6.4 并入引导流为形态演进非缺陷 |
| 3 | ui-board-layout-optimization.md | v1.3 2026-06-13 | cellSize ≥55 目标/iPad 检测（L3） | **文档过时** | BoardSizing.swift:15 maxCellSize=200（:17 为另一平台分支 80）远超 55；布局体系入 LayoutSpec 单源（Views/Layout/LayoutSpec.swift:10；v6.4 commit cac76e2/2886cd5） | P3 归档批 |
| 4 | ui-entry-points-design.md | v1.1 2026-07-15 | P0-3/4/5/6 四入口（引擎分析/教练/开局树/残局章节）经 SheetDestination+段位门禁接入（L13-19/L44-47） | **已实现**（形态演进注记） | SheetDestination 在位 ChineseChessApp.swift:155/:201；门禁 OpeningExplorerView.swift:37（isFeatureUnlocked+DeveloperMode，v5.5.9 注释）；入口经 v6.4 sidebar 化演进（commit 0c69846 OpeningCoachSelectView、a3f77b0 PuzzleSelectView）；Route 与 SheetDestination 哲学一致（StudyRoute.swift:3） | 无动作 |
| 5 | ui-layout-polish.md | v1.1 2026-08-10 | DemoBoardView 居中/sidebar 收窄/控制条紧凑（L18-46） | **文档过时** | 播放页已入 v6.4 C3 重设计（commit cac76e2 DemoControlBar 重头钮、2886cd5 P3/P4 三 tab 化） | P3 归档批 |
| 6 | ui-layout-redesign-v4.md | v4.2 2026-08-10 | 选局/看棋分离、去 sidebar（L20-27 原则 2） | **文档过时**（方向被取代） | v6.4 走共享 sidebar 基建+选择 View sidebar 化（commit a3f77b0/0c69846/5b492ad P5 学棋中心）——与本文档原则 2 方向相反 | **P3 文档修批显式标注 superseded**（防后人按 v4.2 原则误判现行架构为回归） |
| 7 | ui-sidebar-redesign.md | v2.1 2026-08-10 | ScrollView+Button 首选治 sidebar 文字不可见（L8-12 修订链） | **文档过时** | 演进链 v2.1→v3 方案（ui-sidebar-v3-design.md）→v6.4 共享 sidebar 基建 | P3 归档批 |
| 8 | ui-sidebar-v3-design.md | v3.3 2026-08-10 | HStack+GeometryReader 弹性、maxCellSize 200（L34-35） | **文档过时**（部分吸收） | maxCellSize=200 落地 BoardSizing.swift:15 ✓；自适应体系被 v6.2/v6.4 AdaptiveRailState+LayoutSpec 单源取代（cac76e2：弃 ManagedSplitView 改 AdaptiveRailState、LayoutSpec.compactWindowMin） | P3 归档批（maxCellSize 承诺落地后随体系演进） |
| 9 | ios-toolbar-adaptation.md | v3（无日期头） | iOS icon-only 44pt+难度 Menu+borderless（L16-27） | **已实现**（后经 T-1020-OC-02 演进） | ToolbarView.swift:114 #if os(iOS)、44×44 frame 多处（:121-216）、Menu（:190/:342）、menuStyle(.borderlessButton)（:358）；v6.4 C1 溢出菜单（:297；T-1020-OC-02 A+B done 5dd42cf/29adeb8，计划 §7.1 在案） | 无动作 |

**四态统计**：已实现 2（均带形态演进注记）/ 文档过时 6（其中 1 件需显式 superseded 标注）/ 部分实现 0 / 未实现 0

## 三、分片发现项

1. **P3｜ui-layout-redesign-v4.md 方向相反风险**：该件"选局/看棋分离、去 sidebar"原则与 v6.4 现行"共享 sidebar 基建+选择 View sidebar 化"架构方向相反，且未标注被取代——P3 文档修批必须显式写明 supersession 关系，否则 P4 实施者可能按 v4.2 原则把 sidebar 化当回归"修"掉（唯一带误导风险的发现）｜doc: docs/design/ui-layout-redesign-v4.md L20-27 ↔ commit a3f77b0/0c69846
2. **P3｜过时文档集中归档批**：本片 6 件"文档过时"（#1/3/5/6/7/8）与 Alex 已登记的 r3-07 头部日期笔误同批，建议 P3 文档修批开一个 v2/v3-v4 系归档子批一次清（含各件头部加 superseded 指针）
3. **D0 注记（本片）**：无 v3.9 直接发现项挂接（v3.9 审计点为当时现行设计，本片多件在盘但未入 78 项发现池）；v5.6.1 缺口交集=零——v5.6.1-full-requirement-audit.md:18 五模块 100% 通过含学习模块；唯 :18 点名 puzzle-difficulty-rework.md "完全未落地"，该件归 v4/v5 系片（Cody），本片仅转交指针

## 四、与 dim1 主矩阵衔接

- 本片矩阵供 Alex 并入 docs/audits/t1023-dim1-doc-compliance.md 类4 "v2/v3 系片"行（候派→已交）
- 边界件归属两处候裁：auto-demo-design.md（本片 or v4/v5 片）、puzzle-difficulty-rework.md 落地复查（v4/v5 片责任+本片转交的 v5.6.1 L18 指针）

---
> 报告完。零 commit 零台账写入。Eric 2026-10-20