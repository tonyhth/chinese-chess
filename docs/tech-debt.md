# Technical Debt Registry

记录项目中的技术债务、重构需求和优化机会。

---

## TD-001: CMA-ES 单线程瓶颈

**发现日期**：2026-06-24  
**严重程度**：高（阻塞调参效率）  
**涉及模块**：`AI/CMAESOptimizer.swift`, `AI/SelfPlayRunner.swift`

### 现象

CMA-ES 调参进程运行时间过长：
- 参数：种群10 / 代数30 / 每代8局自对弈
- 单代时间：40-80分钟
- 总时间：20-40小时（Intel Mac）

### 根因

**全局状态竞争**：

```swift
// CMAESOptimizer.swift:evaluatePopulation()
for i in 0..<population.count {  // 串行循环
    let weights = individual.toEvalWeights()
    EvalConfigManager.shared.setWeights(weights)  // ← 全局单例！
    let result = SelfPlayRunner().run(config)    // 自对弈评估
    population[i].fitness = computeFitness(result)
}
```

`EvalConfigManager.shared` 是全局单例，无法支持并行评估：
- 个体 A 设置权重 → 个体 B 设置权重 → A 的权重被覆盖
- SelfPlayRunner 读取错误的权重配置

### 解决方案

**重构 SelfPlayRunner 支持权重参数注入**：

```swift
class SelfPlayRunner {
    func run(config: SelfPlayConfig, weights: EvalWeights? = nil) -> SelfPlayResult {
        // 如果提供 weights，创建独立引擎实例并注入
        // 不依赖 EvalConfigManager.shared
    }
}

// CMAESOptimizer 改为 async 并行评估
func evaluatePopulationParallel() async {
    await withTaskGroup(of: (Int, Double).self) { group in
        for i in 0..<population.count {
            group.addTask {
                let weights = population[i].toEvalWeights()
                let result = SelfPlayRunner().run(config: config, weights: weights)
                return (i, computeFitness(result))
            }
        }
        for await (i, fitness) in group {
            population[i].fitness = fitness
        }
    }
}
```

**预期效果**：
- 10个体并行 → 5-8分钟/代
- 30代 → 2.5-4小时（提速 8-10倍）

### 状态（2026-09-13 对账更新：修复已落地，Ruby/Tina 交叉结论）

- [x] 问题识别
- [x] ~~等当前进程跑完验证单线程结果~~（2026-06 运行中进程早已结束，事项失效）
- [x] 重构 SelfPlayRunner
- [x] 重构 CMAESOptimizer.evaluatePopulation()
- [x] 并行测试验证（Batch1P0CMAESTests/CMAESWeightInjectionTests 固化注入→使用→恢复语义；并行一致性由注入闭竞争面收敛，无专项对照用例）
- [x] 更新 CLI 参数（可选：支持 `--parallel`）→ 不再适用：TaskGroup 并行已是 evaluatePopulation 唯一路径，开关无必要（CLI 入口 runCMAESFromCLI 无开关，CMAESOptimizer.swift:462）

### 修复证据（2026-09-13 台账对账补登，commit d2ac85e）

- `src/ChineseChess/AI/SelfPlayRunner.swift:95-97` — `init(weights:)` 权重注入构造器（独立引擎实例）
- `src/ChineseChess/AI/AIEngine.swift:46-49` — `init(weights:)` 独立实例构造器（CMA-ES 并行评估专用，不读全局单例）
- `src/ChineseChess/AI/CMAESOptimizer.swift:302-341` — `evaluatePopulation()` TaskGroup 并行（动态调度，并发度 = CPU 核数）
- `src/ChineseChess/AI/CMAESOptimizer.swift:345-367` — `evaluateFitness(weights:)` 每个体独立 `SelfPlayRunner(weights:)`

### 备注

- 单线程结果可作为基线对照
- 并行化后需验证结果一致性（权重参数注入不能影响评估准确性）

---

## TD-002: Swift Concurrency `withCheckedContinuation` 不响应取消

**发现日期**：2026-06-24  
**严重程度**：中（导致测试僵死）  
**涉及模块**：`AI/UCITransceiver.swift`

