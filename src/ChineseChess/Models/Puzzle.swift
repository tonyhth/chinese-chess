import Foundation

// MARK: - 残局解法模式

enum SolutionMode: String, Codable {
    case guided    // 有解法引导
    case freePlay  // 自由对弈 vs AI
}

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
    let source: String?          // 残局出处（橘中秘、梅花谱等），向后兼容

    // Phase 3.5 新增字段（有默认值，向后兼容）
    var solutionType: String     // "checkmate"(默认) | "sequence" | "hint"
    var endDescription: String?  // 通关描述文字

    // v2.2.6 新增字段
    var solutionMode: SolutionMode  // 默认 .guided
    var subcategory: String?        // 难度标签（"入门"/"简单"/"中等"/"困难"/"大师"）
    var tacticalGroup: String?     // 战术子分类（"杀势"/"困毙"/"催杀"/"弃子攻杀"/"其他"），车马炮类专用

    init(id: String, name: String, category: String, difficulty: Int, stars: Int,
         description: String, playerSide: String, initialFEN: String,
         solution: [String], hints: [String]?, maxMoves: Int, source: String? = nil,
         solutionType: String = "checkmate", endDescription: String? = nil,
         solutionMode: SolutionMode = .guided, subcategory: String? = nil,
         tacticalGroup: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.stars = stars
        self.description = description
        self.playerSide = playerSide
        self.initialFEN = initialFEN
        self.solution = solution
        self.hints = hints
        self.maxMoves = maxMoves
        self.source = source
        self.solutionType = solutionType
        self.endDescription = endDescription
        self.solutionMode = solutionMode
        self.subcategory = subcategory
        self.tacticalGroup = tacticalGroup
    }

    /// 计算属性：solutionMode=freePlay → freePlay；solution 非空→guided；否则→solutionMode
    var effectiveMode: SolutionMode {
        if solutionMode == .freePlay { return .freePlay }
        if !solution.isEmpty { return .guided }
        return solutionMode
    }

    // 向后兼容：旧 JSON 无 solutionType 字段时 Codable 用默认值
    enum CodingKeys: String, CodingKey {
        case id, name, category, difficulty, stars, description
        case playerSide, initialFEN, solution, hints, maxMoves, source
        case solutionType, endDescription
        case solutionMode, subcategory, tacticalGroup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        stars = try c.decode(Int.self, forKey: .stars)
        description = try c.decode(String.self, forKey: .description)
        playerSide = try c.decode(String.self, forKey: .playerSide)
        initialFEN = try c.decode(String.self, forKey: .initialFEN)
        solution = try c.decode([String].self, forKey: .solution)
        hints = try c.decodeIfPresent([String].self, forKey: .hints)
        maxMoves = try c.decode(Int.self, forKey: .maxMoves)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        solutionType = (try? c.decode(String.self, forKey: .solutionType)) ?? "checkmate"
        endDescription = try c.decodeIfPresent(String.self, forKey: .endDescription)
        solutionMode = (try? c.decode(SolutionMode.self, forKey: .solutionMode)) ?? .guided
        subcategory = try c.decodeIfPresent(String.self, forKey: .subcategory)
        tacticalGroup = try c.decodeIfPresent(String.self, forKey: .tacticalGroup)
    }

    var side: Side {
        playerSide == "red" ? .red : .black
    }

    /// solutionType 显示标签的 L10n key
    var typeLabelKey: String {
        switch solutionType {
        case "checkmate": return "puzzle.type.checkmate"
        case "sequence": return "puzzle.type.sequence"
        case "hint": return "puzzle.type.hint"
        default: return ""
        }
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
    var bestRating: Int?       // 最佳星级 1-3
}
