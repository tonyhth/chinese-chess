import Foundation

// MARK: - Phase 1: seed 注入通道（SPRT 协议前置，Luke 指令升级项）

/// 可注入的种子化随机源。
///
/// 三注入点（首单五件确认③）：
/// - SelfPlayRunner.softmaxSelect（Double.random）
/// - OpeningBook.lookupWeightedRandom（Int.random）
/// - AIEngine.weightedRandomPick（Int.random）
///
/// 语义：CLI `--seed <N>` 设置一次（501/502/503 与历史 run 区分）；未设置时
/// 回退系统熵（SystemRandomNumberGenerator），产品路径零变化。
/// 线程安全：NSLock 保护（双引擎对弈交错调用）。
enum SeededRandom {

    private static let lock = NSLock()
    private static var rng: SplitMix64?

    /// 设置种子（nil = 回退系统熵）。CLI 启动时调用一次。
    static func configure(seed: UInt64?) {
        lock.lock(); defer { lock.unlock() }
        rng = seed.map { SplitMix64(seed: $0) }
    }

    /// 当前是否已注入种子（报告/落盘元数据用）
    static var isSeeded: Bool {
        lock.lock(); defer { lock.unlock() }
        return rng != nil
    }

    static func int(in range: Range<Int>) -> Int {
        lock.lock(); defer { lock.unlock() }
        if var r = rng {
            let v = Int.random(in: range, using: &r)
            rng = r  // 写回状态（SplitMix64 是值类型）
            return v
        }
        return Int.random(in: range)
    }

    static func double(in range: Range<Double>) -> Double {
        lock.lock(); defer { lock.unlock() }
        if var r = rng {
            let v = Double.random(in: range, using: &r)
            rng = r
            return v
        }
        return Double.random(in: range)
    }
}
