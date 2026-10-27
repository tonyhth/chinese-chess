# T-1023-OC-01·P2·D1 — Cody 分片底稿（v4/v5 系片 + 专项片）

> 角色：Cody（coder｜D1 分片 + D0 分片核销 + D5 协作 0.5）| 日期：2026-10-21 | 版本：v1.0（分片交稿态，2026-10-21 22:xx）
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §三/§五/§六；Alex 矩阵 docs/audits/t1023-dim1-doc-compliance.md v0.3 分片口径（"候派（Cody）"两片）
> 纪律：只检查不改码不编译不打包；轻入场定点进入；无出处结论无效；定稿件零触碰；本件为分片底稿，供 Alex 并入 t1023-dim1-doc-compliance.md 矩阵与 t1023-dim5-perf-stability.md
> **归档定位（2026-10-21）**：结论行集已并入 t1023-dim1-doc-compliance.md v1.1 尾节「类 4 v4/v5 系+专项分片并入」；本件降级为证据链底稿（承诺面/现态证据/覆盖缺口 §九），随矩阵维护不独立演进
> 证据局限声明：本机无目录列举/全文检索工具，文件发现走引用链+定点探测；puzzles.json 为单行 275,401B JSON，读取仅达头部 ~44KB（≈前 90 局采样面）——凡全量统计类结论一律标注采样口径，不做超出处断言

---

## 一、分片清单与覆盖（doc 存在性亲证）

| # | 文件（docs/design/ 除注明外） | 行数 | 族 |
|---|---|---|---|
| 1 | puzzle-difficulty-rework.md | 852 | 残局/puzzle |
| 2 | puzzle-difficulty-analysis.md | 136 | 残局/puzzle（rework 前置分析件） |
| 3 | v4.0-analysis-optimization.md | 372 | v4.0 系 |
| 4 | v4.0-daily-challenge-modes.md | 存在待核 | v4.0 系（v4.1-plan §Phase1 引用） |
| 5 | v4.1-plan.md | 505 | v4.1 系 |
| 6 | v5.0-opening-explorer-upgrade.md | 564 | v5.0 系/开局 |
| 7 | v5.0-cross-quality-check.md | 401 | v5.0 系 |
| 8 | opening-book-expansion.md | 905 | opening-book |
| 9 | master-game-demo-entry.md | 724 | master-game |
| 10 | auto-demo-design.md | 1176 | puzzle-demo/演示 |
| 11 | ai-engine-improvements.md | 655 | 专项 AI |
| 12 | ai-search-optimization-phase3.md | 1043 | 专项 AI |
| 13 | board-thread-safety-fix.md | 778 | 专项 线程安全 |
| 14 | draw-detection-analysis.md | 243 | 专项 和棋检测 |
| 15 | engine-gap-analysis-elephanteye.md | 247 | 专项 引擎差距 |
| 16 | bayeselo 系（具体件名候发现） | — | 专项 校准（T-1022 边界：只对照文档承诺） |
| 17 | coach 系（件名候发现；coach-system-design/coach-explainer-design 两猜测名不存在） | — | coach |

> 矩阵口径 v4.0-×6/v4.1-×3：已实定位 4 件（v4.0×2+v4.1×1+analysis 前置）；余件候引用链发现，发现不到的在底稿末尾"覆盖缺口"登记，不做静默遗漏。

## 二、残局族核验（#1+#2，完成）

### 2.1 承诺面（doc 锚）
puzzle-difficulty-rework.md（Alex 2026-06-29，852L，Vera P0×3/P1×6 修复后定稿态）承诺：4维评分重标定（§2，difficulty_recalc.py 工具链 §2.6/附录A）｜56 局和局转 solutionType="draw"（§3）｜hints 440 条分级覆盖 1★-3★（§4，generate_hints.py）｜freePlay 17→3 局分类处理（§5）｜defenderDifficulty 段位 cap P1-3（§5.3）｜effectiveMaxMoves 动态化 P1-5 容错 ×1.5+3（§6）｜category 均衡化 §7。
前置件 puzzle-difficulty-analysis.md（2026-06-28，136L）：数据源锚 src/ChineseChess/Resources/Puzzles/puzzles.json（当时 version 4）。

### 2.2 现态证据（code/data 锚，2026-10-21 静态取证）
- **E1** puzzles.json 现态 = releases/中国象棋-v6.4.2.app/Contents/Resources/puzzles.json（275,401B 单行；v6.4.1 份同字节数）：version **5**，头描述"适情雅趣551局全量 — 棋子类型分类 + **重新评估难度**"；repo 源路径 src/ChineseChess/Resources/Puzzles/puzzles.json（analysis L5 亲证路径；存在性见本节末探针结果）
- **E2** 采样面（头部 44,106 字符 ≈ 前 90 局 sqyq_001-090，1★×29/2★×52/3★×9，subcategory 入门/初级/中级）：hints 非空 **81/90**、空 0（样例 sqyq_001 两条思路提示："红方大优，积极进攻寻找杀棋"/"关键：炮沉底进攻"）；solutionType 字段采样面零出现（默认值省略形态）；solutionMode guided 89、freePlay 0
- **E3** Puzzle.swift（src/ChineseChess/Models/Puzzle.swift）：hints:[String]? 字段（:17）；typeLabelKey 含 "draw"→"puzzle.type.draw"（:97-104）；**FINAL-006 子集 A** effectiveMaxMoves 计算属性（:120-139，freePlay→200 / draw→solution.count+2 / 空→JSON fallback / 常规→solution.count+2）
- **E4** PuzzleViewModel.swift（1095L）：defenderDifficulty（:104-113）stars 直映射 novice/beginner/amateurLow/Mid/High（depth 2-6，注释"v6.0: 新枚举名"）——**无 §5.3 段位 cap**；**FINAL-006 子集 B** draw 守和块（:253-266）走对 solution[0]→success；effectiveMaxMoves 消费点（:271/:534）；**P0-2 fix** checkAfterPuzzle 调用（:996-1001）
- **E5** 工具链产物不存在：scripts/difficulty_recalc.py ✗、scripts/generate_hints.py ✗、data/difficulty_scores.json ✗（定点探测 2026-10-21）

