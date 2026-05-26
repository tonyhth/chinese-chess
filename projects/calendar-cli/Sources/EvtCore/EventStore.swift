import EventKit
import Foundation

/// Concrete `EventStoreProtocol` implementation backed by Apple EventKit.
///
/// Wraps `EKEventStore` with synchronous APIs using `DispatchSemaphore`,
/// following the same pattern as the remind-cli project.
public final class EventStore: EventStoreProtocol {
    private let store = EKEventStore()
    private var accessGranted = false

    // Cached date formatters
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init() {}

    // MARK: - Access (lazy, only once)

    private func requestAccess() throws {
        guard !accessGranted else { return }
        let sem = DispatchSemaphore(value: 0)
        var granted = false
        store.requestFullAccessToEvents { result, _ in
            granted = result
            sem.signal()
        }
        sem.wait()
        if granted {
            accessGranted = true
        } else {
            throw EventError.accessDenied
        }
    }

    // MARK: - Helpers

    private func calendarTypeString(_ cal: EKCalendar) -> String {
        switch cal.type {
        case .local: return "Local"
        case .calDAV: return "CalDAV"
        case .exchange: return "Exchange"
        case .birthday: return "Birthday"
        default: return "Other"
        }
    }

    private func isICloud(_ cal: EKCalendar) -> Bool {
        return cal.type == .calDAV && cal.source.title.contains("iCloud")
    }

    private func effectiveCalendarType(_ cal: EKCalendar) -> String {
        if isICloud(cal) { return "iCloud" }
        return calendarTypeString(cal)
    }

    private func formatDateTime(_ date: Date?) -> String? {
        guard let d = date else { return nil }
        return Self.dateTimeFormatter.string(from: d)
    }

    private func formatDate(_ date: Date?) -> String? {
        guard let d = date else { return nil }
        return Self.dateFormatter.string(from: d)
    }

    private func calendar(named name: String) -> EKCalendar? {
        store.calendars(for: .event).first { $0.title == name }
    }

    private func defaultCalendar() -> EKCalendar {
        store.defaultCalendarForNewEvents ?? store.calendars(for: .event)[0]
    }

    private func toEventItem(_ e: EKEvent) -> EventItem {
        let alerts = e.alarms?.enumerated().map { (idx, alarm) -> AlertItem in
            if let absDate = alarm.absoluteDate {
                return AlertItem(index: idx, type: "absolute", offset: nil,
                                 absoluteDate: formatDateTime(absDate))
            } else {
                return AlertItem(index: idx, type: "relative",
                                 offset: AlertParser.formatOffset(alarm.relativeOffset),
                                 absoluteDate: nil)
            }
        } ?? []

        let startStr: String
        let endStr: String
        if e.isAllDay {
            startStr = formatDate(e.startDate) ?? ""
            if let end = e.endDate {
                let displayEnd = Calendar.current.date(byAdding: .day, value: -1, to: end)
                endStr = formatDate(displayEnd) ?? ""
            } else {
                endStr = startStr
            }
        } else {
            startStr = formatDateTime(e.startDate) ?? ""
            endStr = formatDateTime(e.endDate) ?? ""
        }

        return EventItem(
            id: e.calendarItemExternalIdentifier,
            title: e.title ?? "",
            calendar: e.calendar.title,
            calendarType: effectiveCalendarType(e.calendar),
            startDate: startStr,
            endDate: endStr,
            isAllDay: e.isAllDay,
            location: e.location,
            notes: e.notes,
            url: e.url?.absoluteString,
            alerts: alerts,
            creationDate: formatDateTime(e.creationDate)
        )
    }

    private func fetchEvents(calendars: [EKCalendar]?, startDate: Date, endDate: Date) -> [EKEvent] {
        let cals = calendars ?? store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        return store.events(matching: predicate)
    }

    private func findEventById(_ id: String) -> EKEvent? {
        if let e = store.event(withIdentifier: id) { return e }
        // Prefix match with wider range (±5 years)
        let now = Date()
        let past = Calendar.current.date(byAdding: .year, value: -5, to: now)!
        let future = Calendar.current.date(byAdding: .year, value: 5, to: now)!
        let allEvents = fetchEvents(calendars: nil, startDate: past, endDate: future)
        return allEvents.first { $0.calendarItemExternalIdentifier.hasPrefix(id) }
    }

