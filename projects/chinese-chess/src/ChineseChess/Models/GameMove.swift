import Foundation

// MARK: - 走法记录（面向视图层的不可变记录）

/// 与 v1.0 Move 的关系：
/// - Move: AI 搜索内部使用的轻量走法，用于 Board.execute/undoLastMove 和 minimax
/// - GameMove: 面向视图层的不可变记录，含棋谱文本、时间戳、将军标记等展示信息
///
/// 创建方式：GameViewModel 走棋后一次性构建，isCheck/isCheckmate 在 execute 后判断。
/// NotationGenerator（Phase 3 实现）将在走棋前生成 notation。
/// 当前 notation 暂为空字符串占位，不影响数据结构完整性。
struct GameMove: Identifiable, Codable {
    let id: UUID
    let piece: Piece           // 移动的棋子
    let from: Position         // 起点
    let to: Position           // 终点
    let captured: Piece?       // 被吃棋子

    // v2.0 新增
    let turnNumber: Int        // 回合号（从 1 开始，红黑各走一次 = 1 回合）
    let notation: String       // 棋谱文本占位，Phase 3 NotationGenerator 实现后填充
    let timestamp: Date        // 走棋时间
    let isCheck: Bool          // 是否将军
    var isCheckmate: Bool     // 是否将死（走棋后延迟标记）
}
