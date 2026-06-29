import Foundation

// MARK: - PGN 导出器

/// 将 GameRecord 导出为 PGN 字符串
/// ICCS 行号映射：9 - row（Vera 审查发现原方案 10-row 有 bug）
/// ICCS 列映射：a-i（a=九路，i=一路）
struct PGNExporter {

    // MARK: - PGN 导出错误

    enum ExportError: Error, LocalizedError {
        case emptyMoves
        case invalidPosition

        var errorDescription: String? {
            switch self {
            case .emptyMoves: return "走法列表为空"
            case .invalidPosition: return "无效的棋盘位置"
            }
        }
    }

    // MARK: - 单局导出

    /// 导出单局棋谱为 PGN 字符串
    static func export(_ record: GameRecord) -> String {
        var lines: [String] = []

        // 必选标签
        lines.append("[Event \"\(eventTitle(record))\"]")
        lines.append("[Site \"中国象棋\"]")
        lines.append("[Date \"\(formatDate(record.date))\"]")
        lines.append("[Round \"1\"]")
        lines.append("[Red \"\(record.redPlayer.name)\"]")
        lines.append("[Black \"\(record.blackPlayer.name)\"]")
        lines.append("[Result \"\(resultString(record.result))\"]")

        // 可选标签：FEN（非标准开局才输出）
        if let fen = record.initialFEN {
            if !FENParser.isStandardInitial(fen) {
                lines.append("[FEN \"\(fen)\"]")
            }
        }
        lines.append("[Format \"ICCS\"]")
        if let diff = record.difficulty {
            lines.append("[Difficulty \"\(diff.rawValue)\"]")
        }
        if let puzzleId = record.puzzleId {
            lines.append("[PuzzleId \"\(puzzleId)\"]")
        }
        lines.append("[Source \"\(record.source.rawValue)\"]")

        // 空行分隔标签和走法
        lines.append("")

        // 走法段：ICCS 格式，单行文本，空格分隔，回合号标记
        let movetext = buildMovetext(record)
        lines.append(movetext)

        return lines.joined(separator: "\n")
    }

    // MARK: - 批量导出

    /// 批量导出（多局合并）
    static func exportBatch(_ records: [GameRecord]) -> String {
        records.map { export($0) }.joined(separator: "\n\n")
    }

    /// 批量导出（容错版本）
    /// 单条导出失败不阻断整批，用注释替代失败记录
    static func exportBatchSafe(_ records: [GameRecord]) -> (pgn: String, failedCount: Int) {
        var parts: [String] = []
        var failedCount = 0
        for record in records {
            do {
                let pgn = try exportSafe(record)
                parts.append(pgn)
            } catch {
                parts.append("[Event \"导出失败\"]\n[Date \"\(formatDate(record.date))\"]\n% ERROR: \(error.localizedDescription)")
                failedCount += 1
            }
        }
        return (parts.joined(separator: "\n\n"), failedCount)
    }

    /// 单局导出（可能抛出错误）
    private static func exportSafe(_ record: GameRecord) throws -> String {
        guard !record.moves.isEmpty else { throw ExportError.emptyMoves }
        return export(record)
    }

    // MARK: - 内部辅助

    /// 构建走法段文本
    /// 格式：1. h2e2 b9c7 2. i0h0 i9i7 ... 结果
    private static func buildMovetext(_ record: GameRecord) -> String {
        let fileChars = Array("abcdefghi")

        // 将所有走法转换为 ICCS 格式
        let iccsMoves = record.moves.map { move -> String in
            // ICCS 行号映射：9 - row
            let from = String(fileChars[move.from.col]) + String(9 - move.from.row)
            let to = String(fileChars[move.to.col]) + String(9 - move.to.row)
            return from + to
        }

        // 按回合组织走法
        var tokens: [String] = []
        var i = 0
        var roundNum = 1
        while i < iccsMoves.count {
            // 回合号 + 红方走法
            var token = "\(roundNum). \(iccsMoves[i])"
            tokens.append(token)

            // 黑方走法（如果有的话）
            if i + 1 < iccsMoves.count {
                tokens.append(iccsMoves[i + 1])
            }

            i += 2
            roundNum += 1
        }

        // 附加结果
        tokens.append(resultString(record.result))

        return tokens.joined(separator: " ")
    }

    /// 赛事标题
    private static func eventTitle(_ record: GameRecord) -> String {
        switch record.source {
        case .versusAI: return "人机对弈"
        case .puzzle: return "残局练习"
        case .imported: return "导入棋谱"
        case .freePlay: return "自由对弈"
        }
    }

    /// 日期格式化
    /// 日期格式化（P2-2: 避免每次调用创建）
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    /// 结果编码
    private static func resultString(_ result: GameState) -> String {
        switch result {
        case .redWon: return "1-0"
        case .blackWon: return "0-1"
        case .draw: return "1/2-1/2"
        case .playing: return "*"
        }
    }
}
