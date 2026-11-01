#!/bin/bash
# run-tests-mutex.sh — v6.3 H-1 统一互斥测试起跑器（Tina）
#
# 用法：
#   bash scripts/run-tests-mutex.sh <Suite1> [Suite2 ...]   # 每 suite 独立 xcodebuild 进程，全局互斥排队
#   bash scripts/run-tests-mutex.sh --h1-verify              # H-1 验证批：四 suite 混跑（L10n 敏感组）
#   bash scripts/run-tests-mutex.sh --full                   # r 系全量批：skip 单源消费即过滤器，总对账门禁
#   bash scripts/run-tests-mutex.sh --check-sandbox         # 沙箱守卫自检：只检测不跑批（exit 0 放行 / 3 拒）
#
# 沙箱守卫（KI-2026-0913-01 落地，Luke 2026-09-16 批准）：
#   代理会话沙箱会阻断测试宿主建连（hung before establishing connection）。
#   检测到代理会话环境（OPENCLAW_*）即默认拒起跑；唯一放行通道
#   RUNTESTS_SANDBOX_EXEMPT=1（人工确认 Sandbox bypassed 横幅后设置）。
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

# PATH 健壮化（v6.4 P1④，Tina 09 实证）：flock 装在 /usr/local/bin（Intel Homebrew），
# 非交互 shell 默认 PATH 不含 → 首跑抢锁 4h 超时。前置补全两处 Homebrew bin。
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

# T-1101-7 R1 根修（bash 3.2 多字节变量名吞雷）：LC_ALL=C 强制字节序名扫描——
# python3 spawn 的子进程带 LC_CTYPE=C.UTF-8（python locale 强制），bash 3.2 在 UTF-8 locale 下
# 把 $VAR 后紧跟的全角字符吞进变量名（$WAKE_RC）→ set -u unbound 静默杀脚本（v1-v6 五轮法证钉死）。
# LC_ALL 优先级压倒一切继承 locale；中文输出字符串按原始字节透传不受影响。
export LC_ALL=C

# ---------- T-1101-1 件3 P3-2（Ruby 审查建议）：GameRecordStore 测试底座重定向，默认双通道注入 ----------
# 取证：测试宿主 GameRecordStore.shared init 枚举 ~/Documents/GameRecords（TCC 保护域）；
# agent-session/脱离上下文丢归因 → open() 内核态停滞（sample 栈 __open 100%），挂所有触碰 .shared 的套件。
# /tmp 在 TCC 盲区外 0s 实证。DEBUG 缝（GameRecordStore.swift）消费 GAMERECORDSTORE_BASEURL；
# 调用方预设 env 优先（:- 不覆盖）。
export TEST_RUNNER_GAMERECORDSTORE_BASEURL="${TEST_RUNNER_GAMERECORDSTORE_BASEURL:-/tmp/chinesechess-test-gamerecords}"
export GAMERECORDSTORE_BASEURL="${GAMERECORDSTORE_BASEURL:-/tmp/chinesechess-test-gamerecords}"

# ---------- 沙箱守卫（KI-2026-0913-01，Luke 2026-09-16 批准“防呆不防贼”） ----------
# 根因：代理会话沙箱随进程树继承到测试宿主，宿主回连 xctest 的文件/Mach 操作被拒
# → 7m20s+ hung（四象限唯“前台+豁免获批”绿，后台豁免不继承）。
# 检测特征实测（Cody 09-16）：shell 层无可靠 seatbelt 签名（~/.swiftpm 写探针无区分度），
# 代理会话 env 标记（OPENCLAW_*）是可得的最强信号——沙箱内外同带，故默认拒为安全侧。
sandbox_guard() {
  if [ "${RUNTESTS_SANDBOX_EXEMPT:-0}" = "1" ]; then
    echo "[sandbox-guard] 白名单放行（RUNTESTS_SANDBOX_EXEMPT=1，豁免横幅已人工确认）"
    return 0
  fi
  if [ -n "${OPENCLAW_SERVICE_MARKER:-}" ] || [ -n "${OPENCLAW_GATEWAY_PORT:-}" ]; then
    echo "❌ [sandbox-guard] 检测到代理会话环境（OPENCLAW_*），拒起跑——KI-2026-0913-01："
    echo "   代理沙箱阻断测试宿主建连（hung before establishing connection，四象限唯前台+豁免获批绿）。"
    echo "   走沙箱外/前台+豁免通道（确认 Sandbox bypassed 横幅后）：RUNTESTS_SANDBOX_EXEMPT=1 再起跑。"
    return 3
  fi
  echo "[sandbox-guard] 未检测到代理会话标记，放行"
  return 0
}

