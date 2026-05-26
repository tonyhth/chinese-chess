import Foundation

public enum MatchResult<T> {
    case found(T)
    case multiple([T])
    case none
}
