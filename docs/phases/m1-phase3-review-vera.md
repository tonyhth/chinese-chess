# M1 Phase 3 设计快审 — Vera

> 任务：Luke 快审单（四点）。输入：docs/phases/m1-phase3.md（Alex，2026-08-16）。性质：快审+熔断，照 L2 先例（test-baseline-pollution-l2-review-alex.md）。
> 实核：AIEngine.swift（negamax :718-812 / QS :945-1001 / 根层 :169/:234/:459/:520 / isTerminal :1047 / order 消费点 :240/:526/:830）· MoveOrderer.swift（order :120-153 / givesCheck :163-172 / threatBonus :176+）· SearchBoardProtocol.swift（:29-99，V2.legalMoves :78-86 / captureCandidates :90-93）· MoveValidator.swift（:28 v3.9 注释 / captureMoves :30-45 / wouldBeInCheck :321）· SearchBoardV2.swift（结构体 :11-27）· m1-hotpath-redesign.md v1.2（§3.2/§3.3/§3.4/§7.2/§7.4）· m1-cross-review.md D1（我 08-15 原文）· git（v6.1.0 tag 对照、35b4a5c 对照）。
> 钟取：2026-08-16 14:50（date 系统钟）。

## 总表

| # | 审点 | 裁定 | 量级 |
|---|------|------|------|
| 1 | 裁定 A 形态风险面（work 副本/否决记录） | **同意**（附 3 条硬化注，编码吸收） | 分钟级 |
| 2 | 裁定 B 偏差正当性（根层保留） | **同意**——前提确被 P2c 改变，独立核通过 | 零改动 |
| 3 | :38 评估顺序语义保持 | **退回定案**——"等价"主张锚在**死分支**上，live 现状不同，必须显式定案 legalCount==0 语义（二选一，Luke 裁） | 一句话定案 |
| 4 | QS 定调 + NPS 口径 | QS 定调方向对但**事实基座读反**（v3.9 注释）；NPS 不设门 ✓；**"Elo ≥ -30"与两级制冲突** | 改两行表述 |
| 附 | 回滚点 P3-②③ 开关论据 | 修正——通用循环改造不随开关回退，回滚 = commit 级 revert | 改一行表述 |

## 1. 裁定 A —— 同意（P2-5 留白收口合格，附硬化注）

**三选项合成完备**：对照我 D1 §1.3 P2-5 原文三选项（var 局部拷贝 / order 改 inout / givesCheckV2(move, inout V2) 注入），裁定 A = ③的形态 + ①的拷贝提升到 order 层，否决记录（inout 传染、每候选拷贝）与我当年论证一致——两条否决理由成立，无第四形态遗漏。

**生命周期封闭性**（审点 1 核心）：
- order 非重入（消费点 :240/:526/:830 每节点一次，无递归），work 是函数局部值语义副本——原 board 从未被 inout 暴露（givesCheckV2 收 `&work`），异常/提前返回路径下 work 直接丢弃，**副本悬挂在值语义下结构性不存在** ✓
- 威胁预提取语义等价：Legacy threatBonus 读 pre-move 盘面（order 在走法循环前跑），V2 预提取同样取 order 入口快照——双方同读 pre-move 对方活跃子，captured 陈旧性两侧对称，全等测试锚（§4 #6）成立 ✓

**硬化注 3 条**（Cody 编码吸收，不改设计）：
1. Debug 断言改为**每候选**查 `work.moveHistory.count` 复位（O(1)），不要只在 order 出口查——否则中途失衡在 Debug 下也先污染同 order 后续候选再报，定位代价高
2. work 提升时 `work.undoStack = []; work.moveHistory = []` **重绑空数组**（非共享 COW 后追加）——undoStack/moveHistory 是深度比例 COW（UndoInfo ~40B × 深度 8-10），共享+首 make 触发整栈拷贝，且断言简化为归零判
3. "~250B memcpy" 实为 **5 个 [Int8] 缓冲的 COW 拷贝之和**（90+90+32+2 ≈ 246B + undoStack/moveHistory）——量级同阶，文档措辞校准，防 Cody 按单 memcpy 理解做错优化

## 2. 裁定 B —— 同意（独立核：前提真被 P2c 改变）

