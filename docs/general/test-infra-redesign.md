> ℹ️ v3 修订版（Vera 复查后定稿），初版见 test-infra-fix.md
# 测试基础设施修复方案 v3

> 中国象棋项目 · 测试分类 + 超时保护 + 进程守护
> 架构师：Alex · 2026-08-03 · v3（Vera 复查后定稿）

---

## 修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1 | 2026-08-03 | 初版 |
| v2 | 2026-08-03 | 回应 Vera 审查 4P0 + 6P1，架构重写 |
| v3 | 2026-08-03 | 回应 Vera 复查 N1-N6，定稿 |

### P0 回应摘要

| P0# | 问题 | 回应 | 方案变更 |
|-----|------|------|----------|
| P0-1 | Tag 过滤语法错误，项目已废弃 SPM | ✅ 同意。删除所有 `swift test` 命令示例 | §1.4 改为 xcodebuild + test-batch.sh 模式 |
| P0-2 | Tag 与硬编码 suite 列表两套体系必 drift | ✅ 同意。选方案 B：xcodebuild -skip-testing/-only-testing 为唯一运行时分类 | §1 Tag 降级为注释+文档，§3 基于 skip/only 列表 |
| P0-3 | xcodebuild 逐 suite 调用 = 85 次编译，致命 | ✅ 致命问题。改为**一次编译 + 一次 xcodebuild test**，用 -skip-testing 批量排除 | §3 架构重写：build once, test once |
| P0-4 | kill -- -pid 对 xcodebuild 子进程无效 | ✅ 同意。改用递归 pkill -P | §4 重写进程树清理 |

### P1 回应摘要

| P1# | 问题 | 回应 | 方案变更 |
|-----|------|------|----------|
| P1-1 | testDefaults 与 EloBaselineTests 矛盾 | ✅ 同意。testDefaults 只适用于 SelfPlayRunnerTests | §2.2 明确适用范围 |
| P1-2 | 混合文件拆分应提 Phase 1 | ✅ 同意。否则 ai 模式覆盖不全 | §6 调整分期 |
| P1-3 | 近期活跃 XCTest 应提 Phase 1 | ✅ 同意。B1/B2 相关文件优先迁移 | §6 调整分期 |
| P1-4 | 缺少 Phase 专项/失败重跑 | ✅ 同意。加 --suites 和 --retry-last | §3 增加 |
| P1-5 | SIGKILL 兜底不可靠 | ✅ 同意。加 xcodebuild 前置锁检测 | §4 增加 |
| P1-6 | Smoke/Unit 重叠 | ✅ 同意。smoke 独立验证用，不与后续模式组合 | §3 明确 |

### N1-N6 回应摘要（v3 新增）

| N# | 问题 | 回应 | 方案变更 |
|----|------|------|----------|
| N1 | standard/full 冗余 | ✅ 同意。删除 full 模式 | 模式从 5 个减为 4 个 |
| N2 | kill_tree 缺 SIGKILL 兜底 | ✅ 同意。加等待+SIGKILL+死亡确认 | §4.1 修订 |
| N3 | Phase 1 工作量被低估 | ✅ 同意。XCTest 迁移拆为非阻塞项 | §6 分 Phase 1a/1b |
| N4 | bash local 不在函数内 | ✅ 同意。改为 select_test_args 函数 | §3.3 修订 |
| N5 | --with-ai 文档与实现矛盾 | ✅ 同意。改文档匹配实现 | §1.2 修订 |
| N6 | 编译产物过期检测 | ✅ 同意。加 xcodeproj 时间戳检查 | §3.3 新增 |

---

## 0. 问题现状

| 指标 | 数值 |
|------|------|
| 测试文件 | 149 个（排除 .build/_archive） |
| @Test 方法 | 2,398 个（Swift Testing） |
| XCTest func test | 1,099 个 |
| 总测试方法 | **3,497 个** |
| SelfPlay 涉及文件 | 7 个（SelfPlayRunnerTests + 6 个含 SelfPlay 调用） |
| 每局 SelfPlay 耗时 | 30+ 分钟（hard/master 难度） |
| 当前 DerivedData 大小 | 744MB（实测，远超正常） |

**Tina 连续 3 次超时的根因链**：

```
全量 xcodebuild test（3,497 tests）
  → SelfPlay 测试开始运行（hard/master vs hard/master）
    → 单局 30+ 分钟
      → agent session 超时被 kill
        → xcodebuild/xctest 子进程残留
          → 锁住 DerivedData（实测 744MB 膨胀）
            → 下次编译卡住
```

---

## 1. 测试分类体系

### 1.1 设计决策：xcodebuild -skip-testing/-only-testing 为唯一运行时分类

**v1 方案的问题**：Tag 体系（Swift Testing）和 test-batch.sh 的硬编码 suite 列表是两套独立分类，必 drift。

**决策**：xcodebuild 的 `-skip-testing` / `-only-testing` 是唯一运行时分类。@Tag 作为代码内注释和未来 Swift Testing 原生过滤的预留，但不参与 test-batch.sh 的运行时逻辑。

**理由**：
1. 项目已废弃 SPM，`swift test --filter tag:` 不可用
2. xcodebuild 的 tag 过滤需要 Xcode 16.1+ test plan，配置复杂
3. `-skip-testing` / `-only-testing` 是 xcodebuild 原生能力，稳定可靠
4. Tag 和 suite 列表同步维护 = 人为错误风险，不如只用一套

