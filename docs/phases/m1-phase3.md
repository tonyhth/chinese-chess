# M1 Phase 3：A-1 伪合法化 + givesCheck/threatBonus V2 快路径

> 依 m1-hotpath-redesign.md v1.2 §三（A-1）+ §3.3/§3.4 + §7.2/§7.4 + R2 裁定 P1-1/P1-3/P2-5 · 设计 2026-08-16 · Alex · 负责人 Cody
> v1.2 定稿 08-16 晚：Luke 裁甲（legalCount==0 → static eval 维持 live，mate/困毙归 M2）；v1.1 = Vera 快审四点消化（死分支定案块/QS 事实基座更正/Elo 冒烟化/回滚修正/硬化注 3 条）
> P2 基建（SearchBoardProtocol 泛型链 807a734 / USE_SEARCHBOARD_V2 开关 beeadbe / 跑法 a12f9c0 / MovegenCrosscheck 五源四断言 / SearchBoardV2Tests 单元三层哨兵）**直接引用不重述**。

## 1. 目标与本 Phase 改动面

**A-1 核心**：搜索循环从"整表 legalMoves 预过滤 + 循环 make"（每候选 make 两遍）改为"pseudo 生成 + 循环内 make→inCheck→unmake 内联过滤"（每候选 make 一遍）。同批兑现 givesCheck V2 快路径（P1-1）与 threatBonus V2 专用版（P1-3，v1.2 裁定"与 givesCheck 同批"）。

**P2c 后现状实核**（行号已漂移，以此为准；v1.2 附录 A 行号对照见 §5 注）：
- negamax `:804` `board.legalMoves(for:)` 整表预过滤 + `:760` isTerminal 预检（= legalMoves().isEmpty **全表再跑一遍**）+ `:806` moves.isEmpty 冗余分支——**V2 下每节点 legalMoves 双跑**，是 A-1 内联化的直接对象
- QS `:950+`：captureCandidates 循环 make/递归/unmake——**两态今日均无送将过滤**（MoveValidator:28 v3.9 注释实义 = 跳过 wouldBeInCheck，captureMoves :30-45 无过滤；protocol :91 “与 Legacy 同型”为准——Vera §4 实核更正，我初稿读反）。P3-③ 为两态同改的通用收口，非 “V2 差” 收口
- givesCheck `:166`：as? LegacySearchBoard 已建，V2 分支 return false（不可达，supportsCheckLegalOrder=false 门控）
- threatBonus `:176`：board.pieces.filter **每候选一次**——V2 计算属性下排序成本逆势上升（R2 P1-3 原文）
- 根层 legalMoves 4 处 `:169/:234/:459/:520`

**两个设计裁定**（本 Phase 新增，非 v1.2 复述）：

**裁定 A — givesCheckV2/threatBonusV2 形态定案（Vera P2-5 留白收口）**：
- order 签名不动（`<T: BoardReadable>`，调用方零改动）；入口 `as? SearchBoardV2` 一次判定
- V2 分支：**work 副本提升到 order 层**（`var work = v2Board`，每 order 调用一次 memcpy ~250B + undoStack COW 共享），循环内 `givesCheckV2(move, &work)` = make O(1) + work.inCheck(对方) O(32) + unmake O(1)，make/unmake 严格配对 + Debug 断言（work.moveHistory.count 复位）
- threatBonus 同构：order 层预提取对方活跃子 `(row, col, baseValue)` 元组一次（槽位扫描，排除 general），循环内零分配查询。**等价性测试**：同 move 集 threatBonusV2 与 Legacy 版 bonus 值逐个全等（排序行为等价锚）
- 否决项记录：inout 传染 order 调用方（Legacy 路径无意义且签名不对称）、每候选 var 拷贝（成本高一个量级）——work 层提是 Vera 三选项的最优合成
- **硬化注 3 条（Vera §1，Cody 编码吸收）**：① Debug 断言**每候选**查 work.moveHistory.count 复位（非仅 order 出口）② work 提升时 undoStack/moveHistory **重绑空数组**（深度比例 COW 免拷贝，断言归零判）③ “memcpy ~250B” 措辞校准 = 5 个 [Int8] 缓冲 COW 拷贝之和（≈246B + 两栈），量级同阶防误读
- **supportsCheckLegalOrder 翻转 true**（SearchBoardProtocol :99）= V2 路径恢复 depth≥3 将军排序增益兑现开关