### 2.3 四态结论行（矩阵行格式，供 Alex 并入）

- **[部分实现/P1] FINAL-006 难度重标定：以"非脚本化重评估+代码子集"形态部分落地**｜doc: puzzle-difficulty-rework.md §2（4维模型/§2.6 脚本）/§6.4（×1.5+3 容错）｜code: puzzles.json version5"重新评估难度"+采样面 stars 混布（1★仅 29/90，非机械 110 均布形态）；Puzzle.swift:120-139（FINAL-006 子集 A，容错公式 solution.count+2 与 doc ×1.5+3 取整形不一致=简化落地）；PuzzleViewModel.swift:253（子集 B）｜处置：P3 整改方案把"4维评分模型全量重标定+脚本入库"列为候选项；文档修批将 effectiveMaxMoves 实装公式差异登记
- **[已实现（采样面 81/90）/复核项] FINAL-005 hints：0/551 基线已扭转**｜doc: rework §4（1★-2★ 必须/3★ 推荐，思路提示为主 30 字内）｜code: E1+E2（采样面 81/90 非空、0 空、样例两条符合"讲思路不讲走法"规范）；E3 hints 字段；E5 生成脚本不在库（批量生成链未入库）｜处置：全量覆盖率计数受单行 JSON 读取限制未复核——P4 实测批补一个全量断言（一行 jq/python 即可）；文档修批把 generate_hints.py 工具链要么入库要么从 doc 去引
- **[部分实现/证据受限] FINAL-007 freePlay 缩减+defenderDifficulty 段位 cap：代码面未实现 cap，数据面不可证**｜doc: rework §5（17→3 局三分类）/§5.3 P1-3（max(min(starBased,cap), starBased-1)）｜code: PuzzleViewModel.swift:104-113 直映射无 rank cap；采样面 freePlay 0/90（17 局 freePlay 局域分布未采样）｜处置：P3 整改候选（cap 低成本补齐）；数据面全量扫描列 P4 实测
- **[部分实现/证据受限] 56 局和局 draw 转换：代码就绪、数据面未证**｜doc: rework §3（solutionType="draw"+守和文案+maxMoves=10）｜code: Puzzle.swift:97-104 typeLabelKey 支持 draw；PuzzleViewModel.swift:253-266 守和逻辑；采样面（前 90 局=1-3★ 域）solutionType 零出现——56 局 draw 全在 4★/5★ 尾段（doc §3.1 分布），采样盲区，单行 JSON 无法分段读取｜处置：P4 实测批全量断言 draw 计数；如为 0 则本行升级"未实现"并列为 P1 整改
- **[已修复] v3.9 D4 P0-2 残局成就检查孤岛（D0 三态：已修复）**｜doc: v39-d4-feature-completeness.md P0-2（AchievementChecker.swift:136 定义无调用）、v39-phaseb-summary.md §四#4｜code: PuzzleViewModel.swift:996-1001"P0-2 fix"注释+checkAfterPuzzle 调用｜处置：销项
- **[文档过时/候选] rework §5.3 AI 难度枚举面**：doc 用 v6.0 前枚举（.master depth6/.easy 等），实装已切 v6.0 十级枚举（novice/beginner/amateurLow/Mid/High）｜doc: rework §5.3 代码块｜code: PuzzleViewModel.swift:104-113 注释"v6.0: 新枚举名"｜处置：随 P4 文档修批；难度语义等价性（master→amateurHigh 是否同 depth）留⑤维/P4 实测
- **[已实现/轻核] v3.9 D3 P0-2 开局探索器修复+Phase1#2**：开局族文档核验时合并出结论（见 §四 开局族，待补）

### 2.4 残局族覆盖声明
- 全量统计类（hints 覆盖率、draw 计数、freePlay 局数、星级分布）受单行 JSON 读取限制，仅采样面口径，已逐条标注；P4 实测批可一行脚本补齐
- 章节制衔接（v3.6.0-quest-restructure-design.md，docs/archive/）不在本分片（Eric v2/v3 系），不重复开单

源探针：src/ChineseChess/Resources/Puzzles/puzzles.json 存在性=true

---

## 三、v4.1 系（#5 进行中，505L 全读完成，代码核验待补）
- v4.1-plan.md（Alex，"2025-01-29"⚠️头部年份疑笔误，v3 态=坐标系纠正完毕）：Phase1 cannonOnly 文档勘误（代码正确文档错，v4.0-daily-challenge-modes.md:197 已修正——文档内自述）/Phase2 challengeResult 赋值+alert/Phase3 completeChallenge 路径确认/Phase4 iOS 真机验证/Phase5 测试/Phase6 BugFixV3Tests 断言/Phase7 Pipeline 技术债（pikafish quit/init 循环→D5 关联）/Phase8 推 v4.2
- ⚠️ 日期纪律发现候选：v4.1-plan.md 头部"日期：2025-01-29"违反 document-conventions §3（必须 2026）——与 Alex 已登记 r3-07 L4 同族（document-conventions §3 日期纪律），登记候 P4 文档修批
- 待代码核验：GameViewModel challengeResult 赋值路径（Phase2 V-1）、BoardView alert（Phase2）、DailyChallengeManager 注释（Phase3）、PositionAnalyzer.shared 独立引擎引用（Phase7 方案1）

### v4.0-analysis-optimization.md（#3，完成 2026-10-21）

