# Phase 11：Route B — NNUE 完整实施（远期，v3.2+）

> 路线：**Route B**（自研 NNUE 神经网络评估）
> 时间：v3.2+（需 GPU + ML/C++ 外部人力到位后启动）
> 依赖：Phase 4 可行性报告 + 外部资源（GPU、人力）

---

## ⚠️ 启动条件

本阶段执行的**全部前提**：
- ✅ Phase 4 可行性报告完成，技术路径清晰
- ✅ GPU 资源到位（RTX 3090/4090 或云 GPU）
- ✅ ML/C++ 外部人力到位（至少兼职训练顾问 + 推理引擎工程师）
- ✅ 洪涛批准 GPU + 外部人力预算
- ✅ Route A 已确认不可行，或需要 Route B 作为补充

**启动触发**：v3.2 规划时重新评估 Route B 启动条件。

---

## 目标

通过自研 NNUE 神经网络评估，达到 Elo 3500+，摆脱对 Pikafish 的依赖。

---

## 具体实施内容

### 11.1 数据生成（Week 1-2，与 Phase 4 调研对接）

**方式**：用 Pikafish 自对弈生成训练数据（使用 ≠ 分发，不违反 GPL）。

**规格**：
- 数据量：200-500 万局
- 算力：8 核并行，7-10 天
- 数据格式：每条记录 = FEN + best move + evaluation score
- 数据清洗：去除异常局面（如初始位置、将死位置）

**验证**：数据覆盖开局/中局/残局各阶段，分布均匀。

### 11.2 模型训练（Week 2-4）

**框架**：nnue-pytorch 适配象棋

**特征集**：halfKP-xiangqi，226,800 维输入

**训练流程**：
1. v1 模型：基础训练，GPU 训练 2-4 天 → Elo 预估 3000-3300
2. v2 模型：数据增强 + 超参调优，GPU 训练 2-4 天 → Elo 预估 3300-3500
3. v3+ 模型：迭代优化 → Elo 预估 3500+

**迭代验证**：每轮模型训练后与上一版自对弈验证，确认 Elo 提升。

### 11.3 推理引擎（Week 4-8）

**Clean-room 实现**（法律合规关键）：
- **仅根据 NNUE 论文 + 公开数学描述编写**
- **不参考 Pikafish/Stockfish GPL 源码**
- C++ 实现，C header 接口暴露
- 推理性能目标：移动端 < 1ms/position

**架构**：
```
NNUE Inference Engine (C++)
    │
    ├── Input Layer: halfKP-xiangqi feature embedding
    ├── Hidden Layers: fully connected + ClippedReLU
    ├── Output Layer: single value (position evaluation)
    └── C Interface: nnue_evaluate(FEN) → int score
```

**增量更新策略**：
- copy-make accumulator：每次走子后全量重算（简单但慢）
- 增量更新：只更新变化特征（快但复杂）
- 权衡：移动端推荐 copy-make（正确性优先）

**验收**：推理速度 < 1ms/position（移动端 A14+），评估精度 vs Pikafish ≤ 100cp 差异。

### 11.4 Swift 集成（Week 8-10）

- Swift 桥接层（类似 PikafishBridge）
- 双引擎架构升级：NativeEngine + PikafishEngine + NNUEEngine
- 或替换 PikafishBridge 为 NNUEBridge（如果完全自主）

### 11.5 自研搜索 + NNUE 整合（Week 10-12）

- 将 Phase 2 搜索算法（PVS + Countermove + LMR + 各种剪枝）与 NNUE 评估结合
- 自研搜索框架已有，只需替换评估函数调用
- NNUE 搜索深度可能更深（评估快于手写评估），搜索参数需重新调优

### 11.6 验证与调优（Week 12-16）

- 自对弈验证 Elo 提升
- 外部基准对弈（xiangqi.com）
- 搜索参数调优（LMR 表、Null Move R 值等）
- 置换表大小调优

---

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| NNUE 推理引擎（C++） | **新增** | Clean-room 实现 |
| `nnue_capi.h` | **新增** | C header |
| NNUE 模型文件 | **新增** | 训练产物（~30MB） |
| `AI/NNUEBridge.swift` | **新增** | Swift 桥接 |
| `AI/AIEngine.swift` | **修改** | 三引擎路由 |
| 训练脚本 | **新增** | Python（nnue-pytorch） |
| 数据生成脚本 | **新增** | Python + Swift 互操作 |

---

## 验证标准

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| 训练数据 | 200-500 万局，覆盖各阶段 | 数据统计 |
| v1 模型 Elo | ≥ 3000 | 自对弈 + 外部验证 |
| v2 模型 Elo | ≥ 3300 | 自对弈 + 外部验证 |
| v3+ 模型 Elo | ≥ 3500 | 外部基准验证 |
| 推理速度 | 移动端 < 1ms/position | 性能测试 |
| 评估精度 | vs Pikafish ≤ 100cp 差异 | 对比测试 |
| 法律合规 | Clean-room 实现可证明 | 代码来源审计 |
| App 体积 | NNUE 模型 ≤ 30MB | 文件大小 |

---

## 依赖关系

```
Phase 4（NNUE 可行性报告）
  + 外部资源到位（GPU + ML/C++ 人力 + 预算批准）
  └── Phase 11（本阶段：NNUE 完整实施）
        ├── 输入 ← Phase 2（搜索算法框架，搜索+评估整合）
        ├── 输入 ← Phase 10（Pikafish 集成，用于训练数据生成）
        └── 输出 → Elo 3500+ 自主可控
```

**工期**：12-16 周

**并行标记**：
- 数据生成（11.1）与推理引擎开发（11.3）可部分并行
- 模型训练（11.2）依赖数据生成完成
- Swift 集成（11.4）依赖推理引擎 C API 就绪
- 整体是长周期项目，不与 v3.0/v3.1 其他工作并行
