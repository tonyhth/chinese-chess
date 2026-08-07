import Foundation

// MARK: - 趋势分析

/// 趋势类型
enum TrendType {
    case neutral           // 无明显趋势
    case redAdvantage      // 红方确立优势
    case blackAdvantage    // 黑方步步被动（红方连续好）
    case suddenTension     // 局面突然紧张
}

/// 趋势分析器（滑动窗口）
struct TrendAnalyzer {

    /// 保留最近 N 步的 evalDelta
    private var recentDeltas: [Int] = []
    private let windowSize = 5

    /// 记录一步
    mutating func record(delta: Int) {
        recentDeltas.append(delta)
        if recentDeltas.count > windowSize {
            recentDeltas.removeFirst()
        }
    }

    /// 重置
    mutating func reset() {
        recentDeltas.removeAll()
    }

    /// 趋势判断
    var trend: TrendType {
        guard recentDeltas.count >= 3 else { return .neutral }

        // 连续 3 步同向累积 > 200
        let last3 = recentDeltas.suffix(3)
        let sum = last3.reduce(0, +)
        if sum > 200 { return .redAdvantage }
        if sum < -200 { return .blackAdvantage }

        // 长期平稳后突变
        if recentDeltas.count >= 5 {
            let early = recentDeltas.prefix(4)
            let earlyAllSmall = early.allSatisfy { abs($0) < 30 }
            let lastDelta = recentDeltas.last ?? 0
            if earlyAllSmall && abs(lastDelta) > 100 {
                return .suddenTension
            }
        }

        return .neutral
    }

    /// 趋势文案
    static func commentary(for trend: TrendType) -> String? {
        switch trend {
        case .redAdvantage:
            return ["红方确立优势", "红方步步紧逼，黑方被动", "红方逐渐掌握主动权"]
                .randomElement()
        case .blackAdvantage:
            return ["黑方反客为主", "黑方步步紧逼", "红方陷入被动"]
                .randomElement()
        case .suddenTension:
            return ["局面突然紧张！", "风云突变！", "局势急转直下"]
                .randomElement()
        case .neutral:
            return nil
        }
    }
}
