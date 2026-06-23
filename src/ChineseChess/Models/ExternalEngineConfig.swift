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

    /// 方案 E：使用 in-process mock 引擎（测试用，不启动外部进程）
    var useInProcessMock: Bool = false

    /// 默认配置
    static let defaultConfig = ExternalEngineConfig(
        name: "",
        executablePath: "",
        arguments: nil,
        options: [],
        isEnabled: false,
        useInProcessMock: false
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

    /// 当前选中的外部引擎 ID（nil 表示未选中具体引擎）
    var selectedEngineId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedEngineId?.uuidString, forKey: "chinesechess.selectedEngine")
        }
    }

    /// 用户是否期望使用外部引擎（独立于 selectedEngineId）
    /// Picker 绑定此属性，使选 "外部引擎" 后即使 engines 为空也能显示引导 UI
    var wantsExternalEngine: Bool = false {
        didSet {
            UserDefaults.standard.set(wantsExternalEngine, forKey: "chinesechess.wantsExternalEngine")
        }
    }

    /// 当前是否实际使用外部引擎（有选中的引擎配置）
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
        // P0 修复：读取 wantsExternalEngine 标记
        // 迁移逻辑：如果旧代码中 selectedEngineId != nil 但 wantsExternalEngine 未设置，自动补上
        if let wants = UserDefaults.standard.object(forKey: "chinesechess.wantsExternalEngine") as? Bool {
            wantsExternalEngine = wants
        } else {
            wantsExternalEngine = selectedEngineId != nil
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
            selectedEngineId = engines.first?.id
            // 引擎全删完时，重置 wantsExternalEngine
            if engines.isEmpty {
                wantsExternalEngine = false
            }
        }
    }
}
