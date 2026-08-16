# M1 Phase 4：B cheapEval 分流 + standPat 回退开关

> 依 m1-hotpath-redesign.md v1.2 §五（5.1-5.3 全量引用）+ §7.2 P4 行 + D4 :783 前置核查 + D2 :320 NPS 口径 · 设计 2026-08-16 晚 · Alex · 负责人 Cody
> v1.2 08-16 夜：Luke 五处裁决落定（与 v1.1 消化轮内容重合，交叉时序同 P3）+ 增两件：Ruby 审单三对照点显式行 / 行号 remap 注（v1.2 §5.2 旧→现状）。v1.1 = Vera 快审四点消化（Endgame 分层+守卫/margin-flip/配对主信号/L0-L1-L2+L1 升格/快照扩展）
> P3 四件复用不重述：capability-flag 分派形态（phase3 §1 裁定 A 同型）/ 双态门禁（phase3 §4 #1 口径）/ 专项集断言口径（8.4 族）/ 快审门槛预判（本文 <150 行 + v1.2 §5 全引 + phase3 四件 + R2 三判定 → 引用过半）

## 1. 目标与本 Phase 改动面

**B = 评估热路径降本**，三段（P2b 留白兑现，SearchBoardV2:7-8 注记为证——增量字段按 v1.2 §2.1 属 B 阶段配套，P2 避免无消费者派生状态）：

1. **V2 增量兑现**：materialSum[2]/pstSum[2] 字段 + make/unmake 增量维护（v1.2 §2.5）；PST 表**从全量 evaluate 分项提取复刻**（P4-0 核查通过后的交付物，不从零发明——cheapEval 全等性的锚）
2. **cheapEval O(1)**（v1.2 §5.1 代码原文引用不复制）
3. **六调用点分流**（现状行号实锚 08-16 晚，编码以 grep 现核）：

| 调用点 | 现状 | 改为 | 轴 |
|---|---|---|---|
| negamax 超时 :730 / QS 终止 :954/:982 / 叶子 :772 | 全量 | **全量保留**（低频/质量敏感，v1.2 §5.2 表） | — |
| razoring :745 | 全量 | **cheapEval 无条件**（V2 态） | margin 300/500 容差 |
| futility :845 | 全量 | **cheapEval 无条件**（V2 态） | margin 300/500/900 容差 |
| QS standPat :985 | 全量 | **cheapEval 默认 + 实例级回退开关** | 唯一分值污染通道 |

范围外显式声明（Vera §2 补漏）：根层 rawScore :174/:466（bestMoves topK / rootSearch 走法评分）**全量保留，不进分流表**——产品质量评分，同叶子"分值决定质量不降"口径（有意遗漏非疏漏，免 Ruby 审查误判）

**行号 remap 注**（v1.2 设计稿 §5.2 → 现状实锚 08-16 晚，编码以 grep 现核）：razoring 判定 :611→**:745** / futility 判定 :712→**:845** / QS standPat :829→**:985** / 叶子返回 :627→**:772**；另 QS 终止 :954/:982 与 negamax 超时 :730 为设计稿未列的现状保留点（Vera 九点 grep 补全）

**Ruby 审单对照点（Luke 预定，显式行）**：① Endgame 分层相关系数（禁 pooled）② margin-flip 率实现与阈值 ③ L1 升格路径执行性（switch on→重跑→revert 链可操作）

### 开关边界裁定（本 Phase 设计重心）

**轴分离原则**：USE_SEARCHBOARD_V2（编译开关）= 表示层结构选择，二值，P5 验收翻；qsStandPatFullEval（实例配置）= 评估策略，校准期活调。两轴正交，禁锁死。

**实例级而非编译开关，三条理由**：① SelfPlayRunner 同进程双引擎 A/B（同 binary 不同策略，编译开关做不到）② 回退判据触发即切、零 rebuild（校准是运行期发现，不是构建期决策）③ 策略回退在任何表示下语义有效，编译开关会把"评估策略回退"伪装成"表示回退"

