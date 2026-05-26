#!/usr/bin/env python3
"""task_tracker - 基于 JSON 文件的轻量任务管理 CLI 工具"""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import sys
import tempfile
from datetime import date
from pathlib import Path

DATA_FILE = Path.home() / ".task_tracker.json"
BAK_FILE = Path.home() / ".task_tracker.json.bak"

PRIORITY_ORDER = {"high": 0, "medium": 1, "low": 2}

REQUIRED_TASK_FIELDS = {"id", "title", "priority", "tags", "due", "done", "created"}


def _validate_tasks(data: dict) -> bool:
    """校验每个 task 字段完整性，返回 True 表示有效。"""
    if not isinstance(data.get("tasks"), list) or not isinstance(data.get("next_id"), int):
        return False
    for t in data["tasks"]:
        if not isinstance(t, dict):
            return False
        if not REQUIRED_TASK_FIELDS.issubset(t.keys()):
            return False
    return True


def _load_data() -> dict:
    """加载数据，损坏时从备份恢复。"""
    if not DATA_FILE.exists():
        return {"tasks": [], "next_id": 1}
    try:
        data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or "tasks" not in data:
            raise ValueError("结构无效")
        if not _validate_tasks(data):
            raise ValueError("任务字段不完整")
        return data
    except (json.JSONDecodeError, ValueError):
        print("⚠️  数据文件损坏，尝试从备份恢复...", file=sys.stderr)
        if BAK_FILE.exists():
            try:
                bak_data = json.loads(BAK_FILE.read_text(encoding="utf-8"))
                if not _validate_tasks(bak_data):
                    raise ValueError("备份数据字段不完整")
                shutil.copy2(BAK_FILE, DATA_FILE)
                print("✅ 已从备份恢复", file=sys.stderr)
                return bak_data
            except Exception:
                print("❌ 备份也损坏，初始化空数据", file=sys.stderr)
        return {"tasks": [], "next_id": 1}


def _save_data(data: dict) -> None:
    """备份后原子写入主文件。"""
    if DATA_FILE.exists():
        shutil.copy2(DATA_FILE, BAK_FILE)
    content = json.dumps(data, ensure_ascii=False, indent=2)
    fd, tmp_path = tempfile.mkstemp(dir=DATA_FILE.parent, suffix=".tmp")
    try:
        os.write(fd, content.encode("utf-8"))
        os.close(fd)
        fd = -1
        os.replace(tmp_path, str(DATA_FILE))
        tmp_path = ""
    except Exception:
        if fd >= 0:
            os.close(fd)
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


# ─── 命令实现 ──────────────────────────────────────────────

def cmd_add(args):
    data = _load_data()

    # 校验 --due 格式 (#5)
    if args.due:
        try:
            date.fromisoformat(args.due)
        except ValueError:
            print(f"❌ 截止日期格式错误，请使用 YYYY-MM-DD（收到: {args.due}）", file=sys.stderr)
            sys.exit(1)

    task = {
        "id": data["next_id"],
        "title": args.title,
        "priority": args.priority,
        "tags": args.tag or [],
        "due": args.due,
        "done": False,
        "created": date.today().isoformat(),
    }
    data["tasks"].append(task)
    data["next_id"] += 1
    _save_data(data)
    print(f"✅ 添加任务 #{task['id']}: {task['title']}")


