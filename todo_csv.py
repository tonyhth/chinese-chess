#!/usr/bin/env python3
"""读取 CSV 任务清单，按优先级排序输出。

用法:
    python todo_csv.py
    python todo_csv.py --file /path/to/tasks.csv

CSV 格式: 任务,优先级,截止日期
优先级: 高/中/低
"""

import argparse
import csv
import sys
from pathlib import Path

PRIORITY_ORDER = {"高": 0, "中": 1, "低": 2}


def load_tasks(filepath: str) -> list[dict]:
    path = Path(filepath).expanduser()
    if not path.exists():
        print(f"错误：文件 '{path}' 不存在，请检查路径后重试。")
        sys.exit(1)

    tasks = []
    with open(path, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            task = row.get("任务", "").strip()
            priority = row.get("优先级", "").strip()
            deadline = row.get("截止日期", "").strip()
            if not task:
                continue
            if priority not in PRIORITY_ORDER:
                print(f"警告：任务「{task}」优先级「{priority}」无效，已跳过。", file=sys.stderr)
                continue
            tasks.append({"任务": task, "优先级": priority, "截止日期": deadline})

    return tasks


def sort_tasks(tasks: list[dict]) -> list[dict]:
    return sorted(tasks, key=lambda t: PRIORITY_ORDER[t["优先级"]])


def print_tasks(tasks: list[dict]) -> None:
    if not tasks:
        print("没有可显示的任务。")
        return

    print(f"{'任务':<20}{'优先级':<8}{'截止日期':<12}")
    print("-" * 40)
    for t in tasks:
        print(f"{t['任务']:<20}{t['优先级']:<8}{t['截止日期']:<12}")


def main():
    parser = argparse.ArgumentParser(description="读取 CSV 任务清单并按优先级排序输出")
    parser.add_argument("--file", default="~/todo.csv", help="CSV 文件路径（默认 ~/todo.csv）")
    args = parser.parse_args()

    tasks = load_tasks(args.file)
    sorted_tasks = sort_tasks(tasks)
    print_tasks(sorted_tasks)


if __name__ == "__main__":
    main()