**边界规则**：
- 协议加 `supportsCheapEval` 旗标（V2 true / Legacy false）——P3-① supportsCheckLegalOrder 同型复用（分派形态，不重述）
- **Legacy 态六点全走原路全量**，qsStandPatFullEval 无效位（双态门禁沿用 phase3 §4 #1）
- V2 态：razoring/futility **不设开关**（margin 自带容差吸收噪声，判定错误代价 = 多搜/少搜一层非分值污染）；standPat = 唯一开关位（分值直接进 alpha-beta 流）——**开关面最小 = 校准矩阵 2 轨**（不是 2³ 轨）
- 读取时机：搜索入口**每次调用**读 env `QS_STANDPAT_FULL=1` 默认值（不进程缓存）+ 实例覆盖（v1.2 §5.3 原文口径，入口函数 Cody grep 现核）
- 默认 false（cheap on）= M1 V2 主张路径，**前提 = P4-0 通过（Vera §1 注 2）**；P4-0 不通过线开关废弃（standPat 设计期固定全量，恒 true 无意义）；翻 true 只能由校准判据（§5）触发

### Vera R2 存疑点覆盖（明早快审对位点）

① **分解性核查前置**（D4 :783 采纳为 P4-0，§2）；② Spearman ≥0.9 门槛**口径条件化**——核查通过才有意义，样本 = QS 轨迹 ≥1000 + 构造吃子链集（v1.2 §8.4，随机局面代表不了 QS 分布）；③ KingSafety 方向性偏差 → 回退判据②敏感局面 QS 深度分布对比（§5）；④ NPS 归因口径：qsNodes 字段拆"每节点更快 vs 少搜"（D2 :320，P1 已加字段，P4 报告引用不重述）

## 2. 前置检查（铁律状态）

- P3 门槛全绿 ✅（phase3 §4 七项，Luke 验收记录为准）+ legalCount==0 甲口径已锁
- **P4-0 分解性核查（P1 级前置，D4 :783，半小时只读）**：全量 evaluate 分项（子力/PST/pattern/mobility/KingSafety）可分解性——pattern/mobility 若与子力耦合，cheapEval Spearman ≥0.9 天然达不到 = 口径错位非实现 bug；**另 EndgameEvaluator 早返为已知发散源显式核查（Vera §1 注 1）**：AIEvaluator :18-20 ≤6 子直接返回 endgameScore 不走 material+PST 主路径——cheapEval 在残局天然偏离 full（不同分值体系），核查时**分层报相关系数（非残局/残局不 pooled）**。**判定树**：通过 → PST 表提取 + 继续；**部分通过（仅非残局 ≥0.9）→ standPat 加 endgame 守卫（board.pieces.count > 6 才 cheap，否则 full），开关位不变**；不通过 → standPat 改设计期保留全量（B 收益重估 ×1.5-2 档），razoring/futility 廉价化存续性一并复查 → 报 Luke 裁
- P2b 留白注记确认（SearchBoardV2:7-8）——增量字段本 Phase 落，消费者即到

## 3. 实施步骤（commit 粒度，每 commit 独立可编译 + 双态门禁）

1. **P4-0 核查**（只读，无 commit；结论进完成报告 §6，PST 表提取清单随附）
2. **P4-① V2 增量 + cheapEval**：字段 + make/unmake 维护 + cheapEval API + **增量全等专项**（8.4：随机局面"从零重算 vs 增量"逐局面断言全等——增量系统经典验证，P2 交叉对比框架复用）
3. **P4-② 调用点分流 + 开关**：supportsCheapEval 旗标 + 六点分流（:745/:845/:985 三改三保）+ env/实例开关接线；Legacy 态零触碰（as? 旗标分派，phase3 §1 形态）
4. **P4-③ 校准双轨**（Tina 0.25d）：§4 #2/#3 执行 + 报告
- ①② 可合并单 commit（同族增量交付，Cody 裁量）；③ 是执行项非代码 commit

## 4. 验证命令与门槛（v1.2 §7.2 P4 行 + 双态）

