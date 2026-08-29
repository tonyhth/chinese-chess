#!/bin/bash
# run-tests-mutex.sh — v6.3 H-1 统一互斥测试起跑器（Tina）
#
# 用法：
#   bash scripts/run-tests-mutex.sh <Suite1> [Suite2 ...]   # 每 suite 独立 xcodebuild 进程，全局互斥排队
#   bash scripts/run-tests-mutex.sh --h1-verify              # H-1 验证批：四 suite 混跑（L10n 敏感组）
#   bash scripts/run-tests-mutex.sh --full                   # r 系全量批：skip 单源消费即过滤器，总对账门禁
#
# 机制（v6.3-plan §2 Step 1 首选 a，Luke 08-29 派单）：
#   1. flock 进程互斥：锁文件固定路径 ~/DevTeam/.locks/xcode-tests.lock，
#      所有 suite 起跑前抢锁，抢不到即排队（正式测试批与 r 系长跑基线互斥起跑，08-29 Luke 口径）
#   2. 全局语言锁：注入 AppleLanguages=(zh-Hans)，一处定义全员复用
#      （根因：部分 i18n 用例 setLanguage 后不恢复 → UserDefaults "chinesechess.language"
#       跨 suite 污染；.serialized 不跨 suite，四 suite 混跑出"前1英文后4中文"假红指纹）
#   3. 每 suite 独立进程：跨 suite 状态不共享，从进程面消除竞态载体
#
# 铁律（DEVTEAM.md）：
#   - 绝不跑不带过滤的全量 xcodebuild test（EloBaselineTests 超时）
#   - 日志须对账 "Test run with N tests / Executed N tests" 才可宣告绿（静默零跑门规）
#   - skip 名单单源：docs/test/skip-registry.md（本脚本 --full 模式自动消费）
#
# 长跑规约：调用方如预计 >3 分钟，请以 nohup 脱离本脚本并固定日志路径，禁止盯进程。

set -uo pipefail

PROJECT=~/DevTeam/projects/chinese-chess
LOCK_DIR=~/DevTeam/.locks
LOCK_FILE="$LOCK_DIR/xcode-tests.lock"
DD=/tmp/xc-mutex-dd
LOG_DIR=~/DevTeam/workdirs/logs/h1
SKIP_REGISTRY="$PROJECT/docs/test/skip-registry.md"
EXIT_SUMMARY=()

mkdir -p "$LOCK_DIR" "$LOG_DIR"

# ---------- 语言锁：一处定义 ----------
inject_language_lock() {
  # 双通道注入：TEST_RUNNER_ 前缀（runner/宿主进程）+ 进程环境
  export TEST_RUNNER_AppleLanguages='(zh-Hans)'
  export AppleLanguages='(zh-Hans)'
  export TEST_RUNNER_AppleLocale='zh_CN'
}

# ---------- 从 skip-registry.md 提取常规 skip 名单 ----------
skip_args() {
  [ -f "$SKIP_REGISTRY" ] || return 0
  awk -F'|' '/^\| *[A-Za-z]/ && $3 ~ /skip/ {gsub(/ /,"",$2); print "-skip-testing:ChineseChessTests/" $2}' "$SKIP_REGISTRY"
}

# ---------- 语言锁：一处定义（机制 C，08-29 实证） ----------
# 实证链：TEST_RUNNER_/环境变量注入不生效（probe-a：UserDefaults 不读 env，读回系统值）；
# xcodebuild 命令行 -AppleLanguages 被拒（probe-b：invalid option）。
# 生效机制：批前写测试宿主 app defaults 域（com.chinesechess.app）AppleLanguages=zh-Hans，
# 批后 trap 恢复（未预设则删除）。宿主进程启动时从自身 defaults 域读到锁值。
BID=com.chinesechess.app
SAVED_LANGS_FILE="$LOCK_DIR/.h1-applelanguages-saved"
lock_language() {
  if defaults read "$BID" AppleLanguages >/dev/null 2>&1; then
    defaults read "$BID" AppleLanguages > "$SAVED_LANGS_FILE"
    H1_LANG_HAD_VALUE=1
    echo "[lang-lock] 预设存在，已备份 → $SAVED_LANGS_FILE"
  else
    H1_LANG_HAD_VALUE=0
    echo "[lang-lock] 原无预设"
  fi
  defaults write "$BID" AppleLanguages -array zh-Hans
  echo "[lang-lock] 已注入 AppleLanguages=(zh-Hans) → $BID"
}
unlock_language() {
  if [ "${H1_LANG_HAD_VALUE:-0}" = "1" ] && [ -f "$SAVED_LANGS_FILE" ]; then
    defaults write "$BID" AppleLanguages "$(cat "$SAVED_LANGS_FILE")"
    echo "[lang-lock] 已恢复原值"
  else
    defaults delete "$BID" AppleLanguages 2>/dev/null
    echo "[lang-lock] 原无预设，已删除注入"
  fi
}

