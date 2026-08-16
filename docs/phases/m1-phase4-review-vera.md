# M1 Phase 4 设计快审 — Vera

> 任务：Luke 快审单（四点）。输入：docs/phases/m1-phase4.md（Alex，2026-08-16 晚）。性质：快审+熔断，照 L2 先例。
> 实核：AIEngine.swift（evaluate 九调用点 :174/:466/:730/:745/:772/:845/:954/:982/:985）· AIEvaluator.swift（evaluate :16-75 全分项）· SearchBoardV2.swift（:7-8 留位注记）· KingSafetyEvaluator.swift 存在性 · m1-hotpath-redesign.md v1.2（§5.1-5.3 / §7.2 P4 行 / §8.4）· m1-cross-review.md D4 :781-783 + D2 :320/:693。
> 钟取：2026-08-16 21:32（date 系统钟）。

## 总表

| # | 审点 | 裁定 | 量级 |
|---|------|------|------|
| 1 | P4-0 判定树完备性 | **同意**（闭合）+ 2 注 | 补两行 |
| 2 | 实核事实抽查 | **3/3 通过** + 1 补漏（root :174/:466 未列） | 补一行 |
| 3 | Spearman ≥0.9 + KingSafety 左移 | **方向对** + 2 严谨性补强 | 补指标定义 |
| 4 | 回退三级链互斥完备 | **缺 L1→L2 运行期升格路径** + 判据① 统计功效不足 | P1 改 + 补路径 |

## 1. P4-0 判定树 —— 同意（闭合），附 2 注

判定树闭合 ✓：通过 → PST 提取 + 继续；不通过 → standPat 设计期保留全量 + B 收益重估 ×1.5-2 + razor/futility 廉价化存续性复查 → 报 Luke 裁。兜底是 escalation（非设计缺口）。

**注 1（P4-0 核查范围补漏）**：AIEvaluator.evaluate :18-20 有 **EndgameEvaluator 早返**（≤6 子直接返回 endgameScore，不走 material+PST 主路径）。cheapEval = materialSum+pstSum 在残局局面天然偏离 full eval（不同分值体系）。P4-0 判定树原文只提"pattern/mobility 耦合"——应补 EndgameEvaluator 早返作为**已知发散源**显式核查。QS 轨迹样本里残局占比可能低（mid-game 搜索树），但 razor/futility 浅层节点可能触及稀疏局面——核查时分层报相关系数（非残局 / 残局），不要合一取 pooled。
- 部分通过路径建议补：若 cheapEval 仅在非残局达 ≥0.9 → standPat 加 endgame 守卫（`board.pieces.count > 6` 才 cheap，否则 full），开关位不变。这是判定树"部分通过"的天然分支，闭合性更强。

**注 2（switch 默认值条件化）**：§1 "默认 false（cheap on）= M1 V2 主张路径"——此默认**以 P4-0 通过为前提**。不通过分支下 standPat 设计期全量 = qsStandPatFullEval 实质恒 true（开关无意义）。§1 应注明"默认 false 条件于 P4-0 通过；不通过线开关废弃，standPat 固定全量"。

## 2. 实核事实 —— 3/3 通过 + 1 补漏

| 抽查项 | phase4 声称 | 实核 | 判定 |
|--------|------------|------|------|
| SearchBoardV2:7-8 留位 | materialSum/pstSum P2b 留白 | :7-8 原文"materialSum/pstSum 增量字段按 v1.2 §2.1 属 B 阶段配套，本 Phase 不落" | ✓ 精确 |
| 六调用点行号 | :730/:954/:982/:772 保·:745/:845/:985 改 | grep evaluate 全九点，六点搜索内部行号逐一对齐 | ✓ 精确 |
| PST 从 evaluate 分项提取 | cheapEval = materialSum+pstSum | AIEvaluator :28-35 materialScore（dynamicValue）+ positionScore（PositionTables.positionWeight）——PST 项存在且可提取 | ✓ 可行 |

**补漏**：grep 另有 :174/:466 两处 evaluate（root rawScore，bestMoves topK / rootSearch 走法评分）——phase4 "六调用点"未列。判定：**有意遗漏**（根层产品质量评分，同叶子"分值决定搜索质量不降"理由）——但应在"三保"或范围外显式声明，免 Ruby 审查时误为遗漏。建议补一行"根层 rawScore :174/:466 全量保留（产品质量评分，同叶子口径，不进分流表）"。

## 3. Spearman ≥0.9 + KingSafety 左移 —— 方向对，附 2 严谨性补强

**Spearman ≥0.9 条件化** ✓——我存疑②落点正确：门槛仅 P4-0 通过后才有意义，phase4 §4 #2 已条件化。样本 ≥1000 + 吃子链集覆盖 QS 分布 ✓；≥1000 样本下 Spearman CI ±0.01，阈值判定稳定 ✓。