v1.2 §3.3 :321 根层行"同 negamax 模式"的写定语境（我 D1 当年参与该表修订）：**Legacy 时代根层 allLegalMoves 每候选 O(n) 拷贝**（isValidMove → makeSearchBoard 全盘物化）——根行进 A-1 清单的实质动因是成本，兼迁移完整性。P2c 后实核（SearchBoardProtocol :78-86）：`legalMoves` = 单 work 副本 + 逐 move make O(1)/inCheck/unmake 过滤——**成本前提已死**；根层每 IDS 迭代一次非热路径成立；bestMoves（:169）是 topK 公开接口（UI 合法走法列表），整表精确合法是最自然契约。

**设计未列的补强一条**：根层保留 = P0-2（childHash/make/unmake 配对面）改动面**缩小**到 negamax+QS 两循环——配对复查范围更小，Ruby 审查受益。偏差批准，预备单对照点①维持；根层按函数枚举（:169/:234/:459/:520）符合我 D1 P1-4 "按函数重列" 要求 ✓。

## 3. :38 评估顺序 —— 退回定案（快审单最重发现）

**主张**："杀棋分数写 TT 的时机与现状等价"。**实核不成立**——该主张锚在 :804-811 分支上，而该分支是**不可达死代码**：

- live 现状（v6.1.0 tag → P2c 后同构实核）：negamax 入口序列 = TT probe :741 → razoring :748 → **isTerminal :758 无条件预检 → `return evaluator.evaluate`（static eval，无 TT 写）** → depth≤0/QS :762 → NMP :773 → legalMoves :802 → **:804 isEmpty 分支永远追不上 :758**（同一 legalMoves().isEmpty 条件，:758 先返回，中间无棋盘变更）
- 即：**现状终局节点返回 static eval、从不写 TT、从不产生 mate 分**。:806 的 mate 分 + TT store 自 v6.1.0 起未执行过。v1.2 §3.2 伪码"语义同现状 :673"同病（锚死分支文字，历史遗留，非 phase3 新引入——但 phase3 把它放大成了实现规格）

**P3-② 落地后若 legalCount==0 实现 mate+TT 语义 = 全级别激活 mate 感知**（negamax 全族共享），实际行为变化三处：
1. depth>0 终局节点：static eval → ±100000 mate 分——**棋力语义变化**（可能正向，但 M1 是 NPS 重构不是棋力重构，P5 SPRT δ≥+100 的归因会被 mate 激活混杂：增益来自 V2 速度还是 mate 感知？无法拆账）
2. **困毙规则坑**：:807 `: 0` 是国际象棋 stalemate=和棋惯例——**象棋困毙=判负**，应为 -100000-depth 族。死代码时无害；一旦激活即向搜索注入规则错误的和棋估值
3. 前置交互漂移（无法完全保真的残余）：depth≤0 终局节点 现状直达 static eval → 新走 QS（standPat 或 beta 截断）；depth≥3 **困毙节点**现状被 :758 先收 → 新路径 NMP 先跑可能 fail-high 返回 beta——终局节点上的 NMP 是现状不存在的路径

**修法（二选一，Luke 裁，P3-② 开工前置）**：

> **✅ Luke 裁定：甲（2026-08-16 14:54 验收同单）。** 理由：P3 主题是消两遍式（性能），乙的 mate 激活+困毙规则修复是行为变化——象棋困毙判负 vs :807 国象惯例是产品规则决策，归 M2 候选池独立立项；残余漂移列已知差异。下游：Alex 按甲定稿（含死分支考古注记）/ Cody P3-② 挂定稿版到稿 / Ruby 审单带终局语义（随甲）+ QS 两态同改两对照点。
- **甲（推荐）**：legalCount==0 → `return evaluator.evaluate`（维持 live 语义，零 TT 写）——改动面最小、与 M1 纯性能定位自洽；文档 :38 改为"语义维持 live 现状（static eval），残余交互漂移三条列已知差异"；杀棋/逼和专项（§4 #3）断言口径按 static eval 写
- **乙**：声明 mate 激活为有意行为变化——必须 ①修困毙分（0 → 判负分）②§7.2 式"已知行为差异记录在案"③Ruby 审查单加"终局语义对照"项 ④P4 重校准依赖声明（全级别 Elo 漂移）。**不推荐混在 P3 里做**——立项归 M2 或独立小单

