import XCTest
@testable import VocabGame

final class SeededRandomGeneratorTests: XCTestCase {

    // MARK: - 确定性

    func testSameSeed_producesSameSequence() {
        var g1 = SeededRandomGenerator(seed: 20250525)
        var g2 = SeededRandomGenerator(seed: 20250525)

        let seq1 = (0..<10).map { _ in Int(g1.next() % 100) }
        let seq2 = (0..<10).map { _ in Int(g2.next() % 100) }

        XCTAssertEqual(seq1, seq2, "同一种子应产生相同序列")
    }

    func testDifferentSeeds_produceDifferentSequences() {
        var g1 = SeededRandomGenerator(seed: 1)
        var g2 = SeededRandomGenerator(seed: 2)

        let v1 = g1.next()
        let v2 = g2.next()

        XCTAssertNotEqual(v1, v2, "不同种子应产生不同序列")
    }

    // MARK: - 日期种子映射

    func testDateSeedFormat() {
        // 模拟 DailyChallengeViewModel 中的种子计算
        let date = Date()
        let seed = Calendar.current.component(.day, from: date) * 10000
            + Calendar.current.component(.month, from: date) * 100
            + Calendar.current.component(.year, from: date) % 100

        // 同一天生成两次，种子应相同
        let seed2 = Calendar.current.component(.day, from: date) * 10000
            + Calendar.current.component(.month, from: date) * 100
            + Calendar.current.component(.year, from: date) % 100

        XCTAssertEqual(seed, seed2)

        // 种子应在合理范围
        XCTAssertGreaterThan(seed, 0)
    }

    func testDateSeed_nextDayDifferent() {
        // 同月不同日 → 种子不同
        let day1 = Calendar.current.component(.day, from: date(year: 2025, month: 5, day: 25)!)
        let day2 = Calendar.current.component(.day, from: date(year: 2025, month: 5, day: 26)!)

        let seed1 = day1 * 10000 + 5 * 100 + 25
        let seed2 = day2 * 10000 + 5 * 100 + 25

        XCTAssertNotEqual(seed1, seed2)
    }

    // MARK: - 用作 shuffled(using:) 的 RandomNumberGenerator

    func testShuffledWithSeed_isDeterministic() {
        let items = Array(1...20)
        var g1 = SeededRandomGenerator(seed: 42)
        var g2 = SeededRandomGenerator(seed: 42)

        let s1 = items.shuffled(using: &g1)
        let s2 = items.shuffled(using: &g2)

        XCTAssertEqual(s1, s2)
    }

    func testShuffledWithSeed_isNotOriginalOrder() {
        let items = Array(1...100)
        var g = SeededRandomGenerator(seed: 123)
        let shuffled = items.shuffled(using: &g)

        // 100 个元素不太可能保持原顺序
        XCTAssertNotEqual(shuffled, items)
    }

    // MARK: - 零种子边界

    func testZeroSeed_doesNotCrash() {
        var g = SeededRandomGenerator(seed: 0)
        let _ = g.next()
        let _ = g.next()
        // 不应崩溃
    }

    // MARK: - 种子碰撞

    func testDifferentDates_produceDifferentSeeds_highProbability() {
        // 验证不同日期的种子几乎不会碰撞
        var seeds: Set<Int> = []
        for month in 1...12 {
            for day in 1...28 {
                let seed = day * 10000 + month * 100 + 25
                seeds.insert(seed)
            }
        }
        XCTAssertEqual(seeds.count, 12 * 28, "每月每天的种子应唯一")
    }

    // MARK: - Helper

    private func date(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(calendar: Calendar.current, year: year, month: month, day: day))
    }
}
