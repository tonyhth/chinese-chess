#!/bin/bash
set -e
cd ~/DevTeam

# 清理环境
rm -f ~/.task_tracker.json ~/.task_tracker.json.bak

echo "=== 准备测试数据 ==="
python3 task_tracker.py add "完成API接口" --priority high --tag work --due 2026-04-10
python3 task_tracker.py add "修复登录bug" --priority high --tag bug --tag work --due 2026-04-08
python3 task_tracker.py add "写测试用例" --priority medium --tag testing --due 2026-04-12
python3 task_tracker.py add "更新文档" --priority low --tag docs
python3 task_tracker.py add "代码审查" --priority medium --tag work --tag review
python3 task_tracker.py add "部署上线 🚀" --priority high --tag work

echo ""
echo "=== 测试1: done --ids 传入不存在的 ID ==="
python3 task_tracker.py done --ids 1 2 999 888 2>&1 || true

echo ""
echo "=== 测试2: add --due 非法格式 ==="
python3 task_tracker.py add "测试" --due "明天" 2>&1 || true
python3 task_tracker.py add "测试" --due "2026/04/10" 2>&1 || true
python3 task_tracker.py add "测试" --due "abc" 2>&1 || true

echo ""
echo "=== 测试3: done --ids 和 --all-pending 互斥 ==="
python3 task_tracker.py done --ids 1 --all-pending 2>&1 || true

echo ""
echo "=== 测试4: delete 使用 --ids（非位置参数） ==="
python3 task_tracker.py delete 3 2>&1 || true
python3 task_tracker.py delete --ids 3 --dry-run
python3 task_tracker.py delete --ids 999 888 --dry-run 2>&1 || true

echo ""
echo "=== 测试5: list --filter 无效格式 ==="
python3 task_tracker.py list --filter priority:high --filter badfilter --filter tag:docs 2>&1

echo ""
echo "=== 测试6: stats 标签分布（含完成数） ==="
python3 task_tracker.py stats

echo ""
echo "=== 测试7: 数据文件损坏恢复 ==="
cp ~/.task_tracker.json ~/.task_tracker.json.good
echo "BROKEN" > ~/.task_tracker.json
echo "--- 损坏后 stats ---"
python3 task_tracker.py stats 2>&1
echo "--- 恢复后 stats ---"
python3 task_tracker.py stats 2>&1
# 恢复正常数据继续后续测试
cp ~/.task_tracker.json.good ~/.task_tracker.json

echo ""
echo "=== 测试8: CSV/Markdown 导出 ==="
python3 task_tracker.py export --format csv -o /tmp/test_tasks.csv
echo "--- CSV 内容 ---"
cat /tmp/test_tasks.csv
echo ""
python3 task_tracker.py export --format markdown -o /tmp/test_tasks.md
echo "--- Markdown 内容 ---"
cat /tmp/test_tasks.md

echo ""
echo "=== 测试9: 中文任务名和标签 ==="
python3 task_tracker.py add "编写单元测试 🧪" --priority medium --tag 测试 --tag 开发 --due 2026-04-15
python3 task_tracker.py list --filter tag:测试 2>&1
python3 task_tracker.py done --ids 7
python3 task_tracker.py stats

echo ""
echo "=== 全部测试完成 ==="
