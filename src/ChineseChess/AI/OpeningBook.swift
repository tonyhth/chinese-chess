import Foundation

// MARK: - 开局库

/// 管理经典开局变化，中级及以上难度使用。
/// 初始化时从 JSON 加载，预计算 Zobrist hash，运行时 O(1) 查找。
struct OpeningBook {

    struct OpeningEntry: Codable {
        let name: String
        let variations: [[String]]  // ICCS 格式走法序列
    }

    private let positionIndex: [UInt64: String]  // zobristHash → ICCS move
    private let entries: [OpeningEntry]

    // MARK: - 初始化

    init() {
        // 尝试加载 openings.json
        let loadedEntries: [OpeningEntry]
        if let url = ResourceBundle.url(forResource: "openings", withExtension: "json", subdirectory: "OpeningBook"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([OpeningEntry].self, from: data) {
            loadedEntries = decoded
        } else {
            #if DEBUG
            print("[INFO] OpeningBook: openings.json not found, using empty book")
            #endif
            loadedEntries = []
        }
        // 预计算每个 variation 各步后的 Zobrist hash
        var idx: [UInt64: String] = [:]
        for entry in loadedEntries {
            for variation in entry.variations {
                guard let board = FENParser.parse(fen: FENParser.standardInitial) else { continue }

                for (stepIndex, iccsMove) in variation.enumerated() {
                    guard let move = ICCSParser.parse(iccsMove, on: board) else {
                        #if DEBUG
                        print("[WARN] OpeningBook: illegal move '\(iccsMove)' in '\(entry.name)' at step \(stepIndex + 1)")
                        #endif
                        break
                    }

                    // 执行走法
                    board.execute(move)

                    // 记录执行后的局面 hash → 下一步的 ICCS 走法
                    if stepIndex + 1 < variation.count {
                        let nextMove = variation[stepIndex + 1]
                        let h = ZobristHash.hash(board: board)
                        idx[h] = nextMove
                    }
                }
            }
        }
        self.entries = loadedEntries
        self.positionIndex = idx
    }

    // MARK: - 查找

    /// 查找当前局面的推荐走法。传入当前局面的 Zobrist hash。
    func lookup(zobristHash: UInt64) -> String? {
        positionIndex[zobristHash]
    }

    /// 将 ICCS 格式走法解析为 Move（供 AIEngine 使用）
    func parseICCSMove(_ iccs: String, on board: Board) -> Move? {
        ICCSParser.parse(iccs, on: board)
    }
}
