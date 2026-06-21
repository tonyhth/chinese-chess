import Foundation

// MARK: - 评估权重管理器

/// 管理评估函数权重的加载、热重载和存储
/// v3.1 Phase 1: 支持开发模式热重载
final class EvalConfigManager {
    static let shared = EvalConfigManager()

    /// 当前使用的权重
    private(set) var weights: EvalWeights

    /// 权重配置文件路径
    private let configURL: URL

    /// 开发模式：监控文件变化自动重载
    var devMode: Bool = false {
        didSet {
            if devMode && !isMonitoring {
                startMonitoring()
            } else if !devMode && isMonitoring {
                stopMonitoring()
            }
        }
    }

    private var isMonitoring = false
    private var monitorSource: DispatchSourceFileSystemObject?
    private var lastModTime: Date?

    private init() {
        // 配置文件路径：bundle Resources
        self.configURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/eval-weights.json")

        if FileManager.default.fileExists(atPath: configURL.path) {
            self.weights = EvalWeights.load(from: configURL)
        } else {
            self.weights = .default
            self.weights.save(to: configURL)
        }
    }

    /// 测试用初始化器
    init(weights: EvalWeights = .default) {
        self.weights = weights
        self.configURL = URL(fileURLWithPath: "/dev/null")
    }

    // MARK: - 热重载

    func reload() {
        if FileManager.default.fileExists(atPath: configURL.path) {
            weights = EvalWeights.load(from: configURL)
        }
    }

    /// 用新的权重替换（供 CMA-ES / 测试使用）
    func setWeights(_ newWeights: EvalWeights) {
        weights = newWeights
    }

    // MARK: - 文件监控

    private func startMonitoring() {
        guard !isMonitoring else { return }

        let queue = DispatchQueue(label: "com.chinesechess.eval-monitor", qos: .utility)
        let fileDescriptor = open(configURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        isMonitoring = true

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.handleFileChange()
            }
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.resume()
        self.monitorSource = source
    }

    private func stopMonitoring() {
        monitorSource?.cancel()
        monitorSource = nil
        isMonitoring = false
    }

    private func handleFileChange() {
        let modDate = (try? FileManager.default.attributesOfItem(atPath: configURL.path)[.modificationDate]) as? Date
        if let modDate = modDate, modDate != lastModTime {
            lastModTime = modDate
            reload()
        }
    }

    deinit {
        stopMonitoring()
    }
}
