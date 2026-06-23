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
struct ExternalEngineConfig: Equatable, Identifiable {
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

    // P1 #3: 引擎自报的身份信息（测试连接后填充）
    var resolvedName: String?     // 如 "Pikafish"
    var resolvedVersion: String?  // 如 "4.0.0"

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

// MARK: - Codable 自定义实现（向后兼容）

extension ExternalEngineConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case executablePath
        case arguments
        case options
        case isEnabled
        case useInProcessMock
        case resolvedName
        case resolvedVersion
    }

    /// P0 修复：手动实现解码，对缺失的 useInProcessMock 使用默认值
    /// 确保旧配置 JSON（无此字段）能正常加载
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        executablePath = try container.decode(String.self, forKey: .executablePath)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments)
        options = try container.decode([UCIOption].self, forKey: .options)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        // 关键：缺失时使用默认值 false（向后兼容）
        useInProcessMock = try container.decodeIfPresent(Bool.self, forKey: .useInProcessMock) ?? false
        // P1 #3: 向后兼容，缺失时为 nil
        resolvedName = try container.decodeIfPresent(String.self, forKey: .resolvedName)
        resolvedVersion = try container.decodeIfPresent(String.self, forKey: .resolvedVersion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(executablePath, forKey: .executablePath)
        try container.encodeIfPresent(arguments, forKey: .arguments)
        try container.encode(options, forKey: .options)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(useInProcessMock, forKey: .useInProcessMock)
        try container.encodeIfPresent(resolvedName, forKey: .resolvedName)
        try container.encodeIfPresent(resolvedVersion, forKey: .resolvedVersion)
    }
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

    // P1 #5: 待切换引擎 ID（菜单栏切换目标，下次对局生效）
    var pendingEngineId: UUID? {
        didSet {
            UserDefaults.standard.set(pendingEngineId?.uuidString, forKey: "chinesechess.pendingEngine")
        }
    }

    // P1 返工: pendingNative — 用户选"内置引擎"时标记，解决 Picker 弹回问题
    var pendingNative: Bool = false {
        didSet {
            UserDefaults.standard.set(pendingNative, forKey: "chinesechess.pendingNative")
        }
    }

    /// 是否有待切换的引擎
    var hasPendingSwitch: Bool {
        pendingEngineId != selectedEngineId
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
        // P1 #5: 读取待切换引擎 ID
        if let idStr = UserDefaults.standard.string(forKey: "chinesechess.pendingEngine"),
           let uuid = UUID(uuidString: idStr) {
            pendingEngineId = uuid
        }
        // P1 返工: 读取 pendingNative 标记
        pendingNative = UserDefaults.standard.bool(forKey: "chinesechess.pendingNative")
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
