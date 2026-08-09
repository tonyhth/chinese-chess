import Foundation

// MARK: - v6.0 Phase 4: Elo 估算引擎

/// 基于 delta→Elo 映射的 Elo 估算器
/// 参考 chess.com CAPS2 和 Lichess 方法
enum EloEstimator {

    // MARK: - 核心公式

    /// 单步 delta → Elo 贡献
    /// delta = |bestEval - playerEval|（cp）
    static func eloFromDelta(_ delta: Int) -> Double {
        if delta <= 0 { return 2500 }
        return 2500.0 - 120.0 * log(Double(delta) + 1.0)
    }

    // MARK: - 批量估算

    /// 从多步 delta 列表估算 Elo
    static func estimate(deltas: [Int]) -> EloEstimate {
        guard deltas.count >= 20 else {
            return EloEstimate(
                estimate: 1000,
                lowerBound: 600,
                upperBound: 1600,
                sampleSize: deltas.count,
                confidence: .low
            )
        }

        // 1. 计算每步的 Elo 贡献
        let moveElos = deltas.map { eloFromDelta($0) }

        // 2. 截尾平均（去最高/最低 10%，避免单步失误拉偏）
        let trimmed = trimOutliers(moveElos, ratio: 0.1)

        // 3. 均值
        let mean = trimmed.reduce(0, +) / Double(trimmed.count)

        // 4. 置信区间
        let stddev = standardDeviation(moveElos)
        let ci = 1.96 * stddev / sqrt(Double(moveElos.count))
        let ciRounded = max(150.0, ci) // 最小 ±150

        // 5. 置信度
        let confidence: EloEstimate.Confidence
        switch deltas.count {
        case 0..<40:   confidence = .low
        case 40..<80:  confidence = .medium
        default:       confidence = .high
        }

        return EloEstimate(
            estimate: Int(mean.rounded()),
            lowerBound: Int((mean - ciRounded).rounded()),
            upperBound: Int((mean + ciRounded).rounded()),
            sampleSize: deltas.count,
            confidence: confidence
        )
    }

    // MARK: - 推荐级别映射

    /// Elo → 推荐 AIDifficulty
    static func recommendedLevel(from elo: EloEstimate) -> AIDifficulty {
        switch elo.estimate {
        case 0...800:    return .novice
        case 801...1000: return .beginner
        case 1001...1300: return .amateurLow
        case 1301...1600: return .amateurMid
        case 1601...1900: return .amateurHigh
        case 1901...2200: return .amateurDan
        case 2201...2500: return .proApprentice
        case 2501...2800: return .proExpert
        case 2801...3100: return .proMaster
        default:          return .grandmaster
        }
    }

    // MARK: - 统计辅助

    /// 截尾平均：去掉最高和最低的 ratio 比例
    private static func trimOutliers(_ values: [Double], ratio: Double) -> [Double] {
        guard values.count >= 10 else { return values }
        let sorted = values.sorted()
        let trimCount = Int(Double(sorted.count) * ratio)
        guard trimCount > 0, sorted.count > trimCount * 2 else { return values }
        return Array(sorted[trimCount..<(sorted.count - trimCount)])
    }

    /// 标准差
    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }
}
