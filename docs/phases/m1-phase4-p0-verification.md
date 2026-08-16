# P4-0 分解性核查报告（2026-08-16 夜，Cody）

> phase4.md §2 判定树输入 · 只读核查 · 结论：**通过（分层口径）** → PST 提取 + P4-①② 开工

## 一、全量 evaluate 分项结构实核（AIEvaluator.swift :15-64）

| 分项 | 结构 | 可分解性 |
|---|---|---|
| material（:27-35） | Σ dynamicValue(piece, totalPieces)，黑加红减 | ✅ 逐子可加 |
| PST（:31-33） | Σ PositionTables.positionWeight(piece, totalPieces) | ✅ 逐子可加 |
| pattern（:38-40） | PatternRecognizer.bonusPatterns 整体 | ❌ 非逐子（独立加分项） |
| safety（:44-48） | KingSafetyEvaluator 整体 | ❌ 非逐子（独立项） |
| mobility（:52+） | simplifiedMobilityScore 整体 | ❌ 非逐子（独立项） |
| Endgame 早返（:18-20） | ≤6 子直接返回 endgameScore **不走 material+PST** | ⚠️ 硬发散源（Vera 注 1 实核确认） |

**关键发现 1——耦合判定**：material 与 PST 均为**分项相加结构，无乘法耦合**。cheapEval（materialSum+pstSum）缺失的是 pattern/safety/mobility 三个**独立加分项**——它们是"噪声项"而非"结构耦合项"，Spearman 门槛可达性成立。

**关键发现 2——phase 相位依赖**（设计稿未列，本核查新增）：
- dynamicValue **残局调整**（:87-99）：soldier 过河 ×2 / elephant ÷2 / advisor ×0.75，触发条件 `totalPieces ≤ 16`
- PositionTables **开局/残局双表**（PositionTables.swift:139 `isEndgame = totalPieces ≤ 16`）：horse/chariot/cannon/soldier 四类有相位切换
- **推论**：cheapEval 的 pstSum 若用固定表，在 totalPieces ≤16 区间与 full eval 的 PST 分项**系统性偏离**——PST 提取必须**双表都提**（开局表 + 残局表），materialSum 的 dynamicValue 调整同样双相位。增量维护需跟踪 pieceCount 跨 16 阈值（整表切换 = 全子重算一次，每局至多 1-2 次，可接受）

## 二、判定树落点：通过（带两条实现纪律）

- **非残局（>16 子）**：单表单相位，material+PST 纯子力/位置 → Spearman ≥0.9 预期可达 ✅
- **残局（7-16 子）**：双表切换正确实现后仍逐子可加 → 预期可达（pattern/safety 占比升高略降相关，留校准观察）
- **≤6 子（Endgame 早返域）**：full eval 直接返回 endgameScore，cheapEval 天然偏离 → **分层报告，不入 pooled**（Vera 注 1 口径）；QS 轨迹中该域占比极低（mid-game 搜索树），razor/futility 浅层稀疏局面触及 → 残局分层入校准观察（Vera §6.2 建议采纳）
- **standPat endgame 守卫（Vera :21）**：本核查 **不需要**（早返域 ≤6 子时 full eval 自身就是精确残局分——若 standPat 走 cheap 会偏离；守卫条件实为 totalPieces ≤ 6 时用 full）。实现纪律：**守卫读 pieceCount 增量字段 O(1)（Vera 注 1 编码级要求），不用 board.pieces.count 计算属性（每节点数组分配）**

## 三、PST 表提取清单（P4-① 交付物锚）

提取源 = `PositionTables.positionWeight` 调用链（7 kind × 开局/残局双相位）：
- general/advisor/elephant：单表（无 isEndgame 分支）→ 3 表
- horse/chariot/cannon/soldier：双相位 → 8 表
- **共 11 张表 + dynamicValue 残局三调整**（soldier×2/elephant÷2/advisor×0.75，totalPieces≤16 触发）
- 提取方式：从 PositionTables 现有实现**逐值复刻**（不从零发明——cheapEval 全等性锚，phase4 §1.1 原文）
- totalPieces 口径：`board.pieces.count` 含将帅——V2 增量 pieceCount 同口径（活子数）

## 四、结论

**P4-0 通过** → P4-①（增量字段 + 双表 pstSum + cheapEval + 增量全等专项）+ P4-②（六点分流 + qsStandPatFullEval 实例开关）按 §3 顺序开工。开关默认 false（cheap on）有效（P4-0 通过前提满足）。
