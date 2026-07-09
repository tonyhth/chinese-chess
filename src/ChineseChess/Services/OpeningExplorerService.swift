import Foundation

// MARK: - v5.0 开局库懒展开服务

/// 开局探索懒展开服务
/// 从 opening_book_v2.json 的 Zobrist hash 索引实时查表生成子节点。
/// VE-1: 使用 OpeningBook.shared 单例，避免双重加载 3.7MB JSON
/// VE-7: 预构建 hash map，O(1) 开局名称匹配
/// VE-9: 直接从 Bundle 加载 openings.json，不经过 OpeningTreeStore
/// Phase 3: 搜索功能（走法序列 + 开局名）
@MainActor
final class OpeningExplorerService {
    static let shared = OpeningExplorerService()

    private let openingBook = OpeningBook.shared

    /// 开局名称前缀索引（VE-7: 预构建 hash map）
    /// key: 走法序列的 joined 字符串（如 "h2e2,b9c7,h0g2"）
    /// value: 开局名称（如 "中炮对屏风马"）
    private let prefixMap: [String: String]

    /// 开局名称列表（Phase 3: 开局名搜索用）
    private let openingEntries: [OpeningNameEntry]

    /// 最长前缀长度（用于匹配截断优化）
    private let maxPrefixLength: Int

