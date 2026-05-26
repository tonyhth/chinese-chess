import Foundation

// MARK: - 棋子类型
enum PieceKind: String, CaseIterable {
    case general   // 将/帅
    case advisor   // 士/仕
    case elephant  // 象/相
    case horse     // 马
    case chariot   // 车
    case cannon    // 炮
    case soldier   // 兵/卒
}

// MARK: - 阵营
enum Side: String {
    case red
    case black
}

// MARK: - 游戏状态
enum GameState: Equatable {
    case playing
    case redWon
    case blackWon
    case draw
}

// MARK: - AI 难度
enum AIDifficulty: String, CaseIterable {
    case easy
    case medium
    case hard
}
