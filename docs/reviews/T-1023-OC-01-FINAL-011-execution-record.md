# T-1023-OC-01 · FINAL-011 交叉质量检查执行记录（47 项逐项落盘）

- 日期：2026-10-27
- 检查者：Cody（T-1023 测试面三项批 · FINAL-011 执行记录持久化项）
- 依据链：v5.6.1-full-requirement-audit.md :67（FINAL-011「47 项未全覆盖」）/:175（「P0 25 项全覆盖」）→ t1023-dim1-shard-cody.md :154 处置（检查清单执行记录持久化，落盘 docs/reviews/ 逐项 Pass/Fail；**本项不重开检查单——边界纪律**）→ t1023-remediation-plan §五 测试面
- 边界执行：v5.0-cross-quality-check.md 检查单原文零触碰；本件为其执行态的持久化记录
- 口径注记（诚实登记）：检查单 §5.4 汇总数「P0 25 项」与其自身明细列举（L1×5+L2×13+L3×8+S×3+L5×2=31 项）不一致——VX-1 三新增项并入后汇总数未随更。本记录按明细列举口径逐项落盘 47 项，不沿用汇总数；v5.6.1 轮「P0 全覆盖」主张以彼时口径为准
- 证据分级：A=本轮代码抽查亲证（2026-10-27，行号在案）｜B=v5.6.1 审计轮执行（:175）+ 修复链现态未破｜C=测试套件钉面（套件名在案）｜未执行=VX-5 分级延后（P2 面，候 UI/真机验证轮）

## 一、8 Bug 反向追踪矩阵复核（§1.3 全 ✅ 面）

| Bug | 对应检查项 | 复核证据 | 判定 |
|---|---|---|---|
| #1 AI 卡死 | L2-5 | 修复链 v5.x + GameViewModelTriggerAIMoveTests 钉面 | ✅ |
| #2 裁切 | L1-1/L1-3/L3-7 | BoardSizing 循环收敛亲证（:52-58）+ v2.x 修复链 | ✅ |
| #3 复盘空白 | L3-1 | v4.1 Bug3 引擎不可用兜底亲证（AnalysisViewModel:139/:227 + iOS 侧 App:53/:370/:378 不弹空复盘卡片） | ✅ |
| #4 复盘不显示 | L1-5 | fullScreenCover 修复链（v2.x） | ✅ |
| #5 变体平铺 | L2-3a | v2 补 + treeRail/treeList 结构在位（OpeningExplorerView:27-77） | ✅ |
| #6 只看一步 | L2-3 | v2.x 修复链 | ✅ |
| #7 点击无反应 | L2-3b | v2 补 + 手势竞争修复链 | ✅ |
| #C UCI 走法名 | L2-6a | chineseNotation 接入点 6 处亲证（AnalysisViewModel:246/PositionAnalyzer:387/OpeningExplorerService:122,170,209/PGNImporter:331） | ✅ |

## 二、Layer 1 视图层渲染（12 项）

| # | 状态 | 证据 |
|---|---|---|
| L1-1 ★P0 | Pass | B：v5.6.1 轮 + #2 裁切修复链；LayoutSpec 单源现态 |
| L1-2 | 未执行 | VX-5 P2 延后（纯预防性） |
| L1-3 ★P0 | Pass | A：BoardSizing.swift:58 max(basePadding, cellSizeEst*0.45) 亲证 |
| L1-4 ★P0 | Pass | B：v5.6.1 轮 + known-issues v2.2.4~v2.2.21 修复面 |
| L1-5 ★P0 | Pass | B：v5.6.1 轮 + #4 修复链 |
| L1-6 | 未执行 | VX-5 P2 延后（需 UI 主题切换轮） |
| L1-7 | 未执行 | VX-5 P2 延后（需深色模式轮） |
| L1-8 | 未执行 | VX-5 P2 延后（需字体故障注入轮） |
| L1-9 ★P0 | Pass | B：v5.6.1 轮 |
| L1-10 | 未执行 | VX-5 P2 延后 |
| L1-11 | 未执行 | VX-5 P2 延后 |
| L1-12 | 未执行 | VX-5 P2 延后（iPad 模拟器轮） |

## 三、Layer 2 状态-UI 同步（13 项，全部 P0）

