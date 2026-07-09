# v3.x 全功能审计方案

> 负责人：Alex | 日期：2026-06-29（初版）/ 2026-07-14（v2.0 补全 v3.6.0-v3.7.1）
>
> 目标：逐一审计 v3.0 以来所有设计文档的功能完成度和完成质量，识别差距并给出建议动作。

---

## 一、审计范围

| 版本 | 文档位置 | Phase 数 | 审计状态 |
|------|----------|----------|----------|
| v3.0 | `docs/archive/v3.0/phase1-11.md` + `upgrade-plan.md` | 11 | ✅ 已审计 |
| v3.1 | `docs/archive/v3.1/` (i18n, macOS 英文, VoiceOver, Phase2c UCI) | 4 | ✅ 已审计 |
| v3.2.x | `docs/archive/v3.2.x/` (棋盘翻转, 侧边栏切换) | 3 | ✅ 已审计 |
| v3.3.0 | `docs/archive/v3.3.0/` (iOS 引擎集成) | 1 | ✅ 已审计 |
| v3.4.0 | `docs/active/phases/v3.4.0-*` (macOS 引擎嵌入 A-D) | 6 | ✅ 已审计 |
| v3.5.0 | `docs/active/phases/v3.5.0-plan.md` | 5 | ✅ 已审计（规划阶段） |
| **v3.6.0** | `docs/active/phases/v3.6.0-*.md` | **10 (Phase 0-4 + Q1-Q5)** | ✅ **本次补全** |
| **v3.7.0** | `docs/phases/v3.7.0-*.md` | **2** | ✅ **本次补全** |
| **v3.7.1** | `docs/phases/v3.7.1-*.md` | **2** | ✅ **本次补全** |

**总计**：约 44 个设计文档/Phase

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

---

## 三、v3.0 Phase 逐项审计矩阵

### Phase 1：AI 基础设施 — **85%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 自对弈框架 | SelfPlayRunner 引擎 vs 引擎自动对弈 | 100% | — |
| Elo 基线 | BayesElo 估值 + 基线对比 | 50% | Intel Mac 超时，Apple Silicon 正常 |
| 评估快修 | EvalConfigManager + 权重调整 | 100% | — |

### Phase 2：搜索算法升级 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| PVS | Principal Variation Search | 100% | — |
| Countermove | Countermove Heuristic | 100% | — |
| LMR | Late Move Reduction | 100% | — |
| NMP | Null Move Pruning | 100% | — |
| Futility | Futility Pruning | 100% | — |
| Razoring | Razoring Pruning | 100% | — |
| TT 多桶 | TranspositionTable 多桶替换 | 100% | — |
| IID | Internal Iterative Deepening | 100% | — |
| Pikafish Spike | macOS UCI 外部进程 | — | 已被 v3.4.0 嵌入方案取代 ✅ |

### Phase 3：评估函数深度调优 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 位置特定性 | 开局/中局/残局差异化权重 | 100% | — |
| 残局阶段检测 | 子力阈值切换残局权重 | 100% | — |
| CMA-ES 调参 | 自动调参框架 | 100% | CMAESOptimizer.swift 526行 |
| CMA-ES 并行化 | 并行评估 10 个体 | 100% | — |

### Phase 4：NNUE 技术调研 — **100%** ✅（通过 v3.3.0/v3.4.0 间接完成）

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| NNUE 可行性报告 | 技术路径评估文档 | 100% | — |
| NNUE Spike | iOS C++ interop 验证 | 100% | 通过 v3.3.0/v3.4.0 Pikafish 嵌入完成 |

### Phase 5：新手引导 + 对弈选边 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 5 步互动教程 | TutorialView + TutorialViewModel | 100% | — |
| 对弈选边 | 执红/执黑选择 | 100% | — |

### Phase 6：段位系统 + 成就系统 — **80%** ⚠️

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 7 级段位 | Rank 枚举 + 特权解锁 | 80% | 残留硬编码中文 |
| 34 个成就 | Achievement 模型 + AchievementView | 80% | 硬编码中文待 i18n |
| 成就空状态 | 无成就时引导提示 | 0% | 未实现 |