承诺面（doc 锚）：v4.0-analysis-optimization.md（Alex 2026-07-16，v3 态，Luke 裁 B+C 组合）——策略 B 只分析玩家方走法（isPlayerMove/firstMoverColor/playerColorOverride，让先场景覆盖 V-B5/V-B9）+ 策略 C quickClassify 快速预筛（delta≤10cp→brilliant / <30→good，QuickClassifyResult 携带中间结果防重复调用，isQuickResult 来源标记 V-B6/V-B8）+ 进度文案改玩家步数；目标 160s→~72s（§3.4）；测试要点 11 条（§八）。

现态证据（code 锚）：
- AnalysisViewModel.swift（382L）：:47 isPlayerMove(at:)；:123 注释"v4.0 Phase 3 #8: 只分析玩家方走法（策略 B）"；:163/:167（进度计数按玩家步数）；:179（analyzeAll 循环 guard 跳过）；:250/:270/:296（续分析/导出/单步门禁全链消费）；:6 注释"v6.4 P1 并发修复：标 @MainActor——analyzeAll 跨 await 在非主线程写"
- PositionAnalyzer.swift（463L）：:134 actor PositionAnalyzer（"局面分析器（actor，线程安全）"）；:248 quickClassify；:313 analyzeMove 预筛接入；:171 quickClassify 耗时链注释；:397 "与 analyzeMove 共享同一引擎实例，通过 actor 串行化保证安全"

四态结论行：
- **[已实现] FINAL-009 分析性能优化（策略 B+C）：v5.6.1 基线"未实施"已翻转（D0 三态=已修复）**｜doc: v4.0-analysis-optimization.md 全文+v5.6.1-full-requirement-audit.md §三 P2 FINAL-009（"~160s vs ~72s"）｜code: AnalysisViewModel.swift:47/:123/:179；PositionAnalyzer.swift:248/:313｜处置：D0 销项；~72s 达标实测属 P4（本轮不跑 benchmark，两栏口径列"需 P4 实测确认"）
- **[已实现/形态演进] v3.9 §五"复盘并行分析（PositionAnalyzer actor 重构）"建议**：以 actor 串行化形态落地（非并行加速）｜doc: v39-phaseb-summary.md §五（"需重构 PositionAnalyzer actor"）｜code: PositionAnalyzer.swift:134/:397｜处置：登记；真正并行化仍列 P3 改进候选（actor 串行=安全但单引擎串行）
- **[附带/D5 候选] AnalysisViewModel.swift:6 v6.4 P1 并发修复在案**：⑤维稳定性链"已知-已修"证据｜code: AnalysisViewModel.swift:6｜处置：入 D5 底稿

### v4.1 系代码核验（完成 2026-10-21）

- Phase2 **[已实现]**：GameViewModel.swift:145 challengeResult 属性；:347-350 solveMate 即时判定（executeMove 内）；**:987-995 "v4.1 Phase 2: 补全 endgameStart 和 cannonOnly 的 challengeResult 赋值"注释+nil 守卫赋值+completeChallenge 调用**（与 v4.1-plan §2.2 方案代码逐字级吻合）；BoardView.swift:25-30 challenge.success/failure alert binding（复用已有 key 方案如 doc 所裁）
- Phase3 **[已实现/轻核]**：GameViewModel.swift:987 `challengeMode != nil && gameState != .playing` 覆盖块在盘（三模式统一判定）；cannonOnly nil puzzleId 注释锚未核——DailyChallengeManager.swift 定位失败（Services/ViewModels/Managers/Models 四路径探测均无，登记 §九）；DailyChallenge.swift:22-31 十模式枚举在盘
- Phase7 **[部分在盘/D5 关联]**：PositionAnalyzer.swift:134 actor 化在盘；:390-424 analyzeMoveLite（MasterGameCommentator 专用轻量分析）；:439-446 v6.4 A2① currentEngineVersion()（分析持久化过期判定锚）；引擎所有权=getEngine() 共享实例+actor 串行化（:397 注释）——v4.1 Phase7 方案1"PositionAnalyzer 独立引擎引用"与现状共享实例的落差需读 getEngine 实现段终判（D5 底稿跟进项）

四态结论行：
- **[已实现] v4.1 Phase2 challengeResult 三模式补全+View alert（V-1 修复）**｜doc: v4.1-plan.md §Phase2｜code: GameViewModel.swift:987-995; BoardView.swift:25-30｜处置：销项
- **[已实现] v4.1 Phase3 completeChallenge 覆盖块**（注释锚弱核）｜doc: v4.1-plan.md §Phase3｜code: GameViewModel.swift:987-995｜处置：销项（注释锚列 §九）

### v4.0-daily-challenge-modes.md（#4，完成 2026-10-21）

承诺面（doc 锚）：v4.0 新增 3 低复杂度挑战模式（endgameStart/solveMate/cannonOnly；v2 态=V-C1~C7 修复后）；§2.4 horseOnly V-C4 明确"v4.1 待实现"；§4.2 isImplemented 扩展 horseOnly=false 注释"v4.1 待实现"；7 老占位模式维持待实现口径。

现态证据（code 锚）：
- DailyChallengeView.swift（297L）：:201-238 三模式加载链全接（"v4.0 Phase 5: endgameStart/solveMate/cannonOnly"注释+loadChallenge 调用）；:286-290 对应 case 分支；**comingSoon 关键词全文件扫描零命中**
- DailyChallenge.swift（482L）：:22-31 十模式枚举（horseOnly :31 在）；:7-9 ChallengeResult；:14-17 ChallengeModeType；:37-44 中文名映射

