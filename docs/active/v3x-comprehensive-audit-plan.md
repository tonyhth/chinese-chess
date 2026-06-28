# v3.x 全功能审计方案

> 负责人：Alex | 日期：2026-06-29
>
> 目标：逐一审计 v3.0 以来所有设计文档的功能完成度和完成质量，识别差距并给出建议动作。

---

## 一、审计范围

| 版本 | 文档位置 | Phase 数 |
|------|----------|----------|
| v3.0 | `docs/archive/v3.0/phase1-11.md` + `upgrade-plan.md` | 11 |
| v3.1 | `docs/archive/v3.1/` (i18n, macOS 英文, VoiceOver, Phase2c UCI) | 4 |
| v3.2.x | `docs/archive/v3.2.x/` (棋盘翻转, 侧边栏切换) | 3 |
| v3.3.0 | `docs/archive/v3.3.0/` (iOS 引擎集成) | 1 |
| v3.4.0 | `docs/active/phases/v3.4.0-*` (macOS 引擎嵌入 A-D) | 6 |
| v3.4.0 审计 | `docs/active/design/v3.4.0-code-quality-audit-plan.md` | 6 维度 |
| v3.5.0 | `docs/active/phases/v3.5.0-plan.md` | 5 Phase |

**总计**：约 36 个设计文档/Phase

---

## 二、审计方法

### 对每个功能项执行 3 步检查

1. **设计承诺**：读取 Phase 文档，提取预期交付物清单
2. **代码验证**：在 `src/ChineseChess/` 中搜索对应实现
3. **测试验证**：在 `src/ChineseChessTests/` 中搜索对应测试

### 完成度评估标准

| 完成度 | 定义 |
|--------|------|
| 100% | 全部交付 + 测试通过 |
| 80% | 核心功能完成，有 P1/P2 遗留 |
| 50% | 部分完成（核心在但缺外围） |
| 20% | 仅框架/接口/占位 |
| 0% | 未开始 |

### 完成质量标记

| 标记 | 含义 |
|------|------|
| ✅ | 通过测试验证 |
| ⚠️ | 有已知 bug/遗留 |
| ❌ | 未验证 |

---

## 三、v3.0 Phase 逐项审计矩阵

### Phase 1：AI 基础设施

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 自对弈框架 | phase1.md | SelfPlayRunner 引擎 vs 引擎自动对弈 | SelfPlayRunner.swift (377行) | SelfPlayRunnerTests.swift ✅ | 100% | ✅ | — | 不需要 |
| Elo 基线 | phase1.md | BayesElo 估值 + 基线对比 | EloBaselineTests.swift | ⚠️ 已知超时/失败 | 50% | ⚠️ | Intel Mac 上超时，需 Apple Silicon | 追加：EloBaseline 排除出验收标准，单独立项（洪涛已确认） |
| 评估快修 | phase1.md | EvalConfigManager + 权重调整 | EvalConfigManager.swift + EvalWeights.swift | EvalWeightsTests.swift ✅ | 100% | ✅ | — | 不需要 |

### Phase 2：搜索算法升级

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| PVS | phase2.md | Principal Variation Search | AIEngine.swift ✅ | Phase2aSearchTests.swift ✅ | 100% | ✅ | — | 不需要 |
| Countermove | phase2.md | Countermove Heuristic | MoveOrderer.swift ✅ | Phase2aTests ✅ | 100% | ✅ | — | 不需要 |
| LMR | phase2.md | Late Move Reduction | AIEngine.swift ✅ | Phase2bLMRTimeManagementTests ✅ | 100% | ✅ | — | 不需要 |
| NMP | phase2.md | Null Move Pruning | AIEngine.swift ✅ | Phase2bTests ✅ | 100% | ✅ | — | 不需要 |
| Futility | phase2.md | Futility Pruning | AIEngine.swift ✅ | Phase2bOptimizationTests ✅ | 100% | ✅ | — | 不需要 |
| Razoring | phase2.md | Razoring Pruning | AIEngine.swift ✅ | Phase2bOptimizationTests ✅ | 100% | ✅ | — | 不需要 |
| TT 多桶 | phase2.md | TranspositionTable 多桶替换 | TranspositionTable.swift ✅ | Phase2bTests ✅ | 100% | ✅ | — | 不需要 |
| IID | phase2.md | Internal Iterative Deepening | AIEngine.swift ✅ | Phase2bTests ✅ | 100% | ✅ | — | 不需要 |
| Pikafish Spike | phase2.md | macOS UCI 外部进程 Spike | — | — | 0% | — | 已被 Phase 10/v3.1 Phase 2 替代 | 降级：已被 v3.4.0 嵌入方案取代 |