**补强 1（margin-flip 率）**：Spearman 测全局秩相关，但剪枝判定关心的是 **margin 附近符号翻转**——一个 position 集 rank-correlation 0.95 仍可能在 alpha/beta 边界处 flip 符号（决策关键区）。建议补一个直击目标的指标：**margin-flip 率** = 样本中 `sign(cheapEval - alpha) ≠ sign(fullEval - alpha)` 的比例，门槛 ≤5%（或类似）。与 Spearman 并列，Spearman 管"整体排序相似性"、flip 率管"决策关键区一致性"。

**补强 2（KingSafety 左移操作化）**：§5 risk #1 "敏感局面 QS 深度分布左移即触发"——"敏感局面"与"显著左移"均未定义。建议：
- 敏感局面 = `|KingSafetyEvaluator.kingSafetyScore| ≥ W_safety × threshold` 的局面（操作化定义，可从 AIEvaluator :51-52 直接取）
- 左移检验 = 配对 Wilcoxon（或 mean Δ ≥ 0.3 层实用门槛）+ 明示为**观测触发**（非统计 gate），避免 Tina 校准时陷入"显著不显著"的解释困境

## 4. 回退三级链 —— 缺 L1→L2 运行期升格路径 + 判据① 统计功效不足

**三级澄清**（Luke 框架对齐）：
- L0（默认）= standPat cheap + razor/futility cheap（全 cheap）
- L1（开关 on = "margin-only"）= standPat full + razor/futility cheap
- L2（设计期全量）= standPat full + razor/futility full（P4-0 不通过线）

**缺口（P1）**：L2 是**设计期决策**（P4-0 不通过），非 L1 的运行期升格。运行期 L0→L1 有开关；L1 若不解（判据② 触发但 standPat switch 后敏感局面深度仍左移 = razor/futility cheapEval 残留偏差）→ **无设计运行期 L1.5**，只能 commit revert P4-②。§5 回退形态"只保 razoring/futility 廉价化"隐含 L1 是稳态，但未声明 L1 不解时的升格路径。
- **修法**：§5 补"L1 升格条款"——判据② 触发 → switch on → 重跑敏感局面深度对比 → 若仍左移（razor/futility 残留偏差）→ 归因为 cheapEval 全局偏差 → commit revert P4-②（razor/futility 回全量），非零 rebuild，Luke 决策点重估 B 收益（×0 档，仅留增量字段收益）。**这是运行期可达的 L1.5**，补全链。

**判据① 统计功效不足（P1）**：§5.3 v1.2 原文"两条独立 match 序列 vs 同一 v4.3 基线（各 ≥50 局比 Elo 差）"——两路各 50 局 vs v4.3 = 两个独立 Elo 点估计各 ±100，差值的 CI ≈ ±140。**>30 触发在 CI ±140 下噪声主导**（true δ=0 时 P(point est >30) ≈ 40%+）——假回退率过高，B 收益无谓流失。双保险 AND（两路都 >30）降至 ~14% 仍偏高，且 AND/OR 未声明。
- **修法（基础设施已在）**：phase4 §1 轴分离理由① 已设计 SelfPlayRunner 同进程双引擎 A/B——**直接 cheap vs full 配对序列**（同 binary、同开局、交替红黑）= 配对数据，方差近半减 + 开局方差消去，50 局 paired CI ~±50-60，>30 触发才有统计意义。建议：判据① 主信号 = cheap-vs-full 直接配对 ≥50 局；两路 vs v4.3 降为 secondary（绝对校准锚，不直接管回退）。v1.2 §5.3 "双保险"口径随之条件化（phase4 是有权改的，§5 全引但 §4 #3 可加主/辅口径声明）。

**触发时序**（minor）：判据①（Elo，batch 后）vs ②（深度，可 mid-batch）——若 ② mid-batch 触发，是立即 switch + 重启 batch 还是跑完再判？建议声明：② mid-batch 触发 → 标记 + 跑完当前 batch → 与 ① 合判（避免中途重启引入选择偏差）。

## 附加

**8.4 快照字段扩展（D2 :693 承载）**：P4-① 增量字段落地后，§8.4 往返一致性"原快照（全字段）"须扩 materialSum/pstSum——D2 :693 原指令"快照字段清单随 Phase 扩展：P4 追加 materialSum/pstSum"。phase4 §4 #5 增量全等专项隐含覆盖，但 8.4 清单应显式声明（Ruby P4 审查单对照点）。

**v1.2 §5.3 遗留 stale claim**："全量 evaluate 自身顺带提速：pieces(for:) 等扫描接口改走槽位遍历"——我 D1 P2-1 当年标"空洞承诺"（泛型代码拿 [Piece] 数组，槽位遍历需 V2 特化）。v1.2 吸收表编号体系不同，此项未修入。phase4 §5 全引但不重复该句即可（不扩 scope 修 v1.2），仅记一笔供 Alex 知悉：若 §5.3 该句入 phase4 正文，按 D1 P2-1 修法① 改措辞"接受 O(32) 重建成本，相对评估计算量可忽略"。

## 通过项（正面清单）

