# v3.9 D1 拆分交叉审核 — 对比汇总

**汇总人**: Luke | **日期**: 2026-07-15

---

## 一、审核概况

| 子任务 | 主审 | 复核 | 问题数 | 报告路径 |
|--------|------|------|--------|----------|
| 子1 棋子走法规则 | Vera | Alex ✅ | 5 (P0×0→P2, P3×3) | v39-d1-sub1-piece-moves.md |
| 子2 胜负判定 | Ruby | Vera（进行中） | 6 (P0×2, P1×2, P2×1, P3×1) | v39-d1-sub2-win-loss.md |
| 子3 AI 引擎逻辑 | Alex | Tina ✅ | 12 (P0×1, P1×4, P2×4, P3×3) + 4项复核补充 | v39-d1-sub3-ai-engine.md |

**原 D1 报告**：17 项（P0×2, P1×6, P2×6, P3×3）

---

## 二、新发现 vs D1 原报告

### 子1 新发现（Vera，3 项）

| # | 问题 | 级别 | D1原报告 | 说明 |
|---|------|------|----------|------|
| 新1 | 将 canAttack 死代码 | P2 | 未发现 | isInCheck中对方将canAttack永远返回false，飞将由独立逻辑处理 |
| 新2 | 象验证不检查from半场 | P3 | 未发现 | isValidElephantMove只检查to在半场，不检查from |
| 新3 | countPiecesBetween不防from==to | P3 | 未发现 | 同位置时返回0而非报错，防御性问题 |

**根因**：canAttack 与 isMovePatternValid 两套独立实现导致不一致。Alex复核确认，建议合并。

**Alex复核修正**：canAttack调用方只有2处（isInCheck + safeRandomMove），Vera说的3处有误（CoachExplainer.isSafeCapture不调用canAttack）。

### 子2 新发现（Ruby，4 项，含 2 个 P0）

| # | 问题 | 级别 | D1原报告 | 说明 |
|---|------|------|----------|------|
| 新4 | detectPerpetualCheck不检查局面重复 | P0→P1* | 未发现 | 连将杀战术会被误判为长将判负 |
| 新5 | checkGameState优先级错误 | P0→P1* | 未发现 | 三次重复判和在长将判负之前 |
| 新6 | 长捉未实现 | P1 | 未发现 | 代码无长捉判定逻辑 |
| 新7 | 三次重复用国际象棋规则 | P2 | 未发现 | 无条件判和，不完全符合中国象棋 |

*Luke降级说明：问题4和5是规则解释设计问题，非代码逻辑错误。已纳入Phase 2规则修正。

**子2确认D1已知问题**：CheckmateSearch maxResponses=8剪枝（D1-P1-6）

### 子3 新发现（Alex 4项 + Tina复核补充4项）

**Alex主审新发现**：

| # | 问题 | 级别 | D1原报告 | 说明 |
|---|------|------|----------|------|
| 新8 | negamax isTerminal返回材质分 | P0 | 未发现 | AI不识别forced mate，Phase 1已修复 |
| 新9 | LMR重搜用原始alpha | P1 | 未发现 | Re-search应使用当前alpha |
| 新10 | QS checkMoves每节点35次execute/undo | P1 | D1-P1-4相关 | 根因是allLegalMoves，不仅是checkMoves过滤 |
| 新11 | 兵/卒位置表row7→8暴跌18倍 | P1 | 未发现 | 过河兵评估跳变异常 |
| 新12 | PositionAnalyzer fallback符号错 | P1 | 未发现 | 回退到自研引擎时评估符号反转 |

**Tina复核补充**：

| # | 问题 | 级别 | 说明 |
|---|------|------|------|
| 新13 | QS根因在allLegalMoves本身 | P1 | 不仅checkMoves过滤，allLegalMoves就是性能瓶颈 |
| 新14 | Null Move Pruning mate score扭曲 | P1 | 返回beta而非nullScore，丢失将死信息 |
| 新15 | beginner难度体验断层 | P2 | 30%搜索+70%随机，体验不连贯 |
| 新16 | Futility Pruning缺将军保护 | P2 | 非吃子将军走法被误剪 |

