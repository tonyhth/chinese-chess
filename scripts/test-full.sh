#!/bin/bash
# test-full.sh — 中国象棋分批测试入口（Intel Mac 安全版）
# 用法：bash scripts/test-full.sh [quick|full|all] [--skip-elo] [--destination ...]
#   quick    — 只跑轻量单元测试（<5min），适合开发时验证
#   full     — 跑轻量+中速，跳过 SelfPlay/Elo（<15min），适合 Phase 交付前
#   all      — 全部三批，含 Elo 自对弈（30-120min），仅后台使用
#   --skip-elo  跳过 Elo baseline（all 模式下生效）
#
# 架构：build-for-testing + test-without-building（一次编译，多次测试）
# 项目已迁移到 xcodegen + xcodebuild，禁止使用 swift test（无 Package.swift）

set -euo pipefail

# ── 配置 ──
PROJECT_DIR=~/DevTeam/projects/chinese-chess
SCHEME=ChineseChess
DESTINATION="platform=macOS,arch=x86_64"
BUILD_DIR="$PROJECT_DIR/.build-test-cache"

# ── 测试分类 ──
# 重型 suite：Batch 1 必须跳过，Batch 2/3 单独跑
HEAVY_SUITES=(
  EloBaselineTests
  Phase3aSearchOptimizationTests
  Phase3bLMRTimeManagementTests
  AIEngineImprovementTests
  P1aRegressionTests
  P1CompleteChallengeTests
  PikafishCAPITests
  Phase3bEvaluationTests
  Phase3aEvaluationTests
)

# SelfPlay 对弈 suite（单局 30+ 分钟，必定卡住全量测试）
SELFPLAY_SUITES=(
  EloBaselineTests
)

# Batch 2：AI 搜索测试（重型但非 Elo 自对弈，5-15min）
BATCH2_SUITES=(
  Phase3aSearchOptimizationTests
  Phase3bLMRTimeManagementTests
  AIEngineImprovementTests
  P1aRegressionTests
  P1CompleteChallengeTests
  PikafishCAPITests
  Phase3bEvaluationTests
  Phase3aEvaluationTests
)

# Batch 3：Elo baseline（30-120min，仅后台）
BATCH3_SUITES=(
  EloBaselineTests
)

# ── 参数解析 ──
MODE="quick"
SKIP_ELO=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    quick|full|all) MODE="$1"; shift ;;
    --skip-elo) SKIP_ELO=true; shift ;;
    --destination) DESTINATION="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ── 工具函数 ──

# 递归杀进程树（比 pkill 更可靠，防止子进程残留锁住 DerivedData）
kill_tree() {
  local pid=$1
  local children
  children=$(pgrep -P "$pid" 2>/dev/null || true)
  for child in $children; do
    kill_tree "$child"
  done
  kill -9 "$pid" 2>/dev/null || true
}

