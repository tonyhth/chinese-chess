# D2 可玩性审计报告

## 审计范围

| 模块 | 文件 | 行数 |
|------|------|------|
| **GameViewModel** | `ViewModels/GameViewModel.swift` | ~480 |
| **PuzzleViewModel** | `ViewModels/PuzzleViewModel.swift` | ~590 |
| **ReplayViewModel** | `ViewModels/ReplayViewModel.swift` | ~175 |
| **AnalysisViewModel** | `ViewModels/AnalysisViewModel.swift` | ~120 |
| **TutorialViewModel** | `ViewModels/TutorialViewModel.swift` | ~100 |
| **CoachExplainer** | `AI/CoachExplainer.swift` | ~280 |
| **SelfPlayRunner** | `AI/SelfPlayRunner.swift` | ~280 |
| **PatternRecognizer** | `AI/PatternRecognizer.swift` | ~380 |

补充审查了关联文件：`AIEngine.swift`（难度→搜索深度映射）、`AIConstants.swift`（搜索配置）、`PlayerProfile.swift`（段位系统）、`Puzzle.swift`（残局数据模型）、`puzzles.json`（551 局残局数据）、`Localizable.xcstrings`（教程文案）。

---

## 发现的问题（按严重度 P0-P3 分级）

### P0 — 阻断性：规则教学与实现矛盾

**D2-P0-1: 教程教"长将和棋"，游戏判"长将判负"**

Tutorial 第 3 课文案（`tutorial.3.description`）：

> 🤝 长将和棋：连续将军，对方循环
> 🤝 长捉和棋：连续捉子，循环不变

但 `GameViewModel.detectPerpetualCheck()` 的实现：

```swift
// P0-3: 长将判负（中国象棋规则：连续将军判将军方负）
gameState = (currentSide == .red) ? .blackWon : .redWon
```

游戏执行的是正规竞赛规则（长将方判负），教程教的是民间休闲规则（长将和棋）。新手学完教程第一次触发长将时会完全无法理解为什么自己输了。

**影响**：规则认知混乱，直接影响第一局体验。
**修复方向**：教程文案改为"⚠️ 长将判负：连续将军 3 个回合，将军方判输！正式比赛规则"，或同时改教程 + 添加首次触发时的弹窗解释。

---

### P1 — 严重：影响核心体验

**D2-P1-1: AI 难度 medium→hard 存在断崖**

| 难度 | 搜索深度 | 关键优化 | 评估配置 |
|------|----------|----------|----------|
| beginner | depth 1 / 随机 | 无 | basic |
| easy | depth 3 | TT + moveOrder | basic |
| **medium** | depth 6-7 (ID) | **仅 killerMove** | **basic（无机动性评估）** |
| **hard** | depth 6-7 (ID) + 杀棋搜索 | **全开（QS+PVS+LMR+nullMove+futility+razoring+IID+countermove）** | **advanced** |

medium 到 hard 的跨度是质变：
- medium 没有静默搜索（quiescence）— 搜索末端全是静止评估，容易被战术组合击溃
- medium 没有机动性评估 — 完全不考虑棋子活动空间
- hard 突然开启全部 10+ 种搜索优化 + 12 步杀棋搜索

**段位系统放大问题**：`recommendedCoachDifficulty` 映射中，scholar→medium、juren→hard。一个秀才玩家赢了就跳到举人，AI 对手从"无 QS 的 basic eval"直接变成"全优化 + 杀棋搜索"，玩家会觉得"突然变了一个游戏"。

**影响**：中等水平玩家在晋升段位时遭遇不可预期的难度跳跃，挫败感强。
**修复方向**：(1) medium 加入 quiescence search（深度限制 2 即可）；(2) 在 medium 和 hard 之间增加一个过渡配置（如 medium 启用 QS + LMR，但不启用 nullMove/PVS）。

**D2-P1-2: 残局 difficulty 与 stars 完全冗余**

551 道残局数据中 `difficulty` 和 `stars` 永远相等（difficulty=N → stars=N），实际上退化成了一个维度。代码中 `defenderDifficulty` 用 `stars` 映射 AI 搜索深度，`calculateRating()` 用 `difficulty` 做参考——但两者取值永远相同。

