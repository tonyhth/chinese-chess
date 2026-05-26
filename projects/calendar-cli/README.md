# calcli — macOS Calendar CLI

A command-line tool for managing macOS Calendar events. Built with Swift and EventKit.

## Installation

```bash
cd ~/DevTeam/projects/calendar-cli
swift build -c release
cp .build/release/calcli /usr/local/bin/calcli
```

**First run**: macOS will prompt for Calendar access. Grant it in *System Settings → Privacy & Security → Calendars* if missed.

## Usage

### Create an event

```bash
calcli add "Team Standup" --start "2026-04-21 10:00" --end "2026-04-21 10:30" \
  --calendar Work --location "Room A" --alert 15m --alert 1h
```

### Create an all-day event

```bash
# May 1–3 (inclusive: 3 days)
calcli add "Holiday" --start 2026-05-01 --end 2026-05-03 --all-day
```

### List events

```bash
calcli list                          # This week
calcli list --days 30                # Next 30 days
calcli list -c Work --days 14        # Work calendar, 2 weeks
calcli list -k "standup" --days 90   # Search by keyword
```

### Show event details

```bash
calcli show "Team Standup"
calcli show ABC123 --id              # Match by event ID
```

### Update an event

```bash
calcli update "Standup" --title "Daily Sync"
calcli update "Standup" --start "2026-04-21 09:30"
calcli update "Standup" --location ""   # Clear location
calcli update "Standup" -c Personal     # Move to another calendar
```

### Delete an event

```bash
calcli delete "Old Meeting"
calcli delete ABC123 --id --force       # Skip confirmation
```

### Manage alerts

```bash
calcli alert add "Standup" --time 30m
calcli alert add "Standup" --time @2026-04-21 09:00
calcli alert list "Standup"
calcli alert remove "Standup" --index 2
```

### JSON output

All commands support `--json`:

```bash
calcli --json list --days 7
```

## Date formats

| Input | Meaning |
|-------|---------|
| `2026-04-19` | Date only (midnight) |
| `2026-04-19 14:30` | Date + time |
| `today` / `tomorrow` | Relative |
| `now` | Current moment |
| `+3` / `+3d` | 3 days from today |
| `+1w` | 1 week from today |

## Alert formats

| Input | Meaning |
|-------|---------|
| `15m` | 15 minutes before |
| `1h` | 1 hour before |
| `2h30m` | 2 hours 30 minutes before |
| `1d` | 1 day before |
| `@2026-04-19 08:30` | Absolute time |

## Environment

- `NO_COLOR` — disable colored output (respects [no-color.org](https://no-color.org/))
- `--json` — machine-readable output, no colors

## License

Internal tool. See team knowledge base for conventions.