### Phase 3：评估函数深度调优

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 位置特定性 | phase3.md | 开局/中局/残局差异化权重 | PositionTables.swift ✅ | Phase3Tests ✅ | 100% | ✅ | — | 不需要 |
| 残局阶段检测 | phase3.md | 子力阈值切换残局权重 | EndgameEvaluator.swift ✅ | Phase3aEvaluationTests ✅ | 100% | ✅ | — | 不需要 |
| CMA-ES 调参 | phase3.md | 自动调参框架 | CMAESOptimizer.swift (526行) | Batch1P0CMAESTests ✅ | 100% | ✅ | — | 不需要 |
| CMA-ES 并行化 | TD-001 | 并行评估 10 个体 | CMAESOptimizer ✅ (已实现) | — | 100% | ✅ | — | 不需要 |

### Phase 4：NNUE 技术调研

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| NNUE 可行性报告 | phase4.md | 技术路径评估文档 | nnue-embedding-investigation.md ✅ | — | 100% | ✅ | — | 不需要 |
| NNUE Spike | phase4.md | iOS C++ interop 验证 | v3.3.0 iOS 引擎集成 ✅ | — | 100% | ✅ | 实际通过 v3.3.0/v3.4.0 完成 | 不需要 |

### Phase 5：新手引导 + 对弈选边

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 5 步互动教程 | phase5.md | TutorialView + TutorialViewModel | TutorialView.swift (237行) ✅, TutorialViewModel.swift (111行) ✅ | Phase5Tests ✅ | 100% | ✅ | — | 不需要 |
| 对弈选边 | phase5.md | 执红/执黑选择 | GameViewModel.humanSide ✅ | Phase5Tests ✅ | 100% | ✅ | — | 不需要 |

### Phase 6：段位系统 + 成就系统

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 7 级段位 | phase6.md | Rank 枚举 + 特权解锁 | PlayerProfile.swift (220行) ✅, RankPrivilegeView.swift ✅ | Phase6Tests ✅ | 80% | ⚠️ | RankPrivilegeView 残留硬编码中文 (P1-2/3/4) | 追加：v3.5.0 Phase 5.1 修复 |
| 34 个成就 | phase6.md | Achievement 模型 + AchievementView | Achievement.swift (251行) ✅ | Phase6Tests ✅ | 80% | ⚠️ | 硬编码中文待 i18n 重构 | 追加：P0-4 i18n 重构已出方案 |
| 成就空状态 | phase6.md | 无成就时引导提示 | — | — | 0% | ❌ | AchievementView 无 EmptyStateView | 追加：v3.5.0 Phase 2.2 |

### Phase 7：每日挑战 + 残局库扩展

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 每日挑战 | phase7.md | DailyChallenge + 10 种模式 | DailyChallenge.swift (397行) ✅, DailyChallengeView.swift ✅ | Phase7Tests ✅ | 80% | ⚠️ | 硬编码中文待 i18n 重构 | 追加：P0-4 i18n 重构 |
| 连续登录奖励 | phase7.md | DailyStreakReward 8 级 | DailyChallenge.swift ✅ | Phase7Tests ✅ | 80% | ⚠️ | 硬编码中文待 i18n 重构 | 追加：P0-4 i18n 重构 |
| 残局库扩展 | phase7.md | 365 局 + 50 种类型 | puzzles.json (15777行) ✅ | — | 80% | ✅ | 残局数量充足，类型覆盖待确认 | 审计时统计类型数 |
| 残局规则匹配 | phase7.md | 目标 50 种，实际 ~60+ 种 | PuzzleStore.swift ✅ | — | 100% | ✅ | Pikafish NNUE 嵌入后手写规则价值大幅下降，当前 60+ 条够用 | 不需要（洪涛已确认取消扩展） |