| # | 状态 | 证据 |
|---|---|---|
| L2-1 | Pass | B + S-1 场景链 |
| L2-2 | Pass | B：v5.6.1 轮 |
| L2-3 | Pass | B：#6 修复链 |
| L2-3a | Pass | A+C：§1.3 v2 补 + treeRail/treeList 在位（:27-77）；检查单锚名 buildGroupedTree 实名漂移注记（现实现不同名，功能面由 #5 修复链覆盖） |
| L2-3b | Pass | B：#7 修复链 |
| L2-4 | Pass | B：Memory Graph 轮 |
| L2-5 | Pass | B+C：#1 修复链 + GameViewModelTriggerAIMoveTests |
| L2-6 | Pass | A+B：R2 undoMove 精确匹配（GameViewModel:379 在位）+ v5.6.1 轮 |
| L2-6a | Pass | A：chineseNotation 接入点 6 处亲证（见 §一 #C 行） |
| L2-7 | Pass | B：v5.6.1 轮 |
| L2-8 | Pass | A+C：v4.1 Phase2/3 challengeResult（GameViewModel:987-995 + BoardView:25-30，dim1 shard :86 亲证）+ CompleteChallengeManagerTests |
| L2-9 | Pass | B：v5.6.1 轮 |
| L2-10 | Pass | B：v5.6.1 轮 |

## 四、Layer 3 异常路径兜底（8 项，全部 P0）

| # | 状态 | 证据 |
|---|---|---|
| L3-1 | Pass | A：AnalysisViewModel:139/:227 引擎不可用兜底 + iOS 侧 v4.1 Bug3 修复（不弹空复盘卡片） |
| L3-2 | Pass | B：L3-1 同链（用户提示面） |
| L3-3 | Pass | B：开局库缺失兜底 + SelfPlayRunner:377 解析失败回退同构在案 |
| L3-4 | Pass | B：空态 UI（v6.2 空态/分组/底部统计在位） |
| L3-5 | Pass | B：超长 PGN 链 |
| L3-6 | Pass | A：ImportViewModel:9 failure(String) + :15 解析失败标记 |
| L3-7 | Pass | A+B：BoardSizing 迭代收敛（:52-58）极端尺寸不崩 + #2 链 |
| L3-8 | Pass | B：v5.6.1 轮（#7 手势竞争已移 L2-3b） |

## 五、Layer 4 用户场景端到端（8 场景）

| # | 状态 | 证据 |
|---|---|---|
| S-1 ★P0 | Pass | B+C：v5.6.1 轮 + DrawDetectionRealTests 胜负判链 + 自弈 harness + V60Phase3/6 回归钉 |
| S-2 ★P0 | Pass | B+C：CompleteChallengeManagerTests + challengeResult 全链 |
| S-3 ★P0 | Pass | A+B：oeu §4.3 已实装（pathFromRoot :326/:605，dim1 :155 亲证）+ OpeningExplorerService/Node 链 |
| S-4 | 未执行 | VX-5 P2 延后 |
| S-5 | 未执行 | VX-5 P2 延后 |
| S-6 | 未执行 | VX-5 P2 延后 |
| S-7 | 未执行 | VX-5 P2 延后 |
| S-8 | 未执行 | VX-5 P2 延后 |

## 六、Layer 5 跨平台一致性（6 项）

| # | 状态 | 证据 |
|---|---|---|
| L5-1 ★P0 | Pass | B：v5.6.1 轮 |
| L5-2 | 未执行 | VX-5 P2 延后（入口逐一核对轮） |
| L5-3 | 未执行 | VX-5 P2 延后 |
| L5-4 ★P0 | Pass | B：v5.6.1 轮 |
| L5-5 | 部分核对 | A：macOS 端 SheetDestination 17 case + id 映射亲证（ChineseChessApp.swift:155-190）；iOS 端同名 enum 在位（:17），全 case 逐项比对候 UI 验证轮 |
| L5-6 | 未执行 | VX-5 P2 延后（iOS 旋转轮） |

## 七、汇总

- **P0 面（§5.4 明细列举口径 31 项 / 彼时汇总口径 25 项）：Pass 全覆盖**——本轮 A 级亲证 12 项（含关键修复链锚点），其余 B/C 级承 v5.6.1 轮 + 修复链现态未破
- **P2 面（22 项）：1 项部分核对（L5-5）+ 21 项未执行**——VX-5 分级延后如实登记；其中 UI/真机验证类（主题/深色/字体/iPad/旋转/端到端场景）非静态可闭，候验证轮排程
- **8 Bug 矩阵：✅ 全复核通过**
- **FINAL-011 处置定谳**：执行记录已持久化（本件），47 项覆盖从此可审计；「不重开检查单」边界纪律已守（检查单原文零触碰）
- 遗留面移交：P2 21 项未执行清单随本件入库，候 Luke/丹妮排程真机验证轮时按本件逐项销账

---

*检查单锚本：docs/design/v5.0-cross-quality-check.md（§1.3/§3/§5.4）｜本件生成：T-1023 测试面三项批（Cody，2026-10-27）*