### 1.2 分类定义

| 分类 | 运行策略 | 典型耗时 | 说明 |
|------|----------|----------|------|
| **light** | 默认运行 | <10min | unit + integration，排除重型 AI/SelfPlay |
| **heavy-ai** | `--with-ai` 才运行 | +15min | 含 bestMove/引擎搜索 |
| **selfplay** | `--selfplay` 才运行 | 1-2h | 完整对弈 |
| **ios** | iOS SDK 环境运行 | — | iOS 特有 |

三档而非七档。减少分类复杂度，降低维护成本。

### 1.3 Suite 分组列表

> 这是 test-batch.sh 的**唯一数据源**。新增测试文件时必须在此更新。

#### 默认跳过的重型 Suite（selfplay 组）

```bash
SELFPLAY_SUITES=(
    "SelfPlayRunnerTests"
    "EloBaselineTests"
    "Phase3DrawSelfPlayTests"      # 拆分后
    "Phase2bSelfPlayTests"         # 拆分后
    "Phase3aSelfPlayTests"         # 拆分后
    "Phase3bSelfPlayTests"         # 拆分后
    "Phase7SelfPlayTests"          # 拆分后
)
```

#### heavy-ai 组（light 模式跳过，--with-ai 模式运行）

```bash
HEAVY_AI_SUITES=(
    "AIEngineTests"
    "AIAdvancedTests"
    "AIEngineImprovementTests"
    "AIEngineP1bP2Tests"
    "EvalWeightsTests"
    "Phase2aSearchTests"
    "Phase2bTests"
    "Phase3aEvaluationTests"
    "Phase3aSearchOptimizationTests"
    "Phase3bEvaluationTests"
    "Phase3bLMRTimeManagementTests"
    "PikafishCAPITests"
    "PositionAnalyzerTests"
    "P1aRegressionTests"
    "P1CompleteChallengeTests"
    "R3R1FunctionalTests"
    "LazyOpeningBookTests"
    "Phase2bOptimizationTests"     # SelfPlay 拆分后，AI 部分留此
    "Phase3DrawTests"              # SelfPlay 拆分后，AI 部分留此
    "Phase7Tests"                  # SelfPlay 拆分后，AI 部分留此
)
```

#### light 组（默认运行 = 全部 - selfplay - heavy-ai）

light 组不需要显式列出。运行逻辑：`-skip-testing` 排除 selfplay + heavy-ai。

### 1.4 @Tag 的定位

@Tag 降级为**代码内文档注释**，不在运行时使用。但在每个 @Suite 上标注 tag 有两个价值：

1. **可读性**：新人看到 `@Suite("Board Tests", .tags(.unit))` 就知道这是快速单元测试
2. **未来兼容**：当 xcodebuild 支持 tag 过滤或项目恢复 SPM 时，可直接用 tag 驱动

```swift
// 定义（TestTags.swift）— 仅作文档，不参与运行时
extension Tag {
    static var unit: Tag { Tag("unit") }
    static var integration: Tag { Tag("integration") }
    static var ai: Tag { Tag("ai") }
    static var selfplay: Tag { Tag("selfplay") }
}

// 使用— 标注但不驱动运行
@Suite("Board Tests", .tags(.unit))
struct BoardTests { ... }
```

运行命令全部通过 test-batch.sh，不暴露 xcodebuild 细节：

```bash
bash scripts/test-batch.sh light          # 快速验证（<10min）
bash scripts/test-batch.sh standard       # light + heavy-ai（<25min）
bash scripts/test-batch.sh full           # 全部（排除 selfplay）（<30min）
bash scripts/test-batch.sh selfplay       # 只跑 selfplay（1-2h）
bash scripts/test-batch.sh smoke          # 3 个核心 suite（<1min）
bash scripts/test-batch.sh --suites BoardTests,MoveValidatorTests  # 指定 suite
bash scripts/test-batch.sh --retry-last   # 重跑上次失败的 suite
```

---

## 2. SelfPlay 测试超时保护方案

### 2.1 Swift Testing `.timeLimit` 保护

所有 SelfPlay 测试**必须**设置 `.timeLimit`：

```swift
@Suite("自对弈框架测试", .tags(.selfplay))
struct SelfPlayRunnerTests {

    @Test("快速对弈：beginner vs beginner 2局",
          .tags(.selfplay),
          .timeLimit(.minutes(5)))
    func quickSelfPlay() async { ... }

    @Test("先后手交换",
          .tags(.selfplay),
          .timeLimit(.minutes(5)))
    func sideSwap() async { ... }
}
```

**`.timeLimit` 推荐值**：

| 难度组合 | 局数 | .timeLimit | 理由 |
|----------|------|------------|------|
| beginner vs beginner | ≤2 局 | 5 min | 每局 ~30s |
| easy vs medium | 1 局 | 10 min | 每局 ~2min |
| medium vs hard | 1 局 | 15 min | 每局 ~5min |
| hard vs master | 1 局 | 30 min | 每局 ~15min |
| master vs master | 1 局 | 60 min | 每局 ~30min |

### 2.2 SelfPlayConfig.testDefaults 降配

**适用范围**：仅 `SelfPlayRunnerTests`。**不适用** `EloBaselineTests`。

