import Foundation

// MARK: - 评估函数权重配置

/// 评估函数可调参数，从 JSON 加载或使用默认值
/// v3.1 Phase 1: 权重参数化，支持 CMA-ES 自动调参
struct EvalWeights: Codable, Equatable {

    // MARK: - 子力价值

    /// 棋子基础价值（一般不改，但保留灵活性）
    var generalValue: Int = 10000
    var chariotValue: Int = 900
    var horseValueOpening: Int = 400
    var horseValueEndgame: Int = 450   // 残局马 > 炮
    var cannonValueOpening: Int = 450
    var cannonValueEndgame: Int = 400  // 残局炮 < 马
    var advisorValue: Int = 200
    var elephantValue: Int = 200
    var soldierValueEarly: Int = 100
    var soldierValueCrossed: Int = 200
    var soldierValueLateEndgame: Int = 300

    /// 残局/残末期子力切换阈值
    var endgameThreshold: Int = 10     // totalPieces <= 此值进入残局
    var lateEndgameThreshold: Int = 6  // totalPieces <= 此值进入残末期

    // MARK: - evaluate() 组合权重

    /// 评估函数各分量权重（原始代码: 1.0 / 1.0 / 1.0 / 0.33 / 0.8）
    var materialWeight: Double = 1.0
    var positionWeight: Double = 1.0
    var patternWeight: Double = 1.0
    var mobilityWeight: Double = 0.33    // 1/3
    var safetyWeight: Double = 0.8       // 4/5

    // MARK: - 将帅安全评估权重

    var guardWeightOpening: Int = 30
    var guardWeightEndgame: Int = 20
    var elephantWeightModifier: Int = -5  // guardWeight + this
    var exposurePenaltyOpening: Int = 40
    var exposurePenaltyEndgame: Int = 25
    var airDefenseBonus: Int = 40
    var airDefensePenaltyOpening: Int = 30
    var attackPenaltyEndgame: Int = 250
    var attackPenaltyOpening: Int = 200
    var horsePalaceThreatDirect: Int = 150
    var horsePalaceThreatNear: Int = 30

    // MARK: - 机动性评估权重

    var chariotRowColEmptyMultiplier: Int = 5
    var chariotCenterBonus: Int = 30
    var chariotNearCenterBonus: Int = 20
    var chariotEndgameMultiplier: Int = 6
    var chariotOpeningMultiplier: Int = 5
    var cannonTargetBonus: Int = 3
    var cannonCenterBonus: Int = 20
    var cannonEndgameFactor: Int = 7   // score * 7 / 10
    var horseJumpBonus: Int = 3
    var horseEndgameJumpBonus: Int = 2
    var horseBadPositionPenalty: Int = 40  // 窝心马
    var soldierForwardBonus: Int = 15
    var soldierSideBonus: Int = 10

    // MARK: - 棋型识别奖励

    var doubleChariotBonus: Int = 800
    var singleChariotWithWeakBonus: Int = 400
    var horseGeneralFacingBonus: Int = 2000
    var fishingHorseBonus: Int = 1000
    var ironGateBonus: Int = 1500
    var centralCannonBonus: Int = 1200
    var horseCenterBonus: Int = 600
    var horseBadCenterPenalty: Int = -600
    var chariotCannonLineBonus: Int = 1000
    var tandemCannonBonus: Int = 500
    var riverCannonBonus: Int = 400
    var stackedCannonBonus: Int = 200
    var cornerAdvisorBonus: Int = 200
    var flyingElephantBonus: Int = 200
    var generalProximityBonusBase: Int = 50
    var generalProximityBonusRange: Int = 3
    var soldierStructureBonus: Int = 300
    var soldierLineSyncBonus: Int = 300
    var chariotCannonCoordBonus: Int = 350
    var chariotCannonProtectBonus: Int = 250
    var horseCannonCoordBonus: Int = 100

    // MARK: - 搜索参数（非评估，但影响棋力）

    var endgameEvalThreshold: Int = 6  // totalPieces <= 此值时使用残局精确估值

    // MARK: - 默认值

    static let `default` = EvalWeights()

    // MARK: - JSON 加载

    /// 从 JSON 文件加载权重，失败则返回默认值
    static func load(from url: URL) -> EvalWeights {
        guard let data = try? Data(contentsOf: url) else {
            return .default
        }
        return (try? JSONDecoder().decode(EvalWeights.self, from: data)) ?? .default
    }

    /// 从 JSON 字符串加载权重
    static func load(from jsonString: String) -> EvalWeights {
        guard let data = jsonString.data(using: .utf8) else {
            return .default
        }
        return (try? JSONDecoder().decode(EvalWeights.self, from: data)) ?? .default
    }

    /// 导出为 JSON 字符串
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 导出为 JSON Data
    func toJSONData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// 写入文件
    func save(to url: URL) -> Bool {
        guard let data = toJSONData() else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// 导出为字典（供 CMA-ES 使用）
    func toParameterArray() -> [String: Double] {
        let mirror = Mirror(reflecting: self)
        var params: [String: Double] = [:]
        for child in mirror.children {
            guard let label = child.label else { continue }
            switch child.value {
            case let v as Int: params[label] = Double(v)
            case let v as Double: params[label] = v
            default: break
            }
        }
        return params
    }
}
