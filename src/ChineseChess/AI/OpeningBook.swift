import Foundation

// MARK: - 开局库

/// 管理经典开局变化，中级及以上难度使用。
/// 优先加载 v2 格式（hash 直查），fallback 到 v1 格式（树状 JSON）。
final class OpeningBook {
    static let shared = OpeningBook()

    // MARK: - v2 格式类型

    private struct BookEntry: Codable {
        let move: String   // ICCS 格式
        let w: Int         // 权重
    }

    private struct BookFileV2: Codable {
        let version: Int
        let description: String?
        let entries: [String: [BookEntry]]  // hash_hex → [entries]
    }

    // MARK: - v1 格式类型（兼容）

    private struct OpeningEntryV1: Codable {
        let name: String
        let variations: [[String]]  // ICCS 格式走法序列
    }

    // MARK: - 运行时索引

    /// zobristHash → [(move, weight)]，按权重降序
    private let positionIndex: [UInt64: [(move: String, weight: Int)]]

    // MARK: - 初始化

    private init() {
        var idx: [UInt64: [(move: String, weight: Int)]] = [:]

        // 优先尝试加载 v2 格式（subdirectory → 根目录 fallback）
        var v2URL = ResourceBundle.url(forResource: "opening_book_v2", withExtension: "json",
                                         subdirectory: "OpeningBook")
        if v2URL == nil { v2URL = ResourceBundle.url(forResource: "opening_book_v2", withExtension: "json") }
        if let url = v2URL,
           let data = try? Data(contentsOf: url),
           let book = try? JSONDecoder().decode(BookFileV2.self, from: data),
           book.version == 2 {
            for (hashHex, entries) in book.entries {
                guard let hash = UInt64(hashHex.replacingOccurrences(of: "0x", with: ""),
                                         radix: 16) else { continue }
                idx[hash] = entries.map { (move: $0.move, weight: $0.w) }
                    .sorted { $0.weight > $1.weight }
            }
            #if DEBUG
            AppLog.openingBook.info("loaded v2 format, \(idx.count) positions")
            #endif
        } else {
            // fallback: 加载旧 v1 格式（subdirectory → 根目录 fallback）
            var v1URL = ResourceBundle.url(forResource: "openings", withExtension: "json",
                                             subdirectory: "OpeningBook")
            if v1URL == nil { v1URL = ResourceBundle.url(forResource: "openings", withExtension: "json") }
            if let url = v1URL,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([OpeningEntryV1].self, from: data) {
                idx = Self.buildV1Index(decoded)
                #if DEBUG
                AppLog.openingBook.info("loaded v1 format (fallback), \(idx.count) positions")
                #endif
            } else {
                #if DEBUG
                AppLog.openingBook.warning("no opening book found, using empty book")
                #endif
            }
        }

        self.positionIndex = idx
    }

    // MARK: - 查找

    /// 查找当前局面的推荐走法。返回权重最高的走法。
    func lookup(zobristHash: UInt64) -> String? {
        guard let entries = positionIndex[zobristHash], !entries.isEmpty else { return nil }
        return entries[0].move  // 已按权重降序排列
    }

    /// 查找当前局面的所有候选走法（按权重降序）。
    func lookupAll(zobristHash: UInt64) -> [(move: String, weight: Int)]? {
        positionIndex[zobristHash]
    }

    /// 按权重随机选择走法（增加开局多样性）。
    /// 用于中级难度；高级/大师仍用 lookup（选最优）。
    func lookupWeightedRandom(zobristHash: UInt64) -> String? {
        guard let entries = positionIndex[zobristHash], !entries.isEmpty else { return nil }
        if entries.count == 1 { return entries[0].move }

        let totalWeight = entries.reduce(0) { $0 + $1.weight }
        var r = SeededRandom.int(in: 0..<totalWeight)  // Phase 1 seed 注入点②
        for entry in entries {
            r -= entry.weight
            if r < 0 { return entry.move }
        }
        return entries[0].move
    }

    /// 将 ICCS 格式走法解析为 Move（供 AIEngine 使用）
    /// 拷贝路径版（UI Board / LegacySearchBoard 调用方——Phase2aTests 等）。
    /// 与协议版共存无歧义：Board 仅 conform SearchBoardConvertible，
    /// AIEngine 泛型链仅匹配协议版。
    func parseICCSMove<T: SearchBoardConvertible>(_ iccs: String, on board: T) -> Move? {
        ICCSParser.parse(iccs, on: board)
    }

    /// P2c-①：SearchBoardProtocol 后端版（AIEngine 泛型链直通）。
    /// 语义与拷贝路径版全等（交叉对比 A/C/D 谓词）。
    func parseICCSMove<B: SearchBoardProtocol>(_ iccs: String, on board: B) -> Move? {
        ICCSParser.parseOnBackend(iccs, on: board)
    }

    // MARK: - v1 兼容索引构建

    private static func buildV1Index(_ entries: [OpeningEntryV1]) -> [UInt64: [(move: String, weight: Int)]] {
        var idx: [UInt64: [(move: String, weight: Int)]] = [:]
        for entry in entries {
            for variation in entry.variations {
                guard let board = FENParser.parse(fen: FENParser.standardInitial) else { continue }

                for (stepIndex, iccsMove) in variation.enumerated() {
                    guard let move = ICCSParser.parse(iccsMove, on: board) else {
                        #if DEBUG
                        AppLog.openingBook.warning("illegal move '\(iccsMove)' in '\(entry.name)' at step \(stepIndex + 1)")
                        #endif
                        break
                    }

                    // 执行走法
                    board.execute(move)

                    // 记录执行后的局面 hash → 下一步的 ICCS 走法
                    if stepIndex + 1 < variation.count {
                        let nextMove = variation[stepIndex + 1]
                        let h = ZobristHash.hash(board: board)
                        // v1 每个局面只有一个走法，权重设为 1
                        if idx[h] != nil {
                            idx[h]!.append((move: nextMove, weight: 1))
                        } else {
                            idx[h] = [(move: nextMove, weight: 1)]
                        }
                    }
                }
            }
        }
        return idx
    }
}