### Phase 7：每日挑战 + 残局库扩展 — **80%** ⚠️

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 每日挑战 | DailyChallenge + 10 种模式 | 80% | 硬编码中文待 i18n |
| 连续登录奖励 | DailyStreakReward 8 级 | 80% | — |
| 残局库扩展 | 365 局 + 50 种类型 | 80% | — |
| 残局规则匹配 | 目标 50 种，实际 ~60+ | 100% | — |

### Phase 8：主题经济 + 数据迁移 + QA — **85%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 主题解锁系统 | BoardTheme + 段位/成就关联 | 80% | — |
| 开局库扩展 | 10000 位置 + 50 名称 | 100% | — |
| 数据迁移 | v2.x → v3.0 迁移 | 80% | — |
| QA / iOS bugs | v2.2.17 iOS bug 修复 | 100% | — |

### Phase 9：AI 教练 + 引擎分析 + 开局树 — **已全部在 v3.6.0 实现** ✅

| 功能项 | 预期交付物 | v3.0 规划时状态 | **v3.6.0 实现状态** | 完成度 |
|--------|-----------|---------------|-------------------|--------|
| AI 教练模式 | "刚好比你强一点"的 AI | ❌ 0% 未实现 | ✅ CoachExplainer.swift(304行) + CoachModeOverlay.swift(198行) + 8 类场景模板 | **80%** |
| 引擎分析/复盘 | 走法质量 6 级分级 | ⚠️ 50%（仅有基础回放） | ✅ PositionAnalyzer.swift(248行) + MoveQuality 6级分级 + 段位门禁 | **85%** |
| 开局树探索 | 交互式可视化开局树 | ❌ 0% 未实现 | ✅ OpeningTreeNode.swift(183行) + OpeningExplorerView.swift(214行) | **80%** |

> **注**：Phase 9 的三项功能在 v3.0 规划时因复杂度高被降级为远期功能，后在 v3.6.0 中全面实现。详细审计见 §十 v3.6.0 Phase 2-4。

### Phase 10：Pikafish 集成 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| C 静态库集成 | Pikafish 编译为 .a 静态库 | 100% | — |
| C API 封装 | pikafish_api.h + Swift 桥接 | 100% | — |
| 引擎切换 | EngineRouter 路由 | 100% | — |

### Phase 11：NNUE 完整实施（远期）— **通过 Pikafish 间接实现**

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| NNUE 数据生成 | 训练数据集 | — | 远期，需 GPU + ML 人力 |
| NNUE 模型训练 | 训练 + 验证 | — | — |
| NNUE 嵌入推理 | 运行时 NNUE 推理 | 100% | 通过 Pikafish 间接实现，非自研 |

---

## 四、v3.1 审计矩阵 — **80%** ⚠️

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| i18n 国际化 | L10n + xcstrings 双语 | 80% | 仍有 ~80 处硬编码中文待修（已精确量化） |
| macOS 英文布局 | 英文 UI 适配 | 100% | — |
| VoiceOver / Dynamic Type | 无障碍支持 | 80% | 覆盖率待审计 |
| Phase 2c UCI 外部引擎 | macOS UCI 进程支持 | — | 已被 v3.4.0 嵌入方案取代 ✅ |

---

## 五、v3.2.x 审计矩阵 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| 棋盘翻转 | 执黑时棋盘 180° 翻转 | 100% | — |
| 红黑切换按钮重设计 | circle.fill + tint 颜色切换 | 100% | — |
| 切换动画颜色修复 | 切换时颜色渲染修复 | 100% | — |

---

## 六、v3.3.0 审计矩阵 — **100%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| iOS 引擎集成 | Pikafish C API + iOS .a 库 | 100% | — |

---

## 七、v3.4.0 审计矩阵 — **95%** ✅

