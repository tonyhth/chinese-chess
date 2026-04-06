#!/usr/bin/env python3
"""Password generator module using cryptographically secure random."""

import argparse
import secrets
import string
import sys

LETTERS = string.ascii_letters
DIGITS = string.digits
SPECIAL = "!@#$%^&*()-_=+[]{}|<>?/~`"


def generate_password(length: int = 16, letters: bool = True, digits: bool = True, special: bool = False) -> str:
    """Generate a random password.

    Args:
        length: Desired password length (>= number of enabled character sets).
        letters: Whether to include ASCII letters (a-zA-Z).
        digits: Whether to include digits (0-9).
        special: Whether to include special characters.

    Returns:
        Randomly generated password of the specified length.

    Raises:
        ValueError: If no character set is enabled or length is too short
            to guarantee at least one character per enabled set.
    """
    charset = ""
    required_chars = []

    if letters:
        charset += LETTERS
        required_chars.append(secrets.choice(LETTERS))
    if digits:
        charset += DIGITS
        required_chars.append(secrets.choice(DIGITS))
    if special:
        charset += SPECIAL
        required_chars.append(secrets.choice(SPECIAL))

    if not charset:
        raise ValueError("At least one character set must be enabled")

    if length < len(required_chars):
        raise ValueError(f"Length {length} is too short for {len(required_chars)} enabled character sets")

    # Fill remaining length with random choices from full charset
    remaining = [secrets.choice(charset) for _ in range(length - len(required_chars))]
    password_chars = required_chars + remaining
    # Use SystemRandom.shuffle to securely randomize character order
    secrets.SystemRandom().shuffle(password_chars)
    return "".join(password_chars)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Generate a random password")
    parser.add_argument("--length", type=int, default=16, help="Password length (default: 16)")
    parser.add_argument("--no-letters", action="store_true", help="Exclude letters")
    parser.add_argument("--no-digits", action="store_true", help="Exclude digits")
    parser.add_argument("--special", action="store_true", help="Include special characters")
    parser.add_argument("--no-special", action="store_true", help="Exclude special characters")
    args = parser.parse_args(argv)

    try:
        print(generate_password(
            length=args.length,
            letters=not args.no_letters,
            digits=not args.no_digits,
            special=args.special and not args.no_special,
        ))
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
