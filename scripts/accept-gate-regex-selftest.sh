#!/bin/bash
# accept-gate 正则自测 · 固化入库版（Batch B T-0916-1 ⓪(d)，charter §3.1/R6/RB-7）
# 用法：bash scripts/accept-gate-regex-selftest.sh [受控仓路径]
#   缺省路径 /tmp/gate-regex-test-v2 不存在时自动搭建（10 commit：六 type 正例×6 + 反例×4）
# 断言口径（Batch B 排期 §2 ⓪(d) + §4 验证门）：
#   六 type 正例各一 + 反例（style 不命中 / prefix-feat 行首锚定不命中）+ 右锚 + 元字符
#   + 旧四型回归不破坏（RB-7：Batch A 已验收语义不动）
export PATH=/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH

SELFTEST_REPO="${1:-/tmp/gate-regex-test-v2}"
# 与 accept-gate.sh 第 2 查完全同构的六 type 正则（单源口径：改 gate 必同步改此处）
RX_TYPES='feat|fix|refactor|test|chore|docs'

esc() { printf '%s' "$1" | sed 's/[][\.*^$(){}?+|\/]/\\&/g'; }
hit() { git -C "$SELFTEST_REPO" log -E --oneline --grep="^(${RX_TYPES})\($(esc "$1")\)" 2>/dev/null | wc -l | tr -d ' '; }

# ---- 受控仓自建（幂等）----
if [ ! -d "$SELFTEST_REPO/.git" ]; then
  mkdir -p "$SELFTEST_REPO" || exit 2
  git -C "$SELFTEST_REPO" init -q || exit 2
  git -C "$SELFTEST_REPO" config user.email selftest@local
  git -C "$SELFTEST_REPO" config user.name selftest
  for m in "feat(rx): p1" "fix(rx): p2" "refactor(rx): p3" "test(rx): p4" "chore(rx): p5" \
           "docs(rx): p6" "style(rx): n1-六型外" "prefix-feat(rx): n2-行首锚定" \
           "feat(rx-extra): n3-右锚" "chore: 无label负例"; do
    git -C "$SELFTEST_REPO" commit -q --allow-empty -m "$m" || exit 2
  done
fi

pass=0; fail=0
ck() { if [ "$2" = "$1" ]; then echo "PASS  $3（命中 $2）"; pass=$((pass+1)); else echo "FAIL  $3（期望 $1，实际 $2）"; fail=$((fail+1)); fi; }

echo "受控仓: $SELFTEST_REPO（$(git -C "$SELFTEST_REPO" log --oneline | wc -l | tr -d ' ') commits）"

# ── 六 type 正例：label=rx 应恰好命中 6（feat/fix/refactor/test/chore/docs 各一）──
N="$(hit 'rx')"
ck 6 "$N" "六 type 正例：label=rx 命中 6（feat+fix+refactor+test+chore+docs 各一）"
# 逐 type 精确断言（每个 type 的 label 恰好 1 条——排除某型缺失/重复）
for t in feat fix refactor test chore docs; do
  n=$(git -C "$SELFTEST_REPO" log -E --oneline --grep="^${t}\(rx\)" | wc -l | tr -d ' ')
  ck 1 "$n" "正例 ${t}(rx) 恰好 1 条"
done

# ── 反例 ──
OUT="$(git -C "$SELFTEST_REPO" log -E --oneline --grep="^(${RX_TYPES})\(rx\)" 2>/dev/null)"
echo "$OUT" | grep -q "style" && { echo "FAIL  style(rx) 被误命中"; fail=$((fail+1)); } || { echo "PASS  反例：style(rx) 六型外不命中"; pass=$((pass+1)); }
echo "$OUT" | grep -q "prefix-feat" && { echo "FAIL  prefix-feat(rx) 被误命中"; fail=$((fail+1)); } || { echo "PASS  反例：prefix-feat(rx) 行首锚定排除"; pass=$((pass+1)); }
echo "$OUT" | grep -q "rx-extra" && { echo "FAIL  feat(rx-extra) 被误命中"; fail=$((fail+1)); } || { echo "PASS  反例：feat(rx-extra) 右锚排除"; pass=$((pass+1)); }
echo "$OUT" | grep -q "无label" && { echo "FAIL  无 label 行被误命中"; fail=$((fail+1)); } || { echo "PASS  反例：chore:（无 label）不命中"; pass=$((pass+1)); }