| 功能项 | 预期交付物 | 完成度 | 备注 |
|--------|-----------|--------|------|
| Phase A：静态库嵌入 | macOS libpikafish.a 集成 | 100% | — |
| Phase B：UCI 协议 | C API 封装 + bestMove | 100% | — |
| Phase C：引擎切换 | EngineRouter + fallback | 100% | — |
| Phase D：测试矩阵 | 17 项测试 | 待执行 | 等 Tina 执行 |
| P0 引擎生命周期修复 | shutdown async + 搜索计数 | 0% | 方案已通过 Vera 审查，待实现 |
| P0-4 i18n 重构 | 139 key + 12 文件 | 部分 | 已精确量化，见 §十三 |

---

## 八、v3.5.0 规划状态

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | 架构重构（AIEngine 拆分+actor） | 方案通过 Vera 审查，待执行 |
| 2 | 功能补全（计时器 UI + 空状态） | 方案通过 |
| 3 | 性能优化（开局库异步） | 方案通过 |
| 4 | 构建系统统一（xcodegen） | 方案通过 |
| 5 | 代码清理 + 测试 | 方案通过 |

> v3.5.0 的规划内容已被后续版本吸收执行，详见 v3.6.0-v3.7.1 审计矩阵。

---

## 十、v3.6.0 审计矩阵（本次补全）

> 详细子报告：`docs/active/v3.6.0-audit-report.md`

### Phase 0：残局模式增强 — **95%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| PuzzlePlayMode 枚举 | `enum PuzzlePlayMode { guided, freePlay }` | ✅ PuzzleViewModel.swift:6 | ✅ V360FullTests | 100% | — |
| 模式切换 UI | 进入弹窗 + 进行中切换 | ✅ switchToFreePlay/switchToGuided | ✅ | 100% | — |
| freePlay 用 Pikafish | EngineRouter 集成 | ✅ PuzzleViewModel.swift:424-432 | ✅ | 100% | — |
| 模式切换逻辑 | 切换重置 | ✅ switchToGuided 重置到 solutionStepIndex | ✅ | 95% | — |

### Phase 1：引擎分析核心 — **90%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| C API: pikafish_eval | pikafish_api.cpp 新接口 | ✅ pikafish_api.cpp:408 | ⚠️ 仅 smoke test | 90% | 无 C API 单元测试 |
| C API: pikafish_multi_pv | 同上 | ✅ pikafish_api.cpp:444 | ⚠️ | 90% | — |
| PikafishEvalResult 结构体 | score_cp + depth + best_move + pv | ✅ pikafish_api.h | ✅ | 100% | — |
| PositionAnalyzer.swift | actor + evaluate/topMoves/classifyMove | ✅ AI/PositionAnalyzer.swift | ❌ **无测试** | 85% | 🔴 缺 PositionAnalyzerTests |
| MoveQuality 枚举 | 6 级分级 | ✅ PositionAnalyzer.swift:7 | ❌ | 85% | 同上 |
| AnalysisViewModel.swift | 分析会话状态管理 | ✅ ViewModels/AnalysisViewModel.swift | ✅ V370Phase2FENChainTests | 90% | — |

**Spike 结论**：✅ C API 扩展成功，额外实现了 pikafish_last_eval、pikafish_set_multipv、pikafish_get_pv_line 辅助接口。

### Phase 2：走法质量分级 UI — **85%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| AnalysisView.swift | 复盘分析视图 | ✅ Views/AnalysisView.swift | ⚠️ V370 测试引用 | 85% | — |
| 走法颜色编码 | 绿/黄/红 | ✅ moveQualityBadge():184 | ✅ P3Batch2Tests | 90% | — |
| 评估曲线图 | 折线图 | ✅ evalChart:224 | ⚠️ 测试覆盖轻 | 80% | — |
| 段位解锁 | 秀才=基础, 进士=专家 | ✅ UnlockedFeature.engineAnalysis → .hanlin | ✅ RankUnlockTests | 100% | — |

