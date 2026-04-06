"""Tina's supplementary tests for password_generator module.

Focus:
1. P0 #1 fix verification: SPECIAL must NOT contain quote characters (" ')
2. Uniqueness / randomness checks
3. Boundary cases: length=0, negative length, length=1, large length
4. Shuffle integrity: required chars not always at start
5. SPECIAL set completeness (no duplicates, all safe)
6. CLI edge cases
"""

import subprocess
import sys
import string
import unittest
from pathlib import Path

from password_generator import DIGITS, LETTERS, SPECIAL, generate_password

MODULE_PATH = Path(__file__).resolve().parent.parent / "password_generator.py"


class TestP0SpecialChars(unittest.TestCase):
    """P0 #1: SPECIAL must not contain quote characters that break shell/DB."""

    def test_special_no_single_quote(self):
        self.assertNotIn("'", SPECIAL)

    def test_special_no_double_quote(self):
        self.assertNotIn('"', SPECIAL)

    def test_special_no_backslash(self):
        # Backslash is also problematic in many contexts
        self.assertNotIn("\\", SPECIAL)

    def test_generated_password_no_quotes(self):
        """Generated passwords with special=True should never contain quotes."""
        for _ in range(100):
            pwd = generate_password(length=20, special=True)
            self.assertNotIn("'", pwd, f"Single quote in: {pwd}")
            self.assertNotIn('"', pwd, f"Double quote in: {pwd}")


class TestSpecialSetIntegrity(unittest.TestCase):
    """SPECIAL set should have no duplicates, be non-empty, and only printable."""

    def test_no_duplicates(self):
        self.assertEqual(len(SPECIAL), len(set(SPECIAL)))

    def test_all_printable(self):
        self.assertTrue(SPECIAL.isprintable())

    def test_non_empty(self):
        self.assertTrue(len(SPECIAL) > 0)

    def test_no_whitespace(self):
        self.assertFalse(any(c.isspace() for c in SPECIAL))


class TestBoundaryLengths(unittest.TestCase):
    """Test edge case lengths."""

    def test_length_1_single_charset(self):
        pwd = generate_password(length=1, digits=False)
        self.assertEqual(len(pwd), 1)
        self.assertTrue(c in LETTERS for c in pwd)

    def test_length_1_special_only(self):
        pwd = generate_password(length=1, letters=False, digits=False, special=True)
        self.assertEqual(len(pwd), 1)
        self.assertIn(pwd[0], SPECIAL)

    def test_length_equals_required_sets(self):
        """length == number of enabled sets should produce exact-length password."""
        pwd = generate_password(length=3, special=True)
        self.assertEqual(len(pwd), 3)

    def test_length_100(self):
        pwd = generate_password(length=100)
        self.assertEqual(len(pwd), 100)

    def test_negative_length_raises(self):
        with self.assertRaises(ValueError):
            generate_password(length=-1)

    def test_zero_length_raises(self):
        with self.assertRaises(ValueError):
            generate_password(length=0)


class TestShuffleIntegrity(unittest.TestCase):
    """Required chars should be shuffled, not always at the beginning."""

    def test_first_char_not_always_letter(self):
        """With letters+special, first char shouldn't always be a letter."""
        found_non_letter_first = False
        for _ in range(100):
            pwd = generate_password(length=5, special=True)
            if pwd[0] not in LETTERS:
                found_non_letter_first = True
                break
        self.assertTrue(found_non_letter_first, "First char was always a letter in 100 iterations")

    def test_first_char_not_always_digit(self):
        """With digits+special, first char shouldn't always be a digit."""
        found_non_digit_first = False
        for _ in range(100):
            pwd = generate_password(length=5, letters=False, special=True)
            if pwd[0] not in DIGITS:
                found_non_digit_first = True
                break
        self.assertTrue(found_non_digit_first, "First char was always a digit in 100 iterations")


class TestUniqueness(unittest.TestCase):
    """Generated passwords should not all be the same (basic randomness check)."""

    def test_passwords_not_identical(self):
        passwords = {generate_password() for _ in range(50)}
        # With 50 random 16-char passwords, we should get many distinct ones
        self.assertGreater(len(passwords), 40, "Too many duplicate passwords — randomness suspect")


class TestCLIEdgeCases(unittest.TestCase):
    """Additional CLI tests."""

    def test_cli_length_1(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--length", "1", "--no-digits"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.strip()), 1)

    def test_cli_length_too_short_error(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--length", "1", "--special"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Error", result.stderr)

    def test_cli_negative_length(self):
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "--length", "-5"],
            capture_output=True, text=True,
        )
        # argparse or generate_password should reject this
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