### Phase 8：主题经济 + 数据迁移 + QA

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 主题解锁系统 | phase8.md | BoardTheme + 段位/成就关联 | BoardTheme.swift (241行) ✅, ThemePickerView.swift ✅ | Phase8Tests ✅ | 80% | ✅ | — | 不需要 |
| 开局库扩展 | phase8.md | 10000 位置 + 50 名称 | opening_book_v2.json (3.7MB) ✅, openings.json ✅ | OpeningBookPhase2Tests ✅ | 100% | ✅ | — | 不需要 |
| 数据迁移 | phase8.md | v2.x → v3.0 迁移 | DataMigration.swift (168行) ✅ | — | 80% | ⚠️ | 迁移测试覆盖不确定——审计执行阶段必须确认 | 追加：审计执行时确认测试覆盖 |
| QA / iOS bugs | phase8.md | v2.2.17 iOS bug 修复 | V2217FixTests ✅, V2218Tests ✅ | ✅ | 100% | ✅ | — | 不需要 |

### Phase 9：AI 教练 + 引擎分析 + 开局树

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| AI 教练模式 | phase9.md | "刚好比你强一点"的 AI | — | — | 0% | ❌ | 完全未实现 | 降级：远期功能，不纳入 v3.5.0 |
| 引擎分析/复盘 | phase9.md | 走法质量 6 级分级 | ReplayView.swift (70行) ✅, ReplayViewModel.swift (144行) ✅ | V2218ReplayBoardViewTests ✅ | 50% | ⚠️ | 有基础回放，但无走法质量分级 | 追加：评估是否纳入 v3.6.0 |
| 开局树探索 | phase9.md | 交互式可视化开局树 | — | — | 0% | ❌ | 完全未实现 | 降级：远期功能 |

### Phase 10：Pikafish 集成

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| C 静态库集成 | phase10.md | Pikafish 编译为 .a 静态库 | libpikafish.a (ios/ios-sim/macos) ✅ | — | 100% | ✅ | — | 不需要 |
| C API 封装 | phase10.md | pikafish_api.h + Swift 桥接 | EmbeddedPikafishEngine.swift ✅ | V34PhaseABCTest ✅ | 100% | ✅ | — | 不需要 |
| 引擎切换 | phase10.md | EngineRouter 路由 | EngineRouter.swift ✅ | V34IntegrationTests ✅ | 100% | ✅ | — | 不需要 |

### Phase 11：NNUE 完整实施（远期）

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| NNUE 数据生成 | phase11.md | 训练数据集 | — | — | 0% | ❌ | 远期，前置条件不满足 | 降级：需 GPU + ML 人力 |
| NNUE 模型训练 | phase11.md | 训练 + 验证 | — | — | 0% | ❌ | 同上 | 降级 |
| NNUE 嵌入推理 | phase11.md | 运行时 NNUE 推理 | Pikafish NNUE 已嵌入 ✅ | — | 100% | ✅ | 通过 Pikafish 间接实现，非自研 | 不需要（通过 v3.4.0 Pikafish 实现） |

---

## 四、v3.1 审计矩阵

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| i18n 国际化 | i18n-implementation-spec.md | L10n + xcstrings 双语 | L10n.swift ✅, xcstrings (191 key) ✅ | UIBugI18nTests ✅ | 80% | ⚠️ | P0-4 仍有 ~139 个硬编码中文待修 | 追加：P0-4 i18n 重构（已出方案） |
| macOS 英文布局 | macos-english-layout.md | 英文 UI 适配 | ✅ | UIAdaptationTests ✅ | 100% | ✅ | — | 不需要 |
| VoiceOver / Dynamic Type | voiceover-dynamic-type.md | 无障碍支持 | 25 处 accessibility 调用 ✅ | — | 80% | ⚠️ | 覆盖率待审计——标准：所有可交互元素有 accessibilityLabel | 追加：审计时按 WCAG 抽检 |
| Phase 2c UCI 外部引擎 | phase2c-design.md / phase2-design.md | macOS UCI 进程支持 | — | — | 0% | ❌ | 已被 v3.4.0 嵌入方案取代 | 降级：不再需要（v3.4.0 更优） |