def cmd_list(args):
    data = _load_data()
    tasks = data["tasks"]

    # 状态过滤
    if args.status == "pending":
        tasks = [t for t in tasks if not t["done"]]
    elif args.status == "done":
        tasks = [t for t in tasks if t["done"]]

    # 条件过滤 (#9: 无效格式报警)
    for f in (args.filter or []):
        if f.startswith("priority:"):
            val = f.split(":", 1)[1]
            tasks = [t for t in tasks if t["priority"] == val]
        elif f.startswith("tag:"):
            val = f.split(":", 1)[1]
            tasks = [t for t in tasks if val in t.get("tags", [])]
        else:
            print(f"⚠️  忽略无效过滤条件: {f}（支持 priority:xxx 或 tag:xxx）", file=sys.stderr)

    # 排序
    if args.sort == "priority":
        tasks.sort(key=lambda t: PRIORITY_ORDER.get(t["priority"], 99))
    elif args.sort == "due":
        tasks.sort(key=lambda t: t["due"] or "9999-12-31")
    elif args.sort == "created":
        tasks.sort(key=lambda t: t.get("created", ""))

    if not tasks:
        print("📭 没有匹配的任务")
        return

    for t in tasks:
        status = "✅" if t["done"] else "⬜"
        due_str = f"  📅 {t['due']}" if t.get("due") else ""
        tags_str = f"  🏷️ {','.join(t['tags'])}" if t.get("tags") else ""
        print(f"{status} #{t['id']} [{t['priority'].upper()}] {t['title']}{due_str}{tags_str}")


def cmd_done(args):
    data = _load_data()
    if args.all_pending:
        count = 0
        for t in data["tasks"]:
            if not t["done"]:
                t["done"] = True
                count += 1
        _save_data(data)
        print(f"✅ 已完成 {count} 个待办任务")
    elif args.ids:
        ids = set(args.ids)
        matched = {t["id"] for t in data["tasks"]}
        not_found = ids - matched
        if not_found:
            print(f"⚠️  以下 ID 不存在: {sorted(not_found)}", file=sys.stderr)
        count = 0
        for t in data["tasks"]:
            if t["id"] in ids and not t["done"]:
                t["done"] = True
                count += 1
        _save_data(data)
        print(f"✅ 已完成 {count} 个任务")
    else:
        print("❌ 请指定 --ids 或 --all-pending", file=sys.stderr)
        sys.exit(1)


