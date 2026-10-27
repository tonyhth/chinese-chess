# T-1023-OC-01·P1 — 中国象棋项目设计文档符合度全面检查计划

> 角色：Alex（架构师）| 日期：2026-10-20 | 版本：v1.1
> 状态：丹妮审查通过（2026-10-20 23:0x，五项裁示并入本版）；P2 已启动（D0+D1 先行）
> 派单链：洪涛 2026-10-20 22:09 全流水线授权 → 丹妮直派（Luke LOOP-FAIL 期间接管，恢复后转统筹）
> 台账：~/DevTeam/TASK-LEDGER.md L121（T-1023-OC-01，doing）
> 修订记录：v1.1 — 2026-10-20 丹妮审查通过，五项裁示并入（"v3.0 定稿"锚改判决策包定稿链 v65-weakening-chain-v3-draft v1.0 正式版；增补⑦⑧批准入 P2；PRD 双副本首日裁定+依据落盘；⑤维两栏口径批准+P4 衔接 T-1022 产物；P2 派发丹妮单通道确认）｜v1.0 — 2026-10-20 首版成稿（Alex）

---

## 一、背景与目标

洪涛指令：安排开发团队深入检查中国象棋项目按照设计文档的完成情况，思考提升改进空间（功能/操作/界面等），流程为 **制定详细检查计划 → 按计划执行 → 形成可落地整改方案和改进计划 → 改进 → 逐一验证**。

本文件是第一阶段（P1）交付物：详细检查计划。全流程分四段：

| 阶段 | 内容 | 约束 |
|------|------|------|
| P1（本文件） | 检查计划 | 零代码动作 |
| P2 | 按计划执行检查，出报告落 docs/ | **不打包/不编译/不改代码/不 tag** |
| P3 | 整改方案+改进计划，呈洪涛拍板 | 同上，纯方案 |
| P4 | 改进实施+逐一验证 | 走正常验收链（编码→Ruby→Tina→门禁） |

目标产物（终态）：可落地整改方案（P3）+ 改进计划，非审计报告堆料。P2 报告的一切发现项都要能直接映射为 P3 整改条目。

## 二、基线与增量策略（不推倒重来）

### 2.1 三层基线

| 层 | 基线 | 产物 | 用途 |
|----|------|------|------|
| A（主基线，派单指定） | v3.9 五维交叉审计（审计点 v3.9，报告落盘 2026-07-09~15） | docs/audits/v39-d1-game-logic.md、v39-d1-sub{1,2,3}-*.md、v39-d2-playability.md、v39-d3-ux-operability.md、v39-d4-feature-completeness.md、v39-d5-i18n.md、v39-d1-comparison.md、v39-phaseb-summary.md（共 9 件） | 六维②③⑤⑥的方法与发现基础；78 项发现（P0×4/P1×23/P2×29/P3×19） |
| B（①维直接前驱） | v5.6.1 全项目需求审计（2026-08-08，PRD v1.1 66 项×设计×代码三方对照，92.4% 通过） | docs/audits/v5.6.1-full-requirement-audit{,-design,-code}.md | 文档符合度维的方法模板与缺口清单 |
| C（专项补充） | v3.7.3 审计、v6.2 HIG 审计、ui-bugs-v5.5.3/ui-bugs-thorough-fix、m1-cross-review 四件、v6.4-ui-debt-ledger、known-issues.md（26 条 active） | 各自路径见 §六分工表 | 对应维度专项挂接 |

> 注：派单口径"2026-07-04 v3.9 五维交叉审计"与在盘产物时间（07-09~15 落盘）为同一审计战役，以在盘文件日期为准引用。

### 2.2 增量域（本检查的主战场）

v5.6.1 审计之后项目经历了大版本演进，以下区域为**全查区**：

