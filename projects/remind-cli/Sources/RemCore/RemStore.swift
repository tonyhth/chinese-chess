import EventKit
import Foundation

public final class RemStore: RemStoreProtocol {
    private let store = EKEventStore()

    public init() {}

    // MARK: - Access

    private func requestAccess() throws {
        let sem = DispatchSemaphore(value: 0)
        var granted = false
        store.requestFullAccessToReminders { result, _ in
            granted = result
            sem.signal()
        }
        sem.wait()
        guard granted else { throw RemError.accessDenied }
    }

    // MARK: - Helpers

    private func fetchReminders(in calendars: [EKCalendar]? = nil) -> [EKReminder] {
        let cals = calendars ?? store.calendars(for: .reminder)
        let sem = DispatchSemaphore(value: 0)
        var result = [EKReminder]()
        let predicate = store.predicateForReminders(in: cals)
        store.fetchReminders(matching: predicate) { rems in
            if let r = rems { result = r }
            sem.signal()
        }
        sem.wait()
        return result
    }

    private func calendar(named name: String) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.title == name }
    }

    private func toRemItem(_ r: EKReminder) -> RemItem {
        RemItem(
            id: r.calendarItemExternalIdentifier,
            title: r.title,
            list: r.calendar.title,
            completed: r.isCompleted,
            dueDate: formatDate(r.dueDateComponents?.date),
            dueDateFull: formatDateTime(r.dueDateComponents?.date),
            priority: r.priority,
            priorityName: Self.priorityName(r.priority),
            notes: r.notes,
            creationDate: formatDateTime(r.creationDate)
        )
    }

    private static func priorityName(_ p: Int) -> String {
        switch p {
        case 1: return "high"
        case 5: return "medium"
        case 9: return "low"
        default: return "none"
        }
    }

    private func formatDate(_ date: Date?) -> String? {
        guard let d = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func formatDateTime(_ date: Date?) -> String? {
        guard let d = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }

    private func findEKReminder(id: String) -> EKReminder? {
        let all = fetchReminders()
        // Try exact ID match first
        if let r = all.first(where: { $0.calendarItemExternalIdentifier == id }) { return r }
        // Try ID prefix match
        return all.first { $0.calendarItemExternalIdentifier.hasPrefix(id) }
    }

    private func findEKReminders(keyword: String, completed: Bool? = nil) -> [EKReminder] {
        let all = fetchReminders()
        var results = [EKReminder]()

        // Exact ID or prefix match
        if let r = findEKReminder(id: keyword) {
            return [r]
        }

        // Title contains (case-insensitive)
        for r in all {
            if let c = completed, r.isCompleted != c { continue }
            if r.title.localizedCaseInsensitiveContains(keyword) {
                results.append(r)
            }
        }
        return results
    }

    // MARK: - RemStoreProtocol

    public func allReminders(in list: String?) throws -> [RemItem] {
        try requestAccess()
        var cals: [EKCalendar]?
        if let name = list {
            guard let cal = calendar(named: name) else {
                throw RemError.calendarNotFound(name: name)
            }
            cals = [cal]
        }
        return fetchReminders(in: cals).map { toRemItem($0) }
    }

    public func allLists() throws -> [ListInfo] {
        try requestAccess()
        let cals = store.calendars(for: .reminder)
        return cals.map { cal in
            let rems = fetchReminders(in: [cal])
            return ListInfo(
                name: cal.title,
                id: cal.calendarIdentifier,
                pendingCount: rems.filter { !$0.isCompleted }.count,
                totalCount: rems.count
            )
        }
    }

    public func search(keyword: String, includeCompleted: Bool) throws -> [RemItem] {
        try requestAccess()
        let all = fetchReminders()
        return all.filter { r in
            if !includeCompleted && r.isCompleted { return false }
            return r.title.localizedCaseInsensitiveContains(keyword)
        }.map { toRemItem($0) }
    }

    public func match(_ query: String, completed: Bool?) throws -> MatchResult<RemItem> {
        try requestAccess()
        let results = findEKReminders(keyword: query, completed: completed)
        switch results.count {
        case 0: return .none
        case 1: return .found(toRemItem(results[0]))
        default: return .multiple(results.map { toRemItem($0) })
        }
    }

    public func add(title: String, list: String?, due: String?, priority: String?, notes: String?) throws -> RemItem {
        try requestAccess()

        let listName = list ?? defaultListName()
        guard let cal = listName.flatMap({ calendar(named: $0) }) else {
            if let name = listName {
                throw RemError.calendarNotFound(name: name)
            }
            throw RemError.calendarNotFound(name: "(default)")
        }

        let rem = EKReminder(eventStore: store)
        rem.title = title
        rem.calendar = cal

        if let d = due {
            guard let dc = DateParser.parse(d) else { throw RemError.invalidDate(input: d) }
            rem.dueDateComponents = dc
        }

        if let p = priority {
            guard let pr = Priority(stringValue: p) else { throw RemError.invalidPriority(input: p) }
            rem.priority = pr.rawValue
        }

        if let n = notes, !n.isEmpty {
            rem.notes = n
        }

        do {
            try store.save(rem, commit: true)
        } catch {
            throw RemError.saveFailed(underlying: error)
        }

        return toRemItem(rem)
    }

    public func complete(_ item: RemItem) throws {
        try requestAccess()
        guard let rem = findEKReminder(id: item.id) else {
            throw RemError.noMatch(query: item.id)
        }
        rem.isCompleted = true
        do {
            try store.save(rem, commit: true)
        } catch {
            throw RemError.saveFailed(underlying: error)
        }
    }

    public func uncomplete(_ item: RemItem) throws {
        try requestAccess()
        guard let rem = findEKReminder(id: item.id) else {
            throw RemError.noMatch(query: item.id)
        }
        rem.isCompleted = false
        do {
            try store.save(rem, commit: true)
        } catch {
            throw RemError.saveFailed(underlying: error)
        }
    }

    public func update(_ item: RemItem, title: String?, due: String?, list: String?, priority: String?) throws -> RemItem {
        try requestAccess()
        guard let rem = findEKReminder(id: item.id) else {
            throw RemError.noMatch(query: item.id)
        }

        guard title != nil || due != nil || list != nil || priority != nil else {
            throw RemError.noChanges
        }

        if let t = title { rem.title = t }
        if let d = due {
            guard let dc = DateParser.parse(d) else { throw RemError.invalidDate(input: d) }
            rem.dueDateComponents = dc
        }
        if let ln = list {
            guard let cal = calendar(named: ln) else { throw RemError.calendarNotFound(name: ln) }
            rem.calendar = cal
        }
        if let p = priority {
            guard let pr = Priority(stringValue: p) else { throw RemError.invalidPriority(input: p) }
            rem.priority = pr.rawValue
        }

        do {
            try store.save(rem, commit: true)
        } catch {
            throw RemError.saveFailed(underlying: error)
        }

        return toRemItem(rem)
    }

    public func delete(_ item: RemItem) throws {
        try requestAccess()
        guard let rem = findEKReminder(id: item.id) else {
            throw RemError.noMatch(query: item.id)
        }
        do {
            try store.remove(rem, commit: true)
        } catch {
            throw RemError.saveFailed(underlying: error)
        }
    }

    public func findDuplicate(title: String, in list: String?) throws -> [RemItem] {
        try allReminders(in: list)
            .filter { !$0.completed && $0.title == title }
    }

    public func defaultListName() -> String? {
        store.defaultCalendarForNewReminders()?.title
    }
}
