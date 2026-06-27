# Phase 2：Route A — 搜索算法全面升级

> 路线：**Route A**（自研引擎提升路径）
> 周次：Week 2-3（拆分为 Phase 2a / 2b 两步）
> 并行性：与 Phase 4（Route B NNUE 研究）可并行；与 Phase 5/6（可玩性）可并行

---

## 目标

通过搜索算法的系统性升级，将自研引擎棋力从 ~1800 提升至 ~2200+。这是 Route A 的核心交付物，也是 Route A Pikafish 集成时低难度引擎的技术基础。

---

## 实施节奏

本 Phase 工作量大，拆分为两步实施，每步留足测试时间：

| 步骤 | 周次 | 内容 | 验收节点 |
|------|------|------|----------|
| **Phase 2a** | Week 2 | PVS + Countermove + LMR + Pikafish Spike | 核心搜索效率提升，Elo 基线对比 ≥ +100 |
| **Phase 2b** | Week 3 | NMP + Futility + Razoring + TT 多桶 + IID | 全部剪枝优化到位，Elo ≥ 2200 |

**拆分理由**：PVS/Countermove/LMR 是走法排序+搜索框架的基础改造，互相耦合紧密，需整体验证；NMP/Futility/Razoring 是在良好搜索框架上的增量剪枝，可独立加入和测试。

---

## 具体实施内容

### Phase 2a（Week 2）

### 2.1 PVS（Principal Variation Search / NegaScout）

**当前状态**：`rootSearch` 和递归搜索对所有走法使用全窗口 Alpha-Beta。

**升级内容**：
- 第一个走法（通常是 TT best move 或排序最高）用全窗口搜索
- 后续走法用零窗口（`alpha = alpha + 1`）搜索
- 如果零窗口搜索失败（返回值 > alpha），重新用全窗口搜索
- 对根节点和内部节点都适用

**预期效果**：搜索效率 +10-15%，同时间内搜索深度 +1-2 层

**关键实现点**：
```swift
// PVS 核心逻辑（伪代码）
for (i, move) in orderedMoves.enumerated() {
    if i == 0 {
        // 第一个走法：全窗口
        score = -negamax(board, -beta, -alpha, depth - 1)
    } else {
        // 后续走法：零窗口试探
        score = -negamax(board, -alpha - 1, -alpha, depth - 1)
        if score > alpha && score < beta {
            // 重新全窗口搜索
            score = -negamax(board, -beta, -alpha, depth - 1)
        }
    }
    alpha = max(alpha, score)
    if alpha >= beta { break }  // beta cutoff
}
```

### 2.2 Countermove Heuristic

**当前状态**：`MoveOrderer` 有 TT best > Killer > History，无 Countermove。

**升级内容**：
- 新增 `countermoveTable`：记录上一步走法导致的 cutoff 应着
- 表结构：`[our_last_move → best_counter_move]`
- 排序优先级：TT best > Countermove > 将军 > MVV-LVA > Killer > 威胁 > History
- 表大小：固定数组（9×10×9×10 = 8100 槽），每槽存一个 Move

**预期效果**：走法排序质量显著提升， Alpha-Beta 剪枝效率间接提升

### 2.3 LMR（Late Move Reductions）

**当前状态**：无 LMR 实现。

**升级内容**：
- 对排序靠后的走法（位置 > N，取决于深度），减少搜索深度
- 减少量基于：走法排序位置 + 当前搜索深度 + 是否在 PV 节点
- 减少后如果返回值 > alpha，重新用全深度搜索（re-search）
- 标准 LMR 公式：
  ```
  reduction = max(0, log(depth) * log(moves_searched) / 2 - 1)
  // 深度浅 / 走法靠前时 reduction = 0（不减）
  // 非安静位置（吃子、将军、应将）不减少
  ```

**预期效果**：搜索节点数减少 30-50%，同时间搜索深度 +2-3 层

### Phase 2b（Week 3）

### 2.4 Null Move Pruning（NMP）

**当前状态**：无 NMP。

**升级内容**：
- 在非根节点、非残局局面，如果当前局面评估远高于 beta，"跳过一步"做零窗口搜索
- 如果跳过后对手仍然无法提升（β cutoff），则当前局面明显优势，直接剪枝
- 限制条件：
  - 当前深度 ≥ 3
  - 已评估 ≥ beta + 边际值（如 100cp）
  - 不在将军状态
  - 减少深度 = `depth - 3 - R`（R 通常为 2-3）
- **【象棋特殊安全检查】**：
  - 中国象棋有长将判和规则（连续将军不变着判和）。NMP 的"虚拟空步"可能让对手获得永久将军机会，导致评估出错
  - 安全措施：NMP 搜索结果如果显示对手获得连续将军序列（同一着法重复 ≥ 3 次），则不信任 NMP 结果，回退到正常搜索
  - 残局阶段（剩余子力 ≤ 阈值）禁用 NMP——残局中 zugzwang 概率更高（虽然象棋的 zugzwang 不如国象严重，但空步可能丢掉关键先手）
  - 兵卒残局（双方仅剩将 + 兵/卒）禁用 NMP

**预期效果**：搜索节点数减少 20-30%

### 2.5 Futility Pruning（Phase 2b）

**当前状态**：无。

**升级内容**：
- 在浅深度节点（depth ≤ 3），如果静态评估 + 边际值 ≤ alpha，跳过非吃子走法
- 边际值随深度递增：depth 1 → 300, depth 2 → 500, depth 3 → 900
- 仅对非 PV 节点应用