### 现象

回归测试多次僵死：进程运行但 CPU 0%，无输出，需要手动杀掉。

### 根因

`waitForBestMove` 超时机制使用 `withCheckedContinuation`，但不响应 `Task.cancelAll()`：

```swift
let result = await withTaskGroup(of: String?.self) { group in
    group.addTask {
        await withCheckedContinuation { cont in
            holder.set(cont)  // ← 不响应取消，必须等 cont.resume()
        }
    }
    group.addTask {
        try? await Task.sleep(...)
        return nil  // 超时
    }
    let first = await group.next()
    group.cancelAll()  // ← 对 continuation 阻塞的 Task 无效！
}
```

如果 `readabilityHandler` 永远没收到匹配行 → continuation 永不 resume → **永久阻塞**。

### 解决方案

改用 `withThrowingTaskGroup` + `Task.checkCancellation`：

```swift
func withTimeout<T>(seconds: Int, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            throw TimeoutError()
        }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return result
    }
}
```

### 状态（2026-09-13 对账更新：问题已消，条目转备档）

- [x] 问题识别
- [x] 记录到 tech-debt.md
- [x] 重构 UCITransceiver.waitForBestMove → 以文件退场方式消解（见对账结论）
- [x] 重构 UCITransceiver.waitForToken → 同上
- [x] 验证超时机制生效（迁移后机制：EmbeddedPikafishEngine.withWatchdog）

### 对账结论（2026-09-13）

问题已消，非原地修复：

- `UCITransceiver.swift` 已于 commit d2ac85e 随 7 个 legacy 外置引擎源文件一并删除（外置 UCI 引擎链路整体退场）
- 超时机制迁移至 `EmbeddedPikafishEngine.withWatchdog`（`src/ChineseChess/AI/EmbeddedPikafishEngine.swift:71-89`）：ResumeOnce 守卫 + 双 `Task.detached` 竞速（工作体 vs sleep 超时），等待有界——旧"continuation 永不 resume → 永久阻塞"形态不复存在

### 备档声明

- **Task.cancel 不响应 withCheckedContinuation 阻塞中的 Task，属 Swift 语言限制**（非本项目缺陷）。withWatchdog 以竞速超时绕开该限制；若未来重启外置引擎链路，须沿用同模式，勿回到无界 continuation 等待
- 原备注"当前临时方案：跳过真实引擎测试（`--skip Phase2bUCITests`）"为陈旧引用，2026-09-13 清除：Phase2bUCITests 已随 d2ac85e 删除（4 个 legacy 测试文件之一），当前代码库无此 suite（grep 全 src/ 无匹配），skip-registry（docs/test/skip-registry.md）逐行核对亦无此登记，无需补登

---

---

## Backlog: Pre-existing P1（下个 Sprint）

以下 P1 问题为已有代码的遗留问题，非本次改动引入，排期下个 sprint 修复。

### P1-1: AchievementView 空成就无引导提示

**发现日期**：2026-06-24  
**严重程度**：P1（UX 欠缺）  
**涉及文件**：`Views/AchievementView.swift`

**问题**：当用户成就列表为空时，界面显示空白，无引导提示（如"暂无成就，开始游戏解锁更多"）。

**解决方案**：添加空状态占位符（EmptyStateView），参考 RankProgressView 的空状态设计。

**状态**：待下个 sprint

---

### P1-2: RankPrivilegeView 特权描述硬编码中文

**发现日期**：2026-06-24  
**严重程度**：P1（i18n 遗漏）  
**涉及文件**：`Views/RankPrivilegeView.swift`

**问题**：段位特权描述文本硬编码中文，未使用 Localizable.xcstrings。

**解决方案**：提取字符串到 Localizable.xcstrings，使用 `LocalizedStringKey`。

**状态**：待下个 sprint

---

### P1-3: RankPrivilegeView 进度标签硬编码中文

**发现日期**：2026-06-24  
**严重程度**：P1（i18n 遗漏）  
**涉及文件**：`Views/RankPrivilegeView.swift`

**问题**：进度标签（如"当前进度"、"下一段位"）硬编码中文。

