#!/usr/bin/env python3
"""
开局库构建脚本
从 PGN 大师棋谱提取开局序列，生成 Zobrist hash 开局库。

输入：PGN 文件（ICCS 格式，走法如 C3-C4）
输出：opening_book_v2.json
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# ============================================================
# 配置
# ============================================================

MAX_DEPTH = 10          # 提取前 10 步（5 个完整回合）
MIN_FREQUENCY = 5       # 走法出现 < 5 次的丢弃
MAX_MOVES_PER_POS = 5   # 每个局面最多保留 5 个候选走法

# ============================================================
# Zobrist Hash（Python 复刻 Swift SplitMix64，确保一致性）
# ============================================================

class SplitMix64:
    """与 Swift 端 ZobristHash.SplitMix64 完全一致的 PRNG"""
    MASK64 = (1 << 64) - 1

    def __init__(self, seed: int):
        self.state = seed & self.MASK64

    def next(self) -> int:
        z = (self.state + 0x9E3779B97F4A7C15) & self.MASK64
        self.state = z
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & self.MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & self.MASK64
        return (z ^ (z >> 31)) & self.MASK64


def build_zobrist_table():
    """构建 14×90 随机数表，与 Swift ZobristHash.table 一致"""
    rng = SplitMix64(0x12345678_9ABCDEF0)
    table = []
    for _ in range(14):
        row = [rng.next() for _ in range(90)]
        table.append(row)
    return table


def build_side_hash():
    """行走方切换异或值，与 Swift ZobristHash.sideHash 一致"""
    rng = SplitMix64(0xFEDCBA98_76543210)
    return rng.next()


ZOBRIST_TABLE = build_zobrist_table()
SIDE_HASH = build_side_hash()

# 棋子索引映射（与 Swift pieceIndex 一致）
# general=0, advisor=1, elephant=2, horse=3, chariot=4, cannon=5, soldier=6
# Red: 0-6, Black: 7-13
PIECE_INDEX_MAP = {
    ('general', 'red'): 0, ('advisor', 'red'): 1, ('elephant', 'red'): 2,
    ('horse', 'red'): 3, ('chariot', 'red'): 4, ('cannon', 'red'): 5, ('soldier', 'red'): 6,
    ('general', 'black'): 7, ('advisor', 'black'): 8, ('elephant', 'black'): 9,
    ('horse', 'black'): 10, ('chariot', 'black'): 11, ('cannon', 'black'): 12, ('soldier', 'black'): 13,
}

# ============================================================
# 棋盘模拟（最小实现，用于计算 Zobrist hash）
# ============================================================

# row 0 = 黑方底线 (ICCS 行号 9)
# row 9 = 红方底线 (ICCS 行号 0)
INITIAL_BOARD = [
    # row 0: 车 马 象 士 将 士 象 马 车 (黑方)
    [('chariot','black'), ('horse','black'), ('elephant','black'), ('advisor','black'),
     ('general','black'), ('advisor','black'), ('elephant','black'), ('horse','black'), ('chariot','black')],
    [None]*9,                                                                   # row 1
    [None, ('cannon','black'), None, None, None, None, None, ('cannon','black'), None],  # row 2
    [('soldier','black'), None, ('soldier','black'), None, ('soldier','black'),
     None, ('soldier','black'), None, ('soldier','black')],                     # row 3
    [None]*9,                                                                   # row 4
    [None]*9,                                                                   # row 5
    [('soldier','red'), None, ('soldier','red'), None, ('soldier','red'),
     None, ('soldier','red'), None, ('soldier','red')],                         # row 6
    [None, ('cannon','red'), None, None, None, None, None, ('cannon','red'), None],  # row 7
    [None]*9,                                                                   # row 8
    [('chariot','red'), ('horse','red'), ('elephant','red'), ('advisor','red'),
     ('general','red'), ('advisor','red'), ('elephant','red'), ('horse','red'), ('chariot','red')],  # row 9
]


def board_to_hash(board, is_black_turn=False):
    """计算棋盘的 Zobrist hash"""
    h = 0
    for row in range(10):
        for col in range(9):
            piece = board[row][col]
            if piece:
                kind, side = piece
                pi = PIECE_INDEX_MAP[(kind, side)]
                posi = row * 9 + col
                h ^= ZOBRIST_TABLE[pi][posi]
    if is_black_turn:
        h ^= SIDE_HASH
    return h


def iccs_to_pos(iccs: str):
    """ICCS 小写无连字符 → (from_row, from_col, to_row, to_col)
    列 a→col 0, i→col 8; 行 row = 9 - digit
    """
    from_col = ord(iccs[0]) - ord('a')
    from_row = 9 - int(iccs[1])
    to_col = ord(iccs[2]) - ord('a')
    to_row = 9 - int(iccs[3])
    return from_row, from_col, to_row, to_col


def apply_move(board, iccs: str):
    """在棋盘上执行走法，返回新棋盘（深拷贝）。失败时 raise ValueError。"""
    new_board = [row[:] for row in board]
    fr, fc, tr, tc = iccs_to_pos(iccs)
    # 边界检查
    if not (0 <= fr <= 9 and 0 <= fc <= 8 and 0 <= tr <= 9 and 0 <= tc <= 8):
        raise ValueError(f"Out of bounds move: {iccs}")
    piece = new_board[fr][fc]
    if piece is None:
        raise ValueError(f"No piece at ({fr},{fc}) for move {iccs}")
    new_board[fr][fc] = None
    new_board[tr][tc] = piece
    return new_board


# ============================================================
# PGN 解析
# ============================================================

# ICCS 带连字符: C3-C4, h2-e2
MOVE_PATTERN_ICCS = re.compile(r'\b([A-Ia-i]\d)-([A-Ia-i]\d)\b')
# UCI 无连字符: c3c4, h2e2 (4位字母数字紧凑格式)
MOVE_PATTERN_UCI = re.compile(r'\b([a-i]\d)([a-i]\d)\b')


def parse_pgn_iccs(move_str: str) -> str:
    """PGN ICCS 格式 → 项目内部格式
    'C3-C4' → 'c3c4'
    """
    return move_str.strip().replace('-', '').lower()


def extract_moves_from_pgn(pgn_text: str) -> list:
    """从 PGN 文本提取走法序列（ICCS 或 UCI 格式，统一转为小写无连字符）"""
    moves = []
    # 先尝试 ICCS 带连字符格式 (C3-C4)
    for match in MOVE_PATTERN_ICCS.finditer(pgn_text):
        raw = match.group(0)
        iccs = parse_pgn_iccs(raw)
        moves.append(iccs)
    # 如果没找到 ICCS 格式，尝试 UCI 无连字符格式 (c3c4)
    if not moves:
        for match in MOVE_PATTERN_UCI.finditer(pgn_text):
            raw = match.group(0)
            moves.append(raw.strip().lower())
    return moves


def parse_pgn_file(filepath: str) -> list:
    """解析单个 PGN 文件，返回所有棋谱的走法列表"""
    games = []
    current_game = []

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('['):
                continue
            if not line:
                if current_game:
                    games.append(current_game)
                    current_game = []
                continue
            moves = extract_moves_from_pgn(line)
            current_game.extend(moves)

    if current_game:
        games.append(current_game)

    return games


# ============================================================
# 开局库构建
# ============================================================

def build_opening_book(pgn_files: list, max_depth: int = MAX_DEPTH,
                       min_freq: int = MIN_FREQUENCY,
                       max_moves: int = MAX_MOVES_PER_POS) -> dict:
    """
    从 PGN 文件构建开局库。
    返回: { zobrist_hash_hex: [{"move": "c3c4", "w": 2847}, ...] }
    """
    position_moves = defaultdict(lambda: defaultdict(int))
    total_games = 0
    skipped_moves = 0

    for pgn_file in pgn_files:
        print(f"Processing: {pgn_file}")
        games = parse_pgn_file(pgn_file)
        total_games += len(games)

        for game_moves in games:
            board = [row[:] for row in INITIAL_BOARD]
            is_black_turn = False

            for move in game_moves[:max_depth]:
                pos_hash = board_to_hash(board, is_black_turn=is_black_turn)
                pos_hash_hex = f"0x{pos_hash:016X}"
                position_moves[pos_hash_hex][move] += 1

                try:
                    board = apply_move(board, move)
                    is_black_turn = not is_black_turn
                except (IndexError, ValueError):
                    skipped_moves += 1
                    break

    print(f"Total games processed: {total_games}")
    print(f"Unique positions: {len(position_moves)}")
    if skipped_moves:
        print(f"Skipped illegal moves: {skipped_moves}")

    # 筛选
    result = {}
    for pos_hash, moves in position_moves.items():
        filtered = {m: w for m, w in moves.items() if w >= min_freq}
        if not filtered:
            continue
        sorted_moves = sorted(filtered.items(), key=lambda x: -x[1])[:max_moves]
        result[pos_hash] = [{"move": m, "w": w} for m, w in sorted_moves]

    print(f"Positions after filtering (min_freq={min_freq}): {len(result)}")
    return result


# ============================================================
# 验证
# ============================================================

def verify_hash_consistency():
    """验证 Python 端 hash 与 Swift 端一致"""
    initial_hash = board_to_hash(INITIAL_BOARD, is_black_turn=False)
    expected = 0xC7A374A5ABC843D2
    if initial_hash != expected:
        print(f"ERROR: Initial board hash mismatch!")
        print(f"  Expected: 0x{expected:016X}")
        print(f"  Got:      0x{initial_hash:016X}")
        sys.exit(1)
    print(f"Initial board hash verified: 0x{initial_hash:016X}")

    # 走一步 h2e2 后
    board = [row[:] for row in INITIAL_BOARD]
    board = apply_move(board, 'h2e2')
    hash_after_h2e2 = board_to_hash(board, is_black_turn=True)
    print(f"After h2e2: 0x{hash_after_h2e2:016X}")

    # 再走 b9c7
    board = apply_move(board, 'b9c7')
    hash_after_b9c7 = board_to_hash(board, is_black_turn=False)
    print(f"After h2e2 b9c7: 0x{hash_after_b9c7:016X}")


# ============================================================
# 主入口
# ============================================================

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Build opening book from PGN files')
    parser.add_argument('--verify', action='store_true', help='Run hash consistency verification only')
    parser.add_argument('--output', '-o', default=None, help='Output JSON path')
    parser.add_argument('--input', '-i', nargs='+', default=[], help='PGN input files/dirs')
    parser.add_argument('--min-count', type=int, default=MIN_FREQUENCY, help='Minimum move frequency')
    parser.add_argument('--max-depth', type=int, default=MAX_DEPTH, help='Maximum moves to extract per game')
    args = parser.parse_args()

    if args.verify:
        verify_hash_consistency()
        return

    if not args.output or not args.input:
        print("Usage: build_opening_book.py -o output.json -i pgn_file1 [pgn_file2 ...]")
        print("       build_opening_book.py --verify")
        sys.exit(1)

    # 展开目录
    pgn_files = []
    for path in args.input:
        p = Path(path)
        if p.is_dir():
            pgn_files.extend(str(f) for f in sorted(p.rglob('*.pgn')))
        else:
            pgn_files.append(str(p))

    if not pgn_files:
        print("No PGN files found")
        sys.exit(1)

    print(f"Found {len(pgn_files)} PGN file(s)")

    # 先验证 hash
    verify_hash_consistency()

    # 构建
    entries = build_opening_book(pgn_files, max_depth=args.max_depth,
                                  min_freq=args.min_count)

    output = {
        "version": 2,
        "description": f"Auto-generated from {len(pgn_files)} PGN file(s), {len(entries)} positions",
        "entries": entries
    }

    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    file_size = Path(args.output).stat().st_size
    print(f"Written to: {args.output}")
    print(f"Total entries: {len(entries)}")
    print(f"File size: {file_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
