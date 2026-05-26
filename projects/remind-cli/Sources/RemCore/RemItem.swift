import Foundation

public struct RemItem: Encodable, Sendable {
    public let id: String
    public let title: String
    public let list: String
    public let completed: Bool
    public let dueDate: String?
    public let dueDateFull: String?
    public let priority: Int
    public let priorityName: String
    public let notes: String?
    public let creationDate: String?
}
