#!/usr/bin/env python3
"""词频统计工具。读取文本文件，输出前 N 个高频词。"""

import argparse
import re
import sys
from collections import Counter

_WORD_RE = re.compile(r"[a-zA-Z]+")


def parse_words(text: str) -> Counter:
    return Counter(_WORD_RE.findall(text.lower()))


def count_words(file_path: str) -> Counter:
    counter = Counter()
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            counter.update(parse_words(line))
    return counter


def main():
    parser = argparse.ArgumentParser(description="词频统计工具")
    parser.add_argument("--file", required=True, help="输入文件路径")
    parser.add_argument("--top", type=int, default=10, help="输出前 N 个高频词（默认 10）")
    args = parser.parse_args()

    if args.top < 1:
        print("错误：--top 必须 >= 1", file=sys.stderr)
        sys.exit(1)

    try:
        counter = count_words(args.file)
    except FileNotFoundError:
        print(f"错误：文件不存在 - {args.file}", file=sys.stderr)
        sys.exit(1)
    except IsADirectoryError:
        print(f"错误：{args.file} 是目录，不是文件", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"错误：无权限读取 - {args.file}", file=sys.stderr)
        sys.exit(1)
    except UnicodeDecodeError:
        print(f"错误：文件编码非 UTF-8 - {args.file}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"错误：{e}", file=sys.stderr)
        sys.exit(1)

    # 按频次降序，同频按字母序
    sorted_words = sorted(counter.items(), key=lambda x: (-x[1], x[0]))

    for word, count in sorted_words[: args.top]:
        print(f"{word} {count}")


if __name__ == "__main__":
    main()