case "${1:-}" in
  --check-sandbox)
    sandbox_guard
    rc=$?
    [ $rc -eq 0 ] && echo "[sandbox-guard] 自检结论：可跑" || echo "[sandbox-guard] 自检结论：拒起跑(rc=$rc)"
    exit $rc
    ;;
esac

sandbox_guard || exit $?

# PROJECT 改脚本位置推导（Luke 2026-09-18 18:17 裁定）：主仓行为零变更（推导结果即原绝对路径），
# worktree 副本起跑指向 worktree 工程；推导失败显式报错退出——禁止回退硬编码路径（09-17 坑根源）。
PROJECT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel) || {
    echo "[run-tests-mutex] PROJECT 推导失败（脚本脱离 git 仓）——拒绝回退硬编码路径，退出" >&2
    exit 9
}
LOCK_DIR=~/DevTeam/.locks
LOCK_FILE="$LOCK_DIR/xcode-tests.lock"
DD=/tmp/xc-mutex-dd
# 超时方案①（Luke 2026-08-30 采纳）：外层 timeout 防挂起无限占锁（os_log 类）。默认 1800s，env 可覆盖（自证用）
RUNNER_TIMEOUT="${RUNNER_TIMEOUT:-1800}"
LOG_DIR=~/DevTeam/workdirs/logs/h1
SKIP_REGISTRY="$PROJECT/docs/test/skip-registry.md"
EXIT_SUMMARY=()

mkdir -p "$LOCK_DIR" "$LOG_DIR"

# ---------- T-1101-7 R3：自剥离守护（RUNNER_SURVIVE=1）----------
# 11-01 实证：flock 排队/在跑进程随调用方进程组树被杀（Ruby 复跑排队死、/tmp 日志 0 字节）。
# 开启后 python3 setsid 重执行自身：转后台（新会话脱离进程组）、输出投固定日志、
# 免疫父树连坐；调用方立即拿 rc=0，完结态由 R1 唤醒钩子送达。
# 长跑/脱离形态推荐开启（替代手工 python3 setsid 咒语；setsid 二进制本机不存在，故内联）。
if [ "${RUNNER_SURVIVE:-0}" = "1" ] && [ -z "${RUNNER_SURVIVE_DONE:-}" ]; then
  export RUNNER_SURVIVE_DONE=1
  RUNNER_LOG="${RUNNER_LOG:-$LOG_DIR/runner-$(date +%H%M%S)-$$.log}"
  export RUNNER_LOG
  RUNNER_ABS="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  echo "[survive] setsid 自剥离转后台：日志 -> $RUNNER_LOG (完结态由 runner-wake 送达)"
  RUNNER_SCRIPT="$RUNNER_ABS" python3 -c '
import subprocess, os, sys
argv = ["bash", os.environ["RUNNER_SCRIPT"]] + sys.argv[1:]
p = subprocess.Popen(argv, stdout=open(os.environ["RUNNER_LOG"], "a"), stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, preexec_fn=os.setsid)
print("[survive] 后台 PID=%d" % p.pid)
' "$@"
  exit 0
fi

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

