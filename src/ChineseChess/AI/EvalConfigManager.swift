import Foundation

// MARK: - 评估权重管理器

/// 管理评估函数权重的加载、热重载和存储
/// v3.1 Phase 1: 支持开发模式热重载
/// T-1023 测试面项：线程安全治理——weights/监控状态/lastModTime 历史上多线程裸读写
/// （PatternRecognizer/AIEvaluator TD-001 注入改造已摘热路径缺省参数读，本变更收口管理器内部状态：
///   setWeights 任意线程调用 vs AIEngine init 读、devMode 写侧 vs 监控队列 handleFileChange，
///   均构成数据竞争）。锁形制同项目先例（EmbeddedPikafishEngine/SeededRandom/BoardIntegrityLogger NSLock）。
final class EvalConfigManager {
    static let shared = EvalConfigManager()

    /// 保护全部可变状态的串行锁
    private let stateLock = NSLock()

    /// 权重后备存储（仅持锁触达）
    private var _weights: EvalWeights

    /// 当前使用的权重
    /// 读侧返回 struct 快照（锁内拷贝，无撕裂读）；写侧仅 reload/setWeights/init 域内可达
    private(set) var weights: EvalWeights {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _weights
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _weights = newValue
        }
    }

    /// 权重配置文件路径
    private let configURL: URL

    /// 开发模式：监控文件变化自动重载
    var devMode: Bool = false {
        didSet {
            // 语义与原实现逐字对齐：重复赋同值仍走判定（isMonitoring 失位时允许重试起监控）
            if devMode && !isMonitoringActive() {
                startMonitoring()
            } else if !devMode && isMonitoringActive() {
                stopMonitoring()
            }
        }
    }

    private var isMonitoring = false
    private var monitorSource: DispatchSourceFileSystemObject?
    private var lastModTime: Date?

    private init() {
        // P2-2: 跨平台 bundle 路径
        self.configURL = Bundle.main.url(forResource: "eval-weights", withExtension: "json")
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/eval-weights.json")

        if FileManager.default.fileExists(atPath: configURL.path) {
            self._weights = EvalWeights.load(from: configURL)
        } else {
            self._weights = .default
            self._weights.save(to: configURL)
        }
    }

    /// 测试用初始化器
    init(weights: EvalWeights = .default) {
        self._weights = weights
        self.configURL = URL(fileURLWithPath: "/dev/null")
    }

    // MARK: - 热重载

    func reload() {
        if FileManager.default.fileExists(atPath: configURL.path) {
            weights = EvalWeights.load(from: configURL)
        }
    }

    /// 用新的权重替换（供 CMA-ES / 测试使用；任意线程安全）
    func setWeights(_ newWeights: EvalWeights) {
        weights = newWeights
    }

    // MARK: - 文件监控

    private func isMonitoringActive() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isMonitoring
    }

    private func startMonitoring() {
        stateLock.lock()
        guard !isMonitoring else {
            stateLock.unlock()
            return
        }
        stateLock.unlock()

        let queue = DispatchQueue(label: "com.chinesechess.eval-monitor", qos: .utility)
        let fileDescriptor = open(configURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

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

        // open 期间可能与他线程 start/stop 竞争：装源前锁内复核
        stateLock.lock()
        if isMonitoring {
            stateLock.unlock()
            source.cancel()  // fd 由 cancel handler 关闭
            return
        }
        isMonitoring = true
        monitorSource = source
        stateLock.unlock()
        source.resume()
    }

    private func stopMonitoring() {
        stateLock.lock()
        let source = monitorSource
        monitorSource = nil
        isMonitoring = false
        stateLock.unlock()
        source?.cancel()  // fd 由 cancel handler 关闭
    }

    private func handleFileChange() {
        let modDate = (try? FileManager.default.attributesOfItem(atPath: configURL.path)[.modificationDate]) as? Date
        guard let modDate = modDate else { return }
        stateLock.lock()
        let changed = (modDate != lastModTime)
        if changed {
            lastModTime = modDate
        }
        stateLock.unlock()
        if changed {
            reload()
        }
    }

    deinit {
        stopMonitoring()
    }
}
