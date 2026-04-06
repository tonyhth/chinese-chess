"""Tests for password_generator module."""

import subprocess
import sys
import unittest
from pathlib import Path

from password_generator import DIGITS, LETTERS, SPECIAL, generate_password

MODULE_PATH = Path(__file__).resolve().parent.parent / "password_generator.py"


class TestGeneratePassword(unittest.TestCase):

    # --- Default parameters ---

    def test_default_length(self):
        self.assertEqual(len(generate_password()), 16)

    def test_default_contains_letters_and_digits(self):
        pwd = generate_password()
        self.assertTrue(any(c in LETTERS for c in pwd))
        self.assertTrue(any(c in DIGITS for c in pwd))

    # --- Custom length ---

    def test_custom_length(self):
        for n in [8, 32, 64]:
            self.assertEqual(len(generate_password(length=n)), n)

    # --- Special characters ---

    def test_special_included(self):
        pwd = generate_password(length=20, special=True)
        self.assertTrue(any(c in SPECIAL for c in pwd))
        self.assertTrue(any(c in LETTERS for c in pwd))
        self.assertTrue(any(c in DIGITS for c in pwd))

    # --- Single charset ---

    def test_letters_only(self):
        pwd = generate_password(length=10, digits=False)
        self.assertTrue(all(c in LETTERS for c in pwd))

    def test_digits_only(self):
        pwd = generate_password(length=10, letters=False)
        self.assertTrue(all(c in DIGITS for c in pwd))

    def test_special_only(self):
        pwd = generate_password(length=10, letters=False, digits=False, special=True)
        self.assertTrue(all(c in SPECIAL for c in pwd))

    # --- Minimum one char per enabled set ---

    def test_minimum_one_letter(self):
        for _ in range(50):
            pwd = generate_password(length=3, special=True)
            self.assertTrue(any(c in LETTERS for c in pwd), f"No letter in: {pwd}")

    def test_minimum_one_digit(self):
        for _ in range(50):
            pwd = generate_password(length=3, special=True)
            self.assertTrue(any(c in DIGITS for c in pwd), f"No digit in: {pwd}")

    def test_minimum_one_special(self):
        for _ in range(50):
            pwd = generate_password(length=3, special=True)
            self.assertTrue(any(c in SPECIAL for c in pwd), f"No special in: {pwd}")

    # --- Edge cases ---

    def test_no_charset_enabled_raises(self):
        with self.assertRaises(ValueError):
            generate_password(letters=False, digits=False)

    def test_length_too_short_raises(self):
        with self.assertRaises(ValueError):
            generate_password(length=1, letters=True, digits=True)

    # --- CLI ---

    def test_cli_default(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.strip()), 16)

    def test_cli_custom_length(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--length", "32"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.strip()), 32)

    def test_cli_special(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--special", "--length", "20"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        pwd = result.stdout.strip()
        self.assertTrue(any(c in SPECIAL for c in pwd))

    def test_cli_no_letters(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--no-letters"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        pwd = result.stdout.strip()
        self.assertTrue(all(c in DIGITS for c in pwd))

    def test_cli_error_no_charset(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--no-letters", "--no-digits"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
