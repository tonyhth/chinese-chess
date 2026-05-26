import Foundation

public enum RemError: Error, CustomStringConvertible {
    case accessDenied
    case calendarNotFound(name: String)
    case noMatch(query: String)
    case multipleMatch(query: String, items: [RemItem])
    case invalidDate(input: String)
    case invalidPriority(input: String)
    case saveFailed(underlying: Error)
    case noChanges
    case duplicateFound(count: Int)

    public var description: String {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Grant permission in System Settings > Privacy & Security > Calendars."
        case .calendarNotFound(let name):
            return "List \"\(name)\" not found."
        case .noMatch(let query):
            return "No match found for: \(query)"
        case .multipleMatch(let query, let items):
            let candidates = items.prefix(5).map { "  \($0.id.prefix(8)) | \($0.list) | \($0.title)" }.joined(separator: "\n")
            return "Multiple matches for \"\(query)\":\n\(candidates)\nUse full ID to specify."
        case .invalidDate(let input):
            return "Invalid date: \(input). Use YYYY-MM-DD, today, tomorrow, or +Nd."
        case .invalidPriority(let input):
            return "Invalid priority: \(input). Use high, medium, low, or none."
        case .saveFailed(let err):
            return "Save failed: \(err.localizedDescription)"
        case .noChanges:
            return "No changes specified (--title / --due / --list / --priority)."
        case .duplicateFound(let count):
            return "Duplicate found: \(count) item(s) with the same title. Use --force to skip."
        }
    }
}