```swift
extension SelfPlayConfig {
    /// 测试专用降配：验证框架逻辑（胜负统计、交换、判和），不验证 AI 强度
    /// ⚠️ 仅用于 SelfPlayRunnerTests，EloBaselineTests 需要真实难度
    static var testDefaults: SelfPlayConfig {
        SelfPlayConfig(
            red: .beginner,
            black: .beginner,
            games: 1,
            maxMoves: 30,
            swapSides: false
        )
    }
}
```

**EloBaselineTests 不降配的理由**：Elo 测量的目的就是比较不同难度 AI 的强度差异，降配后测量结果无意义。EloBaselineTests 通过 `-skip-testing` 跳过，仅在 `--selfplay` 模式下运行。

**降配效果**（仅 SelfPlayRunnerTests）：

| 参数 | 原值 | 降配值 | 单局耗时 |
|------|------|--------|----------|
| 难度 | beginner-hard | beginner | ~30s |
| 局数 | 2-4 | 1 | - |
| maxMoves | 40-200 | 30 | - |
| **总耗时估算** | **2-8min** | **<30s** | **10x+** |

### 2.3 EloBaselineTests 改造

```swift
// 移除 .disabled(if: SKIP_ELO)，改为 selfplay tag
@Suite("v3.0 Elo 基线测量", .tags(.selfplay), .serialized)
struct EloBaselineTests {
    // 保留原有逻辑不变，不使用 testDefaults
    @Test("easyVsMedium", .tags(.selfplay), .timeLimit(.minutes(10)))
    func easyVsMedium() async { ... }

    @Test("masterVsMaster", .tags(.selfplay), .timeLimit(.minutes(60)))
    func masterVsMaster() async { ... }
}
```

### 2.4 SelfPlay 混合文件拆分

以下 5 个文件既有普通 AI 测试又有 SelfPlay 对弈测试，**Phase 1 必须拆分**（P1-2）：

| 原文件 | 拆出文件 | 拆出依据 |
|--------|----------|----------|
| Phase3DrawTests.swift | Phase3DrawSelfPlayTests.swift | 含 `await SelfPlayRunner().run(config:)` 的方法 |
| Phase2bOptimizationTests.swift | Phase2bSelfPlayTests.swift | 含 SelfPlayRunner 的方法 |
| Phase3aEvaluationTests.swift | Phase3aSelfPlayTests.swift | 含 SelfPlayRunner 的方法 |
| Phase3bEvaluationTests.swift | Phase3bSelfPlayTests.swift | 含 SelfPlayRunner 的方法 |
| Phase7Tests.swift | Phase7SelfPlayTests.swift | 含 SelfPlayRunner 的方法 |

拆分后：
- 原文件保留非 SelfPlay 测试，归入 heavy-ai 组
- 新 SelfPlay 文件归入 selfplay 组
- 这样 `standard` 模式（light + heavy-ai）能覆盖这些 AI 测试

---

## 3. scripts/test-batch.sh 重设计

### 3.1 核心架构：Build Once, Test Once

**v1 的致命问题**：每个 suite 独立调 xcodebuild，85 次 × 编译 2-3min = 170+ min。

**v2 的架构**：

```
xcodegen generate          ← 生成 xcodeproj
    ↓
xcodebuild build-for-testing  ← 一次编译（8-10min Intel Mac）
    ↓
xcodebuild test-without-building  ← 一次测试调用
    + -skip-testing:SelfPlayRunnerTests,EloBaselineTests,...
    ↓
（按模式不同，skip 列表不同）
```

**关键 API**：

- `xcodebuild build-for-testing` — 只编译，不跑测试
- `xcodebuild test-without-building` — 只跑测试，不编译（使用上一步的编译产物）

这是 Xcode 的官方分步测试流程。编译一次，测试可以跑多轮不同子集，无需重复编译。

### 3.2 模式设计

| 模式 | 编译 | 测试范围 | 预计耗时（Intel Mac） |
|------|------|----------|----------------------|
| smoke | ✅ build-for-testing | 3 个核心 suite（-only-testing） | 编译 8min + 测试 <1min |
| light | ✅ build-for-testing | 全部 - selfplay - heavy-ai（-skip-testing） | 编译 8min + 测试 ~5min |
| standard | ✅ build-for-testing | 全部 - selfplay（-skip-testing） | 编译 8min + 测试 ~20min |
| selfplay | 复用编译 | selfplay suite（-only-testing） | 测试 1-2h |
| --suites A,B | ✅ 或复用 | 指定 suite（-only-testing） | 按需 |
| --retry-last | 复用编译 | 上次失败 suite（-only-testing） | 按需 |

> smoke/light/standard/full 都在同一编译产物上跑不同测试子集。只有 selfplay 和 --retry-last 可以复用已有编译。

### 3.3 脚本设计

