#!/bin/bash
# accept-gate.sh —— Phase 验收门（charter v1.3 §3.1；Batch A 两件套 + Batch B T-0916-1 ⓪ 适配）
# 用法：bash scripts/accept-gate.sh <phase-label> [<task-id>]
# 例：  bash scripts/accept-gate.sh phase-2a T-0913-1
#
# 验收三查（任一 fail 即退出码 1，零 warn 档——验收不是交付，没有"带病通过"）：
#   1. 树净：git status --porcelain 为空（未提交+未跟踪都算不净）
#   2. Phase commit 存在：git log -E --grep="^(feat|fix|refactor|test|chore|docs)\(<label>\)" ≥1
#      （ERE + 锚定行首 + 六 type 全含 + label 正则转义——v1.1 立 v1.3 扩 chore/docs；
#       正则自测固化：scripts/accept-gate-regex-selftest.sh，16 断言含 RB-7 旧四型回归）
#      **非主仓任务型**：台账行备注列含 `no-main-commit` 标记（仅派发者可写，RB-6 权限隔离）
#      → 跳过本查并在输出标注"非主仓任务型"（验收以 DevTeam 仓 commit + 登记簿行为准）
#   3. 台账已回传：TASK-LEDGER 中 <task-id> 行状态=returned 且证据路径非空
#      （两段式语义：查 returned 不查 accepted——gate 跑在销账之前，v1.1）
#
# 任一 fail：退出码 1 + osascript 通知（§2.4 即时兜底：失败摘要取首个 ❌ 行；osascript 失败静默）
# 审计留痕：完整输出追加 ~/DevTeam/evidence/accept-gate/gate-<phase>-<date>.log
#
# PATH 纪律（charter §2.4）：凡调度类/工具类脚本必须自带 PATH export——
# flock 在 /usr/local/bin 不在默认 PATH 的 4h 锁等待教训制度化。
# git 纪律（knowledge/known-issues.md 沙箱 index.lock 条目）：git 只读命令一律
# --no-optional-locks（沙箱内 opportunistic index 更新会残留 index.lock 锁死提交通道）。
export PATH=/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH

set -u

# ---- 常量 ----
# TASK_LEDGER_PATH 可覆盖（默认真台账；自测/演练用它指向临时台账，避免污染真表）
LEDGER="${TASK_LEDGER_PATH:-$HOME/DevTeam/TASK-LEDGER.md}"
EVIDIR="$HOME/DevTeam/evidence/accept-gate"
GIT="git --no-optional-locks"

usage() {
  echo "用法: bash scripts/accept-gate.sh <phase-label> [<task-id>]"
  echo "  <phase-label>  Phase 标签（第 2 查 commit 匹配用，如 phase-2a）"
  echo "  <task-id>      台账任务号（第 3 查用，如 T-0913-1；缺省跳过第 3 查）"
  exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
LABEL="$1"
TASK_ID="${2:-}"

# 正则元字符转义（label 做字面量）
esc() { printf '%s' "$1" | sed 's/[][\.*^$(){}?+|\/]/\\&/g'; }

TS="$(date '+%Y-%m-%d %H:%M:%S')"

# ── 审计留痕：完整输出 tee 进 evidence（charter §3.1）──
mkdir -p "$EVIDIR" 2>/dev/null || true
LOGF="$EVIDIR/gate-$(printf '%s' "$LABEL" | tr '/' '_')-$(date +%Y%m%d).log"
exec > >(tee -a "$LOGF") 2>&1

echo "════ accept-gate ═══════════════════════════════════════"
echo "时刻: $TS   仓: $($GIT rev-parse --show-toplevel 2>/dev/null || echo 'NOT-IN-GIT')"
echo "参数: label=<${LABEL}> task-id=<${TASK_ID:-无}>"
echo "留痕: ${LOGF}"
echo "────────────────────────────────────────────────────────"

FAILED=0
declare -a FAIL_LINES=()

fail() { FAIL_LINES+=("$1"); FAILED=1; }

# ── 台账行预读（第 2 查 no-main-commit 判定 + 第 3 查复用）──
LEDGER_LINE=""
NO_MAIN_COMMIT=0
if [ -n "$TASK_ID" ] && [ -f "$LEDGER" ]; then
  LEDGER_LINE="$(grep -F "| ${TASK_ID} " "$LEDGER" | head -1)"
  # 备注列（$9）含 no-main-commit 标记 → 非主仓任务型（RB-6：标记仅派发者可写，巡检抽查 DevTeam 仓 commit 真实性）
  NOTE="$(printf '%s' "$LEDGER_LINE" | awk -F'|' '{gsub(/^ +| +$/,"",$9); print $9}')"
  case "$NOTE" in *no-main-commit*) NO_MAIN_COMMIT=1 ;; esac
fi

