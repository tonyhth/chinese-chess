import Foundation

// MARK: - 棋子类型
enum PieceKind: String, CaseIterable, Codable {
    case general   // 将/帅
    case advisor   // 士/仕
    case elephant  // 象/相
    case horse     // 马
    case chariot   // 车
    case cannon    // 炮
    case soldier   // 兵/卒
}

// MARK: - 阵营
enum Side: String, Codable {
    case red
    case black
}

// MARK: - 游戏状态
enum GameState: String, Equatable, Codable {
    case playing
    case redWon
    case blackWon
    case draw
}

// MARK: - AI 难度（v2.0: 5 级）
enum AIDifficulty: String, CaseIterable, Codable {
    case beginner  // 新手
    case easy      // 初级
    case medium    // 中级
    case hard      // 高级
    case master    // 大师
}

// MARK: - 对战模式
enum GameMode: String, CaseIterable, Codable {
    case singlePlayer  // 人机对战
    case localPVP      // 本地人人对战
}