四态结论行：
- **[已实现] v4.0 三挑战模式（endgameStart/solveMate/cannonOnly）**｜doc: v4.0-daily-challenge-modes.md §2.1-2.3/§3/§4｜code: DailyChallengeView.swift:201-238; GameViewModel.swift:987-995; DailyChallenge.swift:22-31｜处置：销项
- **[文档过时/候选 P2] horseOnly"v4.1 待实现"承诺漂移**：v4.1-plan.md 八 Phase 清单无 horseOnly（全文实证），实装未发生｜doc: v4.0-daily-challenge-modes.md §2.4/§4.2｜code: DailyChallenge.swift:31（枚举在，无加载分支；DailyChallengeView :286-290 仅三模式）｜处置：P4 文档修批（承诺改"远期"或入 backlog）；与 v3.9 D4 P1-2 占位模式域合并列 P3 整改候选
- **[已修复] v3.9 D4 P1-2 占位模式 7 卡片 → 单行文案（D0 三态=已修复）**｜doc: v39-d4-feature-completeness.md P1-2（comingSoonModes 7 模式卡）+v39-phaseb-summary.md §四#13（"缩减 7→3 或折叠"处方）｜code: DailyChallengeView.swift:22-26（playableModes 6 模式数组）+:44-48（"v4.0: 敬请期待 — 单行文案"daily.view.moreModesComingSoon 单 Text，原 7 卡数组已移除）｜处置：销项；其余 4 模式（materialAdvantage/defendChallenge/comboKill/horseOnly）仍属远期域（与 horseOnly 行合并归 P3 候选）

### v5.0-opening-explorer-upgrade.md（#6，完成 2026-10-21；§五 v5.0 系一并核）

承诺面（doc 锚）：openings.json（23 类型×60 变体×≤6 步）→ opening_book_v2.json（35,896 局面/47,132 候选/前 20 步）数据源升级；懒展开架构（OpeningExplorerNode+PositionSnapshot 轻量快照+@MainActor，VE-2/3/4）；OpeningBook struct→final class 单例（VE-1）；开局名双层标注（openings.json 作字典）；中文走法名强制；性能目标（加载<100ms/内存<15MB/展开<1ms）；搜索列 Phase 2"暂不实现"（§4.3）；OpeningTreeNode.swift 删除（VE-8，§5）。

现态证据（code 锚）：
- OpeningBook.swift（147L）：:7-8 final class+static let shared（VE-1 落地）；:41-43 opening_book_v2.json 加载；:88 lookupAll(zobristHash:)；:134 ZobristHash.hash
- OpeningExplorerService.swift（227L）：:7 "VE-1: 使用 OpeningBook.shared 单例，避免双重加载 3.7MB JSON"；:11 @MainActor；:15 .shared；:65 rootMoves()；:71 expandChildren(of:)；:129/:177/:216 PositionSnapshot(board:)
- OpeningExplorerView.swift（905L）：:326/:605 pathFromRoot()（根到节点路径=v3.9 D3 P0-2 修复面现存形态）；:627 searchByMoveSequence；:677 buildNodePath(forVariation:)；:691-697 moveSequence 搜索结果类型
- Models/OpeningTreeNode.swift 不存在（VE-8 删除兑现，探测 2026-10-21）

四态结论行：
- **[已实现] v5.0 开局数据源升级（懒展开+单例化+轻量快照+@MainActor）**｜doc: v5.0-opening-explorer-upgrade.md §2/§5｜code: 上四条锚｜处置：销项（与 v5.6.1 基线"✅已完整落地"一致，本轮现态复核通过）
- **[已实现·超承诺] §4.3 搜索"Phase 2 暂不实现"已实装**｜doc: oeu §4.3｜code: OpeningExplorerView.swift:627/:677/:691｜处置：登记"实现超前于文档"；P4 文档修批 §4.3 改"已实装"或引后续版本 doc
- **[仍开放/P2] v3.9 D1 P2-4 OpeningBook v1 兼容索引 FENParser 层依赖（D0 三态=仍开放）**｜doc: v39-d1-game-logic.md P2-4（Models 层不应依赖 Services 层 FENParser）｜code: OpeningBook.swift:114-118 buildV1Index 仍用 FENParser.parse｜处置：P3 打磨候选（v39 已判正常对局不触发，防御性）
- **[文档质量/P3] oeu 文档内部 v1 残留两处**：§2.4 init 代码块仍写 self.openingBook = OpeningBook()（与 §2.2 VE-1 修正自相矛盾）；§6.3 仍称"OpeningBook 是 struct（值类型）"｜doc: oeu §2.4/§6.3 vs §2.2｜code: —（实现已按 v2，纯文档残留）｜处置：P4 文档修批随手改
- **[已修复] v3.9 D3 P0-2 开局探索器（D0 三态=已修复）**：路径回溯现形态 pathFromRoot()；棋盘预览=OpeningBoardPreview 复用（oeu §4.4"Bug A 已在 v4.1 修复"）｜doc: v39-phaseb-summary.md §二 P0-2+§四#2；v39-d3-ux-operability.md（P0 发现源）｜code: OpeningExplorerView.swift:326/:605｜处置：销项
- **[日期纪律候选] oeu 头部"日期:2025-01-29"**：document-conventions §3 违例候选（与 v4.1-plan.md 同族，合并一包）

### master-game-demo-entry.md（#9，完成 2026-10-21）

承诺面（doc 锚）：master-game-demo-entry.md（Alex 2026-07-21，v2 审查修复版）——大师棋谱接入 PuzzleDemoView：DemoItemWrapper 枚举（替代 any DemoItem 协议，Equatable 面修复）、MasterGameDemoItem 轻量列表项（走法按需加载 P0#1）、DemoCategory 结构化枚举（.opening(OpeningCategory) P1#5）、DemoViewModel 解耦（init(item:moves:) P0#3）、DemoMoveConverter.convertGameMoves 走 ICCSParser 路径+失败即终止（P0#2 防级联错误）、侧边栏 Section 分组（残局/大师棋谱）。

