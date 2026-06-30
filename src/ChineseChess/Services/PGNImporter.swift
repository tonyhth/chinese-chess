import Foundation

// MARK: - PGN 导入错误

enum PGNError: Error, LocalizedError {
    case illegalMove(step: Int, moveStr: String)
    case noValidGame
    case invalidFEN(String)

    var errorDescription: String? {
        switch self {
        case .illegalMove(let step, let moveStr):
            return "第 \(step) 步非法走法(\(moveStr))"
        case .noValidGame:
            return "无有效棋局"
        case .invalidFEN(let fen):
            return "无效 FEN: \(fen)"
        }
    }
}

// MARK: - 导入结果

struct ImportResult: Identifiable {
    let id = UUID()  // 用于 .sheet(item:) 绑定
    let records: [GameRecord]
    let warnings: [String]
    let skippedCount: Int    // 跳过的局数
    let totalGames: Int      // 检测到的总局数

    var isSuccess: Bool { !records.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }

    /// 便利构造器：从 records 和 warnings 推算 skippedCount/totalGames
    /// skippedCount = warnings.count（每条 warning 对应一局失败）
    /// totalGames = records.count + skippedCount
    init(records: [GameRecord], warnings: [String]) {
        self.records = records
        self.warnings = warnings
        self.skippedCount = warnings.count
        self.totalGames = records.count + warnings.count
    }

    /// 完整构造器（parse() 使用，skippedCount 从实际逻辑推算）
    init(records: [GameRecord], warnings: [String], skippedCount: Int, totalGames: Int) {
        self.records = records
        self.warnings = warnings
        self.skippedCount = skippedCount
        self.totalGames = totalGames
    }
}

// MARK: - PGN 导入解析器

/// 解析 PGN 文本为 GameRecord
/// 导入容错：标签缺失→默认值，FEN 缺失→标准开局，单局非法走法→整体回滚该局，多局→部分成功
/// 走法解析：忽略换行符合并为单行，去掉回合号和结果标记，按空格 tokenize，走法序号=出现顺序
struct PGNImporter {

    // MARK: - 共享 DateFormatter（P2-2: 避免每次调用创建）

    private static let importDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    // MARK: - 公开接口

    /// 解析 PGN 文本（支持单局和多局）
    static func parse(_ pgnText: String) -> ImportResult {
        var records: [GameRecord] = []
        var warnings: [String] = []

        let games = splitGames(pgnText)
        let totalGames = games.count

        for (i, gameText) in games.enumerated() {
            do {
                let record = try parseSingleGame(gameText)
                records.append(record)
            } catch PGNError.illegalMove(let step, let moveStr) {
                warnings.append("第 \(i + 1) 局第 \(step) 步非法走法(\(moveStr))，已跳过该局")
            } catch {
                warnings.append("第 \(i + 1) 局解析失败：\(error.localizedDescription)")
            }
        }

        return ImportResult(
            records: records,
            warnings: warnings,
            skippedCount: totalGames - records.count,
            totalGames: totalGames
        )
    }

    // MARK: - 分割多局 PGN

    /// 按 double newline 或新标签段分割多局 PGN
    private static func splitGames(_ text: String) -> [String] {
        // 策略：当遇到空行后紧跟 [ 标签时，认为新一局开始
        var games: [String] = []
        var currentLines: [String] = []
        let lines = text.components(separatedBy: .newlines)

        var prevWasEmpty = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 空行标记
            if trimmed.isEmpty {
                prevWasEmpty = true
                currentLines.append(line)
                continue
            }

            // 新标签段开始且前面有空行 → 新一局
            if trimmed.hasPrefix("[") && prevWasEmpty && !currentLines.isEmpty {
                // 之前的行作为一个 game
                let gameText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !gameText.isEmpty {
                    games.append(gameText)
                }
                currentLines = [line]
                prevWasEmpty = false
                continue
            }

            prevWasEmpty = false
            currentLines.append(line)
        }

