import Foundation

// MARK: - 玩家信息

struct PlayerInfo: Codable, Equatable {
    let name: String           // "玩家" / "AI-高级" / "红方" / "黑方"
    let isAI: Bool
    let difficulty: AIDifficulty?
}

// MARK: - 棋谱记录

struct GameRecord: Identifiable, Codable {
    let id: UUID
    var title: String          // "第 3 局" 或自定义标题
    let date: Date
    let redPlayer: PlayerInfo
    let blackPlayer: PlayerInfo
    let difficulty: AIDifficulty
    let result: GameState      // redWon / blackWon / draw
    let totalMoves: Int
    let moves: [GameMove]      // 完整走法列表
    let initialFEN: String?    // 非标准开局时记录
}
