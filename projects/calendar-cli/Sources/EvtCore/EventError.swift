import Foundation

/// Errors thrown by `EventStore` operations.
public enum EventError: Error, CustomStringConvertible {
    case accessDenied
    case calendarNotFound(name: String)
    case noMatch(query: String)
    case multipleMatch(query: String, items: [EventItem])
    case invalidDate(input: String)
    case invalidAlert(input: String)
    case noChanges
    case saveFailed(underlying: Error)
    case alertIndexOutOfRange(index: Int, count: Int)
    case eventModifiedExternally
    case exchangeCalendarUnstable(calendar: String)

    public var description: String {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Grant permission in System Settings > Privacy & Security > Calendars."
        case .calendarNotFound(let name):
            return "Calendar \"\(name)\" not found."
        case .noMatch(let query):
            return "No match found for: \(query)"
        case .multipleMatch(let query, let items):
            let candidates = items.prefix(5).map { "  \($0.id.prefix(8)) | \($0.calendar) | \($0.title)" }.joined(separator: "\n")
            return "Multiple matches for \"\(query)\":\n\(candidates)\nUse --id to specify by event ID."
        case .invalidDate(let input):
            return "Invalid date: \(input). Use YYYY-MM-DD [HH:mm], today, tomorrow, now, +Nd, or +Nw."
        case .invalidAlert(let input):
            return "Invalid alert: \(input). Use 15m, 1h, 2h30m, 1d, or @YYYY-MM-DD HH:mm."
        case .noChanges:
            return "No changes specified."
        case .saveFailed(let err):
            return "Save failed: \(err.localizedDescription)"
        case .alertIndexOutOfRange(let index, let count):
            return "Alert index \(index) out of range (1...\(count))."
        case .eventModifiedExternally:
            return "Event was modified externally. Re-fetch and retry."
        case .exchangeCalendarUnstable(let cal):
            return "Calendar \"\(cal)\" is Exchange/CalDAV. IDs may change after sync; consider using title matching."
        }
    }
}
