# T-0926-OC-04 v2 主案编码任务书

> 派发：Luke（lead）｜日期：2026-09-26 17:4x｜DDL：2026-09-28 12:00
> 前置：OC-01 Phase 0 ✅ ACCEPTED（m1 ae3be20，Tina 独立验证 PASS）
> 设计文档：docs/design/v65-weakening-chain-v2-draft.md（v0.3 终版，187 行）
> 拆解单：docs/plans/v65-implementation-batch-order.md

## 编码范围（§3.2 五档总表 + §3.3 叶噪声机制 + §3.4 实现面差异表）

### 1. AIDifficulty 属性变更（§3.4 表）

- **新增**：`leafNoiseAmplitude: Int`（噪声幅度 ±cp，单参数集中此字段）
- **撤销**：`evalNoiseTemperature` / `rootTopK`（温度轴整体撤销，根选法全档确定性 best）
- **保留**：`searchDepth` / `timeBudgetMs` / 其余属性不动

### 2. noisyEvaluate 消费侧包装层（§3.3 + 附录 A 伪码）

- **不动 `evaluator.evaluate` 本体**（红线）
- 新建 `noisyEvaluate` 包装函数：`raw + Int.random(in: -noise...noise)`，noise=0 时直接返回 raw
- **覆盖面写死（P3-2）**：全包叶评估调用点——
  - negamax 静态叶（AIEngine.swift L701 区）
  - quiescenceSearch standPat/超时叶（AIEngine.swift L897 区）
- 漏包任一点 → lvl2-4（noise>0）与 lvl5（noise=0）噪声面不对称、梯度失真
- 等价性锚点：lvl5（noise=0）与现产 hard 搜索输出一致

### 3. §3.2 五档总表落地

| 级别 | 名义 depth | 预算 macOS / iOS(×0.6) | SearchConfig | 叶噪声 ±cp | 开局库 | CheckmateSearch |
|---|---|---|---|---|---|---|
| lvl1 | 2 | 500 / 300ms | 简化 minimax（无 killer/LMR/**无 checkExt**） | 180 | 加权随机·前8步 | 无 |
| lvl2 | 2 | 1000 / 600ms | hard | 120 | 同 | 无 |
| lvl3 | 2 | 2000 / 1200ms | hard | 70 | 同 | 无 |
| lvl4 | 3 | 3000 / 1800ms | hard | 35 | 同 | 浅层 ≤6 地板 |
| lvl5 | 3 | 5000 / 3000ms | hard | 0 | 同 | 浅层 ≤6 地板 + 全量终局模块（12, 1200ms） |

- lvl1 撤 checkExt（§1.3 mid-a 教训：浅档 checkExt 可拖爆 depth 1 迭代）
- lvl5 CheckmateSearch 升级：浅层 ≤6 地板 + 全量终局模块（12, 1200ms）——顶档差增强项

### 4. 配置统一 hard（§3.1）

- lvl2-5 统一 hard（达界稳定性，不为拉深度）
- lvl1 例外：简化 minimax（无 killer/LMR/checkExt）
- mediumNoQS / 其他预设不再使用（保留定义不删）

### 5. 温度轴整体撤销（§3.1）

- 移除 `temperatureWeightedPick` 调用
- 根选法全档确定性 best（score 最高走法）
- 弱化全部由叶噪声承担

## 红线

- **不改 `evaluator.evaluate` 本体**
- **nullmove 不碰**（R=4+ 仅评估不入主案；R=3 门控维持现状）
- **评估阶段零代码零调参**
- 噪声走消费侧包装（noisyEvaluate），不散落到评估函数

## 验证

- `cd ~/DevTeam/projects/chinese-chess && xcodebuild build -scheme ChineseChess -destination 'platform=macOS'`
- 新套件：noisyEvaluate 等价性测试（lvl5 noise=0 与现产 hard 搜索输出一致，跨相位覆盖 QS 路径）
- 现有套件回归全绿
- 完成后汇报：编译结果 + 文件变更清单 + git log --oneline -1
- **Commit message 尾部带 `Line: OC`**

## 注意

- 本任务仅编码 §3.2 五档总表 + §3.3 叶噪声机制 + §3.4 实现面差异
- 完成率矩阵（OC-02）不在本任务范围——Tina 并行执行
- 噪声轴快标定（OC-05）门槛触发后才进正批——本任务交付后解锁
- 标签锁定 = Phase 0 后定（OC-02 完成率矩阵实测后）；本任务落地的是预标定值