# ── 边界 ──
ck 0 "$(hit 'no-such-label')" "负例：不存在的 label 零命中"
ck 0 "$(hit 'a.b+c')"         "负例：元字符 label（a.b+c）字面量化零命中"
ck 1 "$(hit 'rx-extra')"      "自证：label=rx-extra 命中自己（不被 rx 误命中已由 count=6 证明）"

# ── RB-7 旧四型回归：四 type 正则在六型仓上语义不变（feat/fix/refactor/test 仍各命中且不增）──
OLD_N="$(git -C "$SELFTEST_REPO" log -E --oneline --grep="^(feat|fix|refactor|test)\($(esc 'rx')\)" | wc -l | tr -d ' ')"
ck 4 "$OLD_N" "RB-7 回归：旧四型正则仍恰好 4（Batch A 语义不破坏——chore/docs 不混入）"

# ── 对照组：宽松未锚定正则的误收实证（防"随手改宽松"——charter §3.1 Vera P1-③）──
LOOSE="$(git -C "$SELFTEST_REPO" log -E --oneline --grep="(feat|fix|refactor|test|chore|docs)\(rx\)" | wc -l | tr -d ' ')"
if [ "$LOOSE" -ge 7 ]; then echo "PASS  对照：去掉行首锚定命中 $LOOSE 条（误收 prefix-feat 等），锚定必要性实证"; pass=$((pass+1)); else echo "FAIL  对照异常（宽松正则仅 $LOOSE）"; fail=$((fail+1)); fi

# ── v1.4 断言（T-0917-4 维护批）：提示串可执行性 + tee 并发收口 ──
# P2-1：零命中时回显的复查命令必须 (a)含 printf %q 转义形态 (b)粘回车即跑且与 gate 第 2 查语义等价
GATE_DIR="$(cd "$(dirname "$0")" && pwd)"
GATE_OUT="$(GATE_EVIDIR="$SELFTEST_REPO/evi" TASK_LEDGER_PATH=/dev/null bash "$GATE_DIR/accept-gate.sh" 'meta.l+x' 2>/dev/null || true)"
CMDLINE="$(printf '%s\n' "$GATE_OUT" | grep -oE 'git log -E --oneline --grep=.*' | head -1)"
if [ -n "$CMDLINE" ] && printf '%s' "$CMDLINE" | grep -qE '\\\.'; then
  echo "PASS  P2-1：提示串含 %q 转义形态（可执行复查命令在位）"; pass=$((pass+1))
else
  echo "FAIL  P2-1：零命中提示串缺失或未转义"; fail=$((fail+1))
fi
# 提示串字面执行=单次解析（zsh -c 模拟粘贴），零命中语义与 gate 第 2 查一致
if [ -n "$CMDLINE" ]; then
  RECHECK="$(cd "$SELFTEST_REPO" && zsh -c "$CMDLINE" 2>/dev/null | wc -l | tr -d ' ')"
  ck 0 "$RECHECK" "P2-1：提示串粘回车即跑，零命中与 gate 一致（元字符 label=meta.l+x）"
else
  echo "FAIL  P2-1：无提示串可验"; fail=$((fail+1))
fi
# P2-5：tee 留痕完整性——单文件不含外来 label 行（并发收口后应恒成立；此处验正路无污染）
GELOG="$SELFTEST_REPO/evi/gate-meta.l+x-$(date +%Y%m%d).log"
if [ -f "$GELOG" ] && [ "$(grep -cE 'label=<' "$GELOG")" -ge 1 ] && ! grep -E 'label=<' "$GELOG" | grep -vq 'label=<meta.l+x>'; then
  echo "PASS  P2-5：留痕自洽（无外来 label 行）"; pass=$((pass+1))
else
  echo "FAIL  P2-5：留痕缺失或含外来行"; fail=$((fail+1))
fi

echo "────"
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
