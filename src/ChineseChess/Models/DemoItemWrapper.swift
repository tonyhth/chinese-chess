import Foundation

// MARK: - 演示条目包装

/// 演示条目包装（编译期类型安全，自动 Equatable/Hashable）
/// 替代 any DemoItem 协议，避免 Existential Container 开销和 Equatable 问题
enum DemoItemWrapper: Identifiable, Equatable {
    case puzzle(Puzzle)
    case masterGame(MasterGameDemoItem)

    // MARK: - Equatable（手动实现，因为 Puzzle 不符合 Equatable）

    static func == (lhs: DemoItemWrapper, rhs: DemoItemWrapper) -> Bool {
        switch (lhs, rhs) {
        case (.puzzle(let a), .puzzle(let b)):
            return a.id == b.id
        case (.masterGame(let a), .masterGame(let b)):
            return a == b
        default:
            return false
        }
    }

    var id: String {
        switch self {
        case .puzzle(let p): return "puzzle_\(p.id)"
        case .masterGame(let m): return "master_\(m.index.id)"
        }
    }

    /// 演示标题
    var demoTitle: String {
        switch self {
        case .puzzle(let p): return p.name
        case .masterGame(let m): return "\(m.index.redNameCN) vs \(m.index.blackNameCN)"
        }
    }

    /// 演示副标题
    var demoSubtitle: String {
        switch self {
        case .puzzle(let p): return p.description
        case .masterGame(let m):
            var parts: [String] = []
            if let year = m.index.year { parts.append("\(year)") }
            parts.append(m.index.event)
            return parts.joined(separator: " · ")
        }
    }

    /// 分类名
    var demoCategory: String {
        switch self {
        case .puzzle(let p): return p.category
        case .masterGame(let m):
            return OpeningCategories.categories
                .first(where: { $0.firstMove == m.index.firstMove })?.name ?? "其他开局"
        }
    }

    /// 初始 FEN
    /// - .puzzle: 始终可用
    /// - .masterGame: 仅播放时可用（fen 非 nil），列表阶段为 nil 时断言
    var initialFEN: String {
        switch self {
        case .puzzle(let p): return p.initialFEN
        case .masterGame(let m):
            guard let fen = m.fen else {
                assertionFailure("DemoItemWrapper.initialFEN: masterGame.fen 为 nil，列表阶段不应访问此属性")
                return FENParser.standardInitial  // fallback
            }
            return fen
        }
    }

    /// 连播等待时间（秒）
    var autoAdvanceDelay: Double {
        switch self {
        case .puzzle: return 3.0           // 残局短，3 秒够消化
        case .masterGame: return 8.0       // 大师棋谱长，8 秒让用户思考
        }
    }

    /// 棋盘是否翻转（黑方先行时翻转）
    var shouldFlipBoard: Bool {
        switch self {
        case .puzzle(let p): return p.side == .black
        case .masterGame: return false      // 大师棋谱红方先行
        }
    }
}

// MARK: - 大师棋谱演示条目

/// 大师棋谱演示条目（列表展示用，不含走法数据）
/// 走法在用户点击播放时按需加载
///
/// fen 在列表阶段为 nil（FEN 需从 PGN 加载后才可知），
/// 播放时由 PuzzleDemoView 用实际 FEN 构造新的 MasterGameDemoItem。
/// DemoItemWrapper.initialFEN 对 .masterGame 分支在 fen==nil 时断言，
/// 防止列表阶段误用不可信的 FEN。
struct MasterGameDemoItem: Equatable, Identifiable {
    let index: MasterGameIndex
    let fen: String?    // nil = 列表阶段尚未加载，播放时由实际 GameRecord.initialFEN 填充

    var id: Int { index.id }
}

// MARK: - 演示分类

/// 演示分类（结构化关联值，无需字符串反查）
enum DemoCategory: Identifiable, Hashable {
    case puzzles(String)                  // 残局分类名
    case opening(OpeningCategory)         // 开局分类对象（含 firstMove、subcategories）
    case player(String)                   // 棋手名（后续扩展）

    var id: String {
        switch self {
        case .puzzles(let name): return "puzzle_\(name)"
        case .opening(let cat): return "opening_\(cat.id)"
        case .player(let name): return "player_\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .puzzles(let name): return name
        case .opening(let cat): return cat.name
        case .player(let name): return name
        }
    }
}