# ── 第 1 查：树净 ──────────────────────────────────────
echo "── [1/3] 树净检查（porcelain 必须为空）"
if PORC="$($GIT status --porcelain 2>/dev/null)"; then
  if [ -z "$PORC" ]; then
    echo "  ✅ 树净：无未提交、无未跟踪"
  else
    NLINES="$(printf '%s\n' "$PORC" | grep -c . )"
    echo "  ❌ 树不净（${NLINES} 项）："
    printf '%s\n' "$PORC" | head -10 | sed 's/^/      /'
    fail "❌ [1/3] 树不净：$(printf '%s\n' "$PORC" | head -1)"
  fi
else
  echo "  ❌ git status 执行失败（不在 git 仓？）"
  fail "❌ [1/3] git status 失败：非 git 仓"
fi

# ── 第 2 查：Phase commit 存在（非主仓任务型跳过）──────
if [ "$NO_MAIN_COMMIT" -eq 1 ]; then
  echo "── [2/3] 跳过——非主仓任务型（台账备注 no-main-commit，验收口径=DevTeam 仓 commit+登记簿行）"
else
  echo "── [2/3] Phase commit 存在（type∈{feat,fix,refactor,test,chore,docs} 且 label=<${LABEL}>）"
  HITS="$($GIT log -E --oneline --grep="^(feat|fix|refactor|test|chore|docs)\($(esc "$LABEL")\)" 2>/dev/null)"
  if [ -n "$HITS" ]; then
    echo "  ✅ Phase commit 在档："
    printf '%s\n' "$HITS" | sed 's/^/      /'
  else
    echo "  ❌ 零命中：^(feat|fix|refactor|test|chore|docs)\\($(esc "$LABEL")\\)"
    fail "❌ [2/3] Phase commit 缺失：label=<${LABEL}> 零命中"
  fi
fi

# ── 第 3 查：台账已回传（两段式：查 returned，不查 accepted）──
if [ -n "$TASK_ID" ]; then
  echo "── [3/3] 台账回传检查（${TASK_ID}：状态=returned 且证据路径非空）"
  if [ ! -f "$LEDGER" ]; then
    echo "  ❌ 台账不存在：$LEDGER"
    fail "❌ [3/3] 台账缺失：${LEDGER} 不存在"
  elif [ -z "$LEDGER_LINE" ]; then
    echo "  ❌ 台账无此任务行：${TASK_ID}"
    fail "❌ [3/3] 台账无行：${TASK_ID} 未登记"
  else
    # 8 列管道表：| ID | 任务名 | Owner | 派发时刻 | Deadline | 状态 | 证据路径 | 备注 |
    # awk -F'|' 下标：$2=ID $3=任务名 $4=Owner $5=派发时刻 $6=Deadline $7=状态 $8=证据路径 $9=备注
    STATUS="$(printf '%s' "$LEDGER_LINE" | awk -F'|' '{gsub(/^ +| +$/,"",$7); print $7}')"
    EVID="$(printf '%s' "$LEDGER_LINE" | awk -F'|' '{gsub(/^ +| +$/,"",$8); print $8}')"
    echo "  台账行: ${LEDGER_LINE}"
    if [ "${STATUS}" != "returned" ]; then
      echo "  ❌ 状态=${STATUS:-空}（应为 returned；accepted=已销账无需再跑 gate）"
      fail "❌ [3/3] 状态非 returned：当前=${STATUS:-空}（${TASK_ID}）"
    elif [ -z "$EVID" ]; then
      echo "  ❌ 证据路径为空（returned 行证据必填）"
      fail "❌ [3/3] 证据路径空：${TASK_ID} 状态=returned 但证据空"
    else
      echo "  ✅ 已回传：状态=returned 证据=${EVID}"
    fi
  fi
else
  echo "── [3/3] 跳过（未提供 task-id）"
fi

# ── 汇总 ────────────────────────────────────────────────
echo "────────────────────────────────────────────────────────"
if [ "$FAILED" -eq 0 ]; then
  if [ "$NO_MAIN_COMMIT" -eq 1 ]; then
    echo "✅ ACCEPT-GATE PASS（${LABEL} ${TASK_ID}，非主仓任务型——第 2 查按口径跳过）"
  else
    echo "✅ ACCEPT-GATE PASS（${LABEL} ${TASK_ID}）"
  fi
  RC=0
else
  echo "❌ ACCEPT-GATE FAIL（${LABEL} ${TASK_ID}）：${#FAIL_LINES[@]} 项未过"
  for l in "${FAIL_LINES[@]}"; do echo "  $l"; done
  RC=1
fi

# ── §2.4 通知钩子（任一 fail → osascript；失败静默不影响退出码）──
if [ "$FAILED" -ne 0 ]; then
  SUMMARY="${FAIL_LINES[0]}"
  osascript -e "display notification \"验收门未过（${LABEL} ${TASK_ID}）：${SUMMARY}\" with title \"chinese-chess accept-gate\"" >/dev/null 2>&1 || true
fi

exit $RC
