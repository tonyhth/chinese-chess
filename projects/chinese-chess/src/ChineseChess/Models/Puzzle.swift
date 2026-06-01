import Foundation

// MARK: - 残局数据模型

struct Puzzle: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let difficulty: Int          // 1-4
    let stars: Int               // 1-5
    let description: String
    let playerSide: String       // "red" / "black"
    let initialFEN: String
    let solution: [String]       // ICCS 坐标格式
    let hints: [String]?
    let maxMoves: Int

    var side: Side {
        playerSide == "red" ? .red : .black
    }
}

struct PuzzleData: Codable {
    let version: Int
    let puzzles: [Puzzle]
}

// MARK: - 闯关进度

struct PuzzleProgress: Codable {
    let puzzleId: String
    var isCompleted: Bool
    var bestMoves: Int?
    var completedAt: Date?
}
