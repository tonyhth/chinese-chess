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
        // 尝试从 Bundle.module 加载 openings.json
        let loadedEntries: [OpeningEntry]
        if let url = Bundle.module.url(forResource: "openings", withExtension: "json", subdirectory: "OpeningBook"),
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
                    guard let move = Self.parseICCS(iccsMove, on: board) else {
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
        Self.parseICCS(iccs, on: board)
    }

    // MARK: - ICCS 解析

    /// 将 ICCS 格式（如 "h2e2"）解析为 Move
    private static func parseICCS(_ iccs: String, on board: Board) -> Move? {
        guard iccs.count == 4 else { return nil }
        let chars = Array(iccs)

        // ICCS: 列用 a-i（a=col0），行用 0-9（0=黑方底线行）
        guard let fromCol = colFromChar(chars[0]),
              let fromRow = rowFromChar(chars[1]),
              let toCol = colFromChar(chars[2]),
              let toRow = rowFromChar(chars[3]) else { return nil }

        let from = Position(row: fromRow, col: fromCol)
        let to = Position(row: toRow, col: toCol)

        guard let piece = board.piece(at: from) else { return nil }
        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return nil }
        return move
    }

    private static func colFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "a"), ascii <= UInt8(ascii: "i") else { return nil }
        return Int(ascii - UInt8(ascii: "a"))
    }

    private static func rowFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "0"), ascii <= UInt8(ascii: "9") else { return nil }
        // ICCS 行号 0 = 红方底线(row=9), 9 = 黑方底线(row=0)
        return 9 - Int(ascii - UInt8(ascii: "0"))
    }
}