def cmd_delete(args):
    data = _load_data()
    ids = set(args.ids)
    matched = [t for t in data["tasks"] if t["id"] in ids]
    not_found = ids - {t["id"] for t in data["tasks"]}
    if not_found:
        print(f"⚠️  以下 ID 不存在: {sorted(not_found)}", file=sys.stderr)

    if not matched:
        print("❌ 未找到指定任务", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        for t in matched:
            print(f"🗑️  将删除 #{t['id']}: {t['title']}")
        return

    data["tasks"] = [t for t in data["tasks"] if t["id"] not in ids]
    _save_data(data)
    print(f"🗑️  已删除 {len(matched)} 个任务")


def cmd_stats(args):
    data = _load_data()
    tasks = data["tasks"]
    total = len(tasks)

    if total == 0:                          # #4: 提前返回避免除零
        print("📊 暂无任务")
        return

    done_count = sum(1 for t in tasks if t["done"])
    pending = total - done_count

    print("📊 任务统计")
    print(f"  总任务数: {total}")
    print(f"  待办: {pending}  |  完成: {done_count}  |  完成率: {done_count/total*100:.1f}%")

    # 按优先级
    print("\n📋 按优先级:")
    for p in ("high", "medium", "low"):
        pts = [t for t in tasks if t["priority"] == p]
        label = {"high": "高", "medium": "中", "low": "低"}[p]
        print(f"  {label}: {len(pts)} 个 ({sum(1 for t in pts if t['done'])} 完成)")

    # 按标签 (#10: 区分已完成/未完成)
    tag_stats: dict[str, dict[str, int]] = {}
    for t in tasks:
        for tag in t.get("tags", []):
            if tag not in tag_stats:
                tag_stats[tag] = {"total": 0, "done": 0}
            tag_stats[tag]["total"] += 1
            if t["done"]:
                tag_stats[tag]["done"] += 1
    if tag_stats:
        print("\n🏷️  按标签:")
        for tag, info in sorted(tag_stats.items(), key=lambda x: -x[1]["total"]):
            print(f"  {tag}: {info['total']} 个 ({info['done']} 完成)")

    # 逾期
    today = date.today().isoformat()
    overdue = [t for t in tasks if t.get("due") and t["due"] < today and not t["done"]]
    print(f"\n⏰ 逾期未完成: {len(overdue)} 个")
    for t in overdue:
        print(f"  #{t['id']} {t['title']} (截止 {t['due']})")


def cmd_export(args):
    data = _load_data()
    tasks = data["tasks"]

    if not tasks:
        print("📭 没有任务可导出")
        return                               # #8: 退出码 0

    fmt = args.format
    if fmt == "csv":
        out_path = args.output or "tasks_export.csv"
        with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
            writer = csv.writer(f)
            writer.writerow(["ID", "标题", "优先级", "标签", "截止日期", "状态", "创建日期"])
            for t in tasks:
                writer.writerow([
                    t["id"], t["title"], t["priority"],
                    ",".join(t.get("tags", [])),
                    t.get("due", ""), "完成" if t["done"] else "待办",
                    t.get("created", ""),
                ])
        print(f"📄 已导出 CSV: {out_path}")

    elif fmt == "markdown":
        out_path = args.output or "tasks_export.md"
        lines = ["# 任务列表", ""]
        for t in tasks:
            st = "✅" if t["done"] else "⬜"
            due = f" | 📅 {t['due']}" if t.get("due") else ""
            tags = f" | 🏷️ {', '.join(t['tags'])}" if t.get("tags") else ""
            lines.append(f"{st} #{t['id']} **[{t['priority'].upper()}]** {t['title']}{due}{tags}")
        Path(out_path).write_text("\n".join(lines), encoding="utf-8")
        print(f"📄 已导出 Markdown: {out_path}")


# ─── CLI ────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="task_tracker",
        description="轻量任务管理工具，数据存储在 ~/.task_tracker.json",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""示例:
  %(prog)s add "完成周报" --priority high --tag work --due 2026-04-10
  %(prog)s list --filter tag:work --sort priority
  %(prog)s done --ids 1 2 3
  %(prog)s stats
  %(prog)s export --format csv -o tasks.csv
""",
    )
    sub = parser.add_subparsers(dest="command")

    # add
    p = sub.add_parser("add", help="添加新任务")
    p.add_argument("title", help="任务标题")
    p.add_argument("--priority", choices=["high", "medium", "low"], default="medium")
    p.add_argument("--tag", action="append", help="标签（可多次指定）")
    p.add_argument("--due", help="截止日期 YYYY-MM-DD")

    # list
    p = sub.add_parser("list", help="列出任务")
    p.add_argument("--status", choices=["all", "pending", "done"], default="pending")
    p.add_argument("--filter", action="append", help="过滤条件，如 priority:high 或 tag:work")
    p.add_argument("--sort", choices=["priority", "due", "created"], default="created")

    # done (#6: --ids 与 --all-pending 互斥)
    p = sub.add_parser("done", help="标记任务完成")
    done_group = p.add_mutually_exclusive_group(required=True)
    done_group.add_argument("--ids", nargs="+", type=int, help="任务 ID")
    done_group.add_argument("--all-pending", action="store_true", help="完成所有待办")

    # delete (#7: 统一用 --ids)
    p = sub.add_parser("delete", help="删除任务")
    p.add_argument("--ids", nargs="+", type=int, required=True, help="要删除的任务 ID")
    p.add_argument("--dry-run", action="store_true", help="预览删除")

    # stats
    sub.add_parser("stats", help="查看统计")

    # export
    p = sub.add_parser("export", help="导出任务")
    p.add_argument("--format", choices=["csv", "markdown"], required=True)
    p.add_argument("-o", "--output", help="输出文件路径")

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    handlers = {
        "add": cmd_add,
        "list": cmd_list,
        "done": cmd_done,
        "delete": cmd_delete,
        "stats": cmd_stats,
        "export": cmd_export,
    }
    try:
        handlers[args.command](args)
    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