**裁定 B — 根层 4 处 legalMoves 保留不改（v1.2 §3.3 根层行的落地偏差）**：
v1.2 预设根层与 negamax 同型改造（当时 Legacy execute/undo 拷贝路径）；P2c 后 V2.legalMoves 已是快路径（单副本 + O(1) make 过滤），根层每 IDS 迭代一次非热路径，且 bestMoves/bestMove 是产品语义（UI 合法走法列表）——内联收益微秒级、语义风险正向。裁定保留整表调用。**此为与 v1.2 §3.3 表的显式偏差，Cody 预备单对照点 ①。** 补强（Vera §2）：根层保留 = P0-2 配对面缩到 negamax+QS 两循环，Ruby 复查范围受益

## 2. 前置检查（铁律状态）

- P2 合入门槛全绿 ✅（五源四断言 ≥5000 局面零差异 / iOS 门禁 / 开关双态跑法落档 a12f9c0）
- 全量存量基线：aa35f46（93→50，权威对账）——P3 回归账目以此为准
- Tina WIP 两件落定 + 开工令 = Luke 把关（设计不阻塞，到稿即审）

## 3. 实施步骤（commit 粒度，每 commit 独立可编译 + iOS 门禁）

1. **P3-① MoveOrderer V2 双快路径**：givesCheckV2（work 副本）+ threatBonusV2（预提取）+ supportsCheckLegalOrder→true。行为变化仅 V2 路径 order 恢复 checkLegal（走法集不变、顺序变）。单独可测：给将走法确实排前 + threatBonusV2 全等断言
2. **P3-② negamax 伪合法化**：`:804` legalMoves → MoveGenerator.pseudoLegalMoves + 循环内 make→inCheck(side)→unmake/continue + legalCount 计数；isTerminal 预检（:758）与 moves.isEmpty 分支（:804-811）并入循环 legalCount==0（消双跑 + 消冗余分支）；NMP/childHash 调用点位置不动（childHash 仍在 make 前由 move 字段计算，配对不变）
   **⚖ legalCount==0 语义 → 定案甲（Luke 08-16 裁，P3-② 开工前置解除）**：legalCount==0 → `return evaluator.evaluate`（static eval，live 语义，零 TT 写）——与 M1 纯性能定位自洽，P5 SPRT 归因保护（δ≥+100 增益干净归因 V2 速度，不混杂 mate 激活）。
   - 死分支考古注记（Vera §3 实核）：live 现状 = :758 isTerminal 预检**无条件先收 return static eval（无 TT 写）**，:804-811 mate+TT 分支自 v6.1.0 不可达；v1.2 §3.2“语义同现状 :673”同病（锚死分支文字，历史遗留记录在案）
   - 残余漂移三条列已知差异（§4 #3 断言口径按 static eval）：depth≤0 终局走 QS（standPat/beta 截断）/ depth≥3 困毙节点 NMP 可能 fail-high（现状 :758 先收无此路径）/ mate 分永不产生（维持 v6.1.0 起 live 事实）
   - 乙案（mate 激活 + 困毙分修正 ：807 `:0`→判负 + P4 重校准依赖）→ **M2 独立立项**，不在 P3 补丁式回锅；重开条件 = P5 复盘指向终局语义时升格（Vera 熔断 ④）
3. **P3-③ QS 送将过滤收口（两态同改，维持 ungated）**：循环内 make 后 inCheck 过滤（吃子送将跳过）——事实基座更正（Vera §4）：两态今日均无过滤，非“V2 差”收口，而是 v1.2 §3.3 QS 行“同样 make 后过滤”的两态兑现；恰与五源交叉对比自洽（两态候选集保持全等）。QS 语义变化致引擎类测试口径翻转 → 转 Tina 断言清偿对账（已知差异，不算新回归）
4. **P3-④ 专项测试落地**（Tina 0.25d，§4 清单）
- ②③ 允许 Cody 合并为单 commit（同型改造，他预备单裁量——对照点 ②）；① 独立（行为开关性质不同）

