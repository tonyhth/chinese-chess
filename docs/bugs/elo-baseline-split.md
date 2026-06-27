# Elo 基线测量拆解方案

## 问题
当前 EloBaselineTests 用 medium vs medium 5 局自对弈，在 Intel x86_64 上跑 30 分钟+，无法在合理时间内获得结果。

## 拆解方案

改为分难度级别的 1v1 对弈，每次只跑 1 局，独立测量各难度等级的相对棋力：

### 测试 1: easy vs medium（1 局）
- 预期：medium 应胜
- 目的：验证 easy 和 medium 之间有可量化的差距
- 耗时估算：easy 思考快，约 3-5 分钟

### 测试 2: medium vs hard（1 局）
- 预期：hard 应胜
- 目的：验证 medium 和 hard 之间有差距
- 耗时估算：约 5-8 分钟

### 测试 3: hard vs master（1 局）
- 预期：master 应胜
- 目的：验证 hard 和 master 之间有差距
- 耗时估算：master 思考深，约 8-12 分钟

### 测试 4: master vs master（1 局）
- 预期：和棋概率高（同级别）
- 目的：测量 master 级别的先手优势 + 平均步数
- 耗时估算：约 10-15 分钟

### 优势
1. 每局独立可跑，单个 timeout 内完成
2. 结果更有价值——跨难度对比比同级别更有诊断意义
3. 如果某个组合太慢，可以单独跳过不影响其他结果
4. 最终汇总各难度差距，形成 Elo 梯度图

### 实现要求
1. 改造 EloBaselineTests 为 4 个独立 Test（每个 1 局）
2. 每个 Test 设合理的 timeout（Swift Testing 不直接支持 per-test timeout，但可通过 maxMoves 控制）
3. maxMoves 降到 150（减少超长对局概率）
4. 结果输出到独立文件：`docs/elo-baseline-results.md`
5. 汇总各难度差距 + BayesElo 估算

### Elo 锚定
- medium vs medium 同级别 → Elo 差 ≈ 0（基线）
- easy vs medium → 差距 = medium 的相对优势
- 以此类推，构建相对 Elo 梯度
- 绝对 Elo 需要外部基准（xiangqi.com 排位赛），洪涛人工操作
