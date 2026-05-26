import Foundation

struct StarRating {
    static func stars(forScore score: Int) -> Int {
        switch score {
        case 900...: return 3
        case 800..<900: return 2
        case 600..<800: return 1
        default: return 0
        }
    }

    static let thresholds = (star1: 600, star2: 800, star3: 900)
}
