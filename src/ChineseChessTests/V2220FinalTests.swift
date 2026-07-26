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
            // 匹配 @State private var l10n 或 @State private var l10n = ...
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

    // MARK: - P0: BoardMode enum 无 replay case

    @Test("BoardMode enum 不包含 replay case")
    func boardModeNoReplay() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        guard let enumStart = content.range(of: "enum BoardMode") else {
            Issue.record("无法定位 BoardMode enum"); return
        }
        let snippet = String(content[enumStart.lowerBound..<content.index(enumStart.upperBound, offsetBy: 150)])
        #expect(snippet.contains("case playGame"))
        #expect(snippet.contains("case playPuzzle"))
        #expect(!snippet.contains("case replay"))
    }

    // MARK: - P0: ReplayBoardView 独立视图存在

    @Test("ReplayBoardView.swift 存在且为独立 View")
    func replayBoardViewExists() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayBoardView.swift") else {
            Issue.record("ReplayBoardView.swift 不存在"); return
        }
        #expect(content.contains("struct ReplayBoardView: View"))
        #expect(content.contains("let viewModel: ReplayViewModel"))
        #expect(!content.contains("@Environment(L10n.self)"))
        #expect(content.contains("allowsHitTesting(false)"))
    }

    // MARK: - P0: 回放按钮 sheet(item:) 重构

    @Test("macOS: 底部回放按钮使用 sheet(item: $toolbarReplayRecord)")
    func macToolbarReplaySheetItem() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift"); return
        }
        #expect(content.contains("@State private var toolbarReplayRecord: GameRecord?"),
               "应声明 toolbarReplayRecord 状态")
        #expect(content.contains(".sheet(item: $toolbarReplayRecord)"),
               "应使用 sheet(item:) 而非 sheet(isPresented:) — 修复首次点击无反应")
    }

    @Test("iOS: 回放按钮使用 fullScreenCover(item: $toolbarReplayRecord)")
    func iosToolbarReplayFullScreenCoverItem() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessiOSApp.swift") else {
            Issue.record("无法读取 ChineseChessiOSApp.swift"); return
        }
        #expect(content.contains("@State private var toolbarReplayRecord: GameRecord?"))
        #expect(content.contains(".fullScreenCover(item: $toolbarReplayRecord)"),
               "应使用 fullScreenCover(item:) 而非 fullScreenCover(isPresented:)")
    }

    // MARK: - P0: 双 sheet 阻断修复

    @Test("macOS: 历史棋局回放前先关闭 showHistory")
    func macHistoryReplayCloseSheet() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift"); return
        }
        // onReplayRequest 回调中应先 showHistory = false 再设 historyReplayRecord
        guard let callbackRange = content.range(of: "onReplayRequest:") else {
            Issue.record("未找到 onReplayRequest 回调"); return
        }
        let snippet = String(content[callbackRange.lowerBound..<content.index(callbackRange.upperBound, offsetBy: 200)])
        #expect(snippet.contains("showHistory = false"),
               "onReplayRequest 中应先 showHistory = false 再设 historyReplayRecord（双 sheet 阻断）")
        #expect(snippet.contains("historyReplayRecord = record"))
    }

    @Test("iOS: 历史棋局回放前先关闭 showHistory")
    func iosHistoryReplayCloseSheet() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessiOSApp.swift") else {
            Issue.record("无法读取 ChineseChessiOSApp.swift"); return
        }
        guard let callbackRange = content.range(of: "onReplayRequest:") else {
            Issue.record("未找到 onReplayRequest 回调"); return
        }
        let snippet = String(content[callbackRange.lowerBound..<content.index(callbackRange.upperBound, offsetBy: 200)])
        #expect(snippet.contains("showHistory = false"),
               "onReplayRequest 中应先关闭 showHistory（双 sheet 阻断）")
    }

    // MARK: - P0: macOS sheet frame 调整

    @Test("macOS: 残局 sheet frame 600×700")
    func macPuzzleSheetFrame() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift"); return
        }
        #expect(content.contains(".frame(minWidth: 600, minHeight: 700)"),
               "残局 sheet 应为 600×700")
    }

    @Test("macOS: 回放 sheet frame 600×750")
    func macReplaySheetFrame() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift"); return
        }
        // 回放 sheet 应为 600×750
        guard let sheetRange = content.range(of: ".sheet(item: $toolbarReplayRecord)") else {
            Issue.record("未找到回放 sheet"); return
        }
        let snippet = String(content[sheetRange.lowerBound..<content.index(sheetRange.upperBound, offsetBy: 200)])
        #expect(snippet.contains("minWidth: 600, minHeight: 750"),
               "回放 sheet 应为 600×750")

        guard let historyRange = content.range(of: ".sheet(item: $historyReplayRecord)") else {
            Issue.record("未找到历史回放 sheet"); return
        }
        let historySnippet = String(content[historyRange.lowerBound..<content.index(historyRange.upperBound, offsetBy: 200)])
        #expect(historySnippet.contains("minWidth: 600, minHeight: 750"),
               "历史回放 sheet 也应为 600×750")
    }

    // MARK: - P0: L10n.shared 单例可用

    @Test("L10n.shared 单例可访问且功能正常")
    func l10nSharedWorks() {
        #expect(L10n.shared === L10n.shared)
        #expect(!L10n.shared.language.isEmpty)
        let key = "test.\(UUID().uuidString)"
        #expect(L10n.shared.t(key) == key, "未知 key fallback")
    }

    @Test("L10n.swift 注释已更新为 private let l10n = L10n.shared")
    func l10nCommentUpdated() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Services/L10n.swift") else {
            Issue.record("无法读取 L10n.swift"); return
        }
        #expect(content.contains("private let l10n = L10n.shared"),
               "L10n.swift 顶部注释应反映新的 View 层访问方式")
        #expect(!content.contains("@Environment(L10n.self) private var l10n"))
    }

    // MARK: - P1: ReplayView 使用 ReplayBoardView

    @Test("ReplayView 使用 ReplayBoardView(viewModel:) 而非 ChessBoardView")
    func replayViewUsesReplayBoardView() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ReplayView.swift") else {
            Issue.record("无法读取 ReplayView.swift"); return
        }
        #expect(content.contains("ReplayBoardView(viewModel: viewModel)"))
        #expect(!content.contains("ChessBoardView(mode: .replay"))
        #expect(content.contains("private let l10n = L10n.shared"))
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

    // MARK: - 回归: ChessBoardView playGame/playPuzzle 不受影响

    @Test("ChessBoardView 仅支持 playGame + playPuzzle（exhaustive switch）")
    func chessBoardViewModes() {
        guard let content = try? String(contentsOfFile: "\(srcRoot)/Views/ChessBoardView.swift") else {
            Issue.record("无法读取 ChessBoardView.swift"); return
        }
        #expect(content.contains("case .playGame"))
        #expect(content.contains("case .playPuzzle"))
        #expect(!content.contains("case .replay"))
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
