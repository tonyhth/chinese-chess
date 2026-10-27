# T-1023-OC-01·P2·D7 — 符合度全面检查汇总（P3 整改方案直接输入）

> 角色：Alex（架构师，D7 汇总主责）| 日期：2026-10-22 | 版本：v1.0（交审态：八维终稿校验完成，增量已同步——dim2 v1.2.1 脚注/dim6 §7.5 计数定案）
> 状态：**八维终稿校验完成**（洪涛 06:40 加速令，原 10-22 校验门即时执行；末次修订 dim2 00:16 后无新变更）；本文件即 D7 交审件，交丹妮节点审查
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §五/§八；矩阵底稿 docs/audits/t1023-dim1-doc-compliance.md v1.2
> 修订记录：v1.0 — 2026-10-22 定稿交审态：终稿校验 sweep（八维+三分片现态核对）+dim2 v1.2.1 同步（脚注 ※1 已落+§七 交项核验：X-碰撞 P1 入池/P3-N2 测试盲区/P1-N1 P4 验证标准）+dim6 §7.5 同步（楚河汉界 5 文件 12 处三方定案+测试钉反方向断言+丹妮抽验更正记录）｜v0.3 — 2026-10-21 dim8/dim5 Cody 引擎面/dim1 Cody 终版+§九 终裁并入（八维齐），FINAL-013 翻转+60 步裁决入 A 包（丹妮裁决）｜v0.2 — 2026-10-21 初并 dim2/3/4/6+Cody 分片｜v0.1 — 2026-10-20 骨架+dim1 预填

---

## 一、总览矩阵（八维）

| 维 | 主责 | 报告 | 状态 | P0 | P1 | P2 | P3 | 销项 | 文档过时 | 规划态 |
|----|------|------|------|----|----|----|----|------|----------|--------|
| ① 文档符合度 | Alex | t1023-dim1-doc-compliance.md v1.2（终态：含 Cody/Eric 分片+§九 终裁） | ✅ 完成 | 0 | 0 | 2* | 6* | 30+ | 17 | 3 |
| ② 功能完整性 | Tina | t1023-dim2-function.md v1.2.1（脚注 ※1 已落） | ✅ 完成（终稿校验过） | 0 | 1‡‡ | 1 | 6 | 19 | 0 | 0 |
| ③ 操作性/UX | Ruby | t1023-dim3-ux.md | 🔶 初并 | 0 | 1 | 6 | 4 | 7 | 0 | 0 |
| ④ 界面/UI | Vera | t1023-dim4-ui.md | 🔶 初并 | 0 | 0 | 3 | 5 | 21 | 0 | 0 |
| ⑤ 性能与稳定性 | Alex+Cody | t1023-dim5-perf-stability.md v1.1（全并定稿） | ✅ 完成 | 0 | 1† | 0 | 0 | 9 | 0 | 0 |
| ⑥ i18n | Eric+Ruby 复核 | t1023-dim6-i18n.md（§七 复核+§7.5 定案） | ✅ 完成（复核闭合） | 0 | 0 | 2 | 4 | 多项 | 1 | 0 |
| ⑦ 工程发布健康度 | Alex | t1023-dim7-engineering.md v1.0 | ✅ 完成 | 0 | 0 | 2* | 1* | 3 | 0 | 0 |
| ⑧ 数据存档兼容 | Eric | t1023-dim8-data-archive.md v1.0 | ✅ 完成 | 0 | 0 | 0 | 4 | 7 关口 | 0 | 0 |

*①维 P2×1=docs/general/test-rules.md 真相源分裂（P2·候选，改批处置）；P3×3 候选=r3-07 日期笔误/Enums 段位注释/user-guide 12.0+ 口径。
*⑦维 P2×2=release-notes 滞后两代（v6.4.x 三发布零入册）+发布包 tmp.*×3 残留；P3×1=DEVTEAM.md docs-gitignore 声明与实践漂移。
*⑤维 P1×1=KI-2026-0829 业余档时延违约（**修复已落地**：AIEngine.swift L32-33 deadline 硬中止旗标直引 KI 编号，T-0926-OC-01 Phase 0+Cody 互证 node 级检查/五处多层检查点；契约测试 active 带 lvl4/5 观察档——回绿确认需 P4 实测）；原 P2×1（newGame 死锁）**升级销项**（Cody 静态证据：EmbeddedPikafishEngine.swift 全文件 dispatch_sync 零命中，已按 KI 处方重构 async）。
*②维 P1×1=60 步规则合规（丹妮裁决入 A 包，见上；脚注 ※1 已落 dim2 v1.2.1）；X-碰撞 P1 候选已由 dim2 v1.1 §七 入池（全局 P1 候选计此份，Cody 分片侧不重复计）；FINAL-013 翻转（pikafish_api.cpp TODO=0）归登记撤销候选。

