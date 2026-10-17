# T-0929-OC-01 A 系列消融批 + 探针 diff v2 任务书

> 派发：Luke（lead）｜2026-09-29 00:1x｜DDL：一级数据 01:45 / 全批报告 02:45（03:00 硬限）
> 依据：Alex v0.3 §2.3/§5.0 Phase -1（其 23:52 交付建议：E2 正式报告后同晚跑）+ Vera P1-2/P1-3/P1-5/P2-5
> 前置：E2 正式报告已交付并验收（23:55，Luke 抽验 4/4 一致）——你名下 worktree oc05e2-probe（45af5bd，保留）即本次基底
> 资源裁定：v0.3 标注"Cody 工单"，Luke 裁定改派 Tina——探针 v1 作者 + worktree 属主 + 批次执行者三位一体，午夜续作零交接成本；探针级不合 m1，无产品风险

## 1. 探针 diff v2（45af5bd 之上，探针级不合入 m1）

1. `--noise-a <N>`：镜像 `--noise-b` 注入 pairA（A 侧可注 0）
2. 0 值放行：`n > 0` 校验改 `n >= 0`（A2a/A2b 零锚前置）
3. `--topk <K>`：双引擎 topK 注入（A3 用；实例级模式照 leafNoiseOverride）
4. move-history run 专属子目录落盘（Vera P2-5：A23 前缀三层同名 + A55 互撞实测）
5. 冒烟三件：`--noise-a 0 --noise-b 70` ×1（接线+奇偶分派行为）｜`--topk 1` ×1｜无参回归 ×1

## 2. A 系列批（v0.3 §2.3 表为设计源，参数照抄）

**一级（01:45 前出数据——depth2 三点阶梯 = 分支 X/Y 裁决输入）**：

| 批 | 命令 | n | 目的 |
|---|---|---|---|
| A0 | `--calibrate-native 2 2 20 500` | 20 | 120v120 对称对照（50:50 检验+困毙率基线，E1 参照 5%） |
| A2a | `--calibrate-native 2 2 20 500 --noise-a 0 --noise-b 70` | 20 | 0v70 低位锚 |
| A2b | `--calibrate-native 2 2 20 500 --noise-a 0 --noise-b 120` | 20 | 0v120 强度锚 |

**二级（一级跑完后）**：
- A3：`--calibrate-native 2 3 20 500 --topk 1`（H2 判别；**判读控制（Vera P1-5）**：记录 repetition 率，>30% 时 A3 结论降级、报 Luke 评估 A4）
- A4（反重复过滤 off）：**不预跑**——仅 A0/A3 不能裁决 H1/H2 时 Luke 另派（需 selectBestMove 过滤旁路探针）

**条件批（可选顺跑）**：若 Luke ≤02:30 转发 Alex 回填的 N₁/N₂ 值（分支 X 成立时）：
- A5：`--noise-a 0 --noise-b N₁` ×20（终值直锚，Vera P1-3）
- A6：`--noise-a 0 --noise-b N₂` ×20（同上）
- 未收到回填值则跳过，晨窗另派

## 3. 归账与报告

- 噪声侧奇偶归账照 E2 模式（双列透明：噪声侧视角+座位视角）；A0 对称批给 50:50 检验 + stalemate 率基线
- 终局分布全记录（stalemate 通道是 E3 倒挂主载体——H1 判据核心）
- depth2 三点表（0/70/120）+ 与 E3 的 120v70 相对点 + 与 E2 depth3 曲线对照列
- 报告：`calibration-results/oc05-ablation/a-series/A-SERIES-REPORT.md`
- 一行回执：任务 ID + 报告路径 + 一级三点 W/L/D（X/Y 裁决速报）

## 4. 边界

- 探针级零触碰 m1 主树；`evaluator.evaluate` 本体不动（红线）
- `start_new_session` 脱离起批（nohup exec 连坐多次实证）；四批顺序单实例，禁并发格
- A7（kill 0v6）：v0.3 列入回填报值后批次——机制需 kill 开关 override（探针 v2 参数清单未含），执行前等 Alex 通道规格
- 03:00 时间耗尽时：已完成批照报、未完成批标注状态，不硬撑