# ---------- 单 suite 起跑（独立进程） ----------
run_suite() {
  local suite="$1"
  local log="$LOG_DIR/${suite}-$(date +%H%M%S).log"
  echo "▶ [$suite] 起跑 $(date '+%F %T')，日志 $log"
  ( cd "$PROJECT" && \
    bash ~/DevTeam/scripts/preflight-test-assets.sh "$PROJECT" >/dev/null || { echo "preflight 失败（资产缺失）"; exit 3; } ; \
    xcodebuild test -scheme ChineseChess -sdk macosx \
      -derivedDataPath "$DD" \
      $(skip_args) \
      -only-testing:"ChineseChessTests/$suite" 2>&1 | tee "$log" )
  local rc=${PIPESTATUS[0]:-$?}
  # 静默零跑门规（2026-08-29 Step2 终报批实证：filter 名不符 → Executed 0 tests 假绿）
  if ! grep -qE "Test run with [1-9][0-9]* test|Executed [1-9][0-9]* test" "$log" 2>/dev/null; then
    echo "❌ [$suite] 静默零跑：日志无 'N≥1 tests' 对账行（filter 名与实际 suite 名不符嫌疑），批次作废"
    EXIT_SUMMARY+=("FAIL(zero-run) $suite $log")
    return 5
  fi
  local n
  n=$(grep -cE "Executed [0-9]+ test" "$log" 2>/dev/null || true)
  if [ "$rc" -eq 0 ]; then
    echo "✅ [$suite] rc=0 $(date '+%T')"
    EXIT_SUMMARY+=("PASS $suite $log")
  else
    echo "❌ [$suite] rc=$rc $(date '+%T')"
    EXIT_SUMMARY+=("FAIL($rc) $suite $log")
  fi
  return $rc
}

# ---------- 主流程：抢锁 → 逐 suite 串行 ----------
main() {
  exec 9>"$LOCK_FILE"
  echo "⏳ [mutex] 等待测试锁 $LOCK_FILE $(date '+%F %T')"
  if ! flock -w 14400 9; then   # 最长排队 4h
    echo "❌ 抢锁超时（4h），放弃起跑"; exit 4
  fi
  echo "🔒 [mutex] 获得锁 $(date '+%F %T') (holder=$$)"
  trap 'unlock_language' EXIT
  lock_language   # 语言锁整批只加一次（每 suite 重复加锁会把注入值误当原值备份 → 批后残留）

  if [ "${1:-}" = "--h1-verify" ]; then
    shift
    SUITES=(SelectionConsistencyTests L10NDisplayNameV42Tests V223FixTests DifficultyV42Tests RunnerHygieneTests)
  elif [ "${1:-}" = "--full" ]; then
    # r 系全量批（08-29 Luke 放行）：skip 名单即过滤器（DEVTEAM 过滤铁律由 skip 单源满足）
    flog="$LOG_DIR/full-$(date +%H%M%S).log"
    echo "▶ [full] r 系全量批起跑 $(date '+%F %T')，日志 $flog"
    ( cd "$PROJECT" && \
      bash ~/DevTeam/scripts/preflight-test-assets.sh "$PROJECT" >/dev/null || { echo "preflight 失败"; exit 3; } ; \
      xcodebuild test -scheme ChineseChess -sdk macosx \
        -derivedDataPath "$DD" -parallel-testing-enabled NO \
        $(skip_args) 2>&1 | tee "$flog" )
    frc=${PIPESTATUS[0]:-$?}
    # 汇总对账门禁：总 Executed N>=500（r3g 冻结基线 623 量级），低于即批次作废
    ftotal=$(grep -oE "Executed [0-9]+ tests" "$flog" | tail -1 | grep -oE "[0-9]+" || echo 0)
    if [ "${ftotal:-0}" -lt 500 ]; then
      echo "❌ [full] 对账门禁：总 Executed=${ftotal} <500，批次作废"
      EXIT_SUMMARY+=("FAIL(zero-run total=${ftotal}) full $flog")
      echo "锁释放 $(date '+%F %T')"; exit 5
    fi
    if [ "$frc" -eq 0 ]; then echo "✅ [full] rc=0"; else echo "❌ [full] rc=$frc"; fi
    echo "[full] 总对账 Executed=${ftotal} tests $(date '+%T')"
    EXIT_SUMMARY+=("rc=$frc full total=${ftotal} $flog")
    echo "锁释放 $(date '+%F %T')"
    exit "$frc"
  else
    [ $# -ge 1 ] || { echo "用法: $0 <Suite...> | --h1-verify | --full"; exit 2; }
    SUITES=("$@")
  fi

  local overall=0
  for s in "${SUITES[@]}"; do
    run_suite "$s" || overall=1
  done

  echo ""; echo "═══════ H-1 runner 汇总 ═══════"
  for line in "${EXIT_SUMMARY[@]}"; do echo "  $line"; done
  echo "锁释放 $(date '+%F %T')"
  exit $overall
}

main "$@"
