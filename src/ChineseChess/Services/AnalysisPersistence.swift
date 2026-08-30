import Foundation
import CryptoKit

// MARK: - v6.4 A2①：分析结果持久化（decision v1.1）

/// movesHash 口径常量（decision v1.1 冻结，禁止自造口径）
/// 输入 = initialFEN + "\n" + uciMoves 空格连接；SHA256 前 16 hex
enum AnalysisMovesHash {
    /// 分隔符（FEN 与着法列表之间），口径冻结
    static let separator = "\n"
    /// 着法连接分隔符，口径冻结
    static let moveJoinSeparator = " "
    /// 取前 N 位 hex，口径冻结
    static let hexPrefixLength = 16

    static func compute(initialFEN: String, uciMoves: [String]) -> String {
        let input = initialFEN + separator + uciMoves.joined(separator: moveJoinSeparator)
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }
            .joined()
            .prefix(hexPrefixLength)
            .lowercased()
    }
}

/// 分析结果信封（sidecar `{uuid}.analysis.json` 载荷）
/// - movesHash 定整体有效性（变 = 整体重跑，中段编辑即此路径）
/// - analyzedMoveCount 只做尾部追加式增量（续弈从 count 起算），单调不回退
struct AnalysisEnvelope: Codable {
    /// 结构版本（平滑迁移预留）
    let schemaVersion: Int
    /// 所属棋谱 id
    let recordId: UUID
    /// 锁定棋谱内容的哈希（AnalysisMovesHash.compute 口径）
    let movesHash: String
    /// 已分析的玩家着数（尾部追加语义）
    var analyzedMoveCount: Int
    /// 分析时的引擎版本（过期判定锚之一）
    let engineVersion: String
    /// 分析时的深度档（过期判定锚之一）
    let depthSetting: Int
    /// moveIndex → 分析结果（仅玩家着）
    var analyses: [Int: MoveAnalysis]
}

/// 当前分析口径（engineVersion/depthSetting 的单一事实源）
/// AnalysisViewModel 分析与持久化共用，防双口径漂移
enum AnalysisProfile {
    static let schemaVersion = 1
    static let depth = 12
    /// 引擎版本（异步经 PositionAnalyzer 取真实引擎版本；测试经 EngineVersionProvider.override 注入）
    static func engineVersion() async -> String {
        if let o = EngineVersionProvider.override { return o }
        return await PositionAnalyzer.shared.currentEngineVersion()
    }
}

/// 引擎版本提供者（可测试注入）
enum EngineVersionProvider {
    /// 测试注入覆写；nil 时经 PositionAnalyzer 取真实引擎版本
    static var override: String?
}

// MARK: - GameRecordStore 扩展：sidecar 生命周期（decision v1.1 边界提醒）

extension GameRecordStore {

    /// 读取分析信封（按需加载；summaries 路径零膨胀）
    func loadAnalysisEnvelope(recordId: UUID) -> AnalysisEnvelope? {
        let url = baseURL.appendingPathComponent("\(recordId.uuidString).analysis.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        // P2-2：损坏 sidecar 静默全量重跑排查不可见——补 DEBUG 日志（Ruby 08-30）
        if let env = try? JSONDecoder().decode(AnalysisEnvelope.self, from: data) {
            return env
        }
        #if DEBUG
        AppLog.history.warning("analysis sidecar \(recordId.uuidString) corrupt, falling back to full re-analysis")
        #endif
        return nil
    }

    /// 落盘分析信封（writeQueue 串行；analyzedMoveCount 单调不回退）
    /// 写失败留旧不删（旧 movesHash 不匹配新棋谱时自然走过期回收）——decision v1.1 写序语义
    func saveAnalysisEnvelope(_ envelope: AnalysisEnvelope) {
        writeQueue.sync {
            let url = baseURL.appendingPathComponent("\(envelope.recordId.uuidString).analysis.json")
            // 单调不回退：批中 checkpoint 不得覆盖已写入的更高计数
            var toWrite = envelope
            if let existing = try? JSONDecoder().decode(AnalysisEnvelope.self, from: Data(contentsOf: url)),
               existing.movesHash == envelope.movesHash,
               existing.analyzedMoveCount > envelope.analyzedMoveCount {
                toWrite.analyzedMoveCount = existing.analyzedMoveCount
                toWrite.analyses = existing.analyses.merging(envelope.analyses) { _, new in new }
            }
            guard let data = try? JSONEncoder().encode(toWrite) else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                #if DEBUG
                AppLog.history.error("failed to write analysis \(envelope.recordId): \(error)")
                #endif
            }
        }
    }

    /// 删除分析信封（删棋谱连带删 analysis；analysis 无独立删除面）
    func deleteAnalysisEnvelope(recordId: UUID) {
        writeQueue.sync {
            let url = baseURL.appendingPathComponent("\(recordId.uuidString).analysis.json")
            try? fileManager.removeItem(at: url)
        }
    }
}
