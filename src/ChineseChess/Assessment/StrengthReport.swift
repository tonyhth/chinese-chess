import Foundation

// MARK: - v6.0 Phase 4: 棋力评估数据模型

/// 棋力评估报告
struct StrengthReport: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let sourceGames: [UUID]      // 分析的对局 ID 列表

    // 核心结果
    let eloEstimate: EloEstimate
    let recommendedLevel: AIDifficulty

    // 六维评分（0-100）
    let dimensions: SixDimensionScores

    // 逐手统计
    let moveStats: MoveStatistics

    // 建议
    let strengths: [String]
    let weaknesses: [String]
    let trainingSuggestions: [TrainingSuggestion]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceGames: [UUID] = [],
        eloEstimate: EloEstimate,
        recommendedLevel: AIDifficulty,
        dimensions: SixDimensionScores,
        moveStats: MoveStatistics,
        strengths: [String] = [],
        weaknesses: [String] = [],
        trainingSuggestions: [TrainingSuggestion] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceGames = sourceGames
        self.eloEstimate = eloEstimate
        self.recommendedLevel = recommendedLevel
        self.dimensions = dimensions
        self.moveStats = moveStats
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.trainingSuggestions = trainingSuggestions
    }
}

// MARK: - Elo 估算结果

struct EloEstimate: Codable {
    let estimate: Int
    let lowerBound: Int
    let upperBound: Int
    let sampleSize: Int
    let confidence: Confidence

    enum Confidence: String, Codable {
        case low       // < 40 步
        case medium    // 40-79 步
        case high      // ≥ 80 步

        var label: String {
            switch self {
            case .low:    return "低"
            case .medium: return "中"
            case .high:   return "高"
            }
        }
    }
}

// MARK: - 六维评分

struct SixDimensionScores: Codable {
    let opening: ScoreBreakdown      // 开局水平 15%
    let tactics: ScoreBreakdown      // 中盘战术 25%
    let endgame: ScoreBreakdown      // 残局功底 20%
    let consistency: ScoreBreakdown  // 稳定性 20%
    let checkmate: ScoreBreakdown    // 杀棋敏感度 20%

    /// 加权总分
    var overall: Int {
        Int(
            Double(opening.score) * 0.15 +
            Double(tactics.score) * 0.25 +
            Double(endgame.score) * 0.20 +
            Double(consistency.score) * 0.20 +
            Double(checkmate.score) * 0.20
        )
    }

    struct ScoreBreakdown: Codable {
        let score: Int           // 0-100
        let label: String        // "优秀" / "良好" / "一般" / "待提升"
        let detail: String       // 一句话说明
        let metrics: [String: Double]

        static func scoreLabel(_ score: Int) -> String {
            switch score {
            case 85...:        return "优秀"
            case 70..<85:      return "良好"
            case 50..<70:      return "一般"
            default:           return "待提升"
            }
        }
    }
}

// MARK: - 逐手统计

struct MoveStatistics: Codable {
    let totalMoves: Int
    let qualityDistribution: [MoveQuality: Int]
    let avgDelta: Double

    var brilliantRate: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(qualityDistribution[.brilliant] ?? 0) / Double(totalMoves)
    }

    var blunderRate: Double {
        guard totalMoves > 0 else { return 0 }
        return Double((qualityDistribution[.blunder] ?? 0) + (qualityDistribution[.losing] ?? 0)) / Double(totalMoves)
    }

    // Codable 自定义（Dictionary with enum key）
    enum CodingKeys: String, CodingKey {
        case totalMoves, qualityDistribution, avgDelta
    }

    init(totalMoves: Int, qualityDistribution: [MoveQuality: Int], avgDelta: Double) {
        self.totalMoves = totalMoves
        self.qualityDistribution = qualityDistribution
        self.avgDelta = avgDelta
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalMoves = try c.decode(Int.self, forKey: .totalMoves)
        avgDelta = try c.decode(Double.self, forKey: .avgDelta)
        // MoveQuality enum → String key 编码
        let raw = try c.decode([String: Int].self, forKey: .qualityDistribution)
        qualityDistribution = raw.compactMapValues { $0 }.reduce(into: [:]) { dict, pair in
            if let q = MoveQuality(rawValue: Int(pair.key) ?? -1) {
                dict[q] = pair.value
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(totalMoves, forKey: .totalMoves)
        try c.encode(avgDelta, forKey: .avgDelta)
        let raw = qualityDistribution.reduce(into: [String: Int]()) { dict, pair in
            dict[String(pair.key.rawValue)] = pair.value
        }
        try c.encode(raw, forKey: .qualityDistribution)
    }
}

// MARK: - 训练建议

struct TrainingSuggestion: Codable, Identifiable {
    let id: UUID
    let dimension: String
    let title: String
    let description: String
    let actionType: ActionType
    let actionTarget: String

    enum ActionType: String, Codable {
        case puzzleChapter
        case openingExplorer
        case aiMatch
        case replayAnalysis
    }

    init(id: UUID = UUID(), dimension: String, title: String, description: String,
         actionType: ActionType, actionTarget: String) {
        self.id = id
        self.dimension = dimension
        self.title = title
        self.description = description
        self.actionType = actionType
        self.actionTarget = actionTarget
    }
}