# ---------- dd 产物自检（2026-08-30 Tina 修①：陈旧/缺失测试产物强制重建，防 up-to-date 误判空跑） ----------
check_dd_artifacts() {
  local app="$DD/Build/Products/Debug/ChineseChess.app"
  local xctest="$app/Contents/PlugIns/ChineseChessTests.xctest"
  if [ ! -d "$app" ] || [ ! -d "$xctest" ]; then
    echo "⚠️ [dd自检] 测试产物缺失（app/xctest），清理 Products 强制重建：$DD/Build/Products"
    rm -rf "$DD/Build/Products" 2>/dev/null
  else
    echo "[dd自检] 测试产物在位（$(stat -f '%Sm' "$xctest" 2>/dev/null)）"
  fi
}

# ---------- 单 suite 起跑（独立进程） ----------
run_suite() {
  local suite="$1"
  # 2026-08-30 Tina 修②a：用例级路径（含 /）不得进日志文件名（目录不存在→ tee 写丢→ 假零跑）
  local tag="${suite//\//_}"   # 文件名安全化，filter 仍用原 suite
  local log="$LOG_DIR/${tag}-$(date +%H%M%S).log"
  echo "▶ [$suite] 起跑 $(date '+%F %T')，日志 $log"
  # 2026-08-30 Tina 修②c：子 shell 加 pipefail——旧版 rc 取自 PIPESTATUS[0] 实为 tee 退出码（恒 0，
  # TEST FAILED 也报 rc=0 假 PASS 隐患），现子 shell 传递 xcodebuild 真实 rc
  ( set -o pipefail; cd "$PROJECT" && \
    bash ~/DevTeam/scripts/preflight-test-assets.sh "$PROJECT" >/dev/null || { echo "preflight 失败（资产缺失）"; exit 3; } ; \
    timeout "$RUNNER_TIMEOUT" xcodebuild test -scheme ChineseChess -sdk macosx \
      -derivedDataPath "$DD" \
      $(skip_args) \
      -only-testing:"ChineseChessTests/$suite" 2>&1 | tee "$log" )
  local rc=$?
  if [ "$rc" -eq 124 ]; then
    echo "⏱️ [$suite] TIMEOUT：超 ${RUNNER_TIMEOUT}s 被 kill（防挂起占锁），日志尾部标记 ↓" | tee -a "$log"
    echo "=== RUNNER TIMEOUT ${RUNNER_TIMEOUT}s ($suite) $(date '+%F %T') ===" >> "$log"
    EXIT_SUMMARY+=("FAIL(timeout ${RUNNER_TIMEOUT}s) $suite $log")
    return 124
  fi
  # 静默零跑门规（2026-08-29 Step2 终报批实证：filter 名不符 → Executed 0 tests 假绿）
  # 2026-08-30 Tina 复核：双框架对账——XCTest（Executed N）/ Swift Testing（Test run with N tests）任一侧 N≥1 即真跑；
  # 纯 0 计数（含 'Test run with 0 tests'）自然落入零跑分支被拦
  if ! grep -qE "Test run with [1-9][0-9]* test|Executed [1-9][0-9]* test" "$log" 2>/dev/null; then
    echo "❌ [$suite] 静默零跑：日志无 'N≥1 tests' 对账行（filter 名与实际 suite 名不符嫌疑），批次作废"
    EXIT_SUMMARY+=("FAIL(zero-run) $suite $log")
    return 5
  fi
  local n
  n=$(grep -cE "Executed [0-9]+ test" "$log" 2>/dev/null || true)
  n2=$(grep -cE "Test run with [0-9]+ test" "$log" 2>/dev/null || true)
  echo "[对账] XCTest Executed 行=$n / Swift Testing run 行=$n2"
  if [ "$rc" -eq 0 ]; then
    echo "✅ [$suite] rc=0 $(date '+%T')"
    EXIT_SUMMARY+=("PASS $suite $log")
  else
    echo "❌ [$suite] rc=$rc $(date '+%T')"
    EXIT_SUMMARY+=("FAIL($rc) $suite $log")
  fi
  return $rc
}

