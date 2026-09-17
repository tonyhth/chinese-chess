#!/bin/bash
# git-safe-commit.sh —— 主仓安全提交辅助（窄白名单配套，2026-09-16 洪涛批准）
# 目的：消除 git 提交类授权卡（超时伪拒绝问题），并内置陈旧锁清扫（沙箱拒绝 git 自身
#       unlink index.lock 导致锁再生的对冲）。本脚本只做 add+commit，无任何破坏性动词。
# 用法：git-safe-commit.sh <repo绝对路径> "<commit message>" <pathspec>...
# 纪律：一次一批、拒绝模糊 pathspec（禁裸 "."，显式列文件）、提交后回显终态供对账。
set -euo pipefail

REPO="${1:?用法: git-safe-commit.sh <repo> <message> <pathspec>...}"
MSG="${2:?缺 commit message}"
[ $# -ge 3 ] || { echo "❌ 未指定 pathspec（禁裸提交，显式列文件）"; exit 2; }
# 防御0：拒收旗标——本脚本只吃 pathspec，git 旗标误传会变 pathspec 报错（0916 自证教训）
for a in "$@"; do
  case "$a" in -*) echo "❌ 不支持旗标: $a（只收 pathspec）"; exit 2;; esac
done
shift 2

cd "$REPO" || { echo "❌ 仓库不存在: $REPO"; exit 2; }

# 防御1：有活跃 git 写进程时拒绝动锁（避免误清他人正在持有的锁）
if pgrep -x git >/dev/null 2>&1; then
  echo "❌ 检测到活跃 git 进程，拒绝清扫（避免误清在用锁），稍后重试"; exit 3
fi

# 防御2：清扫陈旧锁（昨今两日实证：超时被杀/沙箱拒绝 unlink 的残留）
rm -f .git/index.lock .git/ORIG_HEAD.lock .git/COMMIT_EDITMSG.lock 2>/dev/null || true

# 提交主体
git add -- "$@"
git commit -m "$MSG"

# 终态对账（DEVTEAM 铁律：提审附终态）
echo "=== 终态 ==="
git log --oneline -1
git status --short | head -5
