import Foundation

/// Protocol abstracting EventKit operations for testability.
/// Use `EventStore` in production; mock this protocol in tests.
public protocol EventStoreProtocol {
    /// Create a new calendar event.
    func add(title: String, start: String, end: String?, isAllDay: Bool,
             calendar: String?, location: String?, notes: String?, url: String?,
             alerts: [String]) throws -> EventItem

    /// List events within a date range, optionally filtered by calendar, keyword, etc.
    func list(calendar: String?, from: String?, to: String?, days: Int?,
              keyword: String?, searchLocation: Bool, searchNotes: Bool,
              limit: Int) throws -> (events: [EventItem], truncated: Bool)

    /// Show a single event's details by title or ID.
    func show(query: String, isId: Bool) throws -> EventItem

    /// Match a query against events; returns `.found`, `.multiple`, or `.none`.
    func match(_ query: String, isId: Bool) throws -> MatchResult<EventItem>

    /// Update an existing event's fields. Supports cross-calendar moves.
    func update(query: String, isId: Bool, title: String?, start: String?, end: String?,
                calendar: String?, location: String?, notes: String?, url: String?,
                allDay: Bool?, noAllDay: Bool?) throws -> EventItem

    /// Delete an event by title or ID.
    func delete(query: String, isId: Bool) throws -> EventItem

    /// Add an alert to an event.
    func addAlert(query: String, isId: Bool, time: String) throws -> EventItem

    /// Remove an alert from an event by 1-based index.
    func removeAlert(query: String, isId: Bool, index: Int) throws -> EventItem
}