# ---------- T-1101-7 R1：完批唤醒钩子（EXIT trap 消费，v2 全非阻塞）----------
# 11-01 实证：xcresult 落盘+锁已释、发起会话停摆 4h（完批不自知；历史同族 10+ 例）。
# v1 教训（live test 实证）：openclaw agent 对忙会话阻塞等轮完成（40s rc=124 实测）——
# trap 内直发会拖延锁释放（fd 9 至进程死才关）且有静默死亡面。v2 全非阻塞：
# trap 只做「入队+拉守护+echo」（毫秒级），投递全走 deliver-retry daemon（异步 backoff，
# 服务端持久入列 pendingInputs，忙会话轮完即消费）；RUNNER_WAKE=0 可关。
wake_owner() {
  # v6：去 local 化（WAKE_ 前缀全局）——bash 3.2 + set -u + local 声明在 trap/survive 语境有
  # 语境依赖性 unbound 失效（v1-v5 四轮“静默死亡”均为此图：local 赋值后引用报 unbound，
  # 前台却全过；mini1/mini2 无 local 实验全部存活）——去 local 是唯一全语境实证存活形状
  WAKE_RC="${1:-0}"
  [ "${RUNNER_WAKE:-1}" = "1" ] || return 0
  [ -n "$OWNER" ] || return 0
  WAKE_TARGET="agent:${OWNER}:main"
  WAKE_MSGFILE="$LOCK_DIR/runner-wake-$$.msg"
  echo "[runner-wake] 批完结自动唤醒（T-1101-7 R1，pid $$，rc=$WAKE_RC)" > "$WAKE_MSGFILE"
  echo "suite 汇总：" >> "$WAKE_MSGFILE"
  if [ ${#EXIT_SUMMARY[@]} -gt 0 ]; then
    for WAKE_LINE in "${EXIT_SUMMARY[@]}"; do echo "  $WAKE_LINE" >> "$WAKE_MSGFILE"; done
  else
    echo "  （空——早退/未起跑路径）" >> "$WAKE_MSGFILE"
  fi
  echo "收割：grep -E 'Executed .* tests|Test run with|H-1 runner' 上述 suite 日志" >> "$WAKE_MSGFILE"
  if bash ~/DevTeam/scripts/deliver-retry.sh enqueue "$WAKE_TARGET" "$WAKE_MSGFILE" 2>/dev/null; then
    bash ~/DevTeam/scripts/deliver-retry.sh ensure-daemon 2>/dev/null || true
    echo "[runner-wake] ✅ 已入队 $WAKE_TARGET (daemon 异步投递, 批 rc=$WAKE_RC)"
    rm -f "$WAKE_MSGFILE"
  else
    echo "[runner-wake] ⚠️ 入队失败，唤醒降级（msgfile=$WAKE_MSGFILE 留档待收割）"
  fi
}

# ---------- 主流程：抢锁 → 逐 suite 串行 ----------
OWNER="${RUNNER_OWNER:-}"
if [ -z "$OWNER" ]; then
  echo "❌ 无 owner 拒起跑：export RUNNER_OWNER=<agent名> 后再调用（2026-08-29 Luke 裁定：一切 xcodebuild 跑留痕可溯）"
  exit 6
fi

main() {
  exec 9>"$LOCK_FILE"
  echo "⏳ [mutex] 等待测试锁 $LOCK_FILE $(date '+%F %T')"
  # R3 排队可观测（T-1101-7）：等待者登记 pid|owner|state|ts（亡行留痕=被杀在队的诊断证据）
  echo "$$|$OWNER|waiting|$(date '+%F %T')" >> "$LOCK_DIR/queue.state"
  if ! flock -w 14400 9; then   # 最长排队 4h
    if [ -f "$LOCK_DIR/queue.state" ]; then
      awk -F'|' -v pid="$$" '$1 != pid' "$LOCK_DIR/queue.state" > "$LOCK_DIR/queue.state.tmp" && mv "$LOCK_DIR/queue.state.tmp" "$LOCK_DIR/queue.state"
    fi
    echo "❌ 抢锁超时（4h），放弃起跑"; exit 4
  fi
  if [ -f "$LOCK_DIR/queue.state" ]; then
    awk -F'|' -v pid="$$" '$1 != pid' "$LOCK_DIR/queue.state" > "$LOCK_DIR/queue.state.tmp" && mv "$LOCK_DIR/queue.state.tmp" "$LOCK_DIR/queue.state"
  fi
  # R3 持锁可观测：holder.state（释放由 EXIT trap 清理）
  echo "$$|$OWNER|holding|$(date '+%F %T')" > "$LOCK_DIR/holder.state"
  echo "🔒 [mutex] 获得锁 $(date '+%F %T') (holder=$$, owner=$OWNER)"
  # T-1101-7 v3：trap 只留清理（unlock+holder）——wake 改主流程直调（trap 上下文有不可复现的静默死亡面，
  # v1/v2/v3 三轮法证钉死于 trap 尾段；主流程毫秒前刚成功打印汇总行=同上下文实证健康）
  trap 'unlock_language; rm -f "$LOCK_DIR/holder.state"' EXIT
  lock_language   # 语言锁整批只加一次（每 suite 重复加锁会把注入值误当原值备份 → 批后残留）
  check_dd_artifacts   # 2026-08-30 Tina 修①：dd 产物自检/强制重建

  if [ "${1:-}" = "--h1-verify" ]; then
    shift
    SUITES=(SelectionConsistencyTests L10NDisplayNameV42Tests V223FixTests DifficultyV42Tests RunnerHygieneTests)
  elif [ "${1:-}" = "--full" ]; then
    # r 系全量批（08-29 Luke 放行）：skip 名单即过滤器（DEVTEAM 过滤铁律由 skip 单源满足）
    flog="$LOG_DIR/full-$(date +%H%M%S).log"
    echo "▶ [full] r 系全量批起跑 $(date '+%F %T')，日志 $flog"
    ( cd "$PROJECT" && \
      bash ~/DevTeam/scripts/preflight-test-assets.sh "$PROJECT" >/dev/null || { echo "preflight 失败"; exit 3; } ; \
      timeout "$RUNNER_TIMEOUT" xcodebuild test -scheme ChineseChess -sdk macosx \
        -derivedDataPath "$DD" -parallel-testing-enabled NO \
        $(skip_args) 2>&1 | tee "$flog" )
    frc=$?
    if [ "$frc" -eq 124 ]; then
      echo "⏱️ [full] TIMEOUT：超 ${RUNNER_TIMEOUT}s 被 kill" | tee -a "$flog"
      echo "=== RUNNER TIMEOUT ${RUNNER_TIMEOUT}s (full) $(date '+%F %T') ===" >> "$flog"
    fi
    # 汇总对账门禁：总 Executed N>=500（r3g 冻结基线 623 量级），低于即批次作废
    ftotal=$(grep -oE "Test run with [0-9]+ tests in [0-9]+ suites|Executed [0-9]+ tests" "$flog" | tail -1 | grep -oE "[0-9]+" | head -1 || echo 0)
    if [ "${ftotal:-0}" -lt 500 ]; then
      echo "❌ [full] 对账门禁：总 Executed=${ftotal} <500，批次作废"
      EXIT_SUMMARY+=("FAIL(zero-run total=${ftotal}) full $flog")
      wake_owner 5
      echo "锁释放 $(date '+%F %T')"; exit 5
    fi
    if [ "$frc" -eq 0 ]; then echo "✅ [full] rc=0"; else echo "❌ [full] rc=$frc"; fi
    echo "[full] 总对账 Executed=${ftotal} tests $(date '+%T')"
    EXIT_SUMMARY+=("rc=$frc full total=${ftotal} $flog")
    wake_owner "$frc"
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
  wake_owner "$overall"   # T-1101-7 R1：主流程直调唤醒（trap 只留清理）
  echo "锁释放 $(date '+%F %T')"
  exit $overall
}

main "$@"