```bash
#!/bin/bash
# test-batch.sh — 中国象棋项目统一测试入口（v2）
#
# 核心架构：build-for-testing → test-without-building
# 避免每个 suite 重复编译（v1 的致命问题）
#
# 用法：bash scripts/test-batch.sh <mode> [options]
#
# 模式:
#   smoke     — 3 个核心 suite，验证环境正常
#   light     — unit + integration，排除重型 AI/SelfPlay
#   standard  — light + heavy-ai，排除 SelfPlay
#   full      — 全部（排除 SelfPlay），交付前用
#   selfplay  — 只跑 SelfPlay，需长时间
#
# 选项:
#   --suites A,B,C       只跑指定 suite（逗号分隔）
#   --retry-last          重跑上次失败的 suite
#   --reuse-build         复用已有编译产物（跳过 build-for-testing）
#   --no-build            等同 --reuse-build
#   --timeout <sec>       整体测试超时（默认 1800s = 30min）
#   --verbose             显示完整 xcodebuild 输出
#   --cleanup             跑前清理残留进程 + DerivedData
#   --dry-run             只打印命令不执行

set -euo pipefail

# ── 配置 ──
PROJECT_DIR=~/DevTeam/projects/chinese-chess
SCHEME=ChineseChess
DESTINATION="platform=macOS,arch=x86_64"
RESULT_DIR="/tmp/chinesechess-test-results"
FAILED_FILE="$RESULT_DIR/last-failed-suites.txt"
BUILD_TIMEOUT=600    # 编译超时 10min
TEST_TIMEOUT=1800    # 测试超时 30min

# ── Suite 分组 ──
# 这是唯一的分类数据源。新增测试文件时必须更新。

SELFPLAY_SUITES=(
    "SelfPlayRunnerTests"
    "EloBaselineTests"
    # 以下为拆分后的 SelfPlay 文件，Phase 1 完成后取消注释：
    # "Phase3DrawSelfPlayTests"
    # "Phase2bSelfPlayTests"
    # "Phase3aSelfPlayTests"
    # "Phase3bSelfPlayTests"
    # "Phase7SelfPlayTests"
)

HEAVY_AI_SUITES=(
    "AIEngineTests"
    "AIAdvancedTests"
    "AIEngineImprovementTests"
    "AIEngineP1bP2Tests"
    "EvalWeightsTests"
    "Phase2aSearchTests"
    "Phase2bTests"
    "Phase2bOptimizationTests"         # SelfPlay 拆分后只含 AI 测试
    "Phase3aEvaluationTests"           # SelfPlay 拆分后只含 AI 测试
    "Phase3aSearchOptimizationTests"
    "Phase3bEvaluationTests"           # SelfPlay 拆分后只含 AI 测试
    "Phase3bLMRTimeManagementTests"
    "PikafishCAPITests"
    "PositionAnalyzerTests"
    "P1aRegressionTests"
    "P1CompleteChallengeTests"
    "R3R1FunctionalTests"
    "LazyOpeningBookTests"
    "Phase3DrawTests"                  # SelfPlay 拆分后只含 AI 测试
    "Phase7Tests"                      # SelfPlay 拆分后只含 AI 测试
)

SMOKE_SUITES=(
    "BoardTests"
    "MoveValidatorTests"
    "GameResultTests"
)

# ── 工具函数 ──

# 进程清理（递归杀子进程树）
cleanup_processes() {
    echo "  🧹 清理残留进程..."

    # 递归查找并杀 ChineseChess 测试相关进程
    # pkill -P 递归杀子进程（解决 P0-4：kill -- -pid 不可靠）
    local pids
    pids=$(pgrep -f "xcodebuild.*ChineseChess" 2>/dev/null || true)
    for pid in $pids; do
        # 递归杀子进程树
        kill_tree "$pid"
    done

    pkill -f "xctest.*ChineseChess" 2>/dev/null || true
    pkill -f "swiftpm-testing-helper" 2>/dev/null || true

    sleep 2
}

# 递归杀进程树（SIGTERM → 等待 3s → SIGKILL 兜底）
kill_tree() {
    local pid=$1
    # 先递归杀所有子进程
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        kill_tree "$child"
    done
    # 发 SIGTERM
    kill "$pid" 2>/dev/null || true
    # 等待进程退出，最多 3 秒
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 3 ]]; do
        sleep 1
        ((waited++))
    done
    # 如果还活着，SIGKILL
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi
}

# DerivedData 清理
cleanup_derived_data() {
    local total_size
    total_size=$(du -sm ~/Library/Developer/Xcode/DerivedData/ChineseChess-* 2>/dev/null \
        | awk '{sum+=$1} END {print sum+0}')

    # 阈值 500MB（实测正常编译 ~200-300MB，留余量，避免频繁误清）
    if [[ "${total_size:-0}" -gt 500 ]]; then
        echo "  🧹 DerivedData 膨胀 ${total_size}MB > 500MB，清理..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/ChineseChess-*
    fi
}

# 检测 DerivedData 锁（编译前前置检查）
check_derived_data_lock() {
    local locked
    locked=$(lsof +D ~/Library/Developer/Xcode/DerivedData/ChineseChess-* 2>/dev/null \
        | grep -c "xcodebuild\|xctest\|IBDesignablesAgent" || true)
    if [[ "$locked" -gt 0 ]]; then
        echo "  ⚠️  DerivedData 被锁（$locked 个进程），自动清理..."
        cleanup_processes
        sleep 3
        # 再检查一次
        locked=$(lsof +D ~/Library/Developer/Xcode/DerivedData/ChineseChess-* 2>/dev/null \
            | grep -c "xcodebuild\|xctest" || true)
        if [[ "$locked" -gt 0 ]]; then
            echo "  ❌ DerivedData 仍被锁，无法继续。请手动执行："
            echo "     bash scripts/test-batch.sh --cleanup"
            return 1
        fi
    fi
    return 0
}

# 构建 skip-testing 参数
build_skip_args() {
    local skip_suites=("$@")
    local args=()
    for suite in "${skip_suites[@]}"; do
        args+=(-skip-testing:"ChineseChessTests/$suite")
    done
    echo "${args[@]}"
}

# 构建 only-testing 参数
build_only_args() {
    local only_suites=("$@")
    local args=()
    for suite in "${only_suites[@]}"; do
        args+=(-only-testing:"ChineseChessTests/$suite")
    done
    echo "${args[@]}"
}

# 检测编译产物是否过期（对比 .xcodeproj 修改时间）
check_build_freshness() {
    local proj_dir="$PROJECT_DIR/ChineseChess.xcodeproj"
    if [[ ! -d "$proj_dir" ]]; then
        echo "  ⚠️  .xcodeproj 不存在，需要先 xcodegen generate"
        return 1
    fi
    local proj_mtime
    proj_mtime=$(stat -f %m "$proj_dir/project.pbxproj" 2>/dev/null || echo 0)
    # 找 DerivedData 中最新的构建产物
    local build_mtime=0
    for dd in ~/Library/Developer/Xcode/DerivedData/ChineseChess-*/Build; do
        if [[ -d "$dd" ]]; then
            local mtime
            mtime=$(stat -f %m "$dd" 2>/dev/null || echo 0)
            [[ "$mtime" -gt "$build_mtime" ]] && build_mtime=$mtime
        fi
    done
    if [[ "$proj_mtime" -gt "$build_mtime" ]] && [[ "$build_mtime" -gt 0 ]]; then
        echo "  ⚠️  编译产物可能过期（xcodeproj 比编译产物新）"
        echo "  建议：去掉 --reuse-build 重新编译"
        return 1
    fi
    return 0
}

# 模式选择（包装为函数，解决 bash local 语法问题）
select_test_args() {
    local mode="$1"
    TEST_ARGS=""

    case "$mode" in
        smoke)
            TEST_ARGS=$(build_only_args "${SMOKE_SUITES[@]}")
            echo "  模式: smoke（${#SMOKE_SUITES[@]} 个核心 suite）"
            ;;
        light)
            local skip=("${SELFPLAY_SUITES[@]}" "${HEAVY_AI_SUITES[@]}")
            TEST_ARGS=$(build_skip_args "${skip[@]}")
            echo "  模式: light（跳过 ${#skip[@]} 个重型 suite）"
            ;;
        standard)
            TEST_ARGS=$(build_skip_args "${SELFPLAY_SUITES[@]}")
            echo "  模式: standard（跳过 ${#SELFPLAY_SUITES[@]} 个 SelfPlay suite，含 AI）"
            ;;
        selfplay)
            TEST_ARGS=$(build_only_args "${SELFPLAY_SUITES[@]}")
            echo "  模式: selfplay（${#SELFPLAY_SUITES[@]} 个 SelfPlay suite）"
            TEST_TIMEOUT=7200
            ;;
    esac
}

# ── 参数解析 ──
MODE="standard"
CUSTOM_SUITES=""
RETRY_LAST=false
REUSE_BUILD=false
VERBOSE=false
DO_CLEANUP=false
DRY_RUN=false
TEST_TIMEOUT=1800

while [[ $# -gt 0 ]]; do
    case "$1" in
        smoke|light|standard|selfplay) MODE="$1"; shift ;;
        --suites) CUSTOM_SUITES="$2"; shift 2 ;;
        --retry-last) RETRY_LAST=true; shift ;;
        --reuse-build|--no-build) REUSE_BUILD=true; shift ;;
        --timeout) TEST_TIMEOUT="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --cleanup) DO_CLEANUP=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-elo) shift ;; # 兼容旧参数，忽略
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# ── 前置清理 ──
if $DO_CLEANUP; then
    cleanup_processes
    cleanup_derived_data
fi

# ── xcodegen ──
echo "🔨 xcodegen generate..."
cd "$PROJECT_DIR"
if ! $DRY_RUN; then
    xcodegen generate
fi

# ── 检测 DerivedData 锁 ──
if ! $REUSE_BUILD; then
    check_derived_data_lock || exit 1
else
    # --reuse-build 时检查编译产物是否过期
    if ! check_build_freshness; then
        echo "  继续使用旧编译产物...（如需重新编译请去掉 --reuse-build）"
    fi
fi

# ── Step 1: 编译 ──
mkdir -p "$RESULT_DIR"

if ! $REUSE_BUILD; then
    echo ""
    echo "━━━ Step 1: build-for-testing ━━━"
    echo "  开始: $(date '+%H:%M:%S')"
    echo "  超时: ${BUILD_TIMEOUT}s"

    BUILD_START=$(date +%s)

    if $DRY_RUN; then
        echo "  [DRY RUN] xcodebuild build-for-testing -scheme $SCHEME -destination '$DESTINATION'"
    else
        if ! timeout "$BUILD_TIMEOUT" xcodebuild build-for-testing \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            2>&1 | tail -5; then
            echo "  ❌ 编译失败"
            cleanup_processes
            exit 1
        fi
    fi

    BUILD_END=$(date +%s)
    echo "  结束: $(date '+%H:%M:%S')（$((BUILD_END - BUILD_START))s）"
fi

# ── Step 2: 测试 ──
echo ""
echo "━━━ Step 2: test-without-building ━━━"

# 根据模式确定测试参数
select_test_args "$MODE"
FAILED_SUITES=()

# --suites 覆盖
if [[ -n "$CUSTOM_SUITES" ]]; then
    IFS=',' read -ra suite_arr <<< "$CUSTOM_SUITES"
    TEST_ARGS=$(build_only_args "${suite_arr[@]}")
    echo "  模式: custom（${#suite_arr[@]} 个指定 suite）"
fi

# --retry-last
if $RETRY_LAST; then
    if [[ ! -f "$FAILED_FILE" ]]; then
        echo "  ⚠️  没有上次失败记录（$FAILED_FILE 不存在）"
        echo "  改为运行 smoke 模式"
        TEST_ARGS=$(build_only_args "${SMOKE_SUITES[@]}")
    else
        mapfile -t retry_suites < "$FAILED_FILE"
        # 去空行
        retry_suites=($(printf '%s\n' "${retry_suites[@]}" | sed '/^$/d'))
        if [[ ${#retry_suites[@]} -eq 0 ]]; then
            echo "  上次没有失败 suite，无需重跑"
            exit 0
        fi
        TEST_ARGS=$(build_only_args "${retry_suites[@]}")
        echo "  模式: retry-last（${#retry_suites[@]} 个失败 suite: ${retry_suites[*]}）"
    fi
    REUSE_BUILD=true  # 重跑肯定复用编译
fi

echo "  超时: ${TEST_TIMEOUT}s"
echo "  开始: $(date '+%H:%M:%S')"

TEST_START=$(date +%s)

# 运行测试
TEST_OUTPUT_FILE="$RESULT_DIR/test-output.txt"

if $DRY_RUN; then
    echo "  [DRY RUN] xcodebuild test-without-building -scheme $SCHEME $TEST_ARGS"
else
    if ! timeout "$TEST_TIMEOUT" xcodebuild test-without-building \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        $TEST_ARGS \
        2>&1 | tee "$TEST_OUTPUT_FILE"; then

        # 从输出提取失败 suite
        FAILED_SUITES=($(grep -oE 'Test suite .+failed' "$TEST_OUTPUT_FILE" \
            | grep -oE '"[^"]+"' | tr -d '"' | sort -u || true))

        # 记录失败 suite 供 --retry-last 使用
        printf '%s\n' "${FAILED_SUITES[@]}" > "$FAILED_FILE"
    fi
fi

TEST_END=$(date +%s)
echo "  结束: $(date '+%H:%M:%S')（$((TEST_END - TEST_START))s）"

# ── 后置清理 ──
cleanup_processes

# ── 结果汇总 ──
echo ""
echo "═══════════════════════════════════════════"

if $DRY_RUN; then
    echo "  [DRY RUN] 完成"
elif [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo "  ❌ 测试失败"
    echo "  失败 suite: ${FAILED_SUITES[*]}"
    echo "  重跑命令: bash scripts/test-batch.sh --retry-last --reuse-build"
    echo "═══════════════════════════════════════════"
    exit 1
else
    echo "  ✅ 测试通过"
    # 清空失败记录
    : > "$FAILED_FILE"
    echo "═══════════════════════════════════════════"
    exit 0
fi
```