现态证据（code 锚）：
- DemoViewModel.swift（429L）：:51 let item: DemoItemWrapper；:127-128 "通用初始化：接收 DemoItemWrapper + 预计算的 Move 列表" init（v2 设计落地）
- MasterGameStore.swift（189L）：:8 class+倒排索引四张（player/event/opening/subcategory :17-20）；:95 "构建二级开局分类倒排索引（最长匹配优先，一对局只匹配第一个命中的子分类）"（v5.6.1 P1-3 子分类不互斥修复面）；:150-178 byOpening/bySubcategory/byPlayer/byEvent
- MasterGameLoader.swift（83L）：:11 loadGame(MasterGameIndex)→ImportResult；:37 seek(toOffset: pgnOffset)（按需加载路径与 doc §2.5 一致）
- PuzzleDemoView.swift（663L）：:26/:406/:436 DemoItemWrapper 装配在用；**:428-429 "case .masterGame: // 大师棋谱已迁至 MasterGameBrowserView，此分支不再使用"**

四态结论行：
- **[已实现·形态演进] 大师棋谱接入：mge doc 方案全量落地后迁移出 PuzzleDemoView**｜doc: master-game-demo-entry.md 全文（v2 态）｜code: DemoViewModel.swift:51/:127；MasterGameStore.swift:8/:95；MasterGameLoader.swift:11/:37；PuzzleDemoView.swift:428-429（迁移注释）｜处置：销项+登记演进链（auto-demo 建 PuzzleDemoView 双数据源 → mge 大师棋谱并入 → 后续版本迁出独立 MasterGameBrowserView）；mge doc 中 PuzzleDemoView 装配描述已过时，P4 文档修批标注"已迁 MasterGameBrowserView"
- **[已实现/轻核] v5.6.1 P1-3 子分类逻辑缺陷修复面**（最长匹配优先+单命中语义注释）｜doc: v5.6.1-full-requirement-audit.md §六 P1-3（"子分类不互斥不完备"）｜code: MasterGameStore.swift:95｜处置：销项（合并报告口径 11/11 闭环之一，本轮现态复核通过）

### auto-demo-design.md（#10，完成 2026-10-21）

承诺面（doc 锚）：auto-demo-design.md（Alex，v2.2 态；v2.0 大改=开局演示数据源从 openings.json 改为 PGN 大师对局 40,711 盘）——PuzzleDemoView 新建（分类侧边栏+DemoBoardView 复用 ReplayBoardView+CommentaryOverlay+DemoControlBar）；DemoItem/DemoPlayState 统一模型（索引→解析→播放生命周期）；MasterGameIndex 离线索引；规则推断点评（将军/将死/弃子）；534 局（过滤 freePlay）+40,711 盘双数据体系。

现态证据（code 锚）：
- PuzzleDemoView.swift 663L 在盘（DemoItemWrapper 装配，见上）；MasterGameStore/MasterGameLoader 在盘（索引+按需解析全链）
- CommentaryEngine：Services/CommentaryEngine.swift 不存在（路径探测未中，类型被 DemoViewModel 引用——实际路径候发现，登记 §九；MasterGameCommentator 专用轻量分析见 PositionAnalyzer.swift:390-424 analyzeMoveLite 注释）

四态结论行：
- **[已实现] auto-demo 核心（演示播放+点评+连播+大师对局索引）**｜doc: auto-demo-design.md §1-§3（v2.2）｜code: PuzzleDemoView.swift:26/:406；MasterGameStore.swift:8-20；MasterGameLoader.swift:11；PositionAnalyzer.swift:390-424（MasterGameCommentator 分析链）｜处置：销项（与 v5.6.1 基线"✅已完整落地"一致，本轮现态复核通过）
- **[日期纪律候选] auto-demo 头部"日期：2025-07-25"**：document-conventions §3 违例候选（与 v4.1-plan/oeu 同族，日期违例包第三例，统一一包交 P4 修批）

## 四、开局/演示/大师族（本族完成：#6/#8 段内销项、#9/#10 完成）
## 五、v5.0 系收尾（#7，完成 2026-10-21）

- **[部分执行/证据不足] FINAL-011 v5.0 交叉质量检查 47 项覆盖（D0 三态=仍开放·证据受限）**｜doc: v5.0-cross-quality-check.md §1.3 反向追踪矩阵（8 bug 全 ✅ 覆盖=计划面）+§2 五层模型；v5.6.1-full-requirement-audit.md FINAL-011（"部分执行（当前 11 问题修复）"）｜code: —（执行记录类证据未在 docs/audits、docs/reviews 轻查面发现全量执行存证）｜处置：P3 建议=检查清单执行记录持久化（落盘 docs/reviews/ 逐项 Pass/Fail），否则 47 项覆盖永远不可审计；本项不重开检查单（边界纪律）
- **[日期纪律候选] cqc 头部"日期:2025-01-29"**：违例包第四例（v4.1-plan/oeu/auto-demo 同包）

## 六、专项片（#11-#15，完成 2026-10-21；#16 bayeselo 系见 §九）

### draw-detection-analysis.md（#14，本片最高优先 D0 件）

承诺面（doc 锚）：draw-detection-analysis.md（Alex 2026-07-15，✅审查通过待实施）——评估矩阵 8 类和棋五域对照；P0×3：①GameViewModel 缺三次重复 ②长将判负全链缺失 ③PuzzleViewModel boardFingerprint X-碰撞 bug（doc 原文"应在 P0 中最优先修复（已有 bug 影响线上用户）"）；P1×4：长捉判和/60步规则阈值100→120/Pikafish C API draw 信号/子力不足；Phase1=P0 三项。