- **PRD 增量**：需求功能说明书 v1.1 → v2.1（docs/需求功能说明书.md，基线应用 v5.6.2 快照 → v2.x 火车），差集条目需逐条对照实现
- **实现增量**：v5.6.1 → v6.4.2（当前 tag）：v6.0 统一 10 级段位/开局体系、v6.2 布局+HIG+平台对齐、v6.3 分析链修复（v6.3.0 缺陷中间态→v6.3.1 热修）、v6.4 布局重设计+L10n 段位制全量换轨+教练/工具栏批修、v6.5 削弱链（草案态，查文档态与实现态差距）
- **v3.9 遗留核销**：v39-phaseb-summary.md §四列 Phase1-4 共 18 项修复计划，逐项标注现状（已修/未修/部分/回归），未核销项自动进入本轮发现池

### 2.3 增量三原则

1. 基线发现项先标"仍开放/已修复/已过时"三态，再决定复检深度——已修复项只做回归面抽查，不重做全量审计
2. 增量区（§2.2）全查，方法沿用 v3.9 各维报告的证据格式与分级口径
3. 基线方法直接复用（D1 逐函数、D4 链路追踪、D5 key 覆盖量化等），不发明新方法论

## 三、检查对象：设计文档盘点清单（①维输入）

docs/ 全量约 200 件，按六类分片建立《文档×实现符合度矩阵》：

| 类 | 范围 | 代表锚点 | 备注 |
|----|------|----------|------|
| 1 需求/PRD | docs/需求功能说明书.md（v2.1）；docs/general/需求功能说明书.md | — | ⚠️ 疑似双副本，P2 首日做真相源裁定（头对头 diff），防分家 |
| 2 商业交付清单 | docs/archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md | — | 派单点名；对照当前 release 面（v6.4.2）逐项核销 |
| 3 定稿态/锁数红线文档（只读对照，零触碰） | **决策包定稿链（丹妮裁示①="v3.0 定稿"锚）**：T-1015-OC-01-l1-carrier-decision-pack.md（v1.3 归档态）+ v65-weakening-chain-v3-draft.md（**v1.0 正式版**，姊妹件行亲证）+ difficulty-system-v2.2-draft.md（v2.2 v1.5 锁数姊妹件），覆盖难度体系双轨+L1 UI 定位/命名面；另 difficulty-system-v3.md（v3 定稿链）、difficulty-system-v4-final.md（v4.2 定稿）、difficulty-system-v4.3.md（v1.2） | — | 锚定以丹妮 2026-10-20 23:0x 裁示为准，盘点分片按此 |
| 4 设计文档链 | docs/design/ 全量（~100 件） | v4.0/v5.0/v6.0/v6.2/v6.4/v6.5 各版本系 | 按版本分片，每片标注四态 |
| 5 阶段/计划/审查/审计/active | docs/phases/、docs/plans/、docs/reviews/、docs/audits/、docs/active/ | normalization 三件（docs/active/project-normalization-plan.md 等） | 检查其规划项与 normalization 在途批的衔接，不重复开单 |
| 6 用户/指南/测试面 | docs/user-guide/、docs/guides/、docs/test/、docs/general/ | skip-registry.md、platform-branch-matrix.md | 测试面只读引用，不跑测试 |

**盘点方法**：P2 首日产出矩阵（全文档清单+四态标注+证据列+分片责任人），此为①维第一交付。四态定义见 §五。

## 四、六维检查方法（含增补建议）

每维统一给出：主问 → 方法 → 证据形态 → 产出物。分级与证据规范统一见 §五。

### ① 设计文档符合度（Alex 主笔矩阵 + 全员分片）
- 主问：每份设计文档承诺了什么？实现到什么程度？
- 方法：文档→实现单向对照（不做反向"实现无文档"扫描，该面归 P3 改进建议）；v5.6.1 差集法（PRD v2.1 相对 v1.1 条目差 × v6.x 实现增量）
- 证据：doc 路径:行 ↔ 代码 文件:行 成对引用
- 产出：docs/audits/t1023-dim1-doc-compliance.md（矩阵+四态结论）