### Phase 3：AI 教练模式 — **80%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| CoachExplainer.swift | 8 类场景模板 | ✅ AI/CoachExplainer.swift | ✅ P3Batch2Tests (11 cases) | 90% | — |
| CoachModeOverlay.swift | 提示/详解/跳过 UI | ✅ Views/CoachModeOverlay.swift | ⚠️ 无 UI 测试 | 80% | 🟡 overlay 流程未测 |
| 复盘卡片 | 走法统计 + 棋力评分 | ✅ CoachExplainer.swift:244-298 | ✅ P3Batch2Tests | 85% | — |
| 教练难度调节 | recommendedCoachDifficulty | ✅ PlayerProfile.swift:81 | ✅ V360FullTests (7 cases) | 100% | — |

### Phase 4：开局树探索 — **80%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| OpeningTreeNode.swift | 树节点 + buildFromV1 | ✅ Models/OpeningTreeNode.swift | ❌ **无测试** | 80% | 🟡 缺 OpeningTreeNodeTests |
| OpeningExplorerView.swift | 树形展开/折叠 + 棋盘演示 | ✅ Views/OpeningExplorerView.swift | ❌ | 75% | — |
| 收藏功能 | 保存到 PlayerProfile | ✅ 收藏按钮存在 | ⚠️ 集成度不明 | 70% | 后端集成待确认 |
| 段位解锁 | 秀才浏览, 棋圣收藏 | ✅ UnlockedFeature | ✅ RankUnlockTests | 100% | — |

### Q1：残局章节制 — **90%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| PuzzleChapter.swift | ChapterConfig + 7 章节 | ✅ Models/PuzzleChapter.swift:42-75 | ❌ **无测试** | 85% | 🔴 缺 PuzzleChapterTests |
| ChapterStore.swift | rebuildChapters + checkUnlock | ✅ Services/ChapterStore.swift | ❌ | 85% | — |
| ChapterSelectView.swift | 章节卡片列表 | ✅ Views/ChapterSelectView.swift | ❌ | 80% | — |
| 老存档兼容 | 零迁移 | ✅ isUnlocked computed | ✅ (隐式) | 90% | — |
| .or 解锁条件 | 段位提前解锁 | ✅ PuzzleChapter.swift:11 | ✅ | 100% | — |

### Q2：段位奖励实质化 — **90%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| UnlockedFeature 枚举 | 9 cases + requiredRank | ✅ Models/UnlockedFeature.swift | ✅ RankUnlockTests | 100% | — |
| isFeatureUnlocked() | PlayerProfile 方法 | ✅ UnlockedFeature.swift:87 | ✅ | 100% | — |
| 段位升级弹窗 | .rankPromoted notification | ✅ ChineseChessApp.swift:237 | ✅ | 95% | — |

### Q3：成就系统激活 — **85%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| AchievementChecker.swift | checkAfterGame + checkAfterPuzzle | ✅ ViewModels/AchievementChecker.swift | ✅ V360FullTests | 90% | — |
| 8 个新行为成就 | kill_mate_horse_cannon 等 | ✅ Achievement.swift | ✅ V360FullTests | 95% | — |
| 8 个退役成就 | retired set | ✅ Achievement.swift:155 | ❌ 退役 UI 展示未测 | 85% | 🟡 |
| GameResultInfo 结构体 | isWin/difficulty/moveCount 等 | ✅ AchievementChecker.swift:6 | ✅ | 100% | — |
| effectiveWins/Puzzles | 计算属性 + achievementBonus | ✅ PlayerProfile.swift:209-211 | ✅ | 100% | — |

### Q4：每日挑战做实 — **80%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| 3 种可玩模式 | endgamePuzzle + timeBlitz + masterChallenge | ✅ DailyChallengeView.swift:18 | ❌ 无集成测试 | 80% | 🟡 |
| DailyChallengeMode 枚举 | 3 cases + icon/localizedName | ✅ DailyChallenge.swift:6-34 | ❌ | 80% | — |
| Q4 bonus 字段 | bonusBlitzTimeBonus 等 4 个 | ✅ PlayerProfile.swift:138-141 | ❌ | 80% | — |