### 3.4 smoke 与 light/standard 的关系

**smoke 独立使用**，不与 light/standard 组合。含义：
- smoke：验证编译和基本测试能跑通（CI 门槛、异常恢复后检查）
- light：日常开发验证
- standard：提交前验证

如果 Tina 先跑 smoke 再跑 light，BoardTests/MoveValidatorTests/GameResultTests 确实会跑两遍，但编译产物是复用的，测试本身 <30s，开销可忽略。

### 3.5 与现有脚本的关系

| 现有脚本 | 处置 | 理由 |
|----------|------|------|
| scripts/test-batch.sh | **备份为 test-batch.legacy.sh，然后替换** | P2-5 回滚方案 |
| scripts/test-full.sh | **备份为 test-full.legacy.sh** | 被 test-batch.sh full 替代 |
| scripts/test-runner.sh | **删除**（基于 SPM，项目已不用） | 无保留价值 |
| scripts/test-guard.sh | 不再单独文件，逻辑内联到 test-batch.sh | 简化部署 |

---

## 4. 进程守护方案

### 4.1 递归杀进程树

**v1 的问题**：`kill -- -pid` 发送负 PID 信号，前提是子进程与父同进程组。xcodebuild 启动的子进程通常创建新进程组，信号到不了。

**v2 的方案**：递归 `pgrep -P` + `kill`：