### ② 功能完整性与正确性（Tina 主审 + Cody 协作）
- 主问：核心用户链路是否完整、行为是否正确？
- 方法：复用 D4 链路追踪法，静态代码走查 + 已有用例/测试报告映射（**不跑测试**）；链路清单：对局（含长将/困毙/子力判定）、残局、复盘分析（v6.3.1 修复后状态）、教练（T-1021 修复后状态）、开局库/开局探索器、每日挑战、段位成长、导入导出
- 证据：链路步骤 ↔ 文件:行；与既有测试用例名的映射表
- 产出：docs/audits/t1023-dim2-function.md

### ③ 操作性/UX（Ruby 主审）
- 主问：交互流程是否顺、新手能否自助、出错时用户看到什么？
- 方法：复用 D3 方法（Views 层走查）：交互流程断点、新手引导链（FirstLaunchDialog→教程→引导提示）、错误提示盘点（alert 文案面逐一登记）；挂接 T-1020-OC-02 工具栏信息架构结论（A+B 已实施）只核实施后状态
- 证据：View 文件:行 + 文案原文逐字
- 产出：docs/audits/t1023-dim3-ux.md

### ④ 界面/UI（Vera 主审）
- 主问：视觉是否一致、布局是否稳、深色模式与多分辨率是否齐？
- 方法：v6.2 HIG 审计（docs/design/v6.2-hig-audit-vera.md）增量复核 + ui-bugs 历史项回归抽查；主题 token/深色模式断言面静态走查；多分辨率/size-class 挂 T-1020-OC-01 验收证据（evidence/t1020-mobile/ 三态七帧）只核覆盖，不重跑模拟器
- 证据：View/样式代码 文件:行；与 HIG 条目对照
- 产出：docs/audits/t1023-dim4-ui.md

### ⑤ 性能与稳定性（Alex + Cody）
- 主问：已知的性能热点修了吗？还有哪些静态可证的稳定性风险？
- 方法：静态代码分析（v3.9 D1 性能链遗留项核销：quiescenceSearch 全量走法生成、wouldBeInCheck 深拷贝、medium 难度 QS 缺位）+ 历史实测数据引用（docs/spikes/elo-baseline-results.md、calibration-results/、selfplay-results/、docs/phases/m1-fulltest-baseline-20260816.md）+ known-issues 性能/稳定类（EmbeddedPikafishEngine.newGame dispatch_sync 死锁、业余档时延违约 KI-2026-0829 等）。**不跑 benchmark**（不编译约束）；结论分"静态可证 / 需 P4 实测确认"两栏
- 证据：文件:行 + 引用数据文件路径
- 产出：docs/audits/t1023-dim5-perf-stability.md

### ⑥ i18n（Eric 主查 + Ruby 复核）
- 主问：字符串资源覆盖是否全？v6.4.1 段位制换轨后有无漏网？
- 方法：D5 量化法（Localizable.xcstrings key 覆盖对照，抽 Views/Services 面，不做全库通读）+ v6.4.1 L10n 段位制全量换轨专项核对（zh/en+短名+分组标签，规格锚 difficulty-system-v2.2-draft.md v2.4）+ known-issues xcstrings 硬编码条目回归 + v3.9 §3.2 硬编码集群（~37 处）核销
- 证据：key 名 ↔ 使用点 文件:行
- 产出：docs/audits/t1023-dim6-i18n.md

### 增补建议（候丹妮裁定是否入 P2 范围）
- **⑦ 工程与发布健康度（Alex 兼，+0.5 人日）**：版本号一致性（Info.plist CFBundleShortVersionString/CFBundleVersion ↔ tag v6.4.2）、release-notes 滞后（现头部停在 v6.3 系，v6.4.x 未入——候选发现待证）、资产完整性清单（NNUE/开局库/字体/音效四类 gitignored 资产 vs preflight 清单）。全静态可查
- **⑧ 数据与存档兼容（Eric 兼，+0.5 人日）**：schemaVersion 契约（v6.4.1 引入，非 Optional fail-fast 裁定）落地一致性、存档/统计文件格式漂移风险。静态走查

## 五、证据规范与分级标准（全维统一）