    private func findEventsByTitle(_ keyword: String) -> [EKEvent] {
        let now = Date()
        let past = Calendar.current.date(byAdding: .year, value: -5, to: now)!
        let future = Calendar.current.date(byAdding: .year, value: 5, to: now)!
        let allEvents = fetchEvents(calendars: nil, startDate: past, endDate: future)
        return allEvents.filter { $0.title?.localizedCaseInsensitiveContains(keyword) ?? false }
    }

    // MARK: - Concurrency conflict detection (§6.6)

    /// Re-fetch the latest version of an event and compare key fields with the snapshot.
    /// Throws `eventModifiedExternally` if the event was changed between the snapshot and now.
    private func refetchAndValidate(against snapshot: EventItem) throws -> EKEvent {
        guard let event = findEventById(snapshot.id) else {
            throw EventError.noMatch(query: snapshot.id)
        }
        // Compare key fields that matter
        let currentTitle = event.title ?? ""
        let currentStart = event.startDate
        let currentEnd = event.endDate

        if currentTitle != snapshot.title
            || currentStart != Self.dateTimeFormatter.date(from: snapshot.isAllDay
                ? (formatDate(event.startDate) ?? "")
                : snapshot.startDate)
            || currentEnd != Self.dateTimeFormatter.date(from: snapshot.isAllDay
                ? (formatDate(Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate) ?? "")
                : snapshot.endDate) {
            // More reliable comparison: just check title and exact dates
        }

        // Simpler approach: compare title string directly, and date timestamps
        let snapStart = parseDateString(snapshot.startDate)
        if event.title != snapshot.title
            || (snapStart != nil && event.startDate != snapStart) {
            throw EventError.eventModifiedExternally
        }

        return event
    }

    private func parseDateString(_ s: String) -> Date? {
        return Self.dateTimeFormatter.date(from: s) ?? Self.dateFormatter.date(from: s)
    }

    // MARK: - Protocol Methods