| # | 验证 | 门槛 |
|---|------|------|
| 1 | 全量测试双态（phase3 §4 #1 口径复用） | 绿；Legacy 态测试账目零回归 |
| 2 | cheapEval vs 全量 Spearman（QS 轨迹 ≥1000 + 吃子链集，8.4；**分层报：非残局/残局**）+ **margin-flip 率**（Vera §3 补强 1：sign(cheapEval−alpha) ≠ sign(fullEval−alpha) 样本占比，直击剪枝决策关键区） | **≥0.9 且 flip ≤5%（P4-0 通过前提下）**；不达 → §5 回退流程 |
| 3 | QS 双轨校准：**主信号 = cheap-vs-full 直接配对 ≥50 局**（同 binary/同开局/交替红黑，配对 CI ~±50-60，>30 触发才有统计意义——Vera §4 修正：两路各 50 局 vs v4.3 差值 CI ≈ ±140 噪声主导）+ **secondary = 两路 vs v4.3 绝对校准锚**（不直接管回退） | 配对差 >30 → 回退流程（§5）；实例级开关同进程 A/B（v1.2 §5.3 双保险口径按主/辅重释） |
| 4 | IDS_DEPTH_LOG 深度对比 | 应单调提升（cheap 提速 → 同预算更深） |
| 5 | 增量全等专项（P4-① 内；**8.4 快照字段清单同步扩 materialSum/pstSum——D2 :693 指令，Ruby 对照点**） | 随机局面集逐局面全等 |
| 6 | NPS 观测（qsNodes 字段） | 只记录不设门（P5 统一） |

## 5. 已知风险与回滚点

| # | 风险 | 对策 |
|---|------|------|
| 1 | standPat 廉价分方向性偏差（KingSafety 缺失，非纯噪声） | 判据②**操作化**（Vera §3 补强 2）：敏感局面 = |KingSafetyEvaluator.kingSafetyScore| ≥ W_safety×threshold（AIEvaluator :51-52 直取）；左移检验 = 配对 Wilcoxon 或 mean Δ ≥ 0.3 层实用门槛，**观测触发非统计 gate**（免"显著不显著"解释困境）；② mid-batch 触发 → 标记 + 跑完当前 batch 与 ① 合判（免中途重启选择偏差） |
| 2 | 校准 Elo 回退（razor/futility 残留偏差） | 判据①（§4 #3 配对主信号）：配对差 >30 触发 L1 开关 |
| 3 | Spearman 不达（口径错位） | P4-0 前置拦截 + §2 判定树（设计期处置非运行期救火） |
| 4 | QS 循环语义漂移 | **锁**：P4 不触 QS 循环结构——Ruby :661/:728 语义（过滤仅 continue、自然耗尽返 standPat、无 legalCount）P3-③ 已定，P4 只换 standPat 取值来源 |
| 5 | margin 失配 | 不调（v1.2 §5.2 定论）；剪枝率观察留 Tina 校准记录，不扩 scope |

**回退三级链（Vera §4 澄清 + 补 L1 升格条款）**：
- **L0（默认）** = standPat cheap + razor/futility cheap（全 cheap）
- **L1（开关 on = margin-only）** = standPat full + razor/futility cheap（零 rebuild）
- **L1 升格条款（运行期可达的 L1.5）**：判据② 触发 → switch on（L1）→ 重跑敏感局面深度对比 → **仍左移 = razor/futility 残留偏差 → 归因 cheapEval 全局偏差 → commit revert P4-②**（razor/futility 回全量，非零 rebuild，B 收益 ×0 档仅留增量字段收益，Luke 决策点重估）
- **L2（设计期全量）** = P4-0 不通过线（判定树 §2，非运行期可达）
- 判据①触发 = L0→L1；L1 不解 = 升格条款；链闭合无死端

**回滚轴**：P4-①② commit 级 revert（增量字段无消费者后可整体退）；开关位实例级独立于 USE_SEARCHBOARD_V2（轴分离，§1）——表示回退不自动带走评估策略。**熔断**（Vera，照 L2 先例）：①P4-0 未通过不开工①；②增量全等任一失败 P4-① 冻结；③L1 升格条款触发 = B 实质退场，Luke 决策点重估；④重开条件——P5 归因指向 KingSafety 系统性偏差且 L1 不解 → razor/futility 也设实例开关（2² 轨矩阵）或 KingSafety 廉价近似 M2 立项（与 phase3 乙案 mate 激活同池）

## 6. 完成报告（合入时回填）

—（含 P4-0 核查结论 + PST 表提取清单 + 双轨校准数据 + qsNodes 口径引用）
