import Foundation

public enum Priority: Int, CaseIterable, Encodable {
    case none = 0
    case low = 9
    case medium = 5
    case high = 1

    public init?(stringValue: String) {
        switch stringValue.lowercased() {
        case "high": self = .high
        case "medium": self = .medium
        case "low": self = .low
        case "none": self = .none
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        case .none: return "none"
        }
    }
}