---

## 三、D1原报告问题确认状态

| D1原问题 | 子审核确认 | 级别变化 |
|----------|-----------|---------|
| P0-1 象canAttack半场检查 | 子1确认 ✅ | 维持P2（防御性缺陷） |
| P0-2 将帅攻击逻辑 | 子1确认 ✅（子1新1将canAttack死代码） | 维持P2 |
| P1-1 士canAttack宫殿检查 | 子1确认 ✅ | 维持P1 |
| P1-2 piece(at:) first匹配 | 未再审查 | 维持P1 |
| P1-3 snapshot引用 | 子1确认 ✅安全 | 降为无问题 |
| P1-4 QS全量走法 | 子3深化 ✅ + Tina补充根因 | 维持P1 |
| P1-5 givesCheck线程安全 | 子3未再审查 | 维持P1 |
| P1-6 CheckmateSearch剪枝 | 子2确认 ✅ | 维持P1 |
| P2-1 wouldBeInCheck snapshot | 子3确认 ✅ | 维持P2→Phase 4优化 |
| P2-2 FEN棋子数量校验 | 未再审查 | 维持P2 |
| P2-3 FENDecoder线性查找 | 未再审查 | 维持P2 |
| P2-4 开局库v1依赖FENParser | 未再审查 | 维持P2 |
| P2-5 safeRandomMove在snapshot上 | 未再审查 | 维持P2 |
| P2-6 toggleTurn访问控制 | 未再审查 | 维持P2 |
| P3-1 红方棋子名称 | 未再审查 | 维持P3 |
| P3-2 EvalWeights合并注释 | 未再审查 | 维持P3 |
| P3-3 Zobrist不更新moveHistory | 未再审查 | 维持P3 |

---

## 四、新增问题汇总（共 16 项）

| 级别 | 数量 | 关键项 |
|------|------|--------|
| P0 | 1 | negamax isTerminal（Phase 1已修复） |
| P1 | 7 | 长将局面重复+优先级、LMR alpha、QS根因、兵位置表、Null Move mate、PositionAnalyzer符号、长捉未实现 |
| P2 | 5 | 将canAttack死代码、三次重复规则、beginner体验、Futility将军保护、OpeningBoardPreview竖线 |
| P3 | 3 | 象验证from半场、countPiecesBetween防御、isTerminal死代码清理 |

---

## 五、对Phase 2方案的影响

### 规则修正（新增3项，洪涛已确认）
- detectPerpetualCheck加局面重复检查
- 长将判负优先级提前到三次重复之前
- 去掉50回合自动判和

### 性能优化（新增2项）
- Null Move Pruning mate score特殊处理
- Futility Pruning增加将军走法保护

### 远期（v4.0）
- beginner难度重构（始终搜索+评估噪声）
- canAttack与isMovePatternValid合并重构

---

## 六、拆分审核价值评估

| 维度 | 原D1 | 拆分后增量 | 评价 |
|------|------|-----------|------|
| 问题数 | 17 | +16（去重后约12项有效新增） | 发现率提升~70% |
| P0发现 | 2（均降为P2） | +1（negamax isTerminal，真P0） | 拆分审计发现关键bug |
| 规则正确性 | 未涉及 | +2（长将重复+优先级） | 跨维度视角补充 |
| 性能分析 | 定性 | +量化（1.5-2层深度损失） | 深度提升可操作性 |

**结论**：拆分交叉审核价值显著。原D1报告偏重代码级洞察（Alex架构师视角），拆分后补充了规则正确性（Ruby/UX视角）和测试可操作性（Tina测试视角），特别是negamax isTerminal P0的发现证明了交叉审核的必要性。