本应两个独立维度：
- `difficulty` = 找到正解的难度（ tactical complexity ）
- `stars` = 解法质量评分标准（允许多少步偏差）

**影响**：无法区分"容易发现但需要精确走法"的局和"难以发现但一旦找到就很直接"的局，残局排序对玩家来说缺乏梯度感。
**修复方向**：数据层面修正（需要内容设计，非纯代码），当前系统至少应承认冗余并移除其中一个字段，或明确语义分离。

**D2-P1-3: 所有残局 solutionType 均未设置（默认 checkmate）**

代码支持三种模式：`checkmate`、`sequence`、`hint`。`PuzzleViewModel` 为三种模式编写了不同的判定逻辑和评分逻辑。但 551 道残局中没有一道设置了 `solutionType` 字段——全部走默认的 `checkmate` 路径。

`sequence` 类型的评分逻辑（按是否走了推荐走法评星）和 `hint` 类型的提示逻辑（纯文字提示无 step-by-step solution）都是死代码。

**影响**：`PuzzleViewModel.calculateRating()` 中 sequence 分支永远不会执行。如果未来添加 sequence 局，需要充分测试这些代码路径——目前它们从未被生产环境验证过。
**修复方向**：要么为部分残局补充 solutionType（如多步杀用 sequence），要么删除未使用的代码路径。

**D2-P1-4: 复盘分析在自研引擎回退时静默失效**

`PositionAnalyzer.getEngine()` 检查 `EngineRouter` 当前引擎是否为 `EmbeddedPikafishEngine`，如果不是则返回 nil，分析直接跳过：

```swift
guard let emb = engine as? EmbeddedPikafishEngine else {
    NSLog("[PositionAnalyzer] Engine is not EmbeddedPikafishEngine, analysis disabled")
    return nil
}
```

当 Pikafish 加载失败、回退到自研引擎时，玩家进入复盘界面点"分析"后，`AnalysisViewModel.analyzeAll()` 会跑完全部循环但每个 `analyses[index]` 都是 nil，最终 evalSequence 为空、qualityDistribution 为空。玩家看到的是空白分析界面，没有任何错误提示。

**影响**：引擎回退场景下复盘功能完全不可用，且无任何用户感知。
**修复方向**：AnalysisViewModel 检测到 engine 不可用时，设置 `errorMessage` 状态供 UI 展示。

---

### P2 — 中等：体验缺陷

**D2-P2-1: 无"认输"功能**

GameViewModel 没有 resign 方法。玩家如果想放弃当前对局，只能点"新游戏"——但这不会记录为败局，不会触发统计、成就检测和 GameRecord 保存。玩家连胜会一直保持。

**影响**：(1) 统计数据失真（玩家可以逃避败局记录）；(2) 在明显劣势的局面下没有体面的退出方式。
**修复方向**：添加 `resign()` 方法，设置 gameState 为对手获胜，走 recordGameResult() 流程。

**D2-P2-2: 提示（hint）与教练（coach）系统完全割裂**

游戏中 `requestHint()` 只返回引擎最佳走法的起止位置高亮——没有文字解释为什么这步好。复盘时 `CoachExplainer` 能生成详细的文字讲解（8 类场景模板），但这两个系统完全独立，玩家在对局中得到提示后不会获得任何教练说明。

玩家看到的："这里亮了，走这里。"
教练系统能说的："你的车应该从底线展开，控制中路要道，评估差距 150cp。"

**影响**：提示系统只有"答案"没有"教学"，新手用提示学不到东西。
**修复方向**：hint 返回后附带 CoachExplainer 的简要文案（至少 1 句话解释为什么）。

**D2-P2-3: 教程只有 5 课，缺少进阶内容**

当前教程：
1. 棋子走法（规则）
2. 将军与应将（规则）
3. 将死判定（3 题一步杀）
4. 特殊规则（困毙、长将）
5. 第一局实战（新手 AI）