## 4. 验证命令与门槛（v1.2 §7.2 P3 行 + 双态）

| # | 验证 | 门槛 |
|---|------|------|
| 1 | 全量测试（开关双态各跑一遍，跑法照 a12f9c0 命令块） | 绿；Legacy 态零回归 = **测试账目口径**（50 基线），非 QS 语义不变（P3-③ 两态同改，Vera §4 加注） |
| 2 | 送将过滤专项集（8.4：车口/炮口/马口/照面各型 + 将军中被迫应将无解） | 引擎候选集无送将走法；**谓词用独立谓词双向闭合**（D4 #6 修正版，禁 pseudo−legal 隐式定义恒真断言） |
| 3 | 杀棋/逼和专项（8.4：双杀/单逼和，legalCount==0 断言**按甲口径 = static eval 返回**） | 断言通过 |
| 4 | 自对弈 lvl5×20 冒烟（v4.3 基线口径） | 点估计 ≥ -30 作**冒烟参考值**（非统计判定——20 局 CI ±150 判不了 -30，两级制口径量化放 P4/P5，P2-2 原判）；**非法走法率 = 0，任何一局非法走法 = STOP + Phase 冻结**（v1.2 §8 前线哨兵，熔断级） |
| 5 | childHash/make/unmake 三元配对复查（Ruby 清单 P0-2） | 配对全等 |
| 6 | threatBonusV2 vs Legacy bonus 值全等（裁定 A 等价锚） | 逐 move 全等 |
| 7 | NPS 观测（V2 态，[NPS] 日志含 qsNodes） | **只记录不设门**（givesCheck O(32)/候选 与排序增益对冲方向不定，P5 统一验收） |

## 5. 已知风险与回滚点

| # | 风险 | 对策 |
|---|------|------|
| 1 | 送将过滤遗漏 = 引擎走非法棋（产品级） | 专项集 + 守门非法走法率 0 + STOP 条款 |
| 2 | legalCount==0 语义漂移（:38 死分支教训，Vera §3） | 定案甲（Luke 08-16）：static eval 维持 live，§3 定稿块；Ruby 审查单两对照点：终局语义（甲口径）+ QS 两态同改声明 |
| 3 | childHash/make 配对破坏 = TT 陈旧 hash = **静默棋力回退**（自对弈能报警但定位代价极高，v1.2 P0-2 原文） | 三元配对复查 + 现有 make/unmake 平衡 Debug 断言保持 |
| 4 | givesCheckV2 work 副本状态污染 | Debug 断言 count 复位；异常路径不吞 unmake |
| 5 | supportsCheckLegalOrder 翻转的 NPS 波动 | 观测项不设门（§4 #7），P5 归因 |
| 6 | Legacy 态回归 | ① 只加 as? V2 分支不改 Legacy 路径；双态门禁（§4 #1） |

| 7 | P3-③ 合入后五源交叉对比 capture 候选集差异（Vera 熔断 ③） | **熔断**——ungated 两态同改假设错（存在未识别门控/生成器分叉），回退 P3-③ 单 commit |

**回滚点**（Vera 附加修正后）：USE_SEARCHBOARD_V2 一行切回 Legacy 仅覆盖 P3-①（V2 专属行为）；**P3-②③ 是通用循环改造，不随开关回退——回滚 = commit 级 revert**（②③ 若合并 commit，revert 粒度与 ① 独立性不冲突）。开关窗口延续到 P5 验收。

**行号注**：本文行号 = 2026-08-16 P2c 后实核（main @aa35f46）；v1.2 附录 A 行号（negamax :670→:718、isTerminal :642→:1047、QS :837→:950、order :96-98→:129、givesCheck :133-139→:166）编码时以 grep 现核为准。

**范围外**：根层 4 处保留（裁定 B）；threatBonus 完整攻击几何重写（保持简化版语义）；Legacy 路径任何改动；P4 cheapEval（后续单，设计可薄）。

## 6. 完成报告（合入时回填）

—