1. **证据格式**：文件路径:行号；文档与代码成对引用。引用定稿文档/判词时逐字引原文、禁转述再创作（authoritative-record-citation 纪律）
2. **四态标注**（①维专用）：已实现 / 部分实现 / 未实现 / 文档过时（实现正确且文档陈述已失效时标"文档过时"，归 P3 文档修批，不算实现缺陷）
3. **问题分级**（②-⑥维通用，沿用 v3.9 口径）：
   - P0：阻断主流程/数据错误/崩溃风险
   - P1：主流程缺陷或明显功能缺失
   - P2：体验缺陷/次要功能缺失
   - P3：打磨项
4. **无出处结论=无效**：丹妮/Vera 审查时逐条抽验出处；抽验不过的条目整条作废回炉
5. **报告落盘**：P1 本计划 → docs/plans/T-1023-OC-01-inspection-plan.md；P2 各维 → docs/audits/t1023-dim{1-8}-*.md（dim7=工程发布健康度、dim8=数据存档兼容，裁示②批准）；汇总 → docs/audits/t1023-summary.md（P3 整改方案的直接输入）
6. **台账纪律**：各维 done 后按回执协议 v2 以完成通报+文件路径回丹妮，台账行由丹妮/Luke 销账

## 六、P2 分工建议与工时估算

| 序 | 工作包 | 主责 | 协作 | 预估 | 基线挂接 |
|----|--------|------|------|------|----------|
| D0 | 基线核销（v3.9 78 项+v5.6.1 缺口项现状三态标注） | 全员分片（每维主责领自己维度的基线项） | — | 0.5 人日/人 | §2.1 三层基线 |
| D1 | ①文档符合度矩阵 | Alex | Cody/Eric 分片 | Alex 1.0 + 分片 1.0 | v5.6.1 三方对照法 |
| D2 | ②功能完整性与正确性 | Tina | Cody 0.5 | 2.0 | v39-d4 链路追踪法 |
| D3 | ③操作性/UX | Ruby | — | 1.0 | v39-d3 + T-1020-OC-02 结论 |
| D4 | ④界面/UI | Vera | — | 1.0 | v6.2 HIG + T-1020-OC-01 证据 |
| D5 | ⑤性能与稳定性 | Alex 0.5 | Cody 0.5 | 1.0 | v39-d1 性能链 + 校准产物引用 |
| D6 | ⑥i18n | Eric | Ruby 复核 0.5 | 1.5 | v39-d5 + v6.4.1 换轨规格 |
| D7 | 汇总+交叉复核 | Alex（汇总） | 丹妮节点审查 | 0.5 | — |
| D8 | ⑦工程与发布健康度（裁示②批准） | Alex | — | 0.5 | known-issues + 发布链 |
| D9 | ⑧数据与存档兼容（裁示②批准） | Eric | — | 0.5 | schemaVersion 契约（v6.4.1） |
| — | **合计** | | | **~10.5-11.5 人日**（含⑦⑧） | 并行墙钟 **~3 天** |

- 增补⑦⑧已批准（裁示②）：+1.0 人日已计入合计，3 天墙钟不变（Eric/Alex 有余量）
- 节奏：D1（D0+矩阵）先行 1 天 → 各维并行 1.5 天 → D7 汇总 0.5 天
- **轻入场纪律**：D0/D1 从文档面起步（零代码扫描），代码核验由矩阵驱动定点进入；禁入场即全库 grep/全量文件通读；禁跑任何构建/测试（P1-P3 硬约束）

## 七、在途协调与红线

### 7.1 在途单边界（只核对覆盖，不重复开单）

| 在途单 | 状态（TASK-LEDGER 在案） | 本检查边界 |
|--------|--------------------------|------------|
| T-1020-OC-01 移动端适配 | done（交付 40125e0，验收截图 evidence/t1020-mobile/ 三态七帧，iOS 6.4.1 对齐） | ④维只核验收态覆盖，不重开单、不重跑模拟器 |
| T-1020-OC-02 工具栏折叠诊断+优化 | done（A+B 方案 5dd42cf 批准，实施 29adeb8，v6.4.1 重打） | ③④维工具栏信息架构只核实施后状态 |
| T-1021-OC-01 教练执方门修复 | done（v6.4.2 已 tag，Ruby 审+Tina 验全过） | ②③维教练域以修复后代码态为对照基线 |
| T-1022 校准域重派 | 在途（派单口径：校准域，本单不介入） | ⑤维只**引用**校准产物为证据源；不开校准新单、不下校准结论、不影响其优先级 |
| normalization 三件（docs/active/） | 在途批 | ①维发现与 normalization 规划衔接标注，不重复立项 |