### Q5：金币经济系统 — **0%** ❌（可选，设计文档标记为 optional）

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| PlayerWallet.swift | Wallet model | ❌ 不存在 | — | 0% | 设计文档标记 optional |
| ShopItem + WalletStore | 消费闭环 | ❌ 不存在 | — | 0% | — |

---

## 十一、v3.7.0 审计矩阵（本次补全）

### Game Record Design — **90%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| GameRecord model | source/tags/puzzleId + RecordSource 枚举 | ✅ Models/GameRecord.swift:5,35-37 | ✅ V370Phase1Tests | 100% | — |
| PlayerInfo.difficulty 可选 | AIDifficulty? | ✅ GameRecord.swift:19 | ✅ V370Phase2SupplementTests | 100% | — |
| Codable 向后兼容 | decodeIfPresent | ✅ GameRecord.swift:60-62 | ✅ V370Phase1Tests | 100% | — |
| GameRecordStore | JSON 文件存储 + writeQueue | ✅ Services/GameRecordStore.swift | ✅ V370Phase1Tests (8 tests) | 100% | — |
| RecordSummary | 含 source 字段 | ✅ GameRecordStore.swift:5 | ✅ | 100% | — |
| UserDefaults → JSON 迁移 | migrateGameHistoryToFiles() | ✅ DataMigration.swift:146 | ✅ V370Phase4Tests (5 tests) | 100% | — |
| FENRebuilder | computeFEN + computeAllFENs | ✅ Services/FENRebuilder.swift | ✅ V370Phase1Tests (5) + V370Phase2FENChainTests (6) | 100% | — |
| FENParser.isStandardInitial | 标准化 FEN 比较 | ✅ FENParser.swift:101 | ✅ V370Phase1Tests (4) | 100% | — |
| PGNExporter | export + exportBatch + exportBatchSafe | ✅ Services/PGNExporter.swift | ✅ V370Phase1Tests (6) + SupplementTests (3) | 100% | — |
| PGNImporter | parse + splitGames + parseSingleGame | ✅ Services/PGNImporter.swift | ✅ V370Phase3Tests (5) + Phase4Tests (3) | 100% | — |
| PGN 文件类型注册 | Info.plist CFBundleDocumentTypes + UTI | ✅ Info.plist:21-53 | — (plist 无单测) | 100% | — |
| GameHistoryStore 废弃 | @deprecated 注解 | ✅ GameHistoryStore.swift:7 | ✅ V370Phase4Tests | 100% | — |
| PuzzleViewModel 存档 | savePuzzleRecord() | ✅ PuzzleViewModel.swift:828 | ✅ V370Phase4Tests + V371Tests | 100% | — |
| GameViewModel 存档 | 对局结束自动存档 | ✅ GameViewModel.swift | ✅ V370Phase2Tests | 100% | — |
| 对局历史 UI 改造 | GameHistoryView 重做 | ✅ Views/GameHistoryView.swift | ⚠️ UI 交互深度未测 | 80% | 🟡 |
| ReplayView 回放增强 | 走法列表 + 评估标注 | ✅ Views/ReplayBoardView.swift + AnalysisView | ⚠️ | 80% | — |
| PGN 导入 UI | 文件选择器 + 导入反馈 | ✅ ChineseChessApp.swift .onOpenURL | ✅ V370Phase3Tests | 90% | — |

### Phase 2 — **90%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| PositionAnalyzer 集成 | AnalysisViewModel 调用 PositionAnalyzer | ✅ | ✅ V370Phase2FENChainTests | 90% | — |
| FEN 链式验证 | 多步走法 FEN 重建 | ✅ FENRebuilder | ✅ V370Phase2FENChainTests (6 tests) | 100% | — |
| 段位解锁验证 | UnlockedFeature 联动 | ✅ | ✅ V370Phase2SupplementTests | 100% | — |
| AnalysisView UI | 棋盘标注 + 走法列表 | ✅ Views/AnalysisView.swift | ⚠️ | 85% | — |
| GameRecord source 分类 | vsAI / puzzle / daily 标记 | ✅ | ✅ V370Phase4Tests | 100% | — |
| 评估曲线数据 | 评估值序列 | ✅ AnalysisViewModel | ⚠️ | 80% | — |

