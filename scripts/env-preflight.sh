#!/bin/bash
# env-preflight.sh —— 环境预检（2026-09-14 全周环境教训固化，复盘 P1 改进）
# 作用：任何会话跑测试批前先跑本脚本，提前拦截陈锁/残留进程/LS 膨胀/互斥锁占用。
# 纪律：只报不清（清理走人工纪律：锁先溯源再 mv 隔离，进程确认归属再杀）。
# 自示范：本脚本内 git 只读命令一律 --no-optional-locks（known-issues 5cd8a28 根因口径）。
# 退出码：0=全绿可开工；1=有警示（先处置或知会再开工）。

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"   # flock 等工具路径（KI 教训：PATH 缺失致锁超时 4h）

WARN=0
say_ok() { printf "✅ %s\n" "$1"; }
say_warn() { printf "⚠️ %s\n" "$1"; WARN=1; }

echo "=== 环境预检 $(date '+%F %T') ==="

# ---- 查 1：残留 index.lock（主仓 + 主仓名下 worktrees + DevTeam 仓）----
echo "--- [1] index.lock 残留 ---"
REPOS="/Users/hth/DevTeam/projects/chinese-chess /Users/hth/DevTeam"
for repo in $REPOS; do
  gitdir="$repo/.git"
  # worktree 的 .git 是文件（gitdir: 指针）——解析后检查其 index.lock
  if [ -f "$gitdir" ]; then
    wt_dir=$(sed 's/^gitdir: *//' "$gitdir")
    for lk in "$wt_dir/index.lock"; do
      [ -e "$lk" ] && say_warn "$repo (worktree): $lk 存在" || say_ok "$repo (worktree): 无 index.lock"
    done
  elif [ -d "$gitdir" ]; then
    if [ -e "$gitdir/index.lock" ]; then
      sz=$(stat -f %z "$gitdir/index.lock" 2>/dev/null)
      say_warn "$repo/.git/index.lock 存在 (size=${sz}B)——先溯源(0B+无git进程=陈旧)再mv隔离, 勿直接rm"
    else
      say_ok "$repo/.git: 无 index.lock"
    fi
    # 主仓名下注册的 worktrees（排除隔离区）
    for wt in "$gitdir"/worktrees/*/; do
      [ -d "$wt" ] || continue
      [ -e "${wt}index.lock" ] && say_warn "worktree $(basename "$wt"): ${wt}index.lock 存在" || true
    done
  fi
done
# 主仓名下 worktree 汇总行（无警示时给一行 ok）
wt_hits=$(ls /Users/hth/DevTeam/projects/chinese-chess/.git/worktrees/*/index.lock 2>/dev/null | wc -l | tr -d ' ')
[ "$wt_hits" = "0" ] && say_ok "主仓名下 worktrees: 无 index.lock" || true

