import Foundation

/// Parses date/time strings into `Date` values.
///
/// Supported formats:
/// - Absolute: `"2026-04-19"`, `"2026-04-19 14:30"`, `"2026/04/19"`
/// - Relative: `"today"`, `"tomorrow"`, `"now"`
/// - Offset: `"+3"`, `"+3d"`, `"+1w"`
public enum DateParser {
    /// Parse a date/time string into a `Date`. Returns `nil` for unrecognized formats.
    public static func parse(_ input: String) -> Date? {
        let cal = Calendar.current
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.lowercased() == "now" {
            return Date()
        }

        if trimmed.hasPrefix("+") {
            let rest = String(trimmed.dropFirst())
            let isWeek = rest.hasSuffix("w")
            let isDay = rest.hasSuffix("d")
            let numStr: String
            if isWeek { numStr = String(rest.dropLast()) }
            else if isDay { numStr = String(rest.dropLast()) }
            else { numStr = rest }

            guard let n = Int(numStr), n >= 0 else { return nil }
            let days = isWeek ? n * 7 : n
            let base = cal.startOfDay(for: Date())
            return cal.date(byAdding: .day, value: days, to: base)
        }

        switch trimmed.lowercased() {
        case "today":
            return cal.startOfDay(for: Date())
        case "tomorrow":
            let base = cal.startOfDay(for: Date())
            return cal.date(byAdding: .day, value: 1, to: base)
        default:
            break
        }

        let dateFormats = [
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd"
        ]
        for fmt in dateFormats {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            if let d = f.date(from: trimmed) {
                return d
            }
        }

        return nil
    }

    /// Parse for all-day events — returns start-of-day only (no time component).
    public static func parseDateOnly(_ input: String) -> Date? {
        guard let d = parse(input) else { return nil }
        return Calendar.current.startOfDay(for: d)
    }
}
