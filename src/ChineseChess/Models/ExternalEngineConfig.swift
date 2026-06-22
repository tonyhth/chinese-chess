import Foundation

// MARK: - UCI 选项

/// UCI 选项键值对（Codable 安全）
struct UCIOption: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String   // 如 "Hash"
    var value: String  // 如 "128"
}

// MARK: - 外部引擎配置

/// 外部引擎配置（持久化到 UserDefaults）
struct ExternalEngineConfig: Codable, Equatable, Identifiable {
    var id: UUID = UUID()

    /// 引擎显示名称（用户自定义，如 "Pikafish 4.0"）
    var name: String

    /// 可执行文件路径（如 /usr/local/bin/pikafish）
    var executablePath: String

    /// 启动参数（可选，如 ["--threads=2"]）
    var arguments: [String]?

    /// UCI 选项列表（如 Hash=128, Threads=2）
    var options: [UCIOption]

    /// 是否启用
    var isEnabled: Bool

    /// 默认配置
    static let defaultConfig = ExternalEngineConfig(
        name: "",
        executablePath: "",
        arguments: nil,
        options: [],
        isEnabled: false
    )
}

// MARK: - 引擎配置管理器

/// 引擎配置管理器（单例）
/// 管理 UserDefaults 持久化的外部引擎配置列表
@MainActor
@Observable
final class EngineConfigStore {
    static let shared = EngineConfigStore()

    private let key = "chinesechess.externalEngines"

    /// 所有已配置的外部引擎列表
    var engines: [ExternalEngineConfig] {
        didSet { save() }
    }

    /// 当前选中的外部引擎 ID（nil 表示使用自研引擎）
    var selectedEngineId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedEngineId?.uuidString, forKey: "chinesechess.selectedEngine")
        }
    }

    /// 当前是否使用外部引擎
    var useExternalEngine: Bool {
        selectedEngineId != nil
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ExternalEngineConfig].self, from: data) {
            engines = decoded
        } else {
            engines = []
        }
        if let idStr = UserDefaults.standard.string(forKey: "chinesechess.selectedEngine"),
           let uuid = UUID(uuidString: idStr) {
            selectedEngineId = uuid
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(engines) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func addEngine(_ config: ExternalEngineConfig) {
        engines.append(config)
    }

    func removeEngine(at index: Int) {
        guard engines.indices.contains(index) else { return }
        let removed = engines[index]
        engines.remove(at: index)
        if selectedEngineId == removed.id {
            selectedEngineId = nil
        }
    }
}