### 7.2 红线

1. **P1-P3 零动作**：不打包、不编译、不改代码、不 tag、不跑测试批；检查全程只读+写 docs/
2. **定稿件零触碰**：lvl6 锁表、difficulty-system-v2.2-draft.md（v2.2 v1.5 锁数）、v3 定稿、决策包 v1.3 等定稿态文档只读对照，任何"文档过时"结论只登记不动手改
3. **双线身份**：本检查属 OC 审计线，零 commit 零台账写入；台账销账归丹妮/Luke
4. **Luke 恢复衔接**：Luke 恢复后转统筹角色，先查台账防重复派发（台账 L121 已备注）；P2 派发经丹妮或恢复后的 Luke 单通道

## 八、P3/P4 接口预留

- **P3 整改方案**（呈洪涛拍板）：从 t1023-summary.md 按 P0/P1/P2 分级打包改进项，每项带：证据链（文件:行）+ 修法建议 + 工时 + 验证标准；文档修批（"文档过时"类）单列一包
- **P4 改进+验证**：走正常验收链（编码→Ruby 审→Tina 验→门禁→tag），届时解除不改码约束；验证按 P3 方案中逐项验证标准执行，逐一销项

## 九、开放问题裁示记录（丹妮 2026-10-20 23:0x 审查，五项全部闭合）

1. **"v3.0 定稿"指向**：✅ 裁定为⑥决策包定稿链（T-1015-OC-01/02 产出、T-1017-OC-02 收口：v3-draft→v1.0 正式版；含难度体系双轨+L1 UI 定位/命名面）——锚定 T-1015-OC-01-l1-carrier-decision-pack.md（v1.3 归档态）+ v65-weakening-chain-v3-draft.md（v1.0 正式版）+ 姊妹件 difficulty-system-v2.2-draft.md v1.5；§三 分片已按此修正
2. **增补维⑦⑧**：✅ 批准入 P2（+1 人日内化，3 天墙钟不破）；§六 已计入
3. **PRD 双副本**：✅ P2 首日头对头裁定+依据落盘（git 历史/台账链引证），结果备案丹妮；实质冲突无法裁定时再上升
4. **⑤维两栏口径**：✅ 批准；P4 实测衔接 T-1022 校准域产物引用
5. **P2 派发通道**：✅ 丹妮单通道确认；Luke 恢复后无缝转统筹

> 验收路径（丹妮确认）：P2 各维报告落盘 docs/（§五 路径）→ D7 汇总交丹妮节点审查 → P3 整改方案呈洪涛拍板 → P4 改进+验证。台账 L121：P1 done / P2 doing。

---

## 附：引用文件清单（本计划证据锚）

- 派单与台账：~/DevTeam/TASK-LEDGER.md L116-121
- 基线 A：docs/audits/v39-phaseb-summary.md（78 项总表）、docs/audits/v39-d1~d5 九件
- 基线 B：docs/audits/v5.6.1-full-requirement-audit.md（66 项 92.4%）
- 需求/交付：docs/需求功能说明书.md（v2.1）、docs/archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md
- 定稿红线件：docs/design/difficulty-system-{v2.2-draft,v3,v4-final,v4.3}.md、docs/design/T-1015-OC-01-l1-carrier-decision-pack.md
- 项目规范：~/DevTeam/projects/chinese-chess/DEVTEAM.md、~/DevTeam/knowledge/known-issues.md（26 条 active）、~/DevTeam/knowledge/document-conventions.md
- 在途单据：docs/plans/T-1020-OC-02-toolbar-diagnosis.md、evidence/t1020-mobile/