覆盖范围仅限"从零学会基本规则"。缺少：
- 开局原则（出车快、马不贸然跳、炮不轻发）
- 基本战术（牵制、闪击、双打）
- 残局基本功（单车胜单将、马兵胜单士等）
- 棋型认知（当头炮、屏风马、反宫马等）

玩家完成教程后，从"会走棋"到"下出基本战术"之间存在认知空白，直接进入对弈会反复被 AI 战术击溃。

**影响**：新手留存率。教程完成后到第一场胜利之间的学习曲线断裂。
**修复方向**：添加进阶教程课程（6-10 课），或引入"每日一题"连接教程和残局。

**D2-P2-4: GameViewModel.isProcessingWrongMove 是死代码**

```swift
var isProcessingWrongMove: Bool = false
```

此属性在 GameViewModel 中声明但从未被赋值为 true，也没有任何地方读取它。只有 PuzzleViewModel 中有完整的 `isProcessingWrongMove` 逻辑。

**影响**：无害但说明可能存在未完成的功能（计划在对弈模式中实现走错提示但未实施）。
**修复方向**：删除死代码，或补全功能。

**D2-P2-5: AnalysisViewModel.analyzeAll() 性能瓶颈——串行分析**

每步分析调用 `PositionAnalyzer.analyzeMove()`，搜索深度 18 + 时间限制 2 秒。60 步对局串行分析需要约 120 秒。没有并行化。

```swift
for (index, move) in moves.enumerated() {
    let analysis = await PositionAnalyzer.shared.analyzeMove(...)
    analyses[index] = analysis
    analysisProgress = (index + 1, moves.count)
}
```

**影响**：完整复盘分析等待时间长，玩家可能放弃等待。
**修复方向**：(1) 用 `TaskGroup` 并行分析（但 PositionAnalyzer 是 actor，天然串行）；(2) 降低分析深度/时间；(3) 只分析玩家方的走法，跳过 AI 走法。

**D2-P2-6: GameViewModel.newGame() 难度自动调节是单向的**

```swift
if !userDidSetDifficulty {
    difficulty = PlayerProfileStore.shared.profile.rank.recommendedCoachDifficulty
}
```

一旦玩家手动设置难度（`userDidSetDifficulty = true`），就永远不会再自动调整。一个学童段位玩家手动选了中级难度，升级到举人后仍然停留在中级——段位提升带来的难度推荐完全失效。

**影响**：段位系统的教练推荐功能价值被削弱。
**修复方向**：段位变化时提示玩家"推荐提升难度"，由玩家确认后更新。

**D2-P2-7: 残局提示系统缺乏渐进层次**

`showHint()` 只有两级：
1. 文字提示（如果有 `hints` 数组）
2. 直接显示 solution 的下一步走法 + 棋谱

没有中间层（如"先提示哪个棋子该动"、"再提示方向"、"最后才给完整走法"）。玩家要么得到模糊提示，要么直接看到答案。

**影响**：残局学习效果打折。玩家依赖答案而非思考。
**修复方向**：三级提示体系：(1) 棋子高亮 (2) 方向箭头 (3) 完整走法。

---

### P3 — 轻微：优化建议

**D2-P3-1: CoachExplainer 场景分类中 isDevelopmentMove 判定过于粗糙**

```swift
private func isDevelopmentMove(_ move: String, fen: String) -> Bool {
    let rankChar = move[move.index(move.startIndex, offsetBy: 1)]
    return rankChar == "0" || rankChar == "9"
}
```

只检查起始行是否在底线。中局阶段从底线移动的棋子（如底线车平移）会被误分类为"兵力展开"。

**D2-P3-2: CoachExplainer.isDefensiveMove 逻辑简化过度**

```swift
return analysis.bestEval < -50
```

只要最佳评估略低于零就判为防守走法。任何均势偏差都会被归类为防守。

**D2-P3-3: SelfPlayRunner 终局检测方式不标准**

```swift
if board.generalPosition(of: .red) == nil { ... 黑方胜 }
```

通过"将帅是否在棋盘上"判断胜负，而不是 `MoveValidator.isCheckmate`。这在正常对弈中可行（将被吃 = 游戏结束），但与 GameViewModel 的胜负判定方式不一致（用 isCheckmate）。如果引擎返回的走法有任何异常，可能将帅被吃后仍继续搜索。

