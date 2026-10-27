import Testing
import Foundation
@testable import ChineseChess

// MARK: - T-1023 测试面项：EvalConfigManager 竞态治理验证
// 依据：t1023-remediation-plan §五「EvalConfigManager 竞态」+ PatternRecognizer/AIEvaluator
// TD-001 注释链（setWeights 与任意线程无锁单例读的数据竞争）。本套件钉管理器内部
// NSLock 串行化行为：并发写读快照一致性、setWeights 读回、devMode 快速启停幂等。
// 全程用测试专用实例（configURL=/dev/null），零触碰 shared 全局——Swift Testing
// 套件间并行，动 shared 会与 Batch1P0CMAESTests 的 setWeights/还原串扰。
// 安全性依据：EvalWeights.load 对空/坏数据回退 .default（partial 解码），/dev/null 读安全。

@Suite("EvalConfigManager 线程安全")
struct EvalConfigManagerConcurrencyTests {

    @Test("并发 setWeights/读竞争：快照必为已写变体（无撕裂读）")
    func concurrentSetReadConsistency() {
        let manager = EvalConfigManager(weights: .default)
        var a = EvalWeights.default
        a.generalValue = 11111
        var b = EvalWeights.default
        b.generalValue = 22222
        let variants: [EvalWeights] = [a, b]

        let counter = NSLock()
        var violations = 0

        // 8 线程 × 300 轮交替写 + 立即读：锁内 struct 拷贝保证快照完整
        DispatchQueue.concurrentPerform(iterations: 8) { threadIdx in
            for i in 0..<300 {
                manager.setWeights(variants[(threadIdx + i) % 2])
                let snapshot = manager.weights
                if !(snapshot == a || snapshot == b) {
                    counter.lock()
                    violations += 1
                    counter.unlock()
                }
            }
        }

        #expect(violations == 0, "2400 对并发写读不允许撕裂快照（violations=\(violations)）")
        let final = manager.weights
        #expect(final == a || final == b, "竞争收敛后终值仍必为某变体")
    }

    @Test("setWeights 即时读回一致")
    func setWeightsReadback() {
        let manager = EvalConfigManager(weights: .default)
        var custom = EvalWeights.default
        custom.materialWeight = 5.0
        manager.setWeights(custom)
        #expect(manager.weights == custom, "setWeights 后读回应逐字段相等")
        #expect(manager.weights.materialWeight == 5.0, "改动字段即时可见")
    }

    @Test("devMode 快速启停：监控幂等无崩溃，权重不受扰")
    func devModeToggleIdempotent() {
        let manager = EvalConfigManager(weights: .default)
        let before = manager.weights
        for _ in 0..<50 {
            manager.devMode = true
            manager.devMode = true   // 重复赋值钉 isMonitoring 幂等门（语义承自原实现）
            manager.devMode = false
            manager.devMode = false
        }
        #expect(manager.weights == before, "监控启停不得扰动权重")
    }
}
