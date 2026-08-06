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

### 状态

- [x] 问题识别
- [ ] 等当前进程跑完验证单线程结果
- [ ] 重构 SelfPlayRunner
- [ ] 重构 CMAESOptimizer.evaluatePopulation()
- [ ] 并行测试验证
- [ ] 更新 CLI 参数（可选：支持 `--parallel`）

### 备注

- 当前 CMA-ES 进程 PID 83785，已运行 ~12小时，预计还需 ~12小时
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

### 状态

- [x] 问题识别
- [ ] 记录到 tech-debt.md
- [ ] 重构 UCITransceiver.waitForBestMove
- [ ] 重构 UCITransceiver.waitForToken
- [ ] 验证超时机制生效

### 备注

- 当前临时方案：跳过真实引擎测试（`--skip Phase2bUCITests`）
- 长期必须修复，否则外部引擎功能不可靠

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
- [ ] 创建 ~/DevTeam/scripts/ 目录
- [ ] 编写 verify_delivery.sh 脚本
- [ ] 集成到打包流程

### 备注

- 历史版本（v2.2.17、v3.1、v3.2）均采用手动等价验证通过
- 不阻塞当前交付，但需尽快补建避免重复劳动

---

（后续技术债务在此追加）