现态证据（code 锚，GameViewModel.swift 1117L）：
- :112-121 halfmoveClock+positionFingerprints 字典+perpetualCheckThreshold=6（"设计文档建议 N=6"）+perpetualChaseThreshold=6（"v4.0 Phase 6"）
- checkGameState（:735-810）：困毙判负（:747"中国象棋规则：无子可动方判负，不是和棋"）→detectPerpetualCheck 判负（含首次触发弹窗+UserDefaults 幂等，即 v3.9 P0-1 处方）→detectPerpetualChase 判负（超承诺）→三次重复判和（count>=3）→50回合规则（halfmoveClock>=100 判和）
- boardFingerprint（:813-817 "P0-1: 生成局面 fingerprint（完整 FEN，含走子方）"=FENParser.generate）——Game 侧碰撞 bug 已修
- PuzzleViewModel.swift:560-573 boardFingerprint 仍为 X-碰撞形态（general→K/chariot→R/其余五种→"X"），注释"用于长将检测"

四态结论行：
- **[已实现] draw-detection Phase1 P0×3 之两项半：三次重复判和+长将判负（Game 侧）**｜doc: draw-detection-analysis.md §2.3/§2.4/§4 P0 表/§6 Phase1｜code: GameViewModel.swift:766-789（长将）/:791-796（三次重复）/:819-846（detectPerpetualCheck 双条件）｜处置：销项
- **[部分修复/P1] P0-3 fingerprint 碰撞：修复不对称——Game 侧已换完整 FEN，Puzzle 侧仍 X-碰撞**｜doc: draw-detection-analysis.md §2.3（bug 精确描述+"最优先修复"）｜code: GameViewModel.swift:813-817（FEN 形态）vs PuzzleViewModel.swift:560-573（"\(row)\(col)\(kind==.general ? K : kind==.chariot ? R : X)\(side)"五行 X 映射仍在）｜处置：**P1 整改候选（puzzle freePlay 长将/和棋检测假阳性风险仍在，doc 自己标注"影响线上用户"）；本项同时移交②维 Tina 复核（D2 交联项）**
- **[超承诺/已实现] 长捉判负（doc 列 P1-4）已随 v4.0 Phase 6 落地**｜doc: draw-detection-analysis.md §2.5/§4 P1#4｜code: GameViewModel.swift:780-788 detectPerpetualChase+:120 阈值+perpetualChaseMessage｜处置：销项（超出 doc Phase1 范围的提前交付，P4 文档修批登记）
- **[文档间冲突/待裁决] 60步规则阈值：doc 处方 100→120（中国象棋 60 步×2）vs 实装+PRD=100 半着**｜doc: draw-detection-analysis.md §2.8/§4 P1#5；对照 v5.6.1-full-requirement-audit.md（"halfmoveClock（100半着）✅ v3.7.3 P0-2 已修复"+FR-R 全✅——PRD v1.1 口径即 100）｜code: GameViewModel.swift:801-804（halfmoveClock>=100 判和）｜处置：**登记冲突呈 P3/Danny 裁决**（亚洲规则 120 vs PRD 100——实装循 PRD，doc 主张未采纳；不改码，只登记）
- **[仍开放/P1] Pikafish C API draw 信号（pikafish_game_result/draw_reason）**｜doc: draw-detection-analysis.md §3/§4 P1#6｜code: pikafish_api.h（include/ 124L）扫描 game_result/draw/RESULT 零命中｜处置：P3 立项候选（doc §3.1 已有详细方案）
- **[仍开放/P1] 子力不足检测（Game 侧缺失，Puzzle 侧粗略）**｜doc: §2.7/§4 P1#7｜code: checkGameState 无 insufficient material 分支（:735-810 全文）｜处置：P3 候选
- **[已修复/销项] v3.7.3 P0-8"和棋检测伪覆盖"关联域（FINAL-012#8）**：检测逻辑本体已系统性补齐（见上三行），测试覆盖真伪属②维/Tina D0（测试面审计），本件只登记检测逻辑面｜doc: v5.6.1-full-requirement-audit.md §六 FINAL-012｜处置：逻辑面销项+测试面移交

### board-thread-safety-fix.md（#13）

承诺面（doc 锚）：board-thread-safety-fix.md v3（Alex 2026-08-03，Phase 1a.2，Vera N1-N5 采纳）——根因=Board @Observable 全局注册表非线程安全×AI 搜索路径 Board 实例；设计原则"AI 搜索路径零 Board 类型"；BoardReadable 协议桥接+SearchBoard 值类型+inout 传递+UI 零改动。

现态证据（code 锚）：
- BoardReadable.swift（AI/，17L）在盘（Alex 矩阵 D0⑤ 锚同源）；MoveOrderer.swift:85 order<T: BoardReadable>、:133-134 givesCheck<T: BoardReadable> 内 var workBoard = board.makeSearchBoard()（值副本 execute/undo）
- AIEngine.swift 搜索签名 inout LegacySearchBoard（:351/:581 masterSearch/masterSearchScored）——值类型命名演进为 LegacySearchBoard（doc 初稿名 SearchBoard）
- TimeManager.positionComplexity<T: BoardReadable>（TimeManager.swift:60 区段）——协议桥接面扩散印证

四态结论行：
- **[已实现] board-thread-safety-fix 核心设计（BoardReadable 桥+搜索路径值类型化）**｜doc: board-thread-safety-fix.md §0-§2｜code: 上三行锚｜处置：销项（命名演进 SearchBoard→LegacySearchBoard 登记 P4 文档修批）
- **[已修复] v3.9 D1 P1-5 MoveOrderer 活动板 execute/undo（D0 三态=已修复·形态演进）**｜doc: v39-d1-game-logic.md P1-5（处方"标注非线程安全注释"）｜code: MoveOrderer.swift:133-134（makeSearchBoard 值副本方案结构性消除风险，处方被取代）｜处置：销项；:132 注释"在原 board 上 execute/undo"与 :134 实现矛盾，P4 文档注释修批随手改

