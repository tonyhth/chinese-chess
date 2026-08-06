> ℹ️ 初版方案，修订版见 test-infra-redesign.md（v3，Vera 复查后定稿）
# 测试基础设施根因分析与修复方案

## 问题陈述

Tina（tester agent）连续 3 次 swift test 超时被 kill（runtimeMs 16min/32min/16min），严重阻塞流水线。这不是偶发问题，而是结构性缺陷。

## 根因分析

### 直接原因：Intel Mac + SPM 测试架构的组合缺陷

1. **`swift test` 单进程串行执行 1099 个测试方法**，无超时控制
   - 149 个测试文件，1099 个测试方法
   - 任何单个测试卡住 → 整个 test run 卡住 → agent 超时被 kill

2. **SelfPlay 测试是卡住的元凶**
   - 7 个文件使用 SelfPlay（自对弈引擎），每个测试跑 1-5 局完整棋局
   - EloBaselineTests: 4 个测试，每局 30+ 分钟 → 单 suite 可锁 2 小时
   - Phase3bLMRTimeManagementTests: 24 个测试，涉及 AI 搜索
   - P1aRegressionTests: 22 个测试，涉及 AI 引擎
   - Phase3a/bEvaluationTests: 33 个测试，涉及搜索评估
   - Phase3DrawTests/Phase7Tests/Phase2bOptimizationTests: 52 个测试，部分使用 SelfPlay

3. **xcodebuild 进程残留**
   - agent 被 kill 后 xcodebuild 子进程不会自动退出
   - 残留进程锁住 DerivedData → 下次测试卡在编译阶段
   - 诊断中发现 8:52 和 9:02 的残留 xcodebuild 进程

4. **Tina 的 session 缺乏进程清理机制**
   - agent killed 后无 cleanup hook
   - 新的测试启动时未检查/清理残留进程

### 根本原因：测试缺少超时和分类治理

| 缺陷 | 影响 |
|------|------|
| SelfPlay 测试无超时 | 一局棋可跑 30+ 分钟，无法中断 |
| 无测试分类标记 | Tina 无法区分快/慢/危险测试 |
| 无进程守护 | agent killed 后子进程残留 |
| 全量测试是默认 | swift test 不带过滤 = 必定超时 |

## 修复方案

### P0: 测试分类标签系统（根治）

为每个测试 Suite 添加 tag，支持按分类执行：

```swift
// 使用 Swift Testing 的 tag 特性
@Suite("Phase B3 Step 1", .tags(.unit, .openingCoach))
struct B3S1OpeningCoachTests { ... }

@Suite("Elo 基线", .tags(.slow, .selfPlay, .benchmark))
struct EloBaselineTests { ... }

extension Tag {
    @Tag static var unit: Tag        // 快速单元测试（<1s/个）
    @Tag static var integration: Tag // 集成测试（<30s/个）
    @Tag static var slow: Tag        // 慢测试（>30s/个）
    @Tag static var selfPlay: Tag    // SelfPlay 对弈测试
    @Tag static var benchmark: Tag   // 性能基准测试
    @Tag static var ui: Tag          // UI 测试
}
```

xcodebuild 支持 tag 过滤：
```bash
# 只跑快速单元测试
xcodebuild test -only-testing:ChineseChessTests/Tag/unit

# 跳过 SelfPlay 和 benchmark
xcodebuild test -skip-testing:ChineseChessTests/Tag/selfPlay -skip-testing:ChineseChessTests/Tag/benchmark
```

### P0: SelfPlay 测试超时保护

```swift
@Suite("Elo 基线", .serialized, .disabled(if: ProcessInfo.processInfo.environment["SKIP_ELO"] != nil))
struct EloBaselineTests {
    
    @Test("easy vs medium", .timeLimit(.minutes(5)))  // 单测试 5 分钟超时
    func easyVsMedium() async throws { ... }
}
```

- 每个涉及 SelfPlay 的测试加 `.timeLimit(.minutes(N))`
- SelfPlayConfig 添加 `timeoutSeconds` 参数，引擎搜索超时自动断开
- 超时测试标记为 failed 而非 hung

### P1: 测试运行脚本

创建 `scripts/test-batch.sh`，Tina 的标准入口：

```bash
#!/bin/bash
# 用法: test-batch.sh quick|full|ci|elo
#   quick  = 只跑 unit tag（<2min）
#   full   = unit + integration，跳过 selfPlay/benchmark（<15min）
#   ci     = full + 代码覆盖率（CI 专用）
#   elo    = 只跑 benchmark/selfPlay（后台，不限时）

MODE=${1:-quick}
case $MODE in
  quick)  FILTER="-only-testing:ChineseChessTests/Tag/unit" ;;
  full)   FILTER="-skip-testing:ChineseChessTests/Tag/selfPlay -skip-testing:ChineseChessTests/Tag/benchmark" ;;
  ci)     FILTER="-skip-testing:ChineseChessTests/Tag/selfPlay" ;;
  elo)    FILTER="-only-testing:ChineseChessTests/Tag/benchmark" ;;
esac

xcodebuild test -scheme ChineseChess -destination 'platform=macOS' $FILTER
```

### P1: 进程守护

Tina 的测试命令前后加清理逻辑：

```bash
# 测试前：清理残留进程
pkill -f 'xcodebuild.*ChineseChess' 2>/dev/null || true
pkill -f 'swift-test' 2>/dev/null || true
sleep 2

# 运行测试
xcodebuild test ...

# 测试后：确认无残留
pkill -f 'xcodebuild.*ChineseChess' 2>/dev/null || true
```

### P2: SelfPlay 测试降配

SelfPlay 测试默认使用低配参数，减少运行时间：

```swift
// 生产配置：5 局 × 150 步
static let production = SelfPlayConfig(games: 5, maxMoves: 150)

// 测试配置：1 局 × 50 步，验证逻辑而非竞技质量
static let testing = SelfPlayConfig(games: 1, maxMoves: 50)
```

## 测试文件分类清单

| 分类 | 文件数 | 测试数 | 预估耗时 | 标签 |
|------|--------|--------|---------|------|
| SelfPlay 对弈 | 7 | 96 | 30-120min | .selfPlay, .benchmark |
| AI 搜索相关 | 5 | 88 | 5-15min | .slow, .integration |
| UI 测试 | 3 | 40 | 2-5min | .ui, .integration |
| 快速单元测试 | 134 | 875 | 3-8min | .unit |

## 实施步骤

1. Alex 设计 Tag 体系和 SelfPlayConfig 降配方案 → Vera 审查
2. Cody 实施标签 + 超时 + 脚本 → Ruby 审查
3. Tina 用新脚本验证各模式 → 回归测试
4. 更新 TOOLS.md 的测试分批策略为标准流程

## 预期效果

- `quick` 模式：<2min，Tina 每次 Phase 专用
- `full` 模式：<15min，Phase 完成后回归
- 不再出现测试卡住导致 agent 被 kill
- 残留进程问题通过守护脚本消除