**解决方案**：提取字符串到 Localizable.xcstrings。

**状态**：待下个 sprint

---

### P1-4: RankPrivilegeView Section header 硬编码中文

**发现日期**：2026-06-24  
**严重程度**：P1（i18n 遗漏）  
**涉及文件**：`Views/RankPrivilegeView.swift`

**问题**：Section header（如"特权列表"、"进度详情"）硬编码中文。

**解决方案**：提取字符串到 Localizable.xcstrings。

**状态**：待下个 sprint

---

---

## TD-003: 门禁验证脚本缺失

**发现日期**：2026-06-24  
**严重程度**：中（基础设施缺失）  
**涉及模块**：交付流程

### 现象

交付验证脚本 `~/DevTeam/scripts/verify_delivery.sh` 不存在，`~/DevTeam/scripts/` 目录未建立。每次打包后需要手动等价验证。

### 影响

- 交付依赖手动检查，效率低
- 验证项可能遗漏（依赖执行者经验）
- 不阻塞交付，但增加重复劳动

### 解决方案

创建标准门禁验证脚本：

```bash
#!/bin/bash
# ~/DevTeam/scripts/verify_delivery.sh
# 交付门禁验证脚本

APP_PATH="$1"

# 验证项清单
echo "=== 交付门禁验证 ==="
echo "App: $APP_PATH"

# 1. 版本号
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
echo "版本号: $VERSION"
[ -z "$VERSION" ] && echo "❌ 版本号缺失" && exit 1

# 2. 架构
ARCH=$(file "$APP_PATH/Contents/MacOS/ChineseChess" | grep -o "Mach-O.*x86_64")
echo "架构: $ARCH"
[ -z "$ARCH" ] && echo "❌ 架构错误" && exit 1

# 3. 签名
codesign -vvv "$APP_PATH" 2>&1 | grep -q "valid on disk" || { echo "❌ 签名无效"; exit 1; }
echo "签名: ✅ valid"

# 4. 资源完整性（图标、字体、国际化、开局库、音效、残局）
[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ] || { echo "❌ 图标缺失"; exit 1; }
[ -f "$APP_PATH/Contents/Resources/LXGWWenKai-Regular.ttf" ] || { echo "❌ 字体缺失"; exit 1; }
[ -f "$APP_PATH/Contents/Resources/Localizable.xcstrings" ] || { echo "❌ 国际化缺失"; exit 1; }
[ -f "$APP_PATH/Contents/Resources/opening_book_v2.json" ] || { echo "❌ 开局库缺失"; exit 1; }
# 音效 + 残局 ...
echo "资源: ✅ 完整"

echo "=== ✅ 全部验证通过 ==="
exit 0
```

### 状态

- [x] 问题识别（v2.2.17、v3.2 打包时均发现）
- [x] 创建 ~/DevTeam/scripts/ 目录（2026-06 已建，2026-09-14 DevTeam 仓 git 化收编 a322e5f）
- [x] 编写 verify_delivery.sh 脚本（主仓版 project-dir 五查版为单源，v1.3 扩面 [3/5]+warn→fail=15aaff9；DevTeam 侧薄 wrapper 化=8bbbce7）
- [x] 集成到打包流程（charter §3.2 交付门：verify_delivery 为打包发版必跑门禁，[3/5] 禁止清单+fail 档已制度化；techdebt-reconcile 同入口挂发版 checklist=Batch B ③b）

### 备注

- 历史版本（v2.2.17、v3.1、v3.2）均采用手动等价验证通过
- 不阻塞当前交付，但需尽快补建避免重复劳动
- **勾销记录（2026-09-17 Batch B ③b，T-0917-1）**：三框清偿证据——目录（DevTeam 仓 a322e5f）/脚本（主仓 15aaff9 v1.3 扩面版）/流程集成（charter §3.2+reconcile 同入口）。双份裁并：docs/general/tech-debt.md（290 行旧副本）出库归档 ~/DevTeam/analysis/doc-merges-20260917/，本文件（303 行现行版）为唯一单源

---

（后续技术债务在此追加）