---

## 十二、v3.7.1 审计矩阵（本次补全）

### Common（通用改进）— **100%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| 统一 sheet 管理 | enum SheetDestination + 单 .sheet(item:) | ✅ ChineseChessApp.swift SheetDestination 枚举 | ✅ V371Tests | 100% | — |
| PGN 导入错误处理 | alert + 用户反馈 | ✅ showImportFailAlert + importFailMessage | ✅ V371Tests | 100% | — |
| App 入口导航 | scenePhase + 命令菜单 | ✅ .commands + CommandMenu | ✅ | 100% | — |
| 颜色方案统一 | preferredColorScheme(.dark) | ✅ | ✅ | 100% | — |
| 窗口尺寸标准化 | minWidth/minHeight/defaultSize | ✅ .frame(minWidth:600, minHeight:700) | — | 100% | — |

### Phase 3（导入增强 + UI 改造）— **85%** ✅

| 功能项 | 预期交付物 | 代码验证 | 测试验证 | 完成度 | 差距 |
|--------|-----------|---------|---------|--------|------|
| PGN 导入增强 | 解析改进 + 错误反馈 | ✅ PGNImporter | ✅ V370Phase3Tests | 90% | — |
| 残局棋谱自动入库 | 批量导入 | ✅ PuzzleStore 集成 | ⚠️ | 80% | 🟡 集成深度待确认 |
| 对局历史 UI | GameHistoryView 改造 | ✅ | ⚠️ | 80% | — |
| 回放视图增强 | ReplayView + 走法标注 | ✅ | ⚠️ | 85% | — |
| 导入导出 UX | 文件选择 + clipboard 导出 | ✅ .onOpenURL + copyRecordToClipboard | ✅ | 90% | — |
| 棋谱记录面板 | RecordPanelView | ✅ | — | 85% | — |
| 统计面板 | StatsPanelView | ✅ | — | 85% | — |

---

## 十三、i18n 硬编码审计（本次补全）

### 总体数据

| 指标 | 数值 |
|------|------|
| xcstrings 总 key 数 | **505** |
| 硬编码中文总出现次数 | **210**（跨 23 个文件） |
| — 其中 UI 层（Text/Button/Label） | **38** |
| — 其中 数据/模型层用户可见 | **~50** |
| — 其中 领域语言（棋谱记法/棋子名） | **~53**（NotationGenerator 39 + Piece 14）— **待定策略** |
| — 其中 纯日志/调试 | **~57**（不本地化） |
| — 其他（待逐项确认） | **~12** |
| 去重后唯一硬编码字符串 | **~170** |
| l10n.t() / L10n.shared.t() 调用行数 | **461** |
| 唯一 l10n key 引用数 | **382** |

### Top 15 硬编码文件

| # | 次数 | 文件 | 类别 |
|---|------|------|------|
| 1 | 39 | `Services/NotationGenerator.swift` | **领域语言**（棋谱记法：将/帅/车/马/炮）— 待定策略 |
| 2 | 27 | `AI/OpeningBookExpander.swift` | 日志/调试（不本地化） |
| 3 | 25 | `Views/Tutorial/TutorialView.swift` | **UI — 最大问题** |
| 4 | 17 | `AI/SelfPlayRunner.swift` | 日志/调试（不本地化） |
| 5 | 14 | `Models/Piece.swift` | **领域语言**（棋子中文名）— 待定策略 |
| 6 | 13 | `AI/CMAESOptimizer.swift` | 日志/调试（不本地化） |
| 7 | 10 | `Models/DailyChallenge.swift` | 数据（挑战描述） |
| 8 | 8 | `Services/PGNExporter.swift` | 数据（PGN 格式） |
| 9 | 8 | `Services/PGNImporter.swift` | 数据（PGN 格式） |
| 10 | 7 | `Models/PlayerProfile.swift` | 数据（段位名）— 领域语言，待定策略 |
| 11 | 7 | `Models/GameRecord.swift` | 数据（结果标签）|
| 12 | 7 | `Services/BoardTheme.swift` | 数据（主题名）|
| 13 | 6 | `Models/Puzzle.swift` | 数据（残局元数据） |
| 14 | 5 | `Models/Achievement.swift` | 数据（成就名） |
| 15 | 4 | `Views/ChessBoardView.swift` | UI（楚河汉界） |