        // 最后一局
        let lastGame = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastGame.isEmpty {
            games.append(lastGame)
        }

        return games
    }

    // MARK: - 解析单局

    private static func parseSingleGame(_ text: String) throws -> GameRecord {
        let lines = text.components(separatedBy: .newlines)

        // 分离标签段和走法段
        var tagLines: [String] = []
        var moveLines: [String] = []
        var inTags = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inTags {
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    tagLines.append(trimmed)
                } else if !trimmed.isEmpty {
                    // 第一个非标签非空行 → 进入走法段
                    inTags = false
                    moveLines.append(line)
                }
                // 空行在标签段内跳过
            } else {
                moveLines.append(line)
            }
        }

        // 解析标签
        let tags = parseTags(tagLines)

        // 确定初始 FEN
        let initialFEN: String
        if let fenTag = tags["FEN"] {
            initialFEN = fenTag
        } else {
            initialFEN = FENParser.standardInitial
        }

        // 解析走法
        let moves = try parseMoves(moveLines, initialFEN: initialFEN)

        // 构建标签默认值
        let redName = tags["Red"] ?? "红方"
        let blackName = tags["Black"] ?? "黑方"
        let result = parseResult(tags["Result"])

        // 确定 difficulty（C5: 导入记录无难度信息时为 nil）
        let difficulty: AIDifficulty?
        if let diffStr = tags["Difficulty"], let diff = AIDifficulty(rawValue: diffStr) {
            difficulty = diff
        } else {
            difficulty = nil  // 无法确定 AI 难度
        }

        // 确定 source
        let source: RecordSource
        if let sourceStr = tags["Source"], let s = RecordSource(rawValue: sourceStr) {
            source = s
        } else {
            source = .imported  // 导入的记录默认标记为 imported
        }

        // 构建记录
        let redPlayer = PlayerInfo(name: redName, isAI: false, difficulty: nil)
        let blackPlayer = PlayerInfo(name: blackName, isAI: false, difficulty: nil)

        // 解析日期
        let date = parseDate(tags["Date"])

        let record = GameRecord(
            title: tags["Event"] ?? "导入棋谱",
            date: date,
            redPlayer: redPlayer,
            blackPlayer: blackPlayer,
            difficulty: difficulty,
            result: result,
            totalMoves: moves.count,
            moves: moves,
            initialFEN: resolveInitialFEN(fenTag: tags["FEN"], parsedFEN: initialFEN, source: source),
            source: source,
            tags: [],
            puzzleId: tags["PuzzleId"]
        )

        return record
    }

    // MARK: - 解析标签段（P1-1: 用 regex capture groups 替代手动字符串切割）

    private static func parseTags(_ lines: [String]) -> [String: String] {
        var tags: [String: String] = [:]
        // 正则匹配 [Key "Value"]，用 capture groups 提取
        let pattern = #"^\[(\w+)\s+"(.*)"\]$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return tags
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, options: [], range: nsRange) else { continue }

            // Capture group 1 = Key, Capture group 2 = Value
            guard let keyRange = Range(match.range(at: 1), in: trimmed),
                  let valueRange = Range(match.range(at: 2), in: trimmed) else { continue }

            let key = String(trimmed[keyRange])
            let value = String(trimmed[valueRange])
            tags[key] = value
        }
        return tags
    }

    // MARK: - 解析走法段

    /// 解析走法段（ICCS 格式）
    /// 忽略换行符合并为单行，去掉回合号和结果标记，按空格 tokenize，走法序号=出现顺序
    private static func parseMoves(_ lines: [String], initialFEN: String) throws -> [GameMove] {
        // 1. 将走法段所有行合并为单行
        let movetext = lines.joined(separator: " ")

        // 2. 去掉回合号（如 "1." "2." "10." 等），提取纯走法 token
        let rawTokens = movetext.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // 过滤回合号和结果标记
        let resultMarkers: Set<String> = ["1-0", "0-1", "1/2-1/2", "*"]
        let tokens = rawTokens.filter { token in
            // 过滤结果标记
            if resultMarkers.contains(token) { return false }
            // 过滤回合号（如 "1." "2." "10."）
            if token.hasSuffix(".") {
                let withoutDot = token.dropLast()
                if withoutDot.allSatisfy(\.isNumber) { return false }
            }
            // 过滤纯注释
            if token.hasPrefix("{") || token.hasSuffix("}") { return false }
            if token.hasPrefix("(") || token.hasSuffix(")") { return false }
            if token.hasPrefix(";") { return false }
            if token.hasPrefix("%") { return false }
            return true
        }

        // 3. 逐个 token 解析为 ICCS 走法，并在棋盘上执行验证
        var board = Board(fen: initialFEN)
        var gameMoves: [GameMove] = []
        let fileChars = Array("abcdefghi")

        for (index, token) in tokens.enumerated() {
            guard token.count == 4 else {
                throw PGNError.illegalMove(step: index + 1, moveStr: token)
            }

            let chars = Array(token)

            // 解析 ICCS 坐标
            guard let fromCol = fileChars.firstIndex(of: chars[0]),
                  let fromRow = Int(String(chars[1])),
                  let toCol = fileChars.firstIndex(of: chars[2]),
                  let toRow = Int(String(chars[3])) else {
                throw PGNError.illegalMove(step: index + 1, moveStr: token)
            }

            // ICCS 行号合法范围 0-9
            guard fromRow >= 0 && fromRow <= 9 && toRow >= 0 && toRow <= 9 else {
                throw PGNError.illegalMove(step: index + 1, moveStr: token)
            }

            // ICCS 行号 → Board row：9 - iccsRow
            let boardFromRow = 9 - fromRow
            let boardToRow = 9 - toRow

            let fromPos = Position(row: boardFromRow, col: fromCol)
            let toPos = Position(row: boardToRow, col: toCol)

            // 验证位置有效性
            guard Position.isValid(fromPos) && Position.isValid(toPos) else {
                throw PGNError.illegalMove(step: index + 1, moveStr: token)
            }

            // 查找棋子
            guard let piece = board.piece(at: fromPos) else {
                throw PGNError.illegalMove(step: index + 1, moveStr: token)
            }

            let captured = board.piece(at: toPos)
            let move = Move(piece: piece, from: fromPos, to: toPos, captured: captured)

            // 执行走法
            board.execute(move)

            // 构建 GameMove
            let gameMove = GameMove(
                id: UUID(),
                piece: piece,
                from: fromPos,
                to: toPos,
                captured: captured,
                turnNumber: (index / 2) + 1,
                notation: "",  // 导入时不生成中文棋谱
                timestamp: Date(),
                isCheck: false,
                isCheckmate: false
            )
            gameMoves.append(gameMove)
        }

        return gameMoves
    }

    // MARK: - 辅助

    /// P2-1: 提取 initialFEN 三元逻辑为辅助函数
    private static func resolveInitialFEN(fenTag: String?, parsedFEN: String, source: RecordSource) -> String? {
        if source == .imported {
            // 导入记录：只有标签中有 FEN 才保留
            return fenTag != nil ? parsedFEN : nil
        } else {
            // 非导入记录：非标准开局才保留
            return FENParser.isStandardInitial(parsedFEN) ? nil : parsedFEN
        }
    }

    /// 解析结果标记
    private static func parseResult(_ resultStr: String?) -> GameState {
        guard let str = resultStr else { return .playing }
        switch str {
        case "1-0": return .redWon
        case "0-1": return .blackWon
        case "1/2-1/2": return .draw
        default: return .playing
        }
    }

    /// 解析日期标签
    private static func parseDate(_ dateStr: String?) -> Date {
        guard let str = dateStr, str != "????.??.??" else { return Date() }
        return importDateFormatter.date(from: str) ?? Date()
    }
}