```bash
kill_tree() {
    local pid=$1
    # 先杀所有子进程（递归）
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        kill_tree "$child"
    done
    # 再杀自己
    kill "$pid" 2>/dev/null || true
}
```

### 4.2 DerivedData 锁检测

**问题**（P1-5）：agent 被 SIGKILL 后，残留进程锁住 DerivedData，下次编译就卡住，等不到 Tina 手动 `--cleanup`。

**方案**：在 `build-for-testing` 前自动检测锁：

```bash
check_derived_data_lock() {
    local locked
    locked=$(lsof +D ~/Library/Developer/Xcode/DerivedData/ChineseChess-* 2>/dev/null \
        | grep -c "xcodebuild\|xctest\|IBDesignablesAgent" || true)
    if [[ "$locked" -gt 0 ]]; then
        echo "  ⚠️  DerivedData 被锁（$locked 个进程），自动清理..."
        cleanup_processes
        # 再检查...
    fi
}
```

这样即使 Tina 直接跑 `xcodebuild build` 而非 test-batch.sh，也能在编译前发现问题。但更可靠的方式是把锁检测集成到 xcodebuild 的 pre-action script 中。

### 4.3 DerivedData 清理阈值

**v1 的 200MB 阈值没有实测依据**。当前实测 DerivedData = 744MB，但这是因为多次编译未清理。正常单次编译约 200-300MB。