## 4. QS 定调 + NPS 口径 —— 两处修正

**QS"修正非回退"**：定调方向正确（v1.2 §3.4 原文成立），**但事实基座读反**——m1-phase3 :15 "Legacy captureMoves v3.9 有过滤"错。MoveValidator.swift:28 原文："**v3.9: 为静态搜索优化，跳过 wouldBeInCheck**" = v3.9 把过滤**去掉**（性能优化），captureMoves（:30-45 实核）无任何送将过滤；protocol :91 注释"与 Legacy QS 候选语义同型"才是对的。**真相：两态 QS 今日均无过滤，不存在"V2 现存语义差"**。
- P3-③ 改通用 QS 循环（无开关门控）= **两态同改**——这恰是与五源交叉对比自洽的选择（两态候选集保持全等），维持 ungated ✓
- 连带修正：§4 #1 "Legacy 态零回归"加注 = **测试账目零回归（50 基线）而非 QS 语义不变**；若 QS 语义变化打翻现有引擎类测试口径 → 按已知差异记录转 Tina 断言清偿对账，不算新回归（预案一句）

**NPS 只记录不设门**：✓ 一致——v1.2 §7.2 P3 行本无 NPS 门槛，量化归 §九/P5；对冲方向不定的理由成立；[NPS] 日志基建 P1 已备。

**"Elo ≥ -30"（§4 #4）与两级制冲突**：v1.2 §7.2 P2-2 两级制明文"20 局 Elo CI ±150+ 判不了回退，量化放 P4/P5"——P3 行加数字门槛是口径回退（我 R2 时代 P2-2 的原判）。修法：改"点估计 ≥ -30 作冒烟参考值（非统计判定），量化判定留 P4/P5"；非法走法率=0 + STOP 条款保留（与 v1.2 §8 前线哨兵一致 ✓）。

## 附加发现

**回滚点段落修正（P2）**："USE_SEARCHBOARD_V2 一行切回 Legacy"对 P3-②③ **不成立**——negamax/QS 循环是泛型通用代码，开关只切棋盘实现不切循环结构，②③ 的回滚 = **commit 级 revert**（②③ 允许合并 commit 的裁量下，注意 revert 粒度与 ① 独立性不冲突——① 可单独 revert ✓ 原文已写对）。

## 通过项（正面清单，不再复述）

- P2 基建直接引用不重述——正确减负 ✓
- 独立谓词双向闭合（§4 #2，D4 #6 修正版）✓——恒真断言防线在案
- childHash 位置不动 + move.captured 依赖已 P2 门控 ✓（QS 循环 :985-991 实核配对形态）
- supportsCheckLegalOrder 翻转影响面 = :240/:526/:830 三消费点（根层顺带恢复将军排序，走法集不变仅顺序变）✓ 与 §3 P3-① 表述一致
- threatBonus 范围外声明（保持简化版语义）✓ 与我 D1 P1-3 修法一致
- 双态跑法照 a12f9c0 ✓；回滚 ① 独立 revert ✓；风险表 #3/#4 对策与 v1.2 P0-2 呼应 ✓

## 熔断条款（照 L2 先例）

1. **legalCount==0 语义未定案（§3 甲/乙）→ P3-② 不得开工**——这是 Cody 预备单 ② 的前置，不是编码裁量
2. 送将专项集（§4 #2）任一失败 / 自对弈任一非法走法 → 沿用 v1.2 §8 STOP + Phase 冻结（原文已有，重申为熔断级）
3. P3-③ 合入后五源交叉对比若现 capture 候选集差异 → **熔断**——说明 ungated 两态同改假设错（存在未识别门控/生成器分叉），回退 P3-③ 单 commit
4. **重开条件**：若 P5 归因发现 mate 激活需求（甲案落地后棋力不达标的复盘指向终局语义）→ 乙案升格为独立立项（含困毙分修正 + P4 重校准），不在 P3 补丁式回锅

## 工期影响

设计 74 行结构合格，四审点仅 §3（一句话定案）+ §4（两行表述）+ 回滚段（一行）需 Alex 改——**半天内可消化，不改变开工节奏**；P1-1 定案是唯一开工前置。Ruby 0.25d 审查单建议补两对照点：终局语义（按 §3 定案结果）+ QS 两态同改声明。

— Vera，2026-08-16 14:50
