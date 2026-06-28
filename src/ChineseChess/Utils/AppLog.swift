import Foundation
import os

/// 统一日志工具，替代散落各处的 print()。
/// App 运行时诊断统一走 os_log；CLI 工具（SelfPlayRunner/CMAESOptimizer/OpeningBookExpander）保留 print。
enum AppLog {
    private static let subsystem = "com.chinesechess.app"

    private static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Categories

    static let gameVM = logger("GameViewModel")
    static let puzzleVM = logger("PuzzleViewModel")
    static let openingBook = logger("OpeningBook")
    static let fontRegistry = logger("FontRegistry")
    static let history = logger("GameHistoryStore")
    static let resourceBundle = logger("ResourceBundle")
    static let puzzleStore = logger("PuzzleStore")
    static let soundEngine = logger("SoundEngine")
}