**初并补记 → 终版并入**：①维 Cody 分片终版（t1023-dim1-shard-cody.md 257L v1.0，Cody 自并入矩阵 v1.1+Alex 验收续并 §九 终裁）——开局/演示/大师族+v5.0 收尾+专项片 #11-15+coach 系+§九 全部完成（销项 ~10 含长捉超承诺/P0-2 探索器/fingerprint Game 侧；P1 候选 3：fingerprint Puzzle 侧不对称/C API draw 信号/子力不足，随 P3 呈裁；P3：engine-gap 三档立项包呈洪涛+checklist 执行记录持久化）；Eric v2/v3 分片 9 件并入（见 §二.5）。

## 二、①维已定谳要点（dim1 v1.2）

1. **PRD 真相源裁定**：docs/需求功能说明书.md v2.1=唯一真相源；general/ v1.1=过期副本候归档（P3 按 098 纪律动）
2. **定稿链全对齐（正面结论）**：决策包定稿链（裁定⑥ Q1/Q2/S2 锁表）+v65 v1.0 正式版锁表在 Enums.swift 逐值对齐；difficulty v4.2 重映射逐字落码
3. **S2 链闭合**：lvl2-5=s0/s4/s7/s10@5000/5000/5000/10000+lvl6-9 过渡位+lvl10=s20 全亲证
4. **v3.9 基线核销**：性能链 2 销项（QS 专用吃子生成器/wouldBeInCheck 轻量副本）+1 文档过时（medium QS 处方被 v4.2 改判）
5. **过时件 11 登记**（全部只登记不动文件）：取代链 5（v3/v4.3/v6.2-difficulty-framework/v6.0-level-naming/mediumQS 处方）+口径漂移 4（r3-07 五档/日期笔误/user-guide 12.0+/Enums 注释）+真相源分裂 1（test-rules.md）+商务口径 1（r3-07 清单）
6. **衍生核验项**：双写历史同根因 sweep（已修 4 处，KI 长期建议仍 active）→②⑤维
7. **在途边界执行**：T-1020-OC-01/02 只核覆盖未重开 ✅；T-1021 教练域以修复后态为基线 ✅；T-1022 校准域零介入（⑤维仅引用产物）✅

## 二.5、初并要点（dim2/3/4/6，2026-10-21）

- **②功能（Tina v1.0）**：八链路全走通，终局判定序符合规则；v39-d4 十二项核销+phaseb 7 任务核销；新发现 P0=0/P1=0/P2=1（StatusBar 残局文案 TODO 悬置）+P3 观察 5；测试映射表 2961 @Test
- **③UX（Ruby）**：基线已修复 7（两 P0 开局探索器彻底修复）/部分修复 5/仍开放 8/新立案 3；有效问题 11 项（P1×1/P2×6/P3×4）；主判断=修复质量高，残留集中回放画布翻转（N-1 架构下沉）、MasterGameBrowser 本地化（N-2 机械修）、教练导航打磨
- **④UI（Vera）**：**无阻断项**；基线债 26 项核销 21 无回潮；P2×3（F1 字号魔法数收编/F2 恒深色策略隐性化+浅色化未决策→**需洪涛决策**/F3 T-1020 证据覆盖缺口→P4 补帧）+P3×5；证据可靠性声明四条全守
- **⑥i18n（Eric 主查+Ruby 复核闭合+§7.5 三方定案）**：基础设施健康（876 键 0 缺失 0 错配），段位制换轨终表 10/10 全合（Ruby 抽验 3/3）；无 P0/P1 新增；P1×5 系 v3.9 基线沿用（BoardTheme 6 键+PGN 7 处仍开放）。Ruby 复核：6/6 代码证据对吻合+Eric 报告通过；**N-2 补录 P2**（MasterGameBrowserView 7 处 Button("OK") 硬编码——键覆盖测试对字面量按钮结构性失明=逃逸根因）；**楚河汉界计数三方对账定案=5 文件 12 处 Text 渲染点**（Eric 8 处作废/Ruby 10 处被取代；新增 OpeningExplorerView:766/768 2 处漏检；BoardCanvasView 迁移面为翻转缺陷变体=与 D3 N-1 同根）；**测试钉反方向断言**（UXAdaptationTests.swift:714-717 hasRiverText==true"文化元素保留"——根治时须同批翻转钉键消费，否则修复被判红；丹妮抽验更正记录+复核方法教训已登记 dim6 §7.5）；P4 修复包量级 ~1.5 人日维持（5 文件 12 处+测试钉翻转三处+N-2 七处）
- **⑧数据存档（Eric）**：存档面 8 盘点+7 跨版本关口全过（v2.x→v3.0 迁移/Bundle ID 偏离/S2 重映射/旧值解码/stats v6/PGN 容错/中文段位键均幂等在位）；schemaVersion 契约（v6.4.1 裁定）落地一致性**通过**；无 P0/P1 静态风险；P3×4 全为"未来演进窗口"加固项（sidecar Release 静默/版本分支/GameRecord 显式版本/注册表归拢）→打包为"存档面加固"单条目
- **①维 Eric v2/v3 分片**：9 件四态（已实现 2/文档过时 6）；**唯一方向性风险件=ui-layout-redesign-v4.md**（"去 sidebar"原则与 v6.4 现行共享 sidebar 架构方向相反且未标注取代——P3 文档修批须显式 superseded，防 P4 实施者误判现行架构为回归）；另 5 件过时+1 件日期纪律候选归 v2/v3-v4 系归档子批