    private init() {
        // VE-9: 直接从 Bundle 加载 openings.json
        var map: [String: String] = [:]
        var maxLen = 0
        var entries: [OpeningNameEntry] = []

        if let url = ResourceBundle.url(forResource: "openings", withExtension: "json",
                                         subdirectory: "OpeningBook")
            ?? ResourceBundle.url(forResource: "openings", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([OpeningNameEntry].self, from: data) {
            entries = decoded
            for entry in entries {
                for variation in entry.variations {
                    // 为每个前缀长度都建索引，最长匹配时从长到短查找
                    for len in 1...variation.count {
                        let key = variation[0..<len].joined(separator: ",")
                        // 只保留更长的匹配（自动实现最长前缀）
                        if map[key] == nil || len > (map[key]?.count ?? 0) {
                            map[key] = entry.name
                        }
                    }
                    if variation.count > maxLen {
                        maxLen = variation.count
                    }
                }
            }
        }

        self.prefixMap = map
        self.maxPrefixLength = maxLen
        self.openingEntries = entries
    }

    // MARK: - 公开接口

    /// 获取初始局面的候选走法（根节点）
    func rootMoves() -> [OpeningExplorerNode] {
        let board = Board(fen: FENParser.standardInitial)
        return expandFromBoard(board, depth: 0)
    }

    /// 展开某节点的子节点（懒加载）
    func expandChildren(of node: OpeningExplorerNode) -> [OpeningExplorerNode] {
        let board = Board(snapshot: node.snapshot)
        return expandFromBoard(board, depth: node.depth + 1)
    }

    /// 匹配开局名称（VE-7: hash map O(1) 最长前缀匹配）
    /// - Parameter moveSequence: ICCS 走法序列（如 ["h2e2", "b9c7", "h0g2"]）
    /// - Returns: 匹配到的开局名称，无匹配返回 nil
    func matchOpeningName(moveSequence: [String]) -> String? {
        guard !moveSequence.isEmpty else { return nil }

        // 从最长前缀开始向下查找，第一个命中的就是最长匹配
        let maxLen = min(moveSequence.count, maxPrefixLength)
        for len in stride(from: maxLen, through: 1, by: -1) {
            let key = moveSequence[0..<len].joined(separator: ",")
            if let name = prefixMap[key] {
                return name
            }
        }
        return nil
    }

    // MARK: - 搜索（Phase 3）

    /// 走法序列搜索
    /// 输入 ICCS 走法序列（如 "h2e2 b9c7 h0g2"），推演并构建节点路径
    /// - Parameter query: 空格或逗号分隔的 ICCS 走法
    /// - Returns: 构建的节点路径（含父子关系），失败返回 nil
    func searchByMoveSequence(_ query: String) -> [OpeningExplorerNode]? {
        let moves = query
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map { String($0).lowercased() }

        guard !moves.isEmpty else { return nil }

        var board = Board(fen: FENParser.standardInitial)
        var nodes: [OpeningExplorerNode] = []

        for (index, moveStr) in moves.enumerated() {
            let hash = ZobristHash.hash(board: board)
            guard let candidates = openingBook.lookupAll(zobristHash: hash) else { return nil }

            // 查找匹配的走法
            guard let candidate = candidates.first(where: { $0.move == moveStr }) else {
                return nil  // 走法不在开局库中
            }

            let childBoard = board.snapshot()
            guard let move = ICCSParser.parse(moveStr, on: childBoard) else { return nil }
            childBoard.execute(move)

            let name = NotationGenerator.chineseNotation(for: move, on: board)

            let node = OpeningExplorerNode(
                move: moveStr,
                moveName: name,
                weight: candidate.weight,
                depth: index,
                snapshot: PositionSnapshot(board: childBoard)
            )
            nodes.append(node)

            board = childBoard
        }

        // 构建父子关系
        for i in 1..<nodes.count {
            nodes[i].parent = nodes[i - 1]
        }

        return nodes
    }

    /// 开局名搜索
    /// 输入中文关键字（如"中炮"），返回匹配的开局名 + 变体
    func searchByOpeningName(_ keyword: String) -> [(name: String, variations: [[String]])] {
        guard !keyword.isEmpty else { return [] }
        return openingEntries
            .filter { $0.name.contains(keyword) }
            .map { (name: $0.name, variations: $0.variations) }
    }

    /// 从走法序列变体构建节点路径（用于开局名搜索结果跳转）
    func buildNodePath(forVariation variation: [String]) -> [OpeningExplorerNode]? {
        guard !variation.isEmpty else { return nil }

        var board = Board(fen: FENParser.standardInitial)
        var nodes: [OpeningExplorerNode] = []

        for (index, moveStr) in variation.enumerated() {
            let hash = ZobristHash.hash(board: board)
            guard let candidates = openingBook.lookupAll(zobristHash: hash) else { break }

            let weight = candidates.first(where: { $0.move == moveStr })?.weight ?? 0

            let childBoard = board.snapshot()
            guard let move = ICCSParser.parse(moveStr, on: childBoard) else { break }
            childBoard.execute(move)

            let name = NotationGenerator.chineseNotation(for: move, on: board)

            let node = OpeningExplorerNode(
                move: moveStr,
                moveName: name,
                weight: weight,
                depth: index,
                snapshot: PositionSnapshot(board: childBoard)
            )
            nodes.append(node)

            board = childBoard
        }

        // 构建父子关系
        for i in 1..<nodes.count {
            nodes[i].parent = nodes[i - 1]
        }

        return nodes.isEmpty ? nil : nodes
    }

    // MARK: - 核心逻辑

    /// 从 Board 查表生成子节点
    private func expandFromBoard(_ board: Board, depth: Int) -> [OpeningExplorerNode] {
        guard depth < 20 else { return [] }

        let hash = ZobristHash.hash(board: board)
        guard let candidates = openingBook.lookupAll(zobristHash: hash),
              !candidates.isEmpty else { return [] }

        let top = Array(candidates.sorted { $0.weight > $1.weight }.prefix(10))

        return top.compactMap { candidate in
            let childBoard = board.snapshot()
            guard let move = ICCSParser.parse(candidate.move, on: childBoard) else { return nil }
            childBoard.execute(move)

            let name = NotationGenerator.chineseNotation(for: move, on: board)

            return OpeningExplorerNode(
                move: candidate.move,
                moveName: name,
                weight: candidate.weight,
                depth: depth,
                snapshot: PositionSnapshot(board: childBoard)
            )
        }
    }
}

// MARK: - openings.json 类型（VE-9: 自定义类型，不依赖 OpeningTreeStore）

private struct OpeningNameEntry: Codable {
    let name: String
    let variations: [[String]]
}