### UI 层硬编码（38 处 — 必须修复）

| 文件 | 次数 | 示例 |
|------|------|------|
| `Tutorial/TutorialView.swift` | **25** | Text("欢迎使用中国象棋！"), Button("不太熟悉"), Text("新手教程") 等 |
| `ChessBoardView.swift` | 4 | Text("汉  界"), Text("楚  河") |
| `DailyChallengeView.swift` | 4 | Text("最近挑战"), Button("完成") |
| `ReplayBoardView.swift` | 2 | Text("楚  河"), Text("汉  界") |
| `ChineseChessApp.swift` | 1 | Button("配置引擎") |
| `AchievementView.swift` | 1 | Text("需 X 胜 + Y 残局") |
| `SettingsView.swift` | 1 | Text("中文") |

### 估算工作量

- UI 层硬编码：~38 处 → ~30 个新 xcstrings key
- 数据/模型层用户可见：~50 处 → 成就描述、挑战文本、结果标签等
- **总计需新增 ~80 个 l10n key**
- 领域语言：~53 处（NotationGenerator 39 + Piece 14）— **待定策略，不计入 i18n 缺陷**
- 纯日志/调试（OpeningBookExpander、SelfPlayRunner、CMAESOptimizer ~57 处）：不需要本地化

### 领域语言策略（待 Luke 决策）

以下硬编码中文属于**中国象棋领域语言**，不是 UI 文本：

| 文件 | 处数 | 内容 | 性质 |
|------|------|------|------|
| NotationGenerator.swift | 39 | 将/帅/车/马/炮/纵线名“一二三…” | 中文棋谱标准记法（如“炮二平五”）|
| Piece.swift | 14 | 棋子中文名属性 | 棋子标识名 |
| PlayerProfile.swift | ~7 | 秀才/举人/进士/翰林/国手/棋圣/棋仙 | 传统段位名 |

**选项 A**：保持中文（领域语言标准）。英文界面下棋谱默认用 ICCS 格式，段位名用拼音或翻译。
**选项 B**：全部提取到 l10n key，支持完全英文棋谱（如 "Cannon 2平5"）。改动较大。

无论选哪个，这 ~53+7 处不计入当前 i18n 缺陷数。

---

## 十四、差距汇总与建议动作（v3.6.0-v3.7.1）

### 🔴 未实现（设计承诺但代码中不存在）

| # | 功能 | 来源 | 原因 | 建议 |
|---|------|------|------|------|
| 1 | PositionAnalyzerTests | v3.6.0 Phase 1 | 遗漏 | P0 — 补测试（含 C API 集成测试） |
| 2 | PuzzleChapterTests | v3.6.0 Q1 | 设计文档明确要求 | P0 — 补测试 |
| 3 | pikafish_api C API 单元测试 | Vera 复核新增 | 仅 smoke test 覆盖 | P2 — 补 C API 测试 |
| 4 | OpeningTreeNodeTests | v3.6.0 Phase 4 | 遗漏 | P2 — 补测试（数据转换逻辑风险较低） |
| 5 | 金币经济系统 | v3.6.0 Q5 | 设计文档标记 optional | 可接受，远期 |

### 🟡 部分完成（核心在但外围缺失）

| # | 功能 | 缺失 | 建议 |
|---|------|------|------|
| 1 | i18n 硬编码 | ~80 个新 key 待提取（38 UI + 50 数据层） | P1 — TutorialView 25 处最优先 |
| 2 | CoachModeOverlay UI 测试 | overlay 流程未测 | P2 |
| 3 | 每日挑战集成测试 | 3 模式与 GameViewModel 集成未验证 | P2 |
| 4 | 退役成就 UI 展示 | retired set 存在但展示未测 | P2 |
| 5 | 开局树收藏后端集成 | 收藏按钮存在，PlayerProfile 集成待确认 | P2 |
| 6 | 评估曲线测试覆盖 | 图表存在但测试覆盖轻 | P2 |

