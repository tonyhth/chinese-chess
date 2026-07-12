import Foundation

// MARK: - 点评类型

/// 棋谱自动演示点评（Phase 1 仅三种）
enum CommentaryType {
    case check(side: Side)       // 将军
    case checkmate(side: Side)   // 将死
    case keyMove                 // 最后一步关键走法
}

// MARK: - 点评条目

struct CommentaryItem: Identifiable {
    let id = UUID()
    let type: CommentaryType
    let timestamp = Date()

    /// 点评文本
    var text: String {
        switch type {
        case .check(let side):
            let sideName = side == .red
                ? String(localized: "红方")
                : String(localized: "黑方")
            return String(localized: "\(sideName)将军！")
        case .checkmate(let side):
            let sideName = side == .red
                ? String(localized: "红方")
                : String(localized: "黑方")
            return String(localized: "\(sideName)将死！绝杀！")
        case .keyMove:
            return String(localized: "关键一步！")
        }
    }

    /// 图标
    var icon: String {
        switch type {
        case .check: return "bolt.fill"
        case .checkmate: return "crown.fill"
        case .keyMove: return "star.fill"
        }
    }
}

// MARK: - CommentaryEngine

/// 规则推断点评引擎
/// Phase 1 仅支持：将军(check)、将死(checkmate)、最后一步(keyMove)
/// 弃子检测留给 Phase 2
struct CommentaryEngine {

    /// 对指定走法生成点评
    /// - Parameters:
    ///   - move: 当前走法
    ///   - board: 执行后的棋盘
    ///   - moveIndex: 走法索引
    ///   - totalMoves: 总步数
    /// - Returns: 点评条目，或 nil
    static func evaluate(move: Move, on board: Board, moveIndex: Int, totalMoves: Int) -> CommentaryItem? {
        // 检查将军/将死
        let currentSide = board.currentTurn  // 下一步走棋方
        if MoveValidator.isInCheck(currentSide, on: board) {
            // currentSide 被将军
            if MoveValidator.isCheckmate(currentSide, on: board) {
                return CommentaryItem(type: .checkmate(side: currentSide))
            }
            return CommentaryItem(type: .check(side: currentSide))
        }

        // 最后一步（非将死）
        if moveIndex == totalMoves - 1 {
            return CommentaryItem(type: .keyMove)
        }

        return nil
    }
}