**D2-P3-4: PatternRecognizer 部分棋型判定用硬编码值**

担子炮 bonus `+300`、巡河炮 `+200`、叠炮 `+250` 等加分量直接写在代码里，不走 EvalWeights。与项目其他部分（EvalConfigManager + EvalWeights）的权重管理方式不一致。如果需要通过 CMA-ES 调优这些参数，需要先迁移到 EvalWeights。

**D2-P3-5: TutorialViewModel 课程数量硬编码为 5**

如果未来扩展课程数量，需要同步修改 `hasCompletedTutorial` 逻辑。当前实现不检查是否逐课完成，只标记最终完成状态。

**D2-P3-6: ReplayViewModel 快照策略无内存上限控制**

`snapshots` 字典每 20 步存一个 Board 快照。200 步对局会存 10 个快照。Board 是值类型，每个快照包含完整棋盘状态（约 32 个 Piece），内存占用可接受但无上限。极长对局（理论 500+ 步）可能产生内存压力。

---

## 建议改进

### 高优先级（建议在 v3.9 发布前完成）

1. **修复教程规则矛盾** [D2-P0-1]：教程第 3 课的长将/长捉规则文案改为与实现一致（判负），添加首次触发时的解说弹窗。

2. **平滑 medium→hard 难度过渡** [D2-P1-1]：为 medium 级别启用 quiescence search（深度 2）和机动性评估。这不会显著增加搜索时间（QS 深度 2 很浅），但会让评估更准确。

3. **复盘分析引擎回退时显示提示** [D2-P1-4]：AnalysisViewModel 检测到引擎不可用时设置错误状态，UI 展示"当前引擎不支持局面分析"。

4. **添加认输功能** [D2-P2-1]：GameViewModel 增加 `resign()` 方法，正常记录败局。

### 中优先级（建议在 v4.0 规划）

5. **提示系统集成教练说明** [D2-P2-2]：`requestHint()` 返回走法后，调用 CoachExplainer 生成 1-2 句简要说明。

6. **扩展教程体系** [D2-P2-3]：增加开局原则、基本战术、残局基础课程（课程 5-10）。

7. **残局三级提示** [D2-P2-7]：从"棋子提示 → 方向提示 → 完整走法"渐进展开。

8. **残局数据修正** [D2-P1-2, D2-P1-3]：对 551 道残局进行分类，标记 solutionType，分离 difficulty 和 stars 语义。

### 低优先级（长期改进）

9. **复盘并行分析** [D2-P2-5]：`analyzeAll()` 只分析玩家方走法，或用并发 Task 加速。

10. **段位提升时的难度推荐交互** [D2-P2-6]：段位变化时弹出"是否提升教练难度"。

11. **PatternRecognizer 权重迁移** [D2-P3-4]：将硬编码的棋型加分迁移到 EvalWeights。

---

## 总结

可玩性基础框架完整：单局流程（选子→走棋→AI 应对→终局判定）逻辑严密，和棋检测（三次重复、50 回合、长将判负）覆盖全面，棋钟系统功能完备，复盘导航和残局引导模式可用。

核心问题集中在三个方面：

1. **教学一致性**：教程与实现存在规则矛盾（P0），是必须修复的阻断项。
2. **难度曲线**：medium→hard 的 AI 强度跃升过大（P1），段位系统的难度推荐在手动设置后永久失效（P2），这两个因素叠加会导致中等水平玩家的体验断裂。
3. **系统协同**：教练讲解、提示系统、残局引导、复盘分析四个子系统各自独立运作，缺乏横向联动。教练能生成丰富的讲解但只在复盘用；提示只给答案不给理由；残局有引导模式和自由对弈模式但切换体验粗糙。如果这四个系统能数据互通（如教练分析结果驱动提示内容、残局弱项分析推荐对应教程），可玩性将有质的提升。

**审计结论**：v3.9 发布前需修复 P0（教程规则矛盾）和评估 P1 中难度过渡问题。P2 中的认输功能和复盘错误提示建议一并修复。其余 P2/P3 可纳入 v4.0 迭代规划。
