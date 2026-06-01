import Foundation

struct StarRating {
    /// 基于正确率评星，不受 combo 波动影响
    /// - 3 星：正确率 ≥ 80%
    /// - 2 星：正确率 ≥ 60%
    /// - 1 星：正确率 ≥ 40%
    static func stars(correctCount: Int, totalCount: Int) -> Int {
        guard totalCount > 0 else { return 0 }
        let rate = Double(correctCount) / Double(totalCount)
        switch rate {
        case 0.8...: return 3
        case 0.6..<0.8: return 2
        case 0.4..<0.6: return 1
        default: return 0
        }
    }

    /// 向后兼容：基于分数的旧接口（内部转正确率估算）
    static func stars(forScore score: Int, questionCount: Int = 10) -> Int {
        // 基础分 100/题 + combo 加成，粗略估算正确数
        let estimatedCorrect = min(score / 100, questionCount)
        return stars(correctCount: estimatedCorrect, totalCount: questionCount)
    }

    static let thresholds = (star1: 0.4, star2: 0.6, star3: 0.8)
}
