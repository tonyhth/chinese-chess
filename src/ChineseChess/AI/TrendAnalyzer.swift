import Foundation

// MARK: - 趋势分析

/// 趋势类型
enum TrendType {
    case neutral           // 无明显趋势
    case advantageEstablished  // 一方确立优势（连续好棋/对手连续失误）
    case suddenTension     // 局面突然紧张
}

/// 趋势分析器（滑动窗口）
struct TrendAnalyzer {

    /// 保留最近 N 步的 evalDelta（绝对值，不区分方向）
    private var recentDeltas: [Int] = []
    private let windowSize = 5

    /// 记录一步
    mutating func record(delta: Int) {
        recentDeltas.append(delta)
        if recentDeltas.count > windowSize {
            recentDeltas.removeFirst()
        }
    }

    /// 重置（跳步时调用）
    mutating func reset() {
        recentDeltas.removeAll()
    }

    /// 趋势判断
    var trend: TrendType {
        guard recentDeltas.count >= 3 else { return .neutral }

        // 连续 3 步累积 delta > 200 → 一方确立优势
        let last3 = recentDeltas.suffix(3)
        let sum = last3.reduce(0, +)
        if sum > 200 { return .advantageEstablished }

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

    /// 趋势文案（通用方向，不区分红黑）
    static func commentary(for trend: TrendType) -> String? {
        switch trend {
        case .advantageEstablished:
            return ["一方确立优势", "连续精准走法，对手陷入被动", "逐渐掌握主动权"]
                .randomElement()
        case .suddenTension:
            return ["局面突然紧张！", "风云突变！", "局势急转直下"]
                .randomElement()
        case .neutral:
            return nil
        }
    }
}
