# T-0928-OC-05E2 E2 噪声响应曲线探针任务书

> 派发：Luke（lead）｜2026-09-28 22:4x｜DDL：2026-09-29 01:00
> 依据：洪涛 22:21 终裁 Step 1 消融探针三组之 E2
> 前置数据：E1 已完成（基线方差，见 §4）；E3 已完成（倒挂复现，见 §4）

## 1. 任务

**E2 噪声响应曲线**：lvl5(噪声 0) vs lvl5+噪声 {50, 100, 200, 400}cp，各 ×20 局（共 80 局），映射噪声→Elo 曲线，定位 alpha-beta 开始崩的膝盖点和全崩平台区。

## 2. 实现：harness 扩展（探针级，不合入 m1）

⚠️ 现有 CLI `--calibrate-native` 只接受预设档位（180/120/70/35/0），自定义噪声值需要最小 diff 扩展：

1. **worktree**：探针 worktree（参考 mkwt / OC-02 惯例，/private/tmp/oc02-wt 先例，但产物路径遵守 08-27 规约放 ~/DevTeam 下），基 m1@15ccd62，rsync 资产按 worktree-resources.txt
2. **AIEngine.swift**：加 `leafNoiseOverride: Int?`（private var + actor 隔离 setter，照 qsStandPatFullOverride 注入点模式）；bestMove/bestMoves 两处赋值点改为 `leafNoise = leafNoiseOverride ?? difficulty.leafNoiseAmplitude`
3. **SelfPlayRunner.swift CLI**：`runCalibrateNativeFromCLI` 解析可选 `--noise-b <N>`（附着到 diffB 角色）

### ⚠️ 关键正确性设计（KI-2026-0921-02 swap 教训类）

**噪声必须跟角色（level）走，不跟座位（seat）走**：
- `--noise-b 100` = diffB 角色带噪声 100；swapSides 轮换时，奇数局 diffB 坐红方 → **红方引擎实例带 override**
- 实现建议：run() 在 override 存在时构造双引擎实例（纯侧 engine 无 override，噪声侧 engine setLeafNoiseOverride(N)），每局按 swap 后的角色分配 redEngine/blackEngine（playGame 已支持 redEngine/blackEngine 参数）
- **单引擎共享实例 + 逐手切 override 的方案严禁**——漏切一手 = 污染整局

### 归账（KI-2026-0922-02 级别视角教训类）

lvl5 vs lvl5 双方 rawValue 相同 → levelPerspective 退化（redIsDiffA 恒真）。**噪声侧 W/L/D 按奇偶归账**：
- 显示局号奇数（gameIndex 偶）→ 噪声侧 = 黑方
- 显示局号偶数（gameIndex 奇）→ 噪声侧 = 红方
- 噪声侧胜 = 奇数局黑胜 + 偶数局红胜
- 报告必须双列：噪声侧视角 + 座位视角（透明防误用）

## 3. 执行

- 构建：`xcodegen generate && xcodebuild -target ChineseChess -configuration Release build`（固定路径）
- 跑批：**setsid/python start_new_session 脱离**（⚠️ nohup 会被 exec 返回杀掉，今晚已实证三次），四格顺序跑（单引擎实例，禁并发格）
- 命令形如：`ChineseChess --calibrate-native 5 5 20 500 --noise-b <N>`，N ∈ {50,100,200,400}
- 输出：`~/DevTeam/projects/chinese-chess/calibration-results/oc05-ablation/e2/batch-<TS>/E2_n<N>.log`
- 逐局即时落盘（A3 教训照旧）

## 4. 已有数据（同批次参照）

- **E1 基线**：lvl5(0) vs lvl5(0) ×20 → 10-7-3（座位 +53 = 先手带内），仪器正常，n=20 噪声带 ±~90
  - 日志：calibration-results/oc05-ablation/batch-20260928-222339/E1_lvl5_vs_lvl5.log
- **E3 倒挂复验**：lvl2(120) vs lvl3(70) ×40 → **24-12-4, +108（级别视角）——倒挂复现且更显著**
  - 日志：calibration-results/oc05-ablation/batch-20260928-222339/E3_lvl2_vs_lvl3_40.log
- OC-05 主批：calibration-results/oc05-noise-quickcalib/OC05-JUDGMENT.md

## 5. 报告要求

每格输出：噪声侧 W/L/D + BayesElo（噪声侧视角）+ 座位视角参照 + 和棋率 + moveLimit 占比。
汇总：噪声 {50,100,200,400} → Elo 曲线表 + 膝盖点/平台区判读。
报告落盘：calibration-results/oc05-ablation/e2/E2-REPORT.md，一行回执（任务 ID + 报告路径）。

## 6. 边界

- 探针代码不合入 m1，worktree 用完保留（Alex v2.1 可能复用 harness）
- 不动 evaluator.evaluate 本体（红线），override 只走消费侧既有 leafNoise 通道
- 二进制为 m1@15ccd62 + 本探针 diff，报告须附 git diff 摘要
