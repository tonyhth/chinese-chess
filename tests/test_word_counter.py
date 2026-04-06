"""word_counter.py 测试 — Tina"""

import subprocess
import sys
import tempfile
import os
import pytest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "word_counter.py")


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True, text=True, timeout=10,
    )


# ── 单元级：parse_words / count_words ──────────────────────────

class TestParseWords:
    def _parse(self, text):
        # 直接导入函数测试
        sys.path.insert(0, os.path.dirname(SCRIPT))
        from word_counter import parse_words
        sys.path.pop(0)
        return parse_words(text)

    def test_basic(self):
        c = self._parse("Hello hello HELLO world")
        assert c["hello"] == 3 and c["world"] == 1

    def test_empty(self):
        c = self._parse("")
        assert len(c) == 0

    def test_numbers_and_punctuation_stripped(self):
        c = self._parse("abc123!@# def")
        assert c == {"abc": 1, "def": 1}

    def test_unicode_ignored(self):
        c = self._parse("你好 hello 世界")
        assert c == {"hello": 1}

    def test_case_insensitive(self):
        c = self._parse("Python python PYTHON")
        assert c["python"] == 3


# ── 集成级：CLI 错误路径 ─────────────────────────────────────

class TestCLI:
    def test_no_args(self, tmp_path):
        r = run()
        assert r.returncode != 0

    def test_file_not_found(self):
        r = run("--file", "/tmp/nonexistent_xyz.txt")
        assert r.returncode == 1
        assert "文件不存在" in r.stderr

    def test_top_zero(self, tmp_path):
        f = tmp_path / "a.txt"
        f.write_text("hello")
        r = run("--file", str(f), "--top", "0")
        assert r.returncode == 1
        assert "--top 必须 >= 1" in r.stderr

    def test_top_negative(self, tmp_path):
        f = tmp_path / "a.txt"
        f.write_text("hello")
        r = run("--file", str(f), "--top", "-3")
        assert r.returncode == 1

    def test_directory_path(self, tmp_path):
        r = run("--file", str(tmp_path))
        assert r.returncode == 1
        assert "目录" in r.stderr

    def test_non_utf8_file(self, tmp_path):
        f = tmp_path / "bin.dat"
        f.write_bytes(b'\xff\xfe\xfd')
        r = run("--file", str(f))
        assert r.returncode == 1
        assert "UTF-8" in r.stderr


# ── 集成级：正常功能 ─────────────────────────────────────────

class TestFunctional:
    def test_basic_top(self, tmp_path):
        f = tmp_path / "t.txt"
        f.write_text("apple banana apple cherry banana apple")
        r = run("--file", str(f), "--top", "5")
        assert r.returncode == 0
        lines = r.stdout.strip().splitlines()
        assert lines[0] == "apple 3"
        assert lines[1] == "banana 2"
        assert lines[2] == "cherry 1"

    def test_top_truncation(self, tmp_path):
        f = tmp_path / "t.txt"
        f.write_text("a b c d e f")
        r = run("--file", str(f), "--top", "3")
        assert r.returncode == 0
        assert len(r.stdout.strip().splitlines()) == 3

    def test_tie_sorted_alphabetically(self, tmp_path):
        f = tmp_path / "t.txt"
        f.write_text("z y x a b c")
        r = run("--file", str(f), "--top", "10")
        assert r.returncode == 0
        words = [l.split()[0] for l in r.stdout.strip().splitlines()]
        assert words == ["a", "b", "c", "x", "y", "z"]

    def test_empty_file(self, tmp_path):
        f = tmp_path / "empty.txt"
        f.write_text("")
        r = run("--file", str(f))
        assert r.returncode == 0
        assert r.stdout.strip() == ""

    def test_large_input(self, tmp_path):
        f = tmp_path / "big.txt"
        f.write_text("hello " * 10000 + "world\n")
        r = run("--file", str(f), "--top", "2")
        assert r.returncode == 0
        assert "hello 10000" in r.stdout
        assert "world 1" in r.stdout

    def test_default_top_10(self, tmp_path):
        """不传 --top 时默认输出 10 条"""
        f = tmp_path / "t.txt"
        words = ["apple","banana","cherry","date","elderberry","fig","grape","honeydew","kiwi","lemon","mango","nectarine","orange","pear","quince"]
        f.write_text(" ".join(words))
        r = run("--file", str(f))
        assert r.returncode == 0
        assert len(r.stdout.strip().splitlines()) == 10