### ai-engine-improvements.md（#11）

承诺面（doc 锚）：6 项改进（P0-P2 实施范围+P3 开局库扩充 Phase 2）：P0 新手级平滑过渡（beginnerMove 30% depth1/70% safeRandom）；P1-a CheckmateSearch maxResponses=8 排序剪枝；P1-b 棋子价值动态调整（dynamicValue 马/炮残局互换+兵过河加权）。

现态证据（code 锚）：
- AIEngine.swift（1031L）：:140-143 "C1: 返回 top-k 候选走法…novice 走 beginnerMove 逻辑"——**beginnerMove 在盘（P0 落地）**
- P1-a 即 v3.9 D1 P1-6 所述 maxResponses=8 现状（CheckmateSearch 剪枝在 v3.9 审计时已存在，落地早于审计）
- dynamicValue：AIEngine 1031L 扫描零命中——P1-b 未见按 doc 形态实装

四态结论行：
- **[已实现] P0 新手级平滑过渡（beginnerMove）**｜doc: ai-engine-improvements.md §P0｜code: AIEngine.swift:143｜处置：销项
- **[已实现·早于审计] P1-a 杀法搜索应对方剪枝**｜doc: §P1-a｜code: v39-d1-game-logic.md P1-6（maxResponses=8+排序+假阳性注释，2026-07-09 审计时已在）｜处置：销项（P1-6 的假阳性风险登记仍有效，归 ②维/P3）
- **[未实现/或被取代·轻登记] P1-b dynamicValue**：doc 形态（AIEngine.evaluate 内 dynamicValue）零命中｜doc: §P1-b｜code: AIEngine.swift 扫描 2026-10-21｜处置：登记；评估演进实际路线（AIEvaluator/EvalWeights 体系统）与 doc 的关系属 P4 文档修批核对项，不判缺陷（无出处不下结论）

### ai-search-optimization-phase3.md（#12）

承诺面（doc 锚，1043L 头部+交叉锚）：搜索优化第三阶段（PVS/剪枝族/QS 等）；关联 difficulty-system-v4-final.md §1.2 引用"搜索配置 .master（PVS, QS qDepth=6, LMR, IID, NullMove, Razoring）｜AISearchConfig"。

现态证据（code 锚，AIEngine.swift 1031L）：
- PVS：:217/:232 usePVS null-window + re-search；:482/:498 同构（Scored 路径）
- Razoring：:675-676 enableRazoring depth<=2+QS 验证
- NullMove：:712-713 allowNullMove/enableNullMoveFix 门控（KI-2026-0925 命名陷阱条目：null-move 恒开，门控=evalCfg.mobility && depth>=3 && 非将军，m1 :704-733/:952 亲读在案）
- TT：TranspositionTable.swift 双桶（v39-d1 已审 ✅）；AISearchConfig 配置面贯穿（:172/:194/:283-332 等 12+ 消费点）
- 时延链：:898 node 级 timeCheckInterval 位掩码 shouldStop 检查+:37 粒度权衡注释（"64 粒度最坏 ≈140ms，shouldStop 开销 <0.1%"）

四态结论行：
- **[已实现] 搜索优化族（PVS/Razoring/NullMove 门控/LMR/TT 双桶/AISearchConfig）**｜doc: ai-search-optimization-phase3.md+difficulty-system-v4-final.md §1.2（交叉印证）｜code: 上五行锚｜处置：销项（本件与 Alex D0⑤ 已销三项互补，搜索链全景闭合）；doc 内部条目级四态细表（1043L 全量）留 Alex 矩阵主笔合并时按需回填，本片以域级结论交付
- **[已修复·静态可证] KI-2026-0829 业余档时延违约根因面（单迭代内 deadline 截断）**｜doc: known-issues.md KI-2026-0829（初判根因 Cody：TimeManager 仅层间检查）｜code: AIEngine.swift:898（nodeCount & (timeCheckInterval-1)==0 → tm.shouldStop，搜索内 node 级检查）+:220/:392/:485/:620/:661 多层检查点；TimeManager.swift:28-33（shouldStop=elapsedMs>=limit，systemUptime 口径休眠不计入）｜处置：**静态面已修复；AIEngineTimingContractTests 回绿+lvl4/lvl5 时延实测列"需 P4 实测确认"栏；known-issues 条目（active·P1）待实测批后由条目 owner 销账**

### engine-gap-analysis-elephanteye.md（#15）

承诺面（doc 锚）：engine-gap-analysis-elephanteye.md v1.0（Alex 2026-08-15，"纯分析，不动代码"）——洪涛立项决策件：差距 ~1000-1400 Elo；P0 热路径重构（6-8 人天，必选）+P1 SEE+搜索内重复检测（4-5 人天）+P2 评估知识（5-10 人天）；已排除项（Pikafish Skill 降档/自训 NNUE/嵌象眼 LGPL/重写 UI Board）。

现态证据（code 锚）：
- MoveOrderer.swift:14-17 historyTable 仍 [String: Int]（"fromRow,fromCol,toRow,toCol" 字符串键，doc §3.1 热路径发现现势仍准；:15 注释"实例级，避免多 AIEngine 并发竞争"）
- AIEngine.swift:140 C1 anti-repetition 走法选择（局外规避形态）——搜索内重复检测仍缺（与 doc §3.1 "❌ 搜索内无重复检测"一致）；SEE 扫描零命中（仍缺）

四态结论行：
- **[分析件·现势有效/未立项实施] engine-gap 三档立项建议（P0 热路径/P1 SEE+搜索内重复/P2 评估知识）均未见实施**｜doc: engine-gap-analysis-elephanteye.md §一/§五（决策件，非实施承诺——四态按"立项文档"口径登记，不算实现缺陷）｜code: MoveOrderer.swift:14-17（String 键仍在）；AIEngine.swift:140（C1 局外规避）；SEE 零命中｜处置：作为 P3 整改方案"引擎上限提升"包的现成输入呈报（doc 本身即立项依据，洪涛未拍板前不动）；§8.1 已排除项不再复议

