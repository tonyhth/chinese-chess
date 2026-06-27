# Phase 1：AI 基础设施 — 自对弈框架 + Elo 基线 + 评估快速修补

> 路线：**公共基础**（Route A / Route B 共同前置）
> 周次：Week 1
> 并行性：此阶段为后续所有 AI 工作的前置依赖，不可并行延后

---

## 目标

1. 建立自对弈测试框架，能量化引擎棋力变化
2. 测出当前大师级 AI 的真实 Elo 基线（预估 ~1500-1800）
3. 对评估函数做快速修补，消除明显的评估缺陷

---

## 具体实施内容

### 1.1 自对弈框架（SelfPlayRunner）

**功能**：引擎 vs 引擎自动对弈，统计胜率，输出 BayesElo 估值。

**设计要点**：
- 支持指定难度组合（如 master vs master、master vs hard）
- 支持指定局数（默认 100 局）
- 每局交换先后手，消除先手优势偏差
- 输出：胜/负/和统计 + BayesElo 差值估算
- 后续 Phase 可对比"旧引擎 vs 新引擎"，量化改进幅度

**数据结构**：
```swift
struct SelfPlayResult {
    let wins: Int          // 先手胜 + 后手胜
    let losses: Int
    let draws: Int
    let totalGames: Int
    let bayesEloDelta: Double  // 相对差值
    let gameRecords: [GameRecord]  // 每局 FEN 序列
}
```

**运行环境**：
- **macOS 命令行工具**（非 iOS）。iOS 后台执行时间受限，无法跑完 100 局
- 实现为 Swift Package 的可执行 target（或 macOS 测试用例）
- 通过 `swift run selfplay --games 100 --difficulty master vs master` 调用
- 输出结果到 stdout + 日志文件（`selfplay-results/` 目录）

**关键实现细节**：
- 每局设置步数上限（如 200 步），防止无限循环
- 检测重复局面（同一 FEN 出现 ≥3 次 → 判和）
- 超时处理：单步时限由调用方指定
- 结果写入日志文件，供后续分析

### 1.2 Elo 基线测量

**测量步骤**：
1. master vs hard 对弈 100 局 → 预期 master 胜率显著高
2. master vs master 对弈 100 局 → 验证一致性
3. hard vs hard 对弈 100 局 → 验证框架稳定性
4. 记录所有对局的 FEN 序列，供调试分析

**Elo 验证方法论**（全局标准，后续 Phase 遵循）：

| 验证方式 | 用途 | 样本量 | 置信度要求 |
|---------|------|--------|----------|
| 自对弈（新旧引擎对比） | 量化相对提升 | ≥ 200 局 | BayesElo 误差棒 ≤ ±50 |
| 交叉对弈（与已知 Elo 引擎） | 锁定绝对 Elo | ≥ 50 局 | 95% 置信区间 ≤ ±150 |
| xiangqi.com 排位赛 | 辅助验证 | ≥ 50 局 | 作为辅助参考，不作唯一 go/no-go 依据 |

> ⚠️ **样本量警告**：< 50 局的 Elo 估算波动可达 ±300 分。任何 Elo go/no-go 决策必须基于 ≥ 50 局交叉对弈或 ≥ 200 局自对弈。

**输出物**：`docs/baseline-elo-report.md`，包含：
- 各难度组合胜率统计
- BayesElo 估算差值
- 典型对局分析（master 输掉的局，为什么输）
- 当前大师级 AI 棋力评估结论

### 1.3 评估函数快速修补

这是 Phase 1 能独立完成的"低垂果实"，不需要搜索算法变更：

| 修补项 | 当前问题 | 修补内容 |
|--------|---------|---------|
| 位置权重表数值放大 | 数值 0-40，被子力值淹没 | 放大 10-20 倍（0-400 量级），使位置评估有实质影响 |
| 大师级开局选择 | `lookupWeightedRandom` 加权随机 | 改为确定性最优（取权重最高走法） |
| QS 将军走法 | `quiescenceSearch` 只搜吃子 | 增加将军走法搜索，减少地平线效应 |
| 位置权重表零值清理 | horse/chariot/cannon 大量 0 值 | 填入合理非零默认值 |

**验收标准**：
- 修补后自对弈 vs 修补前，胜率 ≥ 60%（即修补确实带来提升）
- QS 将军走法搜索不导致搜索时间超过 1.5 倍

### 1.4 Route A 可行性 Spike 启动

Week 1 启动，Week 2 结束出结论（详见 Phase 2 中的 Spike 部分）。

**本周启动项**：
- Pikafish GPLv3 法律评估：联系知识产权律师/法务顾问
- Pikafish 源码下载与初步分析

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `AI/SelfPlayRunner.swift` | **新增** | 自对弈框架核心 |
| `AI/AIEngine.swift` | **修改** | QS 增加将军走法、评估配置调整 |
| `AI/AIEngine.swift`（评估部分） | **修改** | 位置权重表数值调整 |
| `AI/AIEngine.swift`（masterSearch） | **修改** | 开局选择改为确定性最优 |
| `Models/Enums.swift` | 可能修改 | 如需新增评估相关枚举 |
| `docs/baseline-elo-report.md` | **新增** | Elo 基线报告 |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| 自对弈框架可运行 | 100 局自动对弈完成，无崩溃 | 运行 self-play 命令/测试 |
| Elo 基线报告 | 包含各难度组合数据 + 结论 | 文档审查 |
| 评估快速修补 | 修补后 vs 修补前胜率 ≥ 60% | 自对弈对比 |
| QS 将军走法 | 搜索时间增长 ≤ 1.5x | 性能测试 |
| 现有测试全通过 | 298 个测试 0 失败 | `swift test` |
| 新增测试覆盖 | SelfPlayRunner 核心逻辑有测试 | 测试报告 |

---

## 依赖关系

```
Phase 1（本阶段）
├── 无前置依赖
├── 输出 → Phase 2（搜索算法升级的基线对比）
├── 输出 → Phase 3（评估调优的基线对比）
├── 输出 → Phase 4（NNUE 研究的基线参考）
└── 输出 → Phase 5-8（可玩性功能可从此阶段开始并行）
```

**并行标记**：Phase 1 与 Phase 5（新手引导）、Phase 6 前半段（段位系统）可同期启动。AI 工作串行推进，可玩性工作可由不同人员并行。