## 三、P3 整改方案打包结构（初并版，候全维定稿）

- A 包（P0/P1 缺陷）：**P1×3 定谳**——①③维基线开放 1（UX 域）+⑤维时延违约候回绿 1+**②维 60 步规则合规 1（丹妮裁决 2026-10-21）**：采纳 draw-detection-analysis.md 处方 120 半着（60 回合，符合象棋竞赛规则自然限着），PRD/实装 100 半着判 P1 规则合规整改项（GameViewModel.swift:801-804 halfmoveClock>=100 判和为整改落点）；规则语义最终呈洪涛确认；**随包更正**：Tina dim2 报告 §六.1"50 回合判和"结论需加更正脚注（参照源是 PRD 非外部权威，现行判和阈值口径随本裁决修正）——脚注由 Tina 落本人报告
- B 包（P2 体验/次要）：dim1 贡献=test-rules.md 更新（真相源统一，指向 run-tests-mutex.sh）；dim7 贡献=release-notes 补 v6.4.x 三发布条目+发布包 tmp.* 清理（P4 重打包排除）；dim3 贡献=N-1 回放画布翻转一致性（架构下沉根治）+N-2 MasterGameBrowser 按钮本地化（机械修）；dim4 贡献=F1 字号魔法数 token 收编（机械替换）；dim6 贡献=P4 修复包（BoardTheme 6 键+PGN 7 处+engine 回退文案+riverText 单源化含翻转分支+**楚河汉界 5 文件 12 处**（含 OpeningExplorerView 新发现 2 处）+N-2 七处按钮键化+**测试钉翻转三处**（UXAdaptationTests 反方向断言须同批改），~1.5 人日含 manifest 同步）；Cody 分片贡献=OpeningBook v1 兼容索引解耦（防御性打磨）
- C 包（P3 打磨+文档修批）：r3-07 日期笔误/Enums 段位注释同步/user-guide 版本口径/general 归档（098 纪律：保留/删除清单逐项+grep 引用前置）+其余各维 P3
- D 包（"需 P4 实测确认"清单）：wouldBeInCheck 残余成本/mediumNoQS 梯度体感（衔接 T-1022 校准域产物）/parity 84 处 drift 重对账（④维）/dim4 F3 T-1020 证据补帧/⑤维 lvl4/5 观察档回绿/⑧维存档面加固包（sidecar Release 日志+版本分支+GameRecord 显式版本+注册表归拢，Eric 建议 P4 低成本单条目）/**②维 P1-N1 fingerprint P4 验证标准**（Puzzle 侧指纹换 FEN 后补三次重复/长将真驱动用例+LogicReview 三测试改真实断言，dim2 v1.1 §七）等
- E 包（文档过时修批）：取代链件归档标注+口径替换（复用 r3-07 四轮方法论时口径替换）

## 四、验收路径（丹妮确认口径）

P2 各维报告落盘 docs/audits/ → D7 汇总（本文件定稿）交丹妮节点审查 → P3 整改方案呈洪涛拍板 → P4 改进+逐一验证（走验收链：编码→Ruby→Tina→门禁）
