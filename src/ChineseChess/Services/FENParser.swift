import Foundation

// MARK: - FEN 解析与序列化（Services 层薄封装，实际逻辑在 Models/FENDecoder）

/// FEN 格式：rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1
///
/// v3.8.0: 解析逻辑已提取到 Models/FENDecoder.swift，FENParser 保留为 Services 层兼容封装。

/// 标准开局 FEN
typealias FENStandardInitial = FENDecoder

struct FENParser {

    /// 标准开局 FEN（转发到 FENDecoder）
    static let standardInitial = FENDecoder.standardInitial

    // MARK: - 解析（转发到 FENDecoder）

    /// 从 FEN 字符串创建 Board
    static func parse(fen: String) -> Board? {
        guard let result = FENDecoder.parse(fen: fen) else { return nil }
        let board = Board(pieces: result.pieces)
        board.setCurrentTurn(result.currentTurn)
        return board
    }

    // MARK: - 序列化（转发到 FENDecoder）

    /// 从 Board 生成 FEN 字符串
    static func generate(board: Board) -> String {
        FENDecoder.generate(pieces: board.pieces, currentTurn: board.currentTurn)
    }

    // MARK: - 标准开局判断（转发到 FENDecoder）

    /// 判断 FEN 是否代表标准开局
    static func isStandardInitial(_ fen: String) -> Bool {
        FENDecoder.isStandardInitial(fen)
    }
}
