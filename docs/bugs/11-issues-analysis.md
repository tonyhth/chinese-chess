# 洪涛上报 11 个问题 — 完整分析汇总

> 负责人：Luke  
> 分析：Alex（P0 架构）、Vera（P1 数据）、Luke（UI）  
> 日期：2026-08-08

---

## 总览

| # | 问题 | 级级 | 根因类型 | 分析结论 | 修复量 |
|---|------|------|---------|---------|--------|
| 1 | 开局教练不工作 | P0 | SwiftUI API 弃用 | ✅ 根因明确 | 小 |
| 2 | 棋手列表点击区域 | P1 | buttonStyle(.plain) 缺 contentShape | ✅ 根因明确 | 小 |
| 3 | 开局分类数量不一致 | P1 | 子分类不互斥不完备 | ✅ 根因明确 | 中 |
| 4 | iOS 中炮子分类无法进入 | P0 | 条件分支遗漏 selectedSubcategory | ✅ 根因明确 | 小 |
| 5 | 复盘分析无内容 | P0 | 引擎链路 + UI 反馈 | ⚠️ 需运行时排查 | 中-高 |
| 6 | iOS 学棋页布局 | P2 | VStack 改 LazyVGrid | ✅ 根因明确 | 小 |
| 7 | AI 详解无反应/每步无说明 | P0 | 设计 vs 期望偏差 | ⚠️ 需产品决策 | 中 |
| 8 | 教程第7课第二步 | P1 | 非问题 | ✅ 数据正确 | 无 |
| 9 | 大师棋谱演示点评不工作 | P0 | macOS 缺 CommentaryOverlay + iOS 待查 | ✅ macOS 根因明确 | 中 |
| 10 | 残局棋谱格式 | P1 | DemoViewModel 未用 NotationGenerator | ✅ 根因明确 | 小 |
| 11 | 残局 486 局 + 扩展 | P1 | 数据问题（92/551 局） | ✅ 根因明确 | 中（数据） |

---

## P0-1：开局教练不工作

**根因**：`OpeningCoachSelectView` 使用已弃用的 `NavigationLink(isActive:)` + `.background()` + `.hidden()` 模式，在 NavigationStack 环境下失效。

**文件**：`Views/OpeningCoachSelectView.swift` — iOS + macOS 两处

**修复方案**：替换为 `.navigationDestination(isPresented: $navigateToGame)`，放在视图主体上而非 .background 里。

**影响范围**：iOS + macOS，低回归风险

---

## P0-4：iOS 大师棋谱中炮子分类无法进入

**根因**：`browserLayout` iOS 分支条件 `selectedOpening == nil && !showSubcategoryList` 缺少 `selectedSubcategory == nil` 判断。选了子分类后被弹回一级分类列表。

**文件**：`Views/MasterGameBrowserView.swift` 第 125 行附近

**修复方案**：条件中增加 `&& selectedSubcategory == nil`

---

## P0-5：复盘分析无内容

**根因（双重）**：
- A：段位门禁 `.openingTreeBrowse` 语义不匹配（如果段位不够直接显示锁定页）
- B：引擎初始化链路可能断裂 — `analyzeAll()` 检查引擎类型通过，但 `PositionAnalyzer.getEngine()` 内部 `isReady` 检查可能失败
- C：分析全 nil 时，评估曲线显示"分析中..."而非错误提示

**文件**：`Views/AnalysisView.swift`、`ViewModels/AnalysisViewModel.swift`、`AI/PositionAnalyzer.swift`

**修复方案**：
1. UI 层：区分"分析中"和"分析失败"，evalChart 区显示对应提示
2. 引擎层：需运行时日志确认 NNUE 文件是否正确打包加载
3. 门禁语义：复查 `.openingTreeBrowse` 是否应为分析功能的正确门禁

**⚠️ 需要运行时排查**：macOS Console.app 日志、iOS NNUE 文件路径检查

---

## P0-7：AI 详解无反应/每步无说明

**根因**：
- 同步点评仅覆盖将军/将死/弃子/最后一步（~5-10% 走法）
- 异步智能点评 `smartCommentaryEnabled` 默认 false
- 用户期望每步有讲解，但当前设计只有特殊步法有点评

**文件**：`Models/DemoConfig.swift`、`ViewModels/DemoViewModel.swift`、`Helpers/CommentaryEngine.swift`

