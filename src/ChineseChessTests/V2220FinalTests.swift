import Foundation
import Testing
@testable import ChineseChess

@Suite("v2.2.20 最终版本综合测试", .serialized)
@MainActor
struct V2220FinalTests {

    let homeDir: String = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    let srcRoot: String

    init() {
        self.srcRoot = "\(ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess"
    }

    // MARK: - P0: 全局 @Environment(L10n.self) 彻底清除
    // 注意：以下源码扫描测试验证的是项目结构的全局约束，
    // 不是针对特定函数签名的匹配，保留作为项目结构守卫。

    @Test("所有 View 文件中无 @Environment(L10n.self) 残留")
    func noEnvironmentL10nRemnant() {
        let viewsDir = "\(srcRoot)/Views"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: viewsDir) else {
            Issue.record("无法列出 Views 目录"); return
        }
        for file in files where file.hasSuffix(".swift") {
            guard let content = try? String(contentsOfFile: "\(viewsDir)/\(file)") else { continue }
            if content.contains("@Environment(L10n.self)") {
                Issue.record("⚠️ \(file) 仍包含 @Environment(L10n.self)")
            }
        }
    }

    @Test("所有 App 文件中无 .environment(l10n) 残留")
    func noEnvironmentModifierRemnant() {
        let appDir = "\(srcRoot)/App"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: appDir) else {
            Issue.record("无法列出 App 目录"); return
        }
        for file in files where file.hasSuffix(".swift") {
            guard let content = try? String(contentsOfFile: "\(appDir)/\(file)") else { continue }
            if content.contains(".environment(l10n)") {
                Issue.record("⚠️ \(file) 仍包含 .environment(l10n)")
            }
        }
    }

    @Test("App 根视图中无 @State l10n 死代码残留")
    func noStateL10nRemnant() {
        let appDir = "\(srcRoot)/App"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: appDir) else {
            Issue.record("无法列出 App 目录"); return
        }
        for file in files where file.hasSuffix(".swift") {
            guard let content = try? String(contentsOfFile: "\(appDir)/\(file)") else { continue }
            if content.contains("@State") && content.range(of: "@State[^\n]*l10n", options: .regularExpression) != nil {
                Issue.record("⚠️ \(file) 仍包含 @State l10n 死代码")
            }
        }
    }

    // MARK: - P0: 旧 showReplay/replayRecord 彻底清除

    @Test("App 文件中无 showReplay/replayRecord 旧状态残留")
    func noOldReplayStateRemnant() {
        let appDir = "\(srcRoot)/App"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: appDir) else {
            Issue.record("无法列出 App 目录"); return
        }
        for file in files where file.hasSuffix(".swift") {
            guard let content = try? String(contentsOfFile: "\(appDir)/\(file)") else { continue }
            #expect(!content.contains("showReplay"),
                   "\(file) 不应包含 showReplay（已改为 toolbarReplayRecord + sheet(item:)）")
            #expect(!content.contains("replayRecord"),
                   "\(file) 不应包含 replayRecord（已改为 toolbarReplayRecord）")
        }
    }

    // MARK: - P0: L10n.shared 单例可用

    @Test("L10n.shared 单例可访问且功能正常")
    func l10nSharedWorks() {
        #expect(L10n.shared === L10n.shared)
        #expect(!L10n.shared.language.isEmpty)
        let key = "test.\(UUID().uuidString)"
        #expect(L10n.shared.t(key) == key, "未知 key fallback")
    }

    // MARK: - 回归: ReplayViewModel 功能

    @Test("ReplayViewModel: 初始化 + 空记录 + 边界")
    func replayViewModelBasics() {
        let vm = ReplayViewModel(record: Self.makeRecord(moves: []))
        #expect(vm.currentIndex == 0)
        #expect(!vm.canGoForward)
        vm.jumpTo(index: -1); #expect(vm.currentIndex == 0)
        vm.jumpTo(index: 999); #expect(vm.currentIndex == 0)
    }

    @Test("ReplayViewModel: 前进后退 + lastMove")
    func replayViewModelNavigation() {
        let moves = Self.makeTestMoves()
        let vm = ReplayViewModel(record: Self.makeRecord(moves: moves))
        #expect(vm.lastMove == nil)
        vm.goForward()
        #expect(vm.lastMove?.from == moves[0].from)
        while vm.canGoForward { vm.goForward() }
        #expect(vm.currentIndex == moves.count)
        while vm.canGoBack { vm.goBack() }
        #expect(vm.currentIndex == 0)
    }

    @Test("ReplayViewModel: goToStart / goToEnd / progressText")
    func replayViewModelStartEndProgress() {
        let moves = Self.makeTestMoves()
        let vm = ReplayViewModel(record: Self.makeRecord(moves: moves))
        vm.goToEnd(); #expect(vm.currentIndex == moves.count)
        #expect(vm.progressText == "\(moves.count)/\(moves.count)")
        vm.goToStart(); #expect(vm.currentIndex == 0)
        #expect(vm.progressText == "0/\(moves.count)")
    }

    // MARK: - Helper

    private static func makeRecord(moves: [GameMove]) -> GameRecord {
        GameRecord(id: UUID(), title: "v2220测试", date: Date(),
                   redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
                   blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .beginner),
                   difficulty: .beginner, result: .draw,
                   totalMoves: moves.count, moves: moves, initialFEN: nil)
    }

    private static func makeTestMoves() -> [GameMove] {
        [
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4),
                     captured: nil, turnNumber: 1, notation: "兵七进一",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4),
                     captured: nil, turnNumber: 1, notation: "卒4进1",
                     timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]
    }
}