**v2 阈值**：**500MB**。理由：
- 正常编译 ~200-300MB
- 连续编译 2-3 次不过 500MB
- 超过 500MB 说明有残留或膨胀，应该清理
- 阈值太高不清理会卡，太低频繁误清导致编译缓存失效

### 4.4 SIGKILL 兜底

trap 只能捕获 SIGTERM/INT/EXIT，SIGKILL 无法捕获。但 `build-for-testing` 前的 `check_derived_data_lock` 提供了第二层保护：即使上次被 SIGKILL，下次编译前也会检测并清理。

### 4.5 不再独立 test-guard.sh

进程守护逻辑内联到 test-batch.sh，不再独立文件。理由：
1. 简化部署，Tina 只需关心一个脚本
2. cleanup_processes / kill_tree / check_derived_data_lock 都是 test-batch.sh 的内部函数
3. 如需手动清理，用 `bash scripts/test-batch.sh --cleanup`

---

## 5. Tina AGENTS.md 更新建议

### 5.1 标准测试流程

```markdown
## 测试流程

### 收到测试任务后

1. **前置检查（首次/异常后）**
   ```bash
   bash scripts/test-batch.sh --cleanup smoke
   ```
   清理残留 + 验证环境。

2. **根据任务选择模式**

   | 任务类型 | 命令 | 预计耗时 |
   |----------|------|----------|
   | 环境检查 | `bash scripts/test-batch.sh smoke` | 编译 8min + 测试 <1min |
   | 日常验证 | `bash scripts/test-batch.sh light` | 编译 8min + 测试 ~5min |
   | 提交前 | `bash scripts/test-batch.sh standard` | 编译 8min + 测试 ~20min |
   | AI 改动 | `bash scripts/test-batch.sh standard` | 同上（standard 含 AI） |
   | 交付前 | `bash scripts/test-batch.sh standard` | 同上 |
   | 自对弈 | `bash scripts/test-batch.sh selfplay` | 1-2h |

3. **指定 suite**
   ```bash
   bash scripts/test-batch.sh --suites BoardTests,MoveValidatorTests
   ```

4. **失败重跑**（复用编译产物，不重新编译）
   ```bash
   bash scripts/test-batch.sh --retry-last --reuse-build
   ```
   ⚠️ 如果代码有改动，去掉 `--reuse-build` 重新编译。

5. **超时保护**
   - 脚本内置整体超时（light 30min, standard 30min, selfplay 2h）
   - SelfPlay 测试有 Swift Testing `.timeLimit` 兜底

6. **异常处理**
   - 编译失败 → 检查 DerivedData 锁 → 清理重试
   - 测试超时 → 自动清理进程 → 报告超时
   - 连续 2 次超时 → **停止重试，上报 Luke**

### ❌ 禁止事项

- **禁止** `swift test`（项目已废弃 SPM）
- **禁止** `xcodebuild test` 不带 `-only-testing` 或 `-skip-testing`
- **禁止** 全量测试不带超时保护
- **禁止** 连续超时 2 次后继续重试

### 测试失败报告格式

```
测试结果：
- 模式: standard
- 编译: 8min
- 测试: 18min
- ✅ 通过 / ❌ 失败 suite: BoardTests, Phase3Tests
- 重跑: bash scripts/test-batch.sh --retry-last --reuse-build
```
```

### 5.2 DEVTEAM.md 测试命令更新

```diff
- ## ⚠️ 测试命令（铁律）
- - **禁止全量 `xcodebuild test`**（不带过滤参数）— Intel Mac 必定超时
- - **必须用** `xcodebuild test -skip-testing:EloBaselineTests`
- - 专项测试：`xcodebuild test -only-testing:<TestClassName>`
- - EloBaselineTests 是自对弈 5 局 × 30+ 分钟，会锁死构建目录

+ ## ⚠️ 测试命令（铁律）
+ - **所有测试必须通过 `scripts/test-batch.sh`**，禁止直接调用 xcodebuild test
+ - **禁止全量测试不带超时保护**
+ - 模式选择：smoke → light → standard → full（递进）
+ - SelfPlay 测试已隔离，standard/full 模式自动跳过
+ - 失败重跑：`bash scripts/test-batch.sh --retry-last --reuse-build`
```

---

## 6. 实施分期

### Phase 1a：止血（1 天，核心路径）

| # | 事项 |
|---|------|
| 1 | **验证 build-for-testing 可行性**（xcodegen generate → build-for-testing → test-without-building），如不可用退化为“一次 xcodebuild test + -skip-testing” |
| 2 | 新建 `TestTags.swift` + 给 SelfPlay/重型 AI 文件加 @Tag |
| 3 | SelfPlayRunnerTests 加 `.timeLimit` |
| 4 | SelfPlayConfig.testDefaults 降配（仅 SelfPlayRunnerTests） |
| 5 | SelfPlay 混合文件拆分（5 个） |
| 6 | 替换 `scripts/test-batch.sh`（build-for-testing + test-without-building + select_test_args 函数） |
| 7 | 备份旧脚本为 `.legacy.sh` |
| 8 | 进程守护内联（kill_tree 递归 + SIGKILL 兜底 + DerivedData 锁检测） |
| 9 | 更新 DEVTEAM.md 测试命令 |
| 10 | 更新 Tina AGENTS.md 标准测试流程 |

