#!/bin/bash
# T-0915-2 KI 补验队列：Eric #8 (worktree 3 套) + Cody #7 (main 7 套)
# 2026-09-15 v2（Tina，KI 破案后适配 + 首跑教训）：
#   - WT runner 改持久路径（/tmp 副本已被系统清理）
#   - 去 caffeinate（沙箱外执行不需要）
#   - 【教训 1】冷编译宏 flake 与沙箱独立：DD 冷/指纹变更时须 OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox'
#     预热（build-only），暖 DD 后测试调用无需旗标——由 PREWARM_STEP 处理，勿再盲删
#   - 【教训 2】run_in_background 后台任务疑不继承沙箱豁免（Contempt/Phase2b 后台挂起实证）——
#     本队列必须前台执行或每套件显式豁免确认
# 纪律：runner 单通道、EloBaselineTests 必跳（runner 内 skip 单源）、RUNNER_OWNER=tina 留痕
# 2026-09-17 补（T-0917-4 P2-3）：authored 头——每份日志与终端总输出首行带
#   "AUTHORED <ISO8601> RUNNER_OWNER=<owner> SUITE=<suite>"，单次调用单指纹（多日志
#   同指纹无法归因时先看头行）；RUNNER_OWNER 未设时显式标 unknown，不再静默。
set -u
ts() { date '+%H:%M:%S'; }
AUTHORED_HEADER() { date "+AUTHORED %Y-%m-%dT%H:%M:%S%z RUNNER_OWNER=${RUNNER_OWNER:-unknown}"; }
WT_RUNNER=/Users/hth/DevTeam/scripts/run-tests-mutex-v64c2-wt.sh
MAIN_RUNNER=/Users/hth/DevTeam/projects/chinese-chess/scripts/run-tests-mutex.sh

# PREWARM_STEP=1 时先带宏旗标 build-only 预热对应 DD（冷 DD / 指纹被旗标构建改过时用）
if [ "${PREWARM_WT:-0}" = "1" ]; then
  echo "[$(ts)] prewarm: worktree DD (flag build)"
  ( cd /Users/hth/DevTeam/worktrees/v64-c2 && env OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox' \
      /usr/bin/xcodebuild build -project ChineseChess.xcodeproj -scheme ChineseChess \
      -configuration Debug -derivedDataPath /tmp/v64c2-dd -sdk macosx ) \
    > ~/DevTeam/logs/v64c2/prewarm-wt.log 2>&1
  echo "[$(ts)] prewarm wt rc=$?"
fi
if [ "${PREWARM_MAIN:-0}" = "1" ]; then
  echo "[$(ts)] prewarm: main DD (flag build)"
  ( cd /Users/hth/DevTeam/projects/chinese-chess && env OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox' \
      /usr/bin/xcodebuild build -project ChineseChess.xcodeproj -scheme ChineseChess \
      -configuration Debug -derivedDataPath /tmp/xc-mutex-dd -sdk macosx ) \
    > ~/DevTeam/logs/prewarm-main.log 2>&1
  echo "[$(ts)] prewarm main rc=$?"
fi

# Eric #8: 3 suites on worktree v6.4-phase1-C2
AUTHORED_HEADER   # 终端总输出 authored 头（P2-3）
for s in V64C2LayoutTests V64C0LayoutTests V62LayoutTests; do
  echo "[$(ts)] wt: $s"
  { AUTHORED_HEADER; echo "SUITE=$s REPO=wt-v64c2"; RUNNER_OWNER="${RUNNER_OWNER:-tina}" bash "$WT_RUNNER" "$s"; } \
    > ~/DevTeam/logs/v64c2/$s-recap.log 2>&1
  rc=$?
  echo "[$(ts)] wt: $s exit=$rc"
  grep -oE "Test run with [0-9]+ tests? in [0-9]+ suites? (passed|failed)|\\*\\* TEST (SUCCEEDED|FAILED) \\*\\*|hung before establishing|signal term" ~/DevTeam/logs/v64c2/$s-recap.log | tail -1
done

# Cody #7: 7 suites on main repo (m1 HEAD——代码面 Ruby 已增量审, 运行时只看套件健康)
for s in ContemptT2RevertTests Phase2bTests Phase3aEvaluationTests Phase3bEvaluationTests Phase6Tests SigillIronGateRegressionTests VariationAPITests; do
  echo "[$(ts)] main: $s"
  { AUTHORED_HEADER; echo "SUITE=$s REPO=main"; RUNNER_OWNER="${RUNNER_OWNER:-tina}" bash "$MAIN_RUNNER" "$s"; } \
    > ~/DevTeam/logs/$s-recap.log 2>&1
  rc=$?
  echo "[$(ts)] main: $s exit=$rc"
  grep -oE "Test run with [0-9]+ tests? in [0-9]+ suites? (passed|failed)|\\*\\* TEST (SUCCEEDED|FAILED) \\*\\*|hung before establishing|signal term" ~/DevTeam/logs/$s-recap.log | tail -1
done
echo "[$(ts)] all done"
