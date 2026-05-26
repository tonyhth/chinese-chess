import Foundation

/// Parses alert specifications for calendar events.
///
/// Relative formats: `"15m"`, `"1h"`, `"2h30m"`, `"1d"` → negative offset in seconds.
/// Absolute format: `"@2026-04-19 08:30"` → specific date/time.
public enum AlertParser {
    /// Parsed alert specification.
    public enum AlertSpec {
        /// Relative alert: N seconds before the event (negative value).
        case relative(offset: TimeInterval)
        /// Absolute alert: fires at a specific date/time.
        case absolute(date: Date)
    }

    /// Parse an alert string into an `AlertSpec`. Returns `nil` for invalid input.
    public static func parse(_ input: String) -> AlertSpec? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("@") {
            let dateStr = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            if let d = DateParser.parse(dateStr) {
                return .absolute(date: d)
            }
            return nil
        }

        var remaining = trimmed[...]
        var totalSeconds: TimeInterval = 0
        var found = false

        while !remaining.isEmpty {
            let numEnd = remaining.firstIndex(where: { !$0.isNumber }) ?? remaining.endIndex
            guard numEnd != remaining.startIndex else { return nil }
            guard let value = Double(remaining[..<numEnd]) else { return nil }

            let unitStart = numEnd
            let unitEnd = remaining[unitStart...].firstIndex(where: { $0.isNumber }) ?? remaining.endIndex
            let unit = remaining[unitStart..<unitEnd]

            switch unit {
            case "d":
                totalSeconds += value * 86400
            case "h":
                totalSeconds += value * 3600
            case "m":
                totalSeconds += value * 60
            default:
                return nil
            }
            found = true
            remaining = remaining[unitEnd...]
        }

        guard found else { return nil }
        return .relative(offset: -totalSeconds)
    }

    /// Format a relative offset (negative seconds) back to a human-readable string like `"2h30m"`.
    public static func formatOffset(_ seconds: TimeInterval) -> String {
        let absSec = Int(abs(seconds))
        if absSec >= 86400 && absSec % 86400 == 0 {
            return "\(absSec / 86400)d"
        }
        if absSec >= 3600 && absSec % 3600 == 0 {
            return "\(absSec / 3600)h"
        }
        let h = absSec / 3600
        let m = (absSec % 3600) / 60
        if h > 0 && m > 0 {
            return "\(h)h\(m)m"
        }
        if absSec >= 60 && absSec % 60 == 0 {
            return "\(absSec / 60)m"
        }
        return "\(absSec) seconds"
    }
}