# ---- 查 2：残留测试相关进程 ----
echo "--- [2] 残留测试进程 ---"
for name in ChineseChess xctest XCBBuildService xcodebuild; do
  pids=$(pgrep -x "$name" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  if [ -n "$pids" ]; then
    # 展示首个进程的运行时长+命令片段便于判断归属
    first="${pids%%,*}"
    first_et=$(ps -o etime= -p "$first" 2>/dev/null | tr -d ' '); [ -z "$first_et" ] && first_et="未知"
    first_cmd=$(ps -o command= -p "$first" 2>/dev/null | head -c 100)
    say_warn "$name 进程存活 pid=[$pids] (首个已运行 $first_et) cmd: $first_cmd ——确认归属(测试批在跑=正常; 挂起残留=先杀)"
  else
    say_ok "$name: 无残留进程"
  fi
done

# ---- 查 3：~/DevTeam/.locks/ 互斥锁占用状态 ----
echo "--- [3] 互斥锁状态 ---"
LOCKS_DIR="$HOME/DevTeam/.locks"
mkdir -p "$LOCKS_DIR" 2>/dev/null || true
for lk in xcode-tests.lock task-ledger.lock; do
  f="$LOCKS_DIR/$lk"
  if [ ! -e "$f" ]; then say_ok "$lk: 锁文件不存在(空闲)"; continue; fi
  # flock -n 非阻塞试拿：拿到=空闲, 立即释放；拿不到=有批次持有
  if flock -n "$f" -c true 2>/dev/null; then
    say_ok "$lk: 空闲"
  else
    holder=$(lsof "$f" 2>/dev/null | tail -1 | awk '{print $1, $2}')
    say_warn "$lk: 被持有 ($holder)——测试/台账批在途, 勿抢"
  fi
done

# ---- 查 4：LS 数据库膨胀（com.chinesechess.app 注册条目）----
echo "--- [4] LaunchServices 注册膨胀 ---"
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
LS_THRESHOLD=5
LS_BUDGET=${ENV_PREFLIGHT_LS_BUDGET:-20}   # 秒: dump 全库是重操作, 默认截断采样; 需全量核对时前置 ENV_PREFLIGHT_LS_BUDGET=90
DUMP=$(mktemp /tmp/env-preflight-ls.XXXXXX)
"$LSREG" -dump > "$DUMP" 2>/dev/null &
DPID=$!
( sleep "$LS_BUDGET"; kill -9 "$DPID" 2>/dev/null ) &
WD=$!
disown "$WD" 2>/dev/null || true   # 脱离作业表, 避免脚本打印 "Terminated" 噪音
wait "$DPID" 2>/dev/null; RC=$?
kill "$WD" 2>/dev/null
cc_paths=$(awk '/^[[:space:]]*path:/{pp=$2} /^[[:space:]]*identifier:[[:space:]]*com\.chinesechess\.app$/{if(pp!="")print pp}' "$DUMP" | sort -u | tee "$DUMP.u" | wc -l | tr -d ' ')
# 分相统计（截断样本同样有效: 样本内死路径数为下界; 总数含合法并存安装非污染信号, 09-14 定性）
cc_dead=0
while IFS= read -r p; do [ -e "$p" ] || cc_dead=$((cc_dead+1)); done < "$DUMP.u"
rm -f "$DUMP" "$DUMP.u"
suffix=""
[ "$RC" -ge 128 ] && suffix="(${LS_BUDGET}s 截断, 均为下界)"
if [ "$cc_dead" -ge 3 ]; then
  say_warn "com.chinesechess.app 死路径注册≥$cc_dead / 总 $cc_paths $suffix——真污染, 参考 KI-2026-0913-01 招(b)注销死路径"
else
  say_ok "com.chinesechess.app 注册 $cc_paths 条, 死路径≤$cc_dead (<3) $suffix——合法并存非污染; 全量核对 ENV_PREFLIGHT_LS_BUDGET=90"
fi

# ---- 查 5：git 通道自检（本脚本示范 --no-optional-locks 且验后不留锁）----
echo "--- [5] git 通道自检 ---"
for repo in /Users/hth/DevTeam/projects/chinese-chess "$HOME/DevTeam"; do
  label=$(basename "$repo")
  if (cd "$repo" && git --no-optional-locks status --short >/dev/null 2>&1); then
    say_ok "$label: git 只读通道正常"
  else
    say_warn "$label: git status 失败——查权限/仓库完整性"
  fi
done
# 自证不留锁
[ -e "$HOME/DevTeam/.git/index.lock" ] && say_warn "自检后 DevTeam 仓出现 index.lock——脚本违反自身纪律, 请修" || true

# ---- 汇总 ----
echo "=== 汇总 ==="
if [ "$WARN" = "0" ]; then
  echo "✅ 全绿——可开工（测试批先经 run-tests-mutex.sh）"
  exit 0
else
  echo "⚠️ 存在警示——先处置(或知会 owner)再开工; 处置口径见 ~/DevTeam/knowledge/known-issues.md 相关条目"
  exit 1
fi
