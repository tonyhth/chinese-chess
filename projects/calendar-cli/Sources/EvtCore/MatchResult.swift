import Foundation

/// Result of matching a user query against events.
/// - `found`: exactly one match
/// - `multiple`: several candidates (user must narrow down)
/// - `none`: no match
public enum MatchResult<T> {
    case found(T)
    case multiple([T])
    case none
}
