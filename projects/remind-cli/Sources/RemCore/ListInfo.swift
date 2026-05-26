import Foundation

public struct ListInfo: Encodable, Sendable {
    public let name: String
    public let id: String
    public let pendingCount: Int
    public let totalCount: Int
}
