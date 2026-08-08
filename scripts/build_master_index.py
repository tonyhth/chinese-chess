#!/usr/bin/env python3
"""构建大师对局索引。使用二进制模式确保字节偏移准确。

用法：
    python3 build_master_index.py --pgn <pgn_file> [--output <index.json>] [--stats <stats.json>] [--name-map <name_map.json>] [--template <template.json>]

输出：
    master-game-index.json — 40,711 条 MasterGameIndex（含 pgnOffset + pgnLength + redNameCN/blackNameCN + year + firstMoves）
    master-stats.json — 棋手排行榜 + 赛事统计 + 开局分布
    name_map_template.json — 所有独立棋手名（按出场次数排序），供人工补全中文名
"""

import json
import re
import hashlib
import sys
import argparse
from pathlib import Path


def parse_single_game_tags(text: str) -> dict:
    """从单局 PGN 文本中提取标签。"""
    return dict(re.findall(r'\[(\w+)\s+"([^"]*)"\]', text))


def extract_year(event: str) -> int | None:
    """从 Event 标签中提取年份。"""
    years = re.findall(r'\b(19[5-9]\d|20[0-2]\d)\b', event)
    return int(years[-1]) if years else None


def count_moves(moves_section: str) -> int:
    """统计走法数，使用与 PGNImporter 相同的 token 过滤逻辑。"""
    text = re.sub(r'\{[^}]*\}', '', moves_section)
    text = re.sub(r'\([^)]*\)', '', text)
    text = re.sub(r'[;%].*', '', text)
    text = re.sub(r'1-0|0-1|1/2-1/2|\*', '', text)
    text = re.sub(r'\d+\.+\s*', '', text)
    moves = re.findall(r'[a-i]\d[a-i]\d', text)
    return len(moves)


def extract_first_moves(moves_section: str, n: int = 5) -> list[str]:
    """提取前 N 步走法（ICCS 格式）。"""
    text = re.sub(r'\{[^}]*\}', '', moves_section)
    text = re.sub(r'\([^)]*\)', '', text)
    text = re.sub(r'[;%].*', '', text)
    text = re.sub(r'1-0|0-1|1/2-1/2|\*', '', text)
    text = re.sub(r'\d+\.+\s*', '', text)
    moves = re.findall(r'[a-i]\d[a-i]\d', text)
    return moves[:n]


def normalize_name(raw: str) -> str:
    """归一化棋手名。全大写模式（ZHAO GUORONG）→ title case（Zhao Guorong）。
    其他情况保持原样。"""
    # 先 strip
    name = raw.strip()
    # 全大写 → title case
    if name.isupper() and any(c.isalpha() for c in name):
        return name.title()
    return name