**⚠️ 需产品决策**（3 个方案选一）：
- 方案 A：`smartCommentaryEnabled` 默认改 true（有性能风险：引擎并发 + 自动播放）
- 方案 B：增加不依赖引擎的轻量级点评（吃子/攻击提示，覆盖 40-60% 走法）
- 方案 C：保持默认 false，UI 提示用户可开启

**Luke 建议**：方案 B（轻量级同步点评扩展），性能安全且提升覆盖率。智能点评保持默认 false，加 UI 提示。

---

## P0-9：大师棋谱演示点评不工作

**macOS 根因（确定）**：`macosPlayLayout` **完全没有 CommentaryOverlay** — 点评气泡根本不渲染。

**iOS 根因（待查）**：
- 可能 `showCommentary` 被 UserDefaults 持久化为 false
- 或 `onMoveExecutedHandler` 回调时机问题

**文件**：`Views/MasterGameBrowserView.swift` — `macosPlayLayout` 方法

**修复方案**：
1. macOS：在 `macosPlayLayout` 的 DemoBoardView 外层包 ZStack + CommentaryOverlay（和 iOS 对齐）
2. iOS：排查 DemoConfig.showCommentary 持久化值 + 回调日志

---

## P1-2：棋手列表点击区域

**根因**：`.buttonStyle(.plain)` 在 iOS List 中，Button 内 Spacer 撑开的空间不响应点击。全局缺少 `.contentShape(Rectangle())`。

**文件**：`Views/MasterGameBrowserView.swift` — iosPlayerList、iosEventList、iosCategoryList 等所有 List Button

**修复方案**：所有 List 内 Button 的 HStack 加 `.contentShape(Rectangle())`

**影响范围**：iOS 全部列表视图（棋手/赛事/对局/开局），macOS 也建议加

---

## P1-3：开局分类数量不一致

**根因**：
- 一级分类逻辑正确（互斥 + "其他"兜底）
- 子分类不互斥（列炮是顺炮超集）且不完备（部分开局不归任何子分类）

**文件**：`Services/MasterGameStore.swift:93-106`、`Models/OpeningCategories.swift`

**修复方案**：
- 子分类匹配改"最长匹配优先"
- 每个一级分类下加"其他应手"兜底
- 或 UI 不展示子分类 count 之和

---

## P1-8：教程第7课第二步

**结论**：非问题。FEN 和 expectedMoves 数据正确。

- e4e5：红兵前进一步，过河 ✅
- e5d5：兵过河后横移吃黑兵 ✅

**建议**：优化 hint 文案，说明"过河后可以横移"。

---

## P1-10：残局棋谱格式

**根因**：`DemoViewModel.moveNotations` 硬编码 UCIMoveConverter 输出 UCI 坐标（如"红h2e2"），但项目已有 `NotationGenerator` 支持传统中文记谱法。

**文件**：`ViewModels/DemoViewModel.swift:76-81`

**修复方案**：改用 `NotationGenerator.notation(for:on:)`，自动跟随用户设置。

---

## P1-11：残局 486 局 + 全面扫描（92/551 局）

**类型 1（56 局）**：solution 仅 1 步但 mode=guided → 改 freePlay
**类型 2（36 局）**：solution 步数 > maxMoves → 上调 maxMoves

**文件**：`Resources/Puzzles/puzzles.json`

**修复方案**：
- 类型 1：solutionMode 改 freePlay，solution[0] 保留为提示
- 类型 2：maxMoves = len(solution) + 2

---

## P2-6：iOS 学棋页面布局改 2 列 3 行

**当前**：StudyHubView.iOSLayout 用 VStack 纵向排列 6 个卡片
**修复**：改 LazyVGrid 2 列

---

## 需要洪涛决策的问题

### 1. P0-7：每步说明的期望
- 用户是否期望**每一步**都有文字说明？
- 接受方案 B（轻量级同步点评：吃子/攻击提示，不依赖引擎）？

### 2. P0-5：复盘分析排查
- 需要 macOS 运行时日志（Console.app 中 `[Pikafish]` 相关）确认引擎状态
- 洪涛的段位等级？（确认门禁是否是主因）

### 3. P1-3：子分类数量显示策略
- 改为排他匹配 + "其他应手"兜底？
- 还是 UI 上不显示子分类数量之和？

