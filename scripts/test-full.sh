#!/bin/bash
# test-full.sh — 分批串行全量回归测试（Intel Mac 安全版）
# 用法：./scripts/test-full.sh [batch1|batch2|batch3|all] [--skip-elo] [--destination ...]
# 默认 all，--skip-elo 跳过 Batch 3

set -euo pipefail

# ── 配置 ──
PROJECT_DIR=~/DevTeam/projects/chinese-chess
SCHEME=ChineseChess
DESTINATION="platform=macOS,arch=x86_64"

# 重型测试套（Batch 1 须 skip，Batch 2/3 按需 only-testing）
HEAVY_SUITES=(
  EloBaselineTests
  Phase3aSearchOptimizationTests
  Phase3bLMRTimeManagementTests
  AIEngineImprovementTests
  P1aRegressionTests
  P1CompleteChallengeTests
  PikafishCAPITests
)

# Batch 2：AI 搜索测试（重型但非 Elo 自对弈）
BATCH2_SUITES=(
  Phase3aSearchOptimizationTests
  Phase3bLMRTimeManagementTests
  AIEngineImprovementTests
  P1aRegressionTests
  P1CompleteChallengeTests
  PikafishCAPITests
)

# Batch 3：Elo baseline
BATCH3_SUITES=(
  EloBaselineTests
)

# ── 参数解析 ──
BATCH="all"
SKIP_ELO=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    batch1|batch2|batch3|all) BATCH="$1"; shift ;;
    --skip-elo) SKIP_ELO=true; shift ;;
    --destination) DESTINATION="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ── 工具函数 ──
cleanup_processes() {
  echo "  🧹 清理残留进程..."
  # 只清理当前项目的 xctest 进程，避免误杀其他项目
  pkill -f "xctest.*ChineseChess" 2>/dev/null || true
  sleep 2
}