---

## 五、v3.2.x 审计矩阵

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| 棋盘翻转 | board-flip-design.md | 执黑时棋盘 180° 翻转 | ChessBoardView.isFlipped ✅ | V2221BugTests ✅ | 100% | ✅ | — | 不需要 |
| 红黑切换按钮重设计 | side-toggle-design.md | circle.fill + tint 颜色切换 | ToolbarView.swift:186-198 ✅ | V223FixTests ✅ | 100% | ✅ | — | 不需要 |
| 切换动画颜色修复 | side-toggle-color-fix.md | 切换时颜色渲染修复 | ✅（随按钮重设计一并修复） | ✅ | 100% | ✅ | — | 不需要 |

---

## 六、v3.3.0 审计矩阵

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| iOS 引擎集成 | ios-engine-integration.md | Pikafish C API + iOS .a 库 | EmbeddedPikafishEngine.swift ✅, libpikafish.a (ios/ios-sim) ✅ | V34IntegrationTests ✅ | 100% | ✅ | — | 不需要 |

---

## 七、v3.4.0 审计矩阵

| 功能项 | 设计文档 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 质量 | 差距/缺失 | 建议动作 |
|--------|---------|-----------|---------|---------|--------|-----|----------|---------|
| Phase A：静态库嵌入 | v3.4.0-macos-phase-a.md | macOS libpikafish.a 集成 | ✅ | V34PhaseABCTest ✅ | 100% | ✅ | — | 不需要 |
| Phase B：UCI 协议 | v3.4.0-macos-phase-b.md | C API 封装 + bestMove | ✅ | V34PhaseABCTest ✅ | 100% | ✅ | — | 不需要 |
| Phase C：引擎切换 | v3.4.0-macos-phase-c.md | EngineRouter + fallback | ✅ | V34IntegrationTests ✅ | 100% | ✅ | — | 不需要 |
| Phase D：测试矩阵 | v3.4.0-macos-phase-d.md | 17 项测试 | ✅ | 待 Tina 执行 | 待执行 | ⚠️ | 等 Tina 执行 Phase D | 追加：Tina 执行 |
| P0 引擎生命周期修复 | p0-engine-lifecycle-fix.md | shutdown async + 搜索计数 | 方案定稿，待实现 | — | 0% | ❌ | 方案已通过 Vera 审查 | 追加：派 Cody 实现 |
| P0-4 i18n 重构 | p0-i18n-refactor-plan.md | 139 key + 12 文件 | 方案定稿，待实现 | — | 0% | ❌ | 方案已通过 Vera 审查 | 追加：派 Cody 实现 |

---

## 八、v3.4.0 代码质量审计

| 维度 | 状态 | P0 | P1 | P2 | 备注 |
|------|------|-----|-----|-----|------|
| 1. 代码安全性（C API） | Vera 完成 | 3（修复方案通过） | 0 | 0 | shutdown 竞态，方案待实现 |
| 2. 代码规范性 | 待 Ruby | — | — | — | 预计 0.5 天 |
| 3. 架构合理性 | Vera 完成 | 0 | 4（v3.5.0） | 2 | AIEngine 拆分等 |
| 4. 性能风险 | 待 Ruby | — | — | — | 预计 0.5 天 |
| 5. 国际化完整性 | 待 Ruby（P0-4 已出方案） | 1 | — | — | P0-4 覆盖 |
| 6. 测试覆盖 | 待 Tina | — | — | — | 待 Phase D 执行 |

---