### Phase 1b：完善（1 天，非阻塞，可与 Phase 1a 紧接或与 Cody 编码并行）

| # | 事项 |
|---|------|
| 11 | 近期活跃 XCTest → Swift Testing 迁移（8 个 B1/B2 文件） |
| 12 | test-batch.sh 编译产物过期检测（xcodeproj 时间戳对比） |

### Phase 2：分类完善（P1，后续 2-3 天）

1. 所有 149 个测试文件加 @Tag（逐文件标注）
2. 剩余 XCTest → Swift Testing 迁移（~22 个文件）
3. DerivedData 阈值实测校准
4. xcresulttool 结果解析替代 grep

### Phase 3：自动化（P2，后续）

1. CI/定时任务（夜间跑 selfplay）
2. test-batch.sh 输出 JSON 格式报告
3. DerivedData 监控告警（launchd agent）

---

## 7. 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| build-for-testing/test-without-building 在 xcodegen 项目中不可用 | 低 | 高 | 需 Phase 1 第一步验证；如不可用退化为一次 xcodebuild test + -skip-testing |
| SelfPlay 混合文件拆分引入回归 | 中 | 中 | 拆分后跑 full 模式验证 |
| DerivedData 锁检测误判 | 低 | 低 | 检测到锁后先自动清理再确认，不直接退出 |
| @Tag 在 XCTest 文件中不可用 | 确定 | 低 | Phase 1 迁移活跃文件，其余 Phase 2 |
| xcodebuild 输出格式变化导致结果解析失败 | 低 | 低 | 退化为 exit code 判断 + 手动检查 |
| test-batch.sh 复杂度过高 | 中 | 中 | 充分测试 + legacy 脚本保留做回滚 |

### 回滚方案

如 Phase 1 部署后发现问题：
1. `mv scripts/test-batch.legacy.sh scripts/test-batch.sh` 恢复旧脚本
2. `mv scripts/test-full.legacy.sh scripts/test-full.sh` 恢复旧脚本
3. DEVTEAM.md 测试命令恢复为 `-skip-testing:EloBaselineTests`
4. @Tag 和 .timeLimit 无副作用，无需回滚

---

## 附录 A：SelfPlay 混合文件拆分细则

拆分原则：
1. 含 `await SelfPlayRunner().run(config:)` 或 `await runner.run(config:)` 的测试方法 → 移入 SelfPlay 文件
2. 只含 `engine.bestMove(for:difficulty:)` 的测试方法 → 保留在原文件
3. 拆出文件继承原文件的 import 和 @testable

| 原文件 | @Test 总数 | SelfPlay 测试数 | 拆出文件 | 迁移后 tag |
|--------|-----------|-----------------|----------|-----------|
| SelfPlayRunnerTests.swift | 11 | 11 | 不拆（已是纯 SelfPlay） | selfplay |
| EloBaselineTests.swift | 4 | 4 | 不拆（已是纯 SelfPlay） | selfplay |
| Phase3DrawTests.swift | 21 | ~3 | Phase3DrawSelfPlayTests.swift | 原→ai，新→selfplay |
| Phase2bOptimizationTests.swift | 17 | ~2 | Phase2bSelfPlayTests.swift | 原→ai，新→selfplay |
| Phase3aEvaluationTests.swift | 22 | ~5 | Phase3aSelfPlayTests.swift | 原→ai，新→selfplay |
| Phase3bEvaluationTests.swift | 11 | ~2 | Phase3bSelfPlayTests.swift | 原→ai，新→selfplay |
| Phase7Tests.swift | 14 | ~1 | Phase7SelfPlayTests.swift | 原→ai，新→selfplay |

## 附录 B：近期活跃 XCTest 迁移清单

这些文件在 B1/B2 Phase 中新增，Tina 日常需要，Phase 1 优先迁移：

```
PhaseB1Step1Tests.swift          PhaseB1Step2Tests.swift
PhaseB1Step4_5Tests.swift        PhaseB2Step2ReviewTests.swift
PhaseA1CategoryMenuTests.swift   PhaseA2TacticalGroupTests.swift
UnifiedSheetTests.swift          PuzzleDemoViewEntryTests.swift
```

迁移方式：XCTestCase → Swift Testing @Suite/@Test，保持测试逻辑不变。

## 附录 C：build-for-testing / test-without-building 参考

Xcode 8+ 支持的分步测试流程：

```bash
# Step 1: 编译测试目标（不运行）
xcodebuild build-for-testing \
    -scheme ChineseChess \
    -destination "platform=macOS,arch=x86_64"

# Step 2: 运行测试（不编译，使用 Step 1 的产物）
xcodebuild test-without-building \
    -scheme ChineseChess \
    -destination "platform=macOS,arch=x86_64" \
    -skip-testing:ChineseChessTests/EloBaselineTests \
    -skip-testing:ChineseChessTests/SelfPlayRunnerTests
```

优势：
- 编译一次，测试可跑多轮不同子集
- 编译和测试可分开设置超时
- 测试失败后 `--retry-last` 无需重新编译