# 从 xcodebuild 输出提取 pass/fail 计数
parse_results() {
  local output="$1"
  local batch_name="$2"
  local passed failed

  # Swift Testing 格式: "Test run with N test cases passed" or "failed"
  passed=$(echo "$output" | grep -oE '[0-9]+ test[s]? passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
  failed=$(echo "$output" | grep -oE '[0-9]+ test[s]? failed' | grep -oE '[0-9]+' | tail -1 || echo "0")

  # 也检查 XCTest 格式: Executed N tests, with M failures
  if [[ "$passed" == "0" && "$failed" == "0" ]]; then
    passed=$(echo "$output" | grep -oE 'Executed [0-9]+ test' | grep -oE '[0-9]+' | tail -1 || echo "0")
    failed=$(echo "$output" | grep -oE 'with [0-9]+ failure' | grep -oE '[0-9]+' | tail -1 || echo "0")
  fi

  if [[ "$passed" == "0" && "$failed" == "0" ]]; then
    echo "  ⚠️  $batch_name: 无法解析测试结果（输出格式不匹配）"
    BATCH_FAILED=$((BATCH_FAILED + 1))
    return 1
  fi

  echo "  📊 $batch_name: ✅ $passed passed, ❌ $failed failed"
  BATCH_PASSED=$((BATCH_PASSED + passed))
  BATCH_FAILED=$((BATCH_FAILED + failed))
}

run_xcodebuild() {
  local batch_name="$1"
  shift
  local args=("$@")

  echo ""
  echo "━━━ $batch_name ━━━"
  echo "  命令: xcodebuild test ${args[*]}"
  echo "  开始: $(date '+%H:%M:%S')"

  local output
  local rc=0
  output=$(cd "$PROJECT_DIR" && xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    "${args[@]}" \
    2>&1) || rc=$?

  echo "  结束: $(date '+%H:%M:%S')"

  if [[ $rc -ne 0 ]]; then
    # 检查是否是测试失败（不是编译/其他错误）
    if echo "$output" | grep -q "failed\|failure"; then
      parse_results "$output" "$batch_name"
      echo "  ⚠️  $batch_name 有测试失败"
    else
      echo "  💥 $batch_name 构建或运行出错 (exit $rc)"
      echo "$output" | tail -20
      BATCH_FAILED=$((BATCH_FAILED + 1))
    fi
  else
    parse_results "$output" "$batch_name"
    echo "  ✅ $batch_name 通过"
  fi
}

# ── 初始化计数 ──
TOTAL_PASSED=0
TOTAL_FAILED=0
BATCH_PASSED=0
BATCH_FAILED=0

# ── Step 0: xcodegen ──
echo "=== 全量回归测试 ==="
echo "模式: $BATCH | skip-elo: $SKIP_ELO | destination: $DESTINATION"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "🔨 xcodegen generate..."
cd "$PROJECT_DIR" && xcodegen generate

# ── Batch 1: 轻量单元测试 ──
run_batch1() {
  BATCH_PASSED=0; BATCH_FAILED=0

  # 构建 skip-testing 参数
  local skip_args=()
  for suite in "${HEAVY_SUITES[@]}"; do
    skip_args+=(-skip-testing:"ChineseChessTests/$suite")
  done

  run_xcodebuild "Batch 1: 轻量单元测试" "${skip_args[@]}"

  TOTAL_PASSED=$((TOTAL_PASSED + BATCH_PASSED))
  TOTAL_FAILED=$((TOTAL_FAILED + BATCH_FAILED))
  echo ""
  echo "Batch 1 摘要: ✅ $BATCH_PASSED passed / ❌ $BATCH_FAILED failed"
  cleanup_processes
}

# ── Batch 2: AI 搜索测试 ──
run_batch2() {
  BATCH_PASSED=0; BATCH_FAILED=0

  local only_args=()
  for suite in "${BATCH2_SUITES[@]}"; do
    only_args+=(-only-testing:"ChineseChessTests/$suite")
  done

  run_xcodebuild "Batch 2: AI 搜索测试" "${only_args[@]}"

  TOTAL_PASSED=$((TOTAL_PASSED + BATCH_PASSED))
  TOTAL_FAILED=$((TOTAL_FAILED + BATCH_FAILED))
  echo ""
  echo "Batch 2 摘要: ✅ $BATCH_PASSED passed / ❌ $BATCH_FAILED failed"
  cleanup_processes
}

# ── Batch 3: Elo baseline ──
run_batch3() {
  BATCH_PASSED=0; BATCH_FAILED=0

  if $SKIP_ELO; then
    echo ""
    echo "⏭️  Batch 3: Elo baseline — 已跳过 (--skip-elo)"
    return
  fi

  local only_args=()
  for suite in "${BATCH3_SUITES[@]}"; do
    only_args+=(-only-testing:"ChineseChessTests/$suite")
  done

  run_xcodebuild "Batch 3: Elo baseline" "${only_args[@]}"

  TOTAL_PASSED=$((TOTAL_PASSED + BATCH_PASSED))
  TOTAL_FAILED=$((TOTAL_FAILED + BATCH_FAILED))
  echo ""
  echo "Batch 3 摘要: ✅ $BATCH_PASSED passed / ❌ $BATCH_FAILED failed"
  cleanup_processes
}

# ── 执行 ──
case "$BATCH" in
  batch1) run_batch1 ;;
  batch2) run_batch2 ;;
  batch3) run_batch3 ;;
  all)
    run_batch1
    run_batch2
    run_batch3
    ;;
esac

# ── 最终汇总 ──
echo ""
echo "═══════════════════════════════════════════"
echo "  全量回归测试最终汇总"
echo "  ✅ Passed: $TOTAL_PASSED"
echo "  ❌ Failed: $TOTAL_FAILED"
echo "═══════════════════════════════════════════"

if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo "🔴 有测试失败！"
  exit 1
else
  echo "🟢 全部通过！"
  exit 0
fi
