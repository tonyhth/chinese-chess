import Foundation

public protocol RemStoreProtocol {
    func allReminders(in list: String?) throws -> [RemItem]
    func allLists() throws -> [ListInfo]
    func search(keyword: String, includeCompleted: Bool) throws -> [RemItem]
    func match(_ query: String, completed: Bool?) throws -> MatchResult<RemItem>
    func add(title: String, list: String?, due: String?, priority: String?, notes: String?) throws -> RemItem
    func complete(_ item: RemItem) throws
    func uncomplete(_ item: RemItem) throws
    func update(_ item: RemItem, title: String?, due: String?, list: String?, priority: String?) throws -> RemItem
    func delete(_ item: RemItem) throws
    func findDuplicate(title: String, in list: String?) throws -> [RemItem]
    func defaultListName() -> String?
}