- 轴分离正交论证（编译=表示 vs 实例=评估策略）三条理由成立——"编译开关把评估回退伪装成表示回退"的洞察是设计层面正确分隔的标志 ✓
- supportsCheapEval 旗标复用 P3-① supportsCheckLegalOrder 形态（as? 分派，Legacy 零触碰）✓
- 开关面最小化（仅 standPat 位，razor/futility 不设开关靠 margin 容差）= 校准矩阵 2 轨 ✓
- Ruby :661/:728 QS 语义锁（过滤仅 continue、自然耗尽返 standPat、无 legalCount）P3-③ 已定 P4 不触 ✓
- 双态门禁复用 phase3 §4 #1 ✓；增量全等专项（随机局面从零重算 vs 增量）✓ 增量系统经典验证
- 回滚轴 P4-①② commit 级 revert + 开关实例级独立于 USE_SEARCHBOARD_V2（轴分离）✓
- P2b 留白注记确认 ✓（:7-8 实锚）；materialSum/pstSum 消费者即到

## 熔断条款（照 L2 先例）

1. **P4-0 未通过 → P4-① 不得开工**（standPat 廉价化前提）——判定树 §2 兜底报 Luke 裁
2. 增量全等专项（§4 #5）任一失败 → P4-① 冻结（增量系统地基）
3. 判据② 触发后 standPat switch 不解（L1 升格条款）→ commit revert P4-② = B 阶段实质退场，Luke 决策点重估
4. **重开条件**：若 P5 归因指向 cheapEval 方向性偏差（KingSafety 系统性）且 L1 switch 不足以解 → 乙级升格：razor/futility 也设实例开关（2² 轨校准矩阵），或 KingSafety 廉价近似立项（M2 候选池，与 phase3 乙案 mate 激活同池）

## 工期影响

设计 79 行薄形态合格，四审点仅 §5 回退链（L1 升格条款 + 判据① 主信号改配对）+ §2 判定树（Endgame 补 + switch 默认条件化）+ §1 补漏一行需 Alex 改——**半天内可消化，不阻塞明早 Cody P3 收口后接 P4 开工节奏**（P4-0 只读核查零依赖§3/§4 修订，可先行）。Ruby 0.25d 审单建议补三对照点：Endgame 分层相关系数 / margin-flip 率 / L1 升格路径执行性。

> **✅ Luke 验收（2026-08-16 晚）**：两 P1 全采纳（判据① 配对主判 + L1 升格条款闭合）+ Endgame 分层守卫 + 小件四收。修订令已发 Alex（明早 v1.1，不阻塞 Cody P4-0 先行）。

---

## v1.2 复审（加班单，丹妮转达洪涛指令 P4 今晚全链闭环）

> 复审对象 docs/phases/m1-phase4.md v1.2（08-16 21:55，v1.1 消化我四点 + v1.2 落 Luke 五处裁决）。钟取 2026-08-16 夜。

### 逐点核销

| 发现 | v1.2 落点 | 判定 |
|------|-----------|------|
| P1-1 判据① 配对主信号 | §4 #3 主信号 = cheap-vs-full 配对 ≥50 局 + secondary 绝对锚 + 双保险重释 | ✓ 全文采纳 |
| P1-2 L1 升格条款 | §5 三级链 L0/L1/L1.5（升格条款）/L2 + “链闭合无死端” | ✓ 全文采纳 |
| Endgame 分层+守卫 | §2 判定树三分支（含部分通过→endgame 守卫）+ §4 #2 分层报 | ✓ 全文采纳 |
| switch 默认条件化 | §1 边界规则末条 | ✓ |
| root :174/:466 声明 | §1 范围外显式声明段 | ✓ |
| margin-flip ≤5% | §4 #2 与 Spearman 并列 | ✓ |
| KingSafety 操作化 + mid-batch 合判 | §5 risk #1 | ✓ 含 minor 时序点 |
| 8.4 快照扩展 | §4 #5 | ✓ |
| 熎断 4 条 + Ruby 三对照点 | §5 回滚轴 + §1 显式行 | ✓ 原文 |

### 复审新增（非阻塞，Cody/Alex 各一行）

1. **endgame 守卫的 O(1) 实现（Cody）**：判定树部分通过分支写“board.pieces.count > 6”——若经 `pieces` 计算属性（O(32) 槽数组建数组）在 standPat 热路径每节点分配，静默吃掉 cheapEval 部分收益。建议：P4-① 增量字段族顺带加 `pieceCount` 增量维护（或无分配槽扫），守卫取 O(1)。一行注记，编码时落。
2. **部分通过分支 razor/futility 残局复查（Alex 可选）**：不通过分支有“razoring/futility 廉价化存续性一并复查”；部分通过分支仅守卫 standPat，razor/futility 的残局表现靠 margin 容差隐式吸收。可加半句“部分通过线 razor/futility 残局分层一并入校准观察”。非阻塞——剪枝误判代价 = 多搜/少搜一层非分值污染，设计已论证。

### 复审裁定

**通过，建议定稿入库。** v1.2 对快审四点吸收完整无失真；新增两注均为编码级/可选强化，不动设计骨架。三级链闭合、配对主信号统计成立、判定树三分支闭合、范围声明完备——设计质量链就位，Cody 可按 §3 顺序开工（P4-0 只读先行）。

— Vera，2026-08-16 夜（加班单）

— Vera，2026-08-16 21:32
