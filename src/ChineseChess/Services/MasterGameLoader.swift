import Foundation

// MARK: - 大师对局按需加载器

/// 从 PGN 文件中按需加载指定对局（使用 pgnOffset + pgnLength 定位）
struct MasterGameLoader {

    /// 从 PGN 文件中加载指定对局
    /// - Parameter index: 索引条目（含 pgnOffset + pgnLength）
    /// - Returns: ImportResult（与现有 PGNImporter.parse() 返回类型一致）
    static func loadGame(_ index: MasterGameIndex) -> ImportResult {
        guard let pgnURL = Bundle.main.url(
            forResource: "xqdb_masters_40711_UCI_games",
            withExtension: "pgn",
            subdirectory: "pgn-extracted"
        ) else {
            return ImportResult(
                records: [],
                warnings: ["PGN 数据文件缺失"],
                skippedCount: 1,
                totalGames: 1
            )
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: pgnURL) else {
            return ImportResult(
                records: [],
                warnings: ["无法打开 PGN 文件"],
                skippedCount: 1,
                totalGames: 1
            )
        }
        defer { try? fileHandle.close() }

        // 定位到偏移量并读取指定长度
        try? fileHandle.seek(toOffset: UInt64(index.pgnOffset))
        let data = fileHandle.readData(ofLength: index.pgnLength)

        guard let pgnText = String(data: data, encoding: .utf8) else {
            return ImportResult(
                records: [],
                warnings: ["对局 #\(index.id) PGN 文本解码失败"],
                skippedCount: 1,
                totalGames: 1
            )
        }

        // 复用现有 PGNImporter 解析
        return PGNImporter.parse(pgnText)
    }

    /// 批量加载对局（用于预加载等场景）
    /// - Parameter indices: 索引条目数组
    /// - Returns: 所有成功解析的 GameRecord + 警告
    static func loadGames(_ indices: [MasterGameIndex]) -> ImportResult {
        var allRecords: [GameRecord] = []
        var allWarnings: [String] = []
        var skippedCount = 0

        for index in indices {
            let result = loadGame(index)
            allRecords.append(contentsOf: result.records)
            allWarnings.append(contentsOf: result.warnings)
            skippedCount += result.skippedCount
        }

        return ImportResult(
            records: allRecords,
            warnings: allWarnings,
            skippedCount: skippedCount,
            totalGames: indices.count
        )
    }
}