def build_index(pgn_path: str, output_path: str, stats_path: str,
                name_map_path: str | None = None, template_path: str | None = None):
    """构建大师对局索引（二进制模式，确保字节偏移准确）。"""

    # 加载棋手名映射（如果已有）
    name_map = {}
    if name_map_path and Path(name_map_path).exists():
        with open(name_map_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            name_map = data.get('mapping', {})

    # 映射表用小写键查找，确保大小写无关
    name_map_lower = {k.lower(): v for k, v in name_map.items()}

    # 赛事名映射
    event_map = {}
    event_map_path = str(Path(name_map_path).parent / "event_map.json") if name_map_path else None
    if event_map_path and Path(event_map_path).exists():
        with open(event_map_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            event_map = data.get('mapping', {})
    event_map_lower = {k.lower(): v for k, v in event_map.items()}

    games = []
    player_stats = {}    # normalized_name → count
    event_stats = {}     # event → count
    opening_stats = {}   # firstMove → count

    # ★ 关键：二进制模式打开，f.tell() 返回真实字节偏移
    with open(pgn_path, 'rb') as f:
        file_size = Path(pgn_path).stat().st_size

        while f.tell() < file_size:
            game_start = f.tell()

            # 读取标签段
            header_lines = []
            while True:
                pos = f.tell()
                line = f.readline()
                if not line:
                    break
                decoded = line.decode('utf-8', errors='replace').rstrip('\r\n')
                if decoded.startswith('['):
                    header_lines.append(decoded)
                elif decoded.strip() == '' and header_lines:
                    break
                elif decoded.strip() == '':
                    continue
                else:
                    f.seek(pos)
                    break

            if not header_lines:
                continue

            # 读取走法段
            move_lines = []
            while True:
                pos = f.tell()
                line = f.readline()
                if not line:
                    break
                decoded = line.decode('utf-8', errors='replace').rstrip('\r\n')
                if decoded.startswith('['):
                    f.seek(pos)
                    break
                if decoded.strip() == '' and move_lines:
                    next_pos = f.tell()
                    next_line = f.readline()
                    if not next_line:
                        break
                    next_decoded = next_line.decode('utf-8', errors='replace').rstrip('\r\n')
                    if next_decoded.startswith('['):
                        f.seek(next_pos)
                        break
                    else:
                        move_lines.append(decoded)
                        move_lines.append(next_decoded)
                else:
                    if decoded.strip():
                        move_lines.append(decoded)

            game_end = f.tell()
            game_length = game_end - game_start

            # 解析标签
            header_text = '\n'.join(header_lines)
            headers = parse_single_game_tags(header_text)

            # 解析走法信息
            moves_text = '\n'.join(move_lines)
            move_count = count_moves(moves_text)
            first_move_list = extract_first_moves(moves_text, 5)
            first_move = first_move_list[0] if first_move_list else ''

            # 提取年份
            event = headers.get('Event', '未知赛事')
            # 清理嵌套引号（PGN 中 Event 标签可能包含嵌套双引号）
            event = event.replace('\"', '').strip('"').strip()
            while '""' in event:
                event = event.replace('""', '"')
            event = event.strip('"').strip()
            year = extract_year(event)

            # 棋手名（归一化后查映射表）
            red_name = normalize_name(headers.get('Red', '未知'))
            black_name = normalize_name(headers.get('Black', '未知'))
            red_name_cn = name_map_lower.get(red_name.lower(), "")
            black_name_cn = name_map_lower.get(black_name.lower(), "")

            # 赛事中文名
            event_cn = event_map_lower.get(event.lower(), "")

            games.append({
                'id': len(games),
                'event': event,
                'redName': red_name,
                'blackName': black_name,
                'redNameCN': red_name_cn or None,
                'blackNameCN': black_name_cn or None,
                'eventCN': event_cn or None,
                'year': year,
                'firstMove': first_move,
                'firstMoves': first_move_list,
                'moveCount': move_count,
                'pgnOffset': game_start,
                'pgnLength': game_length,
            })

            # 统计
            if red_name and red_name != '未知':
                player_stats[red_name] = player_stats.get(red_name, 0) + 1
            if black_name and black_name != '未知':
                player_stats[black_name] = player_stats.get(black_name, 0) + 1
            if event and event != '未知赛事':
                event_stats[event] = event_stats.get(event, 0) + 1
            if first_move:
                opening_stats[first_move] = opening_stats.get(first_move, 0) + 1

    # PGN 文件哈希（前 1KB）
    with open(pgn_path, 'rb') as f:
        head = f.read(1024)
    pgn_hash = hashlib.sha256(head).hexdigest()

    # 写入索引
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            'version': 2,
            'pgnHash': pgn_hash,
            'totalGames': len(games),
            'games': games,
        }, f, ensure_ascii=False)

    # 写入统计
    top_players = sorted(player_stats.items(), key=lambda x: -x[1])[:100]
    top_events = sorted(event_stats.items(), key=lambda x: -x[1])[:50]

    with open(stats_path, 'w', encoding='utf-8') as f:
        json.dump({
            'totalGames': len(games),
            'players': [{'name': k, 'nameCN': name_map_lower.get(k.lower(), None) or None, 'count': v}
                        for k, v in top_players],
            'events': [{'name': k, 'nameCN': event_map_lower.get(k.lower(), None) or None,
                        'year': extract_year(k), 'count': v}
                       for k, v in top_events],
            'openingDistribution': {k: v for k, v in
                                     sorted(opening_stats.items(), key=lambda x: -x[1])},
        }, f, ensure_ascii=False, indent=2)

    # 输出棋手名映射模板
    if template_path:
        all_players = sorted(player_stats.items(), key=lambda x: -x[1])
        with open(template_path, 'w', encoding='utf-8') as f:
            json.dump({
                'version': 1,
                'pgnHash': pgn_hash,
                'unmapped': [{'name': k, 'count': v, 'mappedCN': name_map_lower.get(k.lower(), '')}
                             for k, v in all_players if k.lower() not in name_map_lower],
                'mapping': {k: v for k, v in name_map.items()},
            }, f, ensure_ascii=False, indent=2)

    print(f"索引构建完成：{len(games)} 局")
    print(f"独立棋手：{len(player_stats)} 名")
    print(f"独立赛事：{len(event_stats)} 个")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='构建大师对局索引')
    parser.add_argument('--pgn', required=True, help='PGN 文件路径')
    parser.add_argument('--output', default='master-game-index.json', help='索引输出路径')
    parser.add_argument('--stats', default='master-stats.json', help='统计输出路径')
    parser.add_argument('--name-map', default='name_map.json', help='棋手名映射文件路径')
    parser.add_argument('--template', default='name_map_template.json', help='棋手名映射模板输出路径')
    args = parser.parse_args()

    build_index(args.pgn, args.output, args.stats, args.name_map, args.template)
