import Foundation

// MARK: - 开局库扩展器

/// 开局库扩展工具
/// v3.1 Phase 1: 从 4602 局面扩展到 10000 局面
/// 方法：自对弈生成 + 经典开局注入
final class OpeningBookExpander {
    
    private let sourceURL: URL
    private let targetURL: URL
    private var entries: [String: [BookEntry]] = [:]
    private var positionCount = 0
    
    struct BookEntry: Codable {
        let move: String
        let w: Int
    }
    
    struct BookFileV2: Codable {
        let version: Int
        let description: String?
        let entries: [String: [BookEntry]]
    }
    
    init(sourcePath: String, targetPath: String) {
        self.sourceURL = URL(fileURLWithPath: sourcePath)
        self.targetURL = URL(fileURLWithPath: targetPath)
    }
    
    // MARK: - 扩展方法
    
    /// 加载现有开局库
    func loadExisting() throws {
        guard let data = try? Data(contentsOf: sourceURL) else {
            throw NSError(domain: "OpeningBookExpander", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法加载源文件"])
        }
        
        let book = try JSONDecoder().decode(BookFileV2.self, from: data)
        entries = book.entries
        positionCount = entries.count
        
        print("✅ 已加载现有开局库：\(positionCount) 个局面")
    }
    
    /// 扩展开局库（自对弈生成）
    /// - Parameters:
    ///   - targetCount: 目标局面数
    ///   - games: 自对弈局数
    ///   - maxMoves: 每局最大步数（开局阶段）
    func expandBySelfPlay(targetCount: Int, games: Int, maxMoves: Int = 20) async throws {
        print("🔄 开始自对弈扩展...")
        
        let runner = SelfPlayRunner()
        let difficulties: [AIDifficulty] = [.medium, .hard, .master]
        
        var addedPositions = 0
        
        for difficulty in difficulties {
            let config = SelfPlayConfig(
                red: difficulty,
                black: difficulty,
                games: games / difficulties.count,
                maxMoves: maxMoves
            )
            
            // 运行自对弈
            let result = runner.run(config: config)
            
            // 从走法历史提取开局局面
            for game in result.games {
                addedPositions += extractPositionsFromGame(game, maxMoves: maxMoves)
            }
            
            print("  \(difficulty.rawValue): 已增加 \(addedPositions) 个局面")
        }
        
        positionCount = entries.count
        print("✅ 自对弈扩展完成：\(positionCount) 个局面（新增 \(addedPositions)）")
    }
    
    /// 从单局对弈提取开局局面
    private func extractPositionsFromGame(_ game: SelfPlayGameResult, maxMoves: Int) -> Int {
        guard game.moveHistory.count >= 2 else { return 0 }
        
        var added = 0
        var board = Board()
        
        // 执行开局阶段的走法，记录每个局面的下一步走法
        for i in 0..<min(game.moveHistory.count - 1, maxMoves) {
            let iccsMove = game.moveHistory[i]
            let nextMove = game.moveHistory[i + 1]
            
            // 执行当前走法
            guard let move = ICCSParser.parse(iccsMove, on: board) else { break }
            board.execute(move)
            
            // 记录局面 hash → 下一步走法
            let hash = ZobristHash.hash(board: board)
            let hashHex = "0x" + String(hash, radix: 16)
            
            // 权重：根据走法在开局中的位置，越早权重越高
            let weight = max(100 - i * 5, 20)
            
            let entry = BookEntry(move: nextMove, w: weight)
            
            if entries[hashHex] != nil {
                // 避免重复走法
                if !entries[hashHex]!.contains(where: { $0.move == nextMove }) {
                    entries[hashHex]!.append(entry)
                }
            } else {
                entries[hashHex] = [entry]
                added += 1
            }
        }
        
        return added
    }
    
    /// 注入经典开局变化
    func injectClassicOpenings() throws {
        print("🔄 注入经典开局变化...")
        
        // 中国象棋经典开局变化
        let classicOpenings: [(name: String, moves: [String])] = [
            // 中炮开局
            ("中炮对屏风马", ["h2e2", "h9g7", "h0g6", "b9a7", "i0h0", "a9b9", "h0h9", "b7b3"]),
            ("中炮对反宫马", ["h2e2", "h7f7", "h0g6", "b9c7", "i0h0", "a9b9", "b2d2"]),
            ("中炮过河车", ["h2e2", "h9g7", "h0g6", "i9h9", "i0h0", "h9h4"]),
            
            // 飞相局
            ("飞相局对左中炮", ["g3e3", "h7e7", "b0c2", "h9g7"]),
            ("飞相局对右中炮", ["g3e3", "b7e7", "b0c2", "b9c7"]),
            
            // 起马局
            ("起马局", ["h0g6", "h9g7", "b0c2", "b9c7"]),
            
            // 仙人指路
            ("仙人指路", ["c3c4", "h7e7", "h2e2", "h9g7", "h0g6"]),
            
            // 过宫炮
            ("过宫炮", ["h2e2", "h7f7", "h0g6", "b9c7"]),
            
            // 士角炮
            ("士角炮", ["h2f2", "h9g7", "b0c2", "b9c7"]),
        ]
        
        var added = 0
        
        for opening in classicOpenings {
            added += injectOpening(name: opening.name, moves: opening.moves)
        }
        
        positionCount = entries.count
        print("✅ 经典开局注入完成：新增 \(added) 个局面")
    }
    
    /// 注入单个开局变化
    private func injectOpening(name: String, moves: [String]) -> Int {
        var added = 0
        var board = Board()
        
        for i in 0..<moves.count - 1 {
            let currentMove = moves[i]
            let nextMove = moves[i + 1]
            
            guard let move = ICCSParser.parse(currentMove, on: board) else {
                print("  ⚠️ \(name): 第 \(i + 1) 步走法无效: \(currentMove)")
                break
            }
            
            board.execute(move)
            
            let hash = ZobristHash.hash(board: board)
            let hashHex = "0x" + String(hash, radix: 16)
            
            let weight = 100  // 经典开局权重较高
            
            let entry = BookEntry(move: nextMove, w: weight)
            
            if entries[hashHex] != nil {
                if !entries[hashHex]!.contains(where: { $0.move == nextMove }) {
                    entries[hashHex]!.append(entry)
                }
            } else {
                entries[hashHex] = [entry]
                added += 1
            }
        }
        
        return added
    }
    
    /// 保存扩展后的开局库
    func save() throws {
        print("💾 保存开局库...")
        
        let book = BookFileV2(
            version: 2,
            description: "中国象棋开局库 v3.1（\(positionCount) 局面）",
            entries: entries
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(book)
        
        try data.write(to: targetURL)
        
        print("✅ 开局库已保存：\(targetURL.path)")
        print("   局面总数：\(positionCount)")
    }
    
    /// 运行完整扩展流程
    func run(targetCount: Int, selfPlayGames: Int) async throws {
        try loadExisting()
        
        // 如果已达到目标，直接保存
        if positionCount >= targetCount {
            print("✅ 开局库已达到目标：\(positionCount) >= \(targetCount)")
            return
        }
        
        // 注入经典开局
        try injectClassicOpenings()
        
        // 自对弈扩展（直到达到目标）
        while positionCount < targetCount {
            let needed = targetCount - positionCount
            let gamesPerRound = min(selfPlayGames, needed * 2)
            
            try await expandBySelfPlay(targetCount: targetCount, games: gamesPerRound)
            
            if positionCount >= targetCount {
                break
            }
        }
        
        try save()
    }
}

// MARK: - 命令行入口

#if os(macOS)
/// 命令行开局库扩展入口
func runOpeningBookExpandFromCLI() async {
    let args = CommandLine.arguments
    
    guard args.count >= 4 else {
        print("""
        用法: ChineseChess --expand-book <源文件> <目标文件> <目标局面数> [自对弈局数]
        
        示例:
          ChineseChess --expand-book opening_book_v2.json opening_book_v3.json 10000 100
        """)
        return
    }
    
    let sourcePath = args[2]
    let targetPath = args[3]
    guard let targetCount = Int(args[4]), targetCount > 0 else {
        print("❌ 无效的目标局面数: \(args[4])")
        return
    }
    let games = args.count > 5 ? (Int(args[5]) ?? 100) : 100
    
    let expander = OpeningBookExpander(sourcePath: sourcePath, targetPath: targetPath)
    
    print("═══════════════════════════════════════════")
    print("  开局库扩展")
    print("  目标: \(targetCount) 局面")
    print("═══════════════════════════════════════════")
    print("")
    
    do {
        try await expander.run(targetCount: targetCount, selfPlayGames: games)
        print("\n✅ 扩展完成")
    } catch {
        print("❌ 扩展失败: \(error.localizedDescription)")
    }
}
#endif