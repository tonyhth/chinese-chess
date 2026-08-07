import Foundation

// MARK: - 演示配置（统一模型）

/// 演示配置（统一，替代 common.md §3.6 的 PuzzleDemoConfig）
/// 字段名与 §3.6 一致，Schema 演进容错（decodeIfPresent + 默认值）
struct DemoConfig: Codable, Equatable {
    var speedMultiplier: Double = 1.0       // 对应 §3.6 speedMultiplier（DemoSpeed.rawValue）
    var pauseOnCommentary: Bool = true      // 对应 §3.6 pauseOnCommentary
    var autoNextPuzzle: Bool = true         // 对应 §3.6 autoNextPuzzle（即 autoAdvance）
    var showCommentary: Bool = true         // 对应 §3.6 showCommentary
    var smartCommentaryEnabled: Bool = false // 智能点评（MasterGameCommentator）

    /// 便利属性：speedMultiplier ↔ DemoSpeed
    var demoSpeed: DemoSpeed {
        get { DemoSpeed(rawValue: speedMultiplier) ?? .normal }
        set { speedMultiplier = newValue.rawValue }
    }

    // MARK: - Schema 演进容错

    enum CodingKeys: String, CodingKey {
        case speedMultiplier
        case pauseOnCommentary
        case autoNextPuzzle
        case showCommentary
        case smartCommentaryEnabled
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speedMultiplier = try container.decodeIfPresent(Double.self, forKey: .speedMultiplier) ?? 1.0
        pauseOnCommentary = try container.decodeIfPresent(Bool.self, forKey: .pauseOnCommentary) ?? true
        autoNextPuzzle = try container.decodeIfPresent(Bool.self, forKey: .autoNextPuzzle) ?? true
        showCommentary = try container.decodeIfPresent(Bool.self, forKey: .showCommentary) ?? true
        smartCommentaryEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartCommentaryEnabled) ?? false
    }

    // MARK: - 持久化

    private static let storageKey = "chinesechess.demoConfig"

    static func load() -> DemoConfig {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return DemoConfig()  // 默认值
        }
        return (try? JSONDecoder().decode(DemoConfig.self, from: data)) ?? DemoConfig()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