    public func add(title: String, start: String, end: String?, isAllDay: Bool,
                    calendar: String?, location: String?, notes: String?, url: String?,
                    alerts: [String]) throws -> EventItem {
        try requestAccess()

        guard let startDate = DateParser.parse(start) else {
            throw EventError.invalidDate(input: start)
        }

        let endDate: Date
        if let e = end {
            guard let d = DateParser.parse(e) else {
                throw EventError.invalidDate(input: e)
            }
            if isAllDay {
                let inclusiveEnd = Calendar.current.startOfDay(for: d)
                endDate = Calendar.current.date(byAdding: .day, value: 1, to: inclusiveEnd)!
            } else {
                endDate = d
            }
        } else if isAllDay {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: startDate))!
        } else {
            endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        }

        let cal: EKCalendar
        if let name = calendar {
            guard let c = self.calendar(named: name) else {
                throw EventError.calendarNotFound(name: name)
            }
            cal = c
        } else {
            cal = defaultCalendar()
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = isAllDay ? Calendar.current.startOfDay(for: startDate) : startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.calendar = cal
        if let l = location { event.location = l }
        if let n = notes { event.notes = n }
        if let u = url, let urlObj = URL(string: u) { event.url = urlObj }

        var alarms: [EKAlarm] = []
        for alertStr in alerts {
            guard let spec = AlertParser.parse(alertStr) else {
                throw EventError.invalidAlert(input: alertStr)
            }
            switch spec {
            case .relative(let offset):
                alarms.append(EKAlarm(relativeOffset: offset))
            case .absolute(let date):
                alarms.append(EKAlarm(absoluteDate: date))
            }
        }
        event.alarms = alarms.isEmpty ? nil : alarms

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return toEventItem(event)
    }

    public func list(calendar: String?, from: String?, to: String?, days: Int?,
                     keyword: String?, searchLocation: Bool, searchNotes: Bool,
                     limit: Int) throws -> (events: [EventItem], truncated: Bool) {
        try requestAccess()

        let cal = Calendar.current
        let now = Date()
        let startDate: Date
        var endDate: Date

        if let f = from {
            guard let d = DateParser.parse(f) else { throw EventError.invalidDate(input: f) }
            startDate = cal.startOfDay(for: d)
        } else {
            startDate = cal.startOfDay(for: now)
        }

        if let t = to {
            guard let d = DateParser.parse(t) else { throw EventError.invalidDate(input: t) }
            endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: d))!
        } else {
            let d = days ?? 7
            endDate = cal.date(byAdding: .day, value: d, to: startDate)!
        }

        var cals: [EKCalendar]?
        if let name = calendar {
            guard let c = self.calendar(named: name) else {
                throw EventError.calendarNotFound(name: name)
            }
            cals = [c]
        }

        var ekEvents = fetchEvents(calendars: cals, startDate: startDate, endDate: endDate)
        ekEvents.sort { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

        if let kw = keyword {
            ekEvents = ekEvents.filter { e in
                let titleMatch = e.title?.localizedCaseInsensitiveContains(kw) ?? false
                let locMatch = searchLocation && (e.location?.localizedCaseInsensitiveContains(kw) ?? false)
                let notesMatch = searchNotes && (e.notes?.localizedCaseInsensitiveContains(kw) ?? false)
                return titleMatch || locMatch || notesMatch
            }
        }

        let truncated = ekEvents.count > limit
        let limited = Array(ekEvents.prefix(limit))
        let items = limited.map { toEventItem($0) }

        return (events: items, truncated: truncated)
    }

    public func show(query: String, isId: Bool) throws -> EventItem {
        let result = try match(query, isId: isId)
        switch result {
        case .found(let item):
            return item
        case .multiple(let items):
            throw EventError.multipleMatch(query: query, items: items)
        case .none:
            throw EventError.noMatch(query: query)
        }
    }

    public func match(_ query: String, isId: Bool) throws -> MatchResult<EventItem> {
        try requestAccess()

        if isId {
            if let e = findEventById(query) {
                return .found(toEventItem(e))
            }
            return .none
        }

        let results = findEventsByTitle(query)
        switch results.count {
        case 0: return .none
        case 1: return .found(toEventItem(results[0]))
        default: return .multiple(results.map { toEventItem($0) })
        }
    }

    // MARK: - Update

    public func update(query: String, isId: Bool, title: String?, start: String?, end: String?,
                       calendar: String?, location: String?, notes: String?, url: String?,
                       allDay: Bool?, noAllDay: Bool?) throws -> EventItem {
        try requestAccess()
        let snapshot = try show(query: query, isId: isId)

        guard title != nil || start != nil || end != nil || calendar != nil
                || location != nil || notes != nil || url != nil
                || allDay == true || noAllDay == true else {
            throw EventError.noChanges
        }

        // P0-1: Re-fetch and detect external modifications
        var event = try refetchAndValidate(against: snapshot)

        // Cross-calendar move
        if let calName = calendar {
            guard let newCal = self.calendar(named: calName) else {
                throw EventError.calendarNotFound(name: calName)
            }
            if event.calendar.calendarIdentifier != newCal.calendarIdentifier {
                return try moveEvent(event, snapshot: snapshot, to: newCal, title: title, start: start, end: end,
                                     location: location, notes: notes, url: url,
                                     allDay: allDay, noAllDay: noAllDay)
            }
        }

        if let t = title { event.title = t }
        if let s = start {
            guard let d = DateParser.parse(s) else { throw EventError.invalidDate(input: s) }
            event.startDate = event.isAllDay ? Calendar.current.startOfDay(for: d) : d
        }
        if let e = end {
            guard let d = DateParser.parse(e) else { throw EventError.invalidDate(input: e) }
            if event.isAllDay {
                let inclusiveEnd = Calendar.current.startOfDay(for: d)
                event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: inclusiveEnd)!
            } else {
                event.endDate = d
            }
        }
        if let l = location { event.location = l.isEmpty ? nil : l }
        if let n = notes { event.notes = n.isEmpty ? nil : n }
        if let u = url { event.url = u.isEmpty ? nil : URL(string: u) }
        if allDay == true { event.isAllDay = true }
        if noAllDay == true { event.isAllDay = false }

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return toEventItem(event)
    }

    private func moveEvent(_ oldEvent: EKEvent, snapshot: EventItem, to newCal: EKCalendar,
                           title: String?, start: String?, end: String?,
                           location: String?, notes: String?, url: String?,
                           allDay: Bool?, noAllDay: Bool?) throws -> EventItem {
        let newEvent = EKEvent(eventStore: store)
        newEvent.title = oldEvent.title ?? ""
        newEvent.startDate = oldEvent.startDate
        newEvent.endDate = oldEvent.endDate
        newEvent.isAllDay = oldEvent.isAllDay
        newEvent.calendar = newCal
        newEvent.location = oldEvent.location
        newEvent.notes = oldEvent.notes
        newEvent.url = oldEvent.url
        newEvent.alarms = oldEvent.alarms
        // P0-3: Copy additional properties
        newEvent.availability = oldEvent.availability
        newEvent.recurrenceRules = oldEvent.recurrenceRules
        newEvent.timeZone = oldEvent.timeZone
        newEvent.structuredLocation = oldEvent.structuredLocation

        if let t = title { newEvent.title = t }
        if let s = start {
            guard let d = DateParser.parse(s) else { throw EventError.invalidDate(input: s) }
            newEvent.startDate = newEvent.isAllDay ? Calendar.current.startOfDay(for: d) : d
        }
        if let e = end {
            guard let d = DateParser.parse(e) else { throw EventError.invalidDate(input: e) }
            if newEvent.isAllDay {
                let inclusiveEnd = Calendar.current.startOfDay(for: d)
                newEvent.endDate = Calendar.current.date(byAdding: .day, value: 1, to: inclusiveEnd)!
            } else {
                newEvent.endDate = d
            }
        }
        if let l = location { newEvent.location = l.isEmpty ? nil : l }
        if let n = notes { newEvent.notes = n.isEmpty ? nil : n }
        if let u = url { newEvent.url = u.isEmpty ? nil : URL(string: u) }
        if allDay == true { newEvent.isAllDay = true }
        if noAllDay == true { newEvent.isAllDay = false }

        do {
            try store.save(newEvent, span: .thisEvent, commit: false)
            try store.remove(oldEvent, span: .thisEvent, commit: false)
            try store.commit()
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return toEventItem(newEvent)
    }

    // MARK: - Delete

    public func delete(query: String, isId: Bool) throws -> EventItem {
        try requestAccess()
        let snapshot = try show(query: query, isId: isId)

        // P0-1: Re-fetch and detect external modifications
        let event = try refetchAndValidate(against: snapshot)

        do {
            try store.remove(event, span: .thisEvent, commit: true)
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return snapshot
    }

    // MARK: - Alert management

    public func addAlert(query: String, isId: Bool, time: String) throws -> EventItem {
        try requestAccess()
        let snapshot = try show(query: query, isId: isId)

        // P0-1: Re-fetch and detect external modifications
        var event = try refetchAndValidate(against: snapshot)

        guard let spec = AlertParser.parse(time) else {
            throw EventError.invalidAlert(input: time)
        }

        var alarms = event.alarms ?? []
        switch spec {
        case .relative(let offset):
            alarms.append(EKAlarm(relativeOffset: offset))
        case .absolute(let date):
            alarms.append(EKAlarm(absoluteDate: date))
        }
        event.alarms = alarms

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return toEventItem(event)
    }

    public func removeAlert(query: String, isId: Bool, index: Int) throws -> EventItem {
        try requestAccess()
        let snapshot = try show(query: query, isId: isId)

        // P0-1: Re-fetch and detect external modifications
        var event = try refetchAndValidate(against: snapshot)

        var alarms = event.alarms ?? []
        guard index >= 1 && index <= alarms.count else {
            throw EventError.alertIndexOutOfRange(index: index, count: alarms.count)
        }
        alarms.remove(at: index - 1)
        event.alarms = alarms.isEmpty ? nil : alarms

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventError.saveFailed(underlying: error)
        }

        return toEventItem(event)
    }
}
