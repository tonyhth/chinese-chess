import Foundation

/// A calendar event with all user-facing fields, ready for display or JSON output.
public struct EventItem: Encodable, Sendable {
    public let id: String           // calendarItemExternalIdentifier
    public let title: String
    public let calendar: String     // Calendar name
    public let calendarType: String // "Local" | "iCloud" | "Exchange" | "CalDAV"
    public let startDate: String    // "2026-04-19 09:00" or "2026-04-19" for all-day
    public let endDate: String
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let url: String?
    public let alerts: [AlertItem]
    public let creationDate: String?
}