# 清理残留的 xcodebuild/xctest 进程
cleanup_processes() {
  echo "  🧹 清理残留进程..."
  # 查找所有相关 xcodebuild/xctest 进程
  local pids
  pids=$(pgrep -f 'xcodebuild.*ChineseChess' 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      kill_tree "$pid"
    done
  fi
  pids=$(pgrep -f 'xctest.*ChineseChess' 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      kill_tree "$pid"
    done
  fi
  sleep 2
  # 确认清理完成
  local remaining
  remaining=$(pgrep -f 'xcodebuild.*ChineseChess|xctest.*ChineseChess' 2>/dev/null || true)
  if [[ -n "$remaining" ]]; then
    echo "  ⚠️  仍有残留进程: $remaining"
  fi
}

# 从 xcodebuild 输出提取 pass/fail 计数
parse_results() {
  local output="$1"
  local batch_name="$2"
  local passed=0 failed=0

  # Swift Testing 格式: "Test run with N test cases passed" or "N test(s) passed"
  local p f
  p=$(echo "$output" | grep -oE '[0-9]+ test[s]? passed' | grep -oE '[0-9]+' | tail -1 || echo "")
  f=$(echo "$output" | grep -oE '[0-9]+ test[s]? failed' | grep -oE '[0-9]+' | tail -1 || echo "")
  [[ -n "$p" ]] && passed=$p
  [[ -n "$f" ]] && failed=$f

  # 也检查 XCTest 格式: Executed N tests, with M failures
  if [[ "$passed" -eq 0 && "$failed" -eq 0 ]]; then
    p=$(echo "$output" | grep -oE 'Executed [0-9]+ test' | grep -oE '[0-9]+' | tail -1 || echo "")
    f=$(echo "$output" | grep -oE 'with [0-9]+ failure' | grep -oE '[0-9]+' | tail -1 || echo "")
    [[ -n "$p" ]] && passed=$p
    [[ -n "$f" ]] && failed=$f
  fi

  if [[ "$passed" -eq 0 && "$failed" -eq 0 ]]; then
    # 最后尝试：检查 TEST SUCCEEDED / TEST FAILED
    if echo "$output" | grep -q "TEST SUCCEEDED"; then
      echo "  📊 $batch_name: ✅ TEST SUCCEEDED（未解析具体计数）"
      BATCH_PASSED=$((BATCH_PASSED + 1))
      return 0
    fi
    echo "  ⚠️  $batch_name: 无法解析测试结果"
    BATCH_FAILED=$((BATCH_FAILED + 1))
    return 1
  fi

  echo "  📊 $batch_name: ✅ $passed passed, ❌ $failed failed"
  BATCH_PASSED=$((BATCH_PASSED + passed))
  BATCH_FAILED=$((BATCH_FAILED + failed))
}

# 运行测试（使用 test-without-building，前提是已经 build-for-testing）
run_test_without_building() {
  local batch_name="$1"
  shift
  local args=("$@")

  echo ""
  echo "━━━ $batch_name ━━━"
  echo "  开始: $(date '+%H:%M:%S')"

  local output
  local rc=0
  output=$(cd "$PROJECT_DIR" && xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    "${args[@]}" \
    -resultBundlePath "$BUILD_DIR/results" \
    2>&1) || rc=$?

  echo "  结束: $(date '+%H:%M:%S')"

  if [[ $rc -ne 0 ]]; then
    if echo "$output" | grep -q "failed\|failure\|TEST FAILED"; then
      parse_results "$output" "$batch_name"
      echo "  ⚠️  $batch_name 有测试失败"
    else
      echo "  💥 $batch_name 运行出错 (exit $rc)"
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

# ── Step 0: 预处理 ──
echo "═══════════════════════════════════════════"
echo "  中国象棋分批测试"
echo "  模式: $MODE | skip-elo: $SKIP_ELO | destination: $DESTINATION"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════"
echo ""

# 清理残留进程
cleanup_processes

# xcodegen 生成项目
echo "🔨 xcodegen generate..."
cd "$PROJECT_DIR" && xcodegen generate

# ── Step 1: 编译（build-for-testing） ──
echo ""
echo "🔨 build-for-testing（一次编译，后续多次测试复用）..."
BUILD_RC=0
xcodebuild build-for-testing \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -resultBundlePath "$BUILD_DIR/build" \
  2>&1 | tail -5 || BUILD_RC=$?

if [[ $BUILD_RC -ne 0 ]]; then
  echo ""
  echo "💥 build-for-testing 失败！请先修复编译错误。"
  echo "   提示：cd $PROJECT_DIR && xcodebuild build-for-testing -scheme ChineseChess -destination 'platform=macOS' 2>&1 | grep 'error:'"
  cleanup_processes
  exit 1
fi

echo "✅ 编译成功，开始分批测试..."
echo ""

# ── Batch 1: 轻量单元测试（跳过所有重型 suite） ──
run_batch1() {
  BATCH_PASSED=0; BATCH_FAILED=0

  local skip_args=()
  for suite in "${HEAVY_SUITES[@]}"; do
    skip_args+=(-skip-testing:"ChineseChessTests/$suite")
  done

  run_test_without_building "Batch 1: 轻量单元测试" "${skip_args[@]}"

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

  run_test_without_building "Batch 2: AI 搜索测试" "${only_args[@]}"

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

  run_test_without_building "Batch 3: Elo baseline（⚠️ 预计 30-120 分钟）" "${only_args[@]}"

  TOTAL_PASSED=$((TOTAL_PASSED + BATCH_PASSED))
  TOTAL_FAILED=$((TOTAL_FAILED + BATCH_FAILED))
  echo ""
  echo "Batch 3 摘要: ✅ $BATCH_PASSED passed / ❌ $BATCH_FAILED failed"
  cleanup_processes
}

# ── 按模式执行 ──
case "$MODE" in
  quick)
    run_batch1
    ;;
  full)
    run_batch1
    run_batch2
    ;;
  all)
    run_batch1
    run_batch2
    run_batch3
    ;;
esac

# ── 最终汇总 ──
echo ""
echo "═══════════════════════════════════════════"
echo "  测试最终汇总"
echo "  模式: $MODE"
echo "  ✅ Passed: $TOTAL_PASSED"
echo "  ❌ Failed: $TOTAL_FAILED"
echo "═══════════════════════════════════════════"

# 最终清理
cleanup_processes

if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo "🔴 有测试失败！"
  exit 1
else
  echo "🟢 全部通过！"
  exit 0
fi