## 九、v3.5.0 规划状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | 架构重构（AIEngine 拆分+actor） | 方案通过 Vera 审查，待执行 |
| 2 | 功能补全（计时器 UI + 空状态） | 方案通过 |
| 3 | 性能优化（开局库异步） | 方案通过 |
| 4 | 构建系统统一（xcodegen） | 方案通过 |
| 5 | 代码清理 + 测试 | 方案通过 |

---

## 十、差距汇总与建议动作

### 🔴 未实现（设计承诺但代码中不存在）

| # | 功能 | 来源 Phase | 原因 | 建议 |
|---|------|-----------|------|------|
| 1 | AI 教练模式 | v3.0 Phase 9 | 复杂度高，远期功能 | 降级到 v3.6.0+，不纳入 v3.5.0 |
| 2 | 引擎走法质量分级 | v3.0 Phase 9 | 有基础回放但未做分级 | 评估 v3.6.0 |
| 3 | 开局树探索 | v3.0 Phase 9 | 复杂度高 | 降级到远期 |
| 4 | 侧边栏切换 | v3.2.x | **误报** — side-toggle-design.md 是红黑方切换按钮 UI 重设计（circle.fill），v3.2.3 已实现 | ~~降级~~ 已修正为完成 |
| 5 | NNUE 自研 | v3.0 Phase 11 | 需 GPU + ML 人力 | 通过 Pikafish 间接实现，不再需要自研 |
| 6 | UCI 外部进程引擎 | v3.1 Phase 2c | 被 v3.4.0 嵌入方案取代 | 正确决策，不再需要 |
| 7 | AchievementView 空状态 | v3.0 Phase 6 backlog | 漏实现 | 追加到 v3.5.0 Phase 2.2 |

### 🟡 部分完成（核心在但外围缺失）

| # | 功能 | 缺失 | 建议 |
|---|------|------|------|
| 1 | 国际化（i18n） | ~139 个硬编码中文 | P0-4 已出方案，待实现 |
| 2 | 引擎生命周期安全 | shutdown 竞态 | P0 修复方案已通过审查，待实现 |
| 3 | 残局规则匹配扩展 | 目标 50 种，实际 ~60+ 种 | ~~追加~~ 洪涛已确认取消扩展（Pikafish NNUE 替代手写规则） |
| 4 | VoiceOver 覆盖率 | 25 处，覆盖率不确定 | 审计时评估 |

### ✅ 已废弃（正确的决策）

| # | 功能 | 原因 |
|---|------|------|
| 1 | NNUE 自研（Phase 11） | Pikafish 间接实现 |
| 2 | UCI 外部进程（v3.1 Phase 2c） | v3.4.0 嵌入方案更优 |
| 3 | TD-002 UCITransceiver | v3.4.0 已删除 |

---

## 十一、审计执行建议

### 执行人分派

| 审计项 | 执行人 | 工期 |
|--------|--------|------|
| v3.0 Phase 1-4（AI） | Ruby + Tina | 0.5 天 |
| v3.0 Phase 5-8（可玩性） | Ruby + Tina | 0.5 天 |
| v3.0 Phase 9-11（远期） | Alex（方案级评估） | 0.5 小时 |
| v3.1-3.3 | Ruby | 0.5 天 |
| v3.4.0 审计维度 2/4/5 | Ruby | 1 天 |
| v3.4.0 审计维度 6 | Tina | 0.5 天 |

### 优先级排序（追加任务）

| 优先级 | 任务 | 来源 |
|--------|------|------|
| P0 | P0 引擎生命周期修复 | Vera 审查 |
| P0 | P0-4 i18n 重构 | 审计维度 5 |
| P1 | AchievementView 空状态 | Phase 6 backlog |
| P1 | RankPrivilegeView i18n 残留 | Phase 8 P1 |
| P1 | v3.5.0 架构重构 | 审计维度 3 |
| P2 | VoiceOver 覆盖率审计 | v3.1 |
| 远期 | AI 教练 / 开局树 / 走法分级 → 纳入 v3.6.0（已出规划） | Phase 9 | 纳入 v3.6.0（洪涛已确认） |