**预期效果**：浅层额外剪枝，减少无用分支

### 2.6 Razoring（Phase 2b）

**当前状态**：无。

**升级内容**：
- 在 depth ≤ 2 时，如果静态评估 + 边际值 ≤ alpha，直接做 QS 搜索
- 如果 QS 结果仍 ≤ alpha，直接返回（不需要做完整搜索）
- 边际值：depth 1 → 300, depth 2 → 500

### 2.7 TT 多桶替换策略（Phase 2b）

**当前状态**：`TranspositionTable` 用固定数组，深度优先替换。

**升级内容**：
- 改为双桶策略（2 slots per index）
- 桶内策略：depth-prefer + age
  - 如果新条目深度 ≥ 现有条目深度 → 替换
  - 如果新条目深度更低但现有条目来自旧搜索（age 不同）→ 替换
- 新增 `age` 字段：每次新搜索（IDS 新的根深度）递增

**预期效果**：长对局 TT 命中率提升，尤其残局阶段

### 2.8 Internal Iterative Deepening（IID）（Phase 2b）

**当前状态**：无。

**升级内容**：
- 当 TT 中无最佳走法且深度 ≥ 4 时，先做一次 depth-2 浅搜
- 用浅搜结果填充走法排序（提供一个 TT best move）
- 防止在"空 TT"情况下走法排序质量差导致的搜索浪费

### 2.9 Pikafish 可行性 Spike（Week 1-2 延续项）

**法律评估**（Week 1 启动，Week 2 出结论）：
- GPLv3 + App Store 合规分析
- 可能的合规路径评估（双许可 / 非嵌入 / 作者协商）
- 结论：合规 / 灰色地带 / 不合规

**iOS C++ 编译 Spike**（Week 2）：
- Pikafish C++ 源码下载
- iOS arm64 编译（Xcode + C++）
- 暴露方案 v3.0 方案中的 C API 接口
- 验证：`pf_engine_init`、`pf_position_from_fen`、`pf_search_bestmove` 可调用
- 测量编译产物体积（如 >50MB 需评估 ODR）

**Spike 验收标准**：
- 法律：明确结论（合规 / 不合规 / 灰色地带按不合规处理）
- 技术：C API 能编译并调用（至少生命周期 + 位置管理 + 搜索三个接口）
- 体积：记录 App 体积增量

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `AI/AIEngine.swift` | **重大修改** | PVS 改造、Null Move、Futility、Razoring、IID |
| `AI/PVSExtension.swift` | **新增** | PVS 搜索逻辑（或直接内嵌 AIEngine） |
| `AI/CountermoveHeuristic.swift` | **新增** | Countermove 表实现 |
| `AI/LateMoveReductions.swift` | **新增** | LMR 计算逻辑 |
| `AI/NullMovePruning.swift` | **新增** | Null Move 判定逻辑 |
| `AI/MoveOrderer.swift` | **修改** | 集成 Countermove 排序 |
| `AI/TranspositionTable.swift` | **修改** | 多桶替换 + age 字段 |
| `AI/SelfPlayRunner.swift` | **修改** | 添加新旧引擎对比模式 |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| PVS 正确性 | PVS 返回的评估值与 Alpha-Beta 在容差 ±10cp 内一致（同深度同局面）。由于搜索顺序不同，TT 交互可能导致具体走法不同，评估值一致即可 | 单元测试：同一组局面，PVS 和原 Alpha-Beta 评估值在容差内 |
| Countermove 效果 | 排序命中率提升 | 统计 countermove 被采用为 cutoff 走法的比例 |
| LMR 正确性 | re-search 逻辑无遗漏 | 单元测试：构造需 re-search 的局面，验证走法选择不变 |
| Null Move 安全性 | Zugzwang 局面不误判 | 单元测试：已知 zugzwang 局面不触发 NMP |
| 搜索效率 | 同深度搜索节点数减少 ≥ 30% | 节点计数对比（新旧引擎） |
| Elo 提升 | Phase 2 后 vs Phase 1 基线，BayesElo 提升 ≥ 200 | 自对弈 200 局（误差棒 ≤ ±50） |
| 外部基准 | 交叉对弈验证 Elo ≥ 2000（95% 置信区间 ≤ ±150） | 与已知 Elo 引擎交叉对弈 ≥ 50 局 |
| 现有测试 | 全部通过 | `swift test` |
| Spike 结论 | 法律 + 技术 + 体积三要素明确 | Spike 报告 |

---

## 依赖关系

```
Phase 1（自对弈框架 + Elo 基线）
  └── Phase 2（本阶段：搜索算法升级）
        ├── 输出 → Phase 3（评估调优，基于新搜索框架）
        ├── 输出 → Phase 10（Pikafish 集成，依赖 Spike 结论）
        └── 可并行 ← Phase 4（NNUE 研究，独立技术栈）
              可并行 ← Phase 5（新手引导 + 选边）
              可并行 ← Phase 6（段位系统）
```

**并行标记**：
- Phase 2 内部各优化项有顺序依赖：PVS → Countermove → LMR（LMR 依赖好的走法排序）→ NMP → 其他
- Phase 2 与 Route B（Phase 4）完全独立，可由不同人员并行
- Phase 2 与可玩性 Phase 5/6 可并行（不同代码区域）
