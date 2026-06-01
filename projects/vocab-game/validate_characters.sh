#!/bin/bash
# validate_characters.sh - from character-upgrade-plan.md section 7
# set -e removed to continue on failures

CHARS_DIR="VocabGame/Resources/Assets.xcassets/EggCharacters"
COLORS=(pink blue green red black yellow)
STATES=(idle happy excited sad)
MINI_STATES=(mini)
PASS=0; FAIL=0

check() {
  local msg="$1"
  local f="$2"
  if [ -f "$f" ]; then echo "✅ $msg"; ((PASS++)); else echo "❌ $msg"; ((FAIL++)); fi
}

check_size() {
  local msg="$1" f="$2" min="$3" max="$4"
  local kb=$(( $(stat -f%z "$f") / 1024 ))
  if [ $kb -ge $min ] && [ $kb -le $max ]; then echo "✅ $msg (${kb}KB)"; ((PASS++)); else echo "❌ $msg (${kb}KB, need ${min}-${max}KB)"; ((FAIL++)); fi
}

check_dim() {
  local msg="$1" f="$2" ew="$3" eh="$4"
  local w=$(sips -g pixelWidth "$f" 2>/dev/null | tail -1 | awk '{print $2}')
  local h=$(sips -g pixelHeight "$f" 2>/dev/null | tail -1 | awk '{print $2}')
  if [ "$w" = "$ew" ] && [ "$h" = "$eh" ]; then echo "✅ $msg (${w}x${h})"; ((PASS++)); else echo "❌ $msg (${w}x${h}, need ${ew}x${eh})"; ((FAIL++)); fi
}

check_alpha() {
  local msg="$1" f="$2"
  local has_alpha=$(sips -g hasAlpha "$f" 2>/dev/null | tail -1 | awk '{print $2}')
  if [ "$has_alpha" = 'yes' ]; then echo "✅ $msg"; ((PASS++)); else echo "❌ $msg (hasAlpha=$has_alpha)"; ((FAIL++)); fi
}

# 1. 检查文件存在性
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}" "${MINI_STATES[@]}"; do
    for suffix in "" "@2x"; do
      f="$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}${suffix}.png"
      check "存在: egg_${c}_${s}${suffix}.png" "$f"
    done
  done
done

# 2. 检查像素尺寸
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    check_dim "尺寸: ${c}_${s}@2x" "$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png" 1024 1024
    check_dim "尺寸: ${c}_${s} @1x" "$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}.png" 512 512
  done
  check_dim "尺寸: ${c}_mini@2x" "$CHARS_DIR/egg_${c}_mini.imageset/egg_${c}_mini@2x.png" 512 512
done

# 3. 检查文件大小
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    check_size "大小: ${c}_${s}@2x" "$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png" 150 400
  done
done

# 4. 检查 alpha 通道
for c in "${COLORS[@]}"; do
  for s in "${STATES[@]}"; do
    check_alpha "Alpha: ${c}_${s}@2x" "$CHARS_DIR/egg_${c}_${s}.imageset/egg_${c}_${s}@2x.png"
  done
done

echo ""
echo "===== 结果: $PASS PASS, $FAIL FAIL ====="
[ $FAIL -eq 0 ] && exit 0 || exit 1
