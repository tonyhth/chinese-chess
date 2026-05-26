# rem — Apple Reminders CLI

A command-line tool for Apple Reminders, written in Swift. Direct EventKit integration, zero third-party runtime dependencies.

Replaces [remindctl](https://github.com/steipete/remindctl) with better output, proper error handling, and multi-match safety.

## Install

```bash
git clone https://github.com/tonyhth/remind-cli.git
cd remind-cli
make install
```

Or manually:

```bash
swift build -c release
cp .build/release/rem /usr/local/bin/rem
```

**Note:** First run requires macOS GUI session to grant Calendar access. SSH-only environments won't work for initial authorization.

## Usage

```bash
rem list                          # List incomplete reminders
rem list --all                    # Include completed
rem list --list Groceries --json  # Filter by list, JSON output

rem lists                         # Show all lists
rem lists --json                  # JSON format

rem add "Buy milk"                # Add to default list (auto-dedup)
rem add "Buy milk" --force        # Skip dedup check
rem add "Meeting" --due tomorrow --priority high --notes "Room 3A"

rem complete <id|keyword>         # Complete a reminder
rem uncomplete <id|keyword>       # Undo completion
rem update <id|keyword> --due +3  # Change due date (+3 days)
rem delete <id|keyword>           # Delete

rem search milk                   # Search by keyword
rem search milk --all --json      # Include completed, JSON output
```

### Date Formats

- `2026-04-15` or `2026/04/15` — absolute date
- `today`, `tomorrow` — relative keywords
- `+3` — 3 days from now (also accepts `+3d`)

### Priority

`high`, `medium`, `low`, `none`

### Multi-Match Safety

When a keyword matches multiple reminders, `rem` lists candidates and asks you to use the full ID:

```
❌ Multiple matches for "meeting":
  ABC12345 | Work | Team meeting
  DEF67890 | Work | Client meeting
Use full ID to specify.
```

### JSON Output

All list/search commands support `--json` with snake_case keys:

```json
[
  {
    "completed": false,
    "creation_date": "2026-04-15 10:30",
    "due_date": "2026-04-16",
    "id": "ABC12345...",
    "list": "Groceries",
    "notes": null,
    "priority": 9,
    "priority_name": "low",
    "title": "Buy milk"
  }
]
```

## Differences from remindctl

- Proper `update` subcommand
- Multi-match safety (no silent first-match)
- Exact dedup (no substring false positives)
- `--version` support
- ArgumentParser for robust flag handling
- Protocol-based store for testability

## Development

```bash
swift build          # Debug build
swift build -c release  # Optimized build
swift test           # Run tests
make install         # Build + install
```

Requires Swift 5.9+, macOS 14+.

## License

MIT
