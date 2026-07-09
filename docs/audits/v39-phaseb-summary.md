# v3.9 Phase B — 五维度审计汇总与升级方案

**汇总人**: Luke | **日期**: 2026-07-15  
**基于**: Phase A 五维度审计（D1-D5），共发现 73 个问题

---

## 一、问题总览

| 维度 | P0 | P1 | P2 | P3 | 小计 |
|------|----|----|----|----|------|
| D1 游戏逻辑 | 2* | 6 | 6 | 3 | 17 |
| D2 可玩性 | 1 | 4 | 7 | 5† | 17 |
| D3 操作性/UX | 2 | 5 | 8 | 5 | 20 |
| D4 功能完整性 | 2 | 3 | 4 | 3 | 12 |
| D5 i18n | 0 | 5 | 4 | 3 | 12 |
| **合计** | **7** | **23** | **29** | **19** | **78** |

> *D1 的两个 P0 经 Alex 确认为防御性缺陷和代码清晰度问题，正常对局不触发，实际严重度降为 P2  
> †D2 的 P3 统计含部分审计方法建议项

---

## 二、真实 P0 问题（必须 v3.9 修复）

### P0-1: 教程规则矛盾 [D2]
教程教"长将和棋/长捉和棋"，游戏实现"长将判负"。新手学完教程触发长将时无法理解为什么输了。  
**修复**: 教程文案改为判负规则 + 首次触发时弹窗解释

### P0-2: 开局探索器完全不可用 [D3]
棋盘预览区域无任何棋盘组件（空白）+ 路径推演递归遍历全部后代而非根到节点路径。功能形同虚设。  
**修复**: 渲染 ChessBoardView + 重写 walkPath 为根到节点路径回溯

### P0-3: 首次启动引导从未调用 [D4]
`FirstLaunchDialog` 已定义但 App 入口从未引用。新用户无引导。  
**修复**: ChineseChessApp.init 检查 completedTutorials，未完成则弹出

### P0-4: 残局成就检查孤岛代码 [D4]
`AchievementChecker.checkAfterPuzzle` 定义但从未调用。行为型残局成就永远无法解锁。  
**修复**: PuzzleViewModel 残局完成回调中调用 checkAfterPuzzle

---

## 三、跨维度交叉发现

### 3.1 AI 搜索性能链（D1 × D2）
- D1-P1-4: quiescenceSearch 全量走法生成（性能热点）
- D1-P2-1: wouldBeInCheck 每次 snapshot 深拷贝
- D2-P1-1: medium→hard 难度断崖（medium 无 QS）

**关联**: medium 缺 QS 导致评估粗糙 → 玩家升段到 hard 时 QS+全优化同时开启 → 断崖感。修复 medium 加 QS(深度2) 可同时缓解 D1 性能问题（QS 深度 2 开销小）。

### 3.2 i18n 硬编码集群（D4 × D5）
- D5-P1-1~2: BoardTheme 主题名称+解锁条件（5 处）
- D5-P1-3~5: PGN 导出/导入错误消息（5 处）
- D4-P1-3: TutorialView 硬编码（25 处）
- D3-P2-2: ChessBoardView 楚河汉界硬编码（2 处）

**关联**: 共约 37 处硬编码中文，集中修一批即可大幅提升英文体验。

### 3.3 资源管理缺陷（D3）
- D3-P1-3: Timer 永不停止（StatusBarView + ChessClockView）
- D3-P1-4: SoundEngine 缺 AVAudioSession 配置
- D3-P2-5: SoundEngine isMuted 竞态条件

**关联**: iOS 端资源管理是薄弱环节，三个问题同属 Services 层。

### 3.4 系统协同断裂（D2 × D4）
- D2-P1-4: 复盘分析引擎回退时静默失效（无错误提示）
- D2-P2-2: 提示与教练系统完全割裂
- D4-P2-3: CoachModeOverlay 对弈中未集成

**关联**: 教练、提示、残局引导、复盘分析四系统各自独立运作，缺乏横向联动。

---

## 四、v3.9 升级方案