## 七、coach 系（#17）——件名发现失败，登记缺口

- 13+ 候选名探测全失（coach-system-design/coach-explainer-design/coach-mode/ai-coach/coach-mode-ui-design/v4.0-coach/coach-explainer-scenes/coach-guidance 等）；docs/README.md 索引停 v3.1 无 coach 域；无目录列举工具（read 拒目录）
- 判断：coach 域设计内容可能折叠在 phases/plans 文档（T-1021-OC-01 教练执方门修复链在 docs/plans/）而非独立 design 件；**清单终裁权在 Alex（矩阵 owner）**——候 Alex 补件名或确认 docs/design/ 无独立 coach 设计件
- 代码域锚（D0/D2 交联面，本轮已核）：CoachModeOverlay 在 ChineseChessApp.swift（852L）零引用——**v3.9 D4 P2-3"CoachModeOverlay 未集成"三态=仍开放**（与 v3.9 同口径同文件）；coach 修复后状态基线=T-1021-OC-01（5ce0fa2，Ruby 审+Tina 验全过，v6.4.2 tag）｜处置：P2-3 列 P3 整改候选（对弈中教练提示集成）；coach 域功能链细查归②维 Tina 主责（D2 边界）

## 八、D5 性能静态链——交联指引

本分片 D5 贡献已单独落盘：**docs/audits/t1023-dim5-shard-cody.md**（两栏口径：静态可证/需 P4 实测确认）。要点预告：KI-2026-0829 时延根因面静态已修（AIEngine:898 node 级截断）、dispatch_sync 死锁 KI 面（EPE 现态无 dispatch_sync，async+cApiQueue 重构）、PositionAnalyzer actor 化、board-thread-safety 值类型化、v6.4 @MainActor 并发修复、复盘静默 nil 长期建议（C API 错误码上抛）、AI 飞将 bug（active 未修复，②维交联）。

## 九、覆盖缺口与移交项（终版）

**文件定位缺口（诚实登记，不静默遗漏）**：
1. **v4.0-×6 缺 4 件**：已实位 v4.0-analysis-optimization/v4.0-daily-challenge-modes；余 4 件名未知（v4.0-plan/v4.2-plan 等 6 名探测全失；oeu/v4.1-plan/daily-challenge 三件互引未再现新名）
2. **v4.1-×3 缺 2 件**：已实位 v4.1-plan.md；oeu §1 提及"v4.1 修复 OpeningExplorer 三个 UI Bug(Bug A/B/C)"——对应件名未知（v4.1-opening-bugfix 等 6 名探测全失）
3. **bayeselo 系（#16）**：具体件名未发现（5 名探测全失；difficulty-system-v4-final.md 头 60 行未见引用——深度引用可能在其中后段，属 Alex 类3 片，本片不深入）；T-1022 边界：校准文档域只对照不结论
4. **coach 系（#17）**：见 §七
5. **DailyChallengeManager.swift**：四标准路径探测均无（类型被 GameViewModel:995 引用、DailyChallenge.swift 同域在盘；实际路径未定位——v4.1 Phase3 注释锚未核，逻辑面已经 GameViewModel:987-995 销项）
6. **CommentaryEngine.swift**：四路径探测均无（类型被 DemoViewModel 引用；MasterGameCommentator 专用分析链在 PositionAnalyzer:390-424 实证）
7. **pikafish_api.cpp g_engine TODO**（FINAL-013）：.h（include/，124L）扫描零命中 TODO/g_engine；.cpp 未定位未扫——FINAL-013 三态=**证据不足维持**（v5.6.1 基线"有 TODO 需运行时验证"未翻转；C 层并发域归 ⑤维 Alex 主责片深度核验，本片交联）
8. **SearchBoard 类型定义文件**：未定位（makeSearchBoard/LegacySearchBoard 使用实证充分，定义位置不影响结论）

**移交项**：
- → **②维 Tina（D2 交联，随完成通报抄送）**：①PuzzleViewModel boardFingerprint X-碰撞（长将/和局检测假阳性域，draw-detection doc 自评"影响线上用户"最优先级）②AI 飞将搜索层 bug（KI-2026-0730 active 未修复）③CheckmateSearch maxResponses=8 假阳性 residual ④和棋检测测试覆盖真伪（FINAL-012#8 测试面）
- → **P3 整改方案输入包**：60步规则 PRD-vs-亚洲规则冲突裁决、子力不足检测、C API draw 信号、CoachModeOverlay 集成、defenderDifficulty 段位 cap、engine-gap 三档立项包（现成决策件）、checklist 执行记录持久化规约
- → **P4 文档修批包**：日期违例四例（v4.1-plan 2025-01-29/oeu 2025-01-29/auto-demo 2025-07-25/cqc 2025-01-29）、oeu 内部 v1 残留两处、MoveOrderer:132 注释矛盾、mge 装配描述已迁 MasterGameBrowserView、oeu §4.3 搜索已实装、horseOnly"v4.1 待实现"漂移、board-thread-safety SearchBoard→LegacySearchBoard 命名、generate_hints/difficulty_recalc 工具链去引或入库

**证据局限终声明**：本机无目录列举/全文检索工具（catalog 27 工具核过，无 shell/fs-list）；全部文件发现走"基线引用链+定点探测"；puzzles.json 单行 275KB 仅头部 ~44KB 可达（采样口径逐条标注）；memory_search 因索引模型不匹配不可用（openclaw memory status --index --agent coder 可重建，未动）。凡"零命中"结论均注明扫描文件与行数边界。