### ✅ 已完成且通过验证

| 版本 | 完成度 | 亮点 |
|------|--------|------|
| v3.6.0 Phase 0 | 95% | 残局模式切换 + Pikafish 集成完整 |
| v3.6.0 Phase 1 | 90% | C API 扩展成功，额外实现辅助接口 |
| v3.6.0 Q1-Q4 | 80-90% | 章节/段位/成就/每日挑战核心完整 |
| v3.7.0 | 90% | GameRecord 全链路 + PGN 导入导出 + 测试覆盖优秀 |
| v3.7.1 | 85-100% | Sheet 统一管理 + 导入增强 |

---

## 十五、建议动作清单（按优先级排序）

### P0（必须修复）

| # | 任务 | 来源 | 工期 |
|---|------|------|------|
| 1 | 补 PositionAnalyzerTests.swift（含 C API 集成测试） | v3.6.0 Phase 1 + Vera 复核 | 0.5-1 天 |
| 2 | 补 PuzzleChapterTests.swift | v3.6.0 Q1 | 0.5 天 |

### P1（应修复）

| # | 任务 | 来源 | 工期 |
|---|------|------|------|
| 3 | TutorialView i18n（25 处硬编码 → l10n key） | i18n 审计 | 1 天 |
| 4 | 数据层 i18n 细分：成就描述/挑战文本/结果标签（~30 处，排除段位名等领域语言） | i18n 审计 + Vera 复核 | 1 天 |
| 5 | ChessBoardView/ReplayBoardView 楚河汉界 i18n（6 处） | i18n 审计 | 0.5 天 |
| 6 | DailyChallengeView 硬编码修复（4 处） | i18n 审计 | 0.5 天 |

### P2（改进建议）

| # | 任务 | 来源 | 工期 |
|---|------|------|------|
| 7 | 补 OpeningTreeNodeTests.swift | v3.6.0 Phase 4 | 0.5 天 |
| 8 | 补 pikafish_api C API 单元测试 | Vera 复核新增 | 0.5 天 |
| 9 | CoachModeOverlay UI 测试 | v3.6.0 Phase 3 | 0.5 天 |
| 10 | 每日挑战集成测试 | v3.6.0 Q4 | 0.5 天 |
| 11 | 退役成就 UI 展示测试 | v3.6.0 Q3 | 0.3 天 |
| 12 | 开局树收藏后端集成确认 | v3.6.0 Phase 4 | 0.5 天 |
| 13 | 评估曲线测试覆盖补强 | v3.6.0 Phase 2 | 0.3 天 |
| 14 | ChineseChessApp "配置引擎" 硬编码 | i18n 审计 | 0.1 天 |
| 15 | 领域语言策略定案（NotationGenerator/Piece/段位名） | Vera 复核新增 | Luke 决策 |

---

## 十六、版本完成度总览

| 版本 | 整体完成度 | 测试覆盖 | 主要差距 |
|------|-----------|---------|---------|
| v3.0 (Phase 1-11) | 85% | 良好 | Phase 9 远期功能已在 v3.6.0 全部实现 ✅ |
| v3.1 | 80% | 良好 | i18n 硬编码（本次精确量化） |
| v3.2.x | 100% | 完整 | — |
| v3.3.0 | 100% | 完整 | — |
| v3.4.0 | 95% | 良好 | 引擎生命周期 P0 待实现 |
| v3.5.0 | N/A（规划） | — | 已被后续版本吸收 |
| **v3.6.0** | **85%** | **中等** | 3 个测试文件缺失，Q5 可选未做 |
| **v3.7.0** | **90%** | **优秀** | UI 交互测试覆盖轻 |
| **v3.7.1** | **90%** | **良好** | 残局棋谱入库集成待确认 |