### Phase 1: P0 修复（预计 3 天）
| # | 任务 | 负责人 | 工期 |
|---|------|--------|------|
| 1 | 教程规则文案修正 + 长将首次触发弹窗 | Cody | 0.5 天 |
| 2 | OpeningExplorerView 棋盘渲染 + walkPath 修复 | Cody | 1.5 天 |
| 3 | FirstLaunchDialog 集成到 App 入口 | Cody | 0.5 天 |
| 4 | checkAfterPuzzle 调用集成 | Cody | 0.5 天 |

### Phase 2: P1 批量修复（预计 5 天）
| # | 任务 | 负责人 | 工期 |
|---|------|--------|------|
| 5 | medium 难度加 QS(深度2) + 机动性评估 | Cody | 1 天 |
| 6 | i18n 硬编码批量修复（BoardTheme+PGN+Tutorial 约 37 处） | Cody | 1.5 天 |
| 7 | Timer 生命周期管理 + SoundEngine AVAudioSession | Cody | 1 天 |
| 8 | 复盘分析引擎回退时显示错误提示 | Cody | 0.5 天 |
| 9 | ThemePickerView 加 ScrollView + ReplayBoardView 翻转一致性 | Cody | 0.5 天 |
| 10 | PuzzleSelectView 废弃 API 替换（UIScreen.main → GeometryReader） | Cody | 0.5 天 |

### Phase 3: 高价值 P2（预计 3 天）
| # | 任务 | 负责人 | 工期 |
|---|------|--------|------|
| 11 | 认输功能 | Cody | 0.5 天 |
| 12 | 棋盘 AI 思考视觉指示 | Cody | 0.5 天 |
| 13 | 每日挑战占位模式缩减（7→3 或折叠） | Cody | 0.5 天 |
| 14 | SettingsView 主题行加色块预览 | Cody | 0.5 天 |
| 15 | game.vsAITitle 占位符修复 + SoundEngine isMuted 改同步 | Cody | 0.5 天 |
| 16 | CoachSessionView 增加上一步按钮 | Cody | 0.5 天 |

### Phase 4: 性能优化（预计 2 天）
| # | 任务 | 负责人 | 工期 |
|---|------|--------|------|
| 17 | wouldBeInCheck 改为 in-place execute/undo | Cody | 1 天 |
| 18 | quiescenceSearch 专用吃子走法生成器 | Cody | 1 天 |

**总预计工期**: ~13 天（含审查和测试）

---

## 五、建议处理但不在 v3.9 的项目

| 项目 | 原因 | 建议版本 |
|------|------|----------|
| iOS 补齐 Analysis/Coach/OpeningExplorer 入口 | 工作量大，需独立设计 iOS 交互 | v4.0 |
| 每日挑战 7 种新模式实现 | 每种需独立设计 | v4.0 迭代 |
| 教程扩展（课程 6-10） | 需内容设计 | v4.0 |
| 残局 difficulty/stars 分离 + solutionType 分类 | 需内容重新评审 | v4.0 |
| PatternRecognizer 权重迁移到 EvalWeights | 低优先级 | v4.0 |
| 复盘并行分析 | 需重构 PositionAnalyzer actor | v4.0 |
| 棋子显示名称传统区分（傌/俥等） | 纯视觉，需洪涛确认 | v4.0 可选 |

---

## 六、审计质量评价

| 维度 | 审计人 | 报告质量 | 评价 |
|------|--------|----------|------|
| D1 游戏逻辑 | Alex | ★★★★★ | 逐函数分析，代码级洞察，性能瓶颈定位精准 |
| D2 可玩性 | Vera | ★★★★★ | 系统级视角，交叉关联到位（难度曲线+段位+教程） |
| D3 操作性/UX | Ruby | ★★★★☆ | 覆盖全面，开局探索器 P0 发现关键 |
| D4 功能完整性 | Tina | ★★★★★ | 链路追踪方法严谨，完成度矩阵信息密度高 |
| D5 i18n | Cody | ★★★★☆ | 量化分析到位（544 keys 全覆盖检查），Ruby 审查确认 |

**Phase A 审计整体质量**: 优秀。5 份报告无重复、无遗漏，跨维度交叉发现自然涌现（非人工引导），说明五维度划分合理。

