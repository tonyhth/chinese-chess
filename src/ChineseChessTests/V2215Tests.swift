import Foundation
import Testing
@testable import ChineseChess

// MARK: - v2.2.15 测试：macOS英文布局 + VoiceOver + 动态字体

@Suite("v2.2.15: macOS英文布局 + VoiceOver + 动态字体", .serialized)
struct V2215Tests {

    // MARK: - 1. xcstrings 翻译完整性（151 key）

    @Suite("xcstrings 翻译完整性", .serialized)
    struct XcstringsIntegrityTests {

        @MainActor
@Test("xcstrings 包含正确的 key 数量")
        func xcstringsKeyCount() {
            let keys = Self.loadKeys()
            #expect(keys.count >= 330, "期望至少 330 key（i18n 扩充后），实际 \(keys.count)")
        }

        @MainActor
@Test("13 个新增 key 全部存在")
        func newKeysExist() {
            let keys = Self.loadKeys()
            let newKeys = [
                "accessibility.board",
                "accessibility.pieceHint",
                "accessibility.rowN",
                "accessibility.colN",
                "accessibility.puzzleSuccess",
                "accessibility.puzzleFailed",
                "replay.firstMove",
                "replay.previous",
                "replay.play",
                "replay.pause",
                "replay.next",
                "replay.lastMove",
                "gameover.drawTitle",
            ]
            var missing: [String] = []
            for key in newKeys {
                if !keys.contains(key) {
                    missing.append(key)
                }
            }
            #expect(missing.isEmpty, "缺失的新 key: \(missing)")
        }

        @MainActor
@Test("en 翻译全覆盖（151 key）")
        func enTranslationComplete() {
            let (keys, locs) = Self.loadWithLocs()
            var missing: [String] = []
            for key in keys {
                guard let enDict = locs[key]?["en"] as? [String: Any],
                      let suDict = enDict["stringUnit"] as? [String: Any],
                      let val = suDict["value"] as? String, !val.isEmpty else {
                    missing.append(key)
                    continue
                }
            }
            #expect(missing.isEmpty, "en 缺失: \(missing)")
        }

        @MainActor
@Test("zh-Hans 翻译全覆盖（151 key）")
        func zhHansTranslationComplete() {
            let (keys, locs) = Self.loadWithLocs()
            var missing: [String] = []
            for key in keys {
                guard let zhDict = locs[key]?["zh-Hans"] as? [String: Any],
                      let suDict = zhDict["stringUnit"] as? [String: Any],
                      let val = suDict["value"] as? String, !val.isEmpty else {
                    missing.append(key)
                    continue
                }
            }
            #expect(missing.isEmpty, "zh-Hans 缺失: \(missing)")
        }

        @MainActor
@Test("新增 accessibility key 的 en 翻译不含中文")
        func newAccessibilityKeysEnNoChinese() {
            let (_, locs) = Self.loadWithLocs()
            let newKeys = ["accessibility.board", "accessibility.pieceHint", "accessibility.rowN",
                          "accessibility.colN", "accessibility.puzzleSuccess", "accessibility.puzzleFailed"]
            let chinesePattern = try? NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]")
            var violations: [String] = []

            for key in newKeys {
                guard let enDict = locs[key]?["en"] as? [String: Any],
                      let suDict = enDict["stringUnit"] as? [String: Any],
                      let val = suDict["value"] as? String else { continue }
                if let regex = chinesePattern {
                    let matches = regex.matches(in: val, range: NSRange(location: 0, length: val.utf16.count))
                    if !matches.isEmpty {
                        violations.append("\(key): \"\(val)\"")
                    }
                }
            }
            #expect(violations.isEmpty, "新增 accessibility key en 含中文: \(violations)")
        }

        @MainActor
@Test("新增 replay key 的 en 翻译不含中文")
        func newReplayKeysEnNoChinese() {
            let (_, locs) = Self.loadWithLocs()
            let newKeys = ["replay.firstMove", "replay.previous", "replay.play",
                          "replay.pause", "replay.next", "replay.lastMove"]
            let chinesePattern = try? NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]")
            var violations: [String] = []

            for key in newKeys {
                guard let enDict = locs[key]?["en"] as? [String: Any],
                      let suDict = enDict["stringUnit"] as? [String: Any],
                      let val = suDict["value"] as? String else { continue }
                if let regex = chinesePattern {
                    let matches = regex.matches(in: val, range: NSRange(location: 0, length: val.utf16.count))
                    if !matches.isEmpty {
                        violations.append("\(key): \"\(val)\"")
                    }
                }
            }
            #expect(violations.isEmpty, "新增 replay key en 含中文: \(violations)")
        }

        // MARK: Helpers

        private static func loadKeys() -> [String] {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else { return [] }
            return Array(strings.keys)
        }

        private static func loadWithLocs() -> ([String], [String: [String: Any]]) {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else { return ([], [:]) }
            var locs: [String: [String: Any]] = [:]
            for (k, v) in strings {
                if let entry = v as? [String: Any], let l = entry["localizations"] as? [String: Any] {
                    locs[k] = l
                }
            }
            return (Array(strings.keys), locs)
        }
    }

    // MARK: - 2. 动态字体迁移验证

    @Suite("动态字体迁移验证", .serialized)
    struct DynamicTypeMigrationTests {

        @MainActor
@Test("Views 中仅剩 1 处 .system(size:)（ChessBoardView cellSize 计算）")
        func onlyCellSizeBasedSystemFontRemains() {
            let viewsDir = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess/Views"
            let fm = FileManager.default
            var hardcodedCount = 0
            var hardcodedFiles: [String] = []

            guard let enumerator = fm.enumerator(atPath: viewsDir) else {
                Issue.record("无法遍历 Views 目录")
                return
            }
            for case let file as String in enumerator {
                guard file.hasSuffix(".swift") else { continue }
                let path = (viewsDir as NSString).appendingPathComponent(file)
                guard let content = try? String(contentsOfFile: path) else { continue }
                let lines = content.components(separatedBy: .newlines)
                for (i, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") { continue }
                    // 排除 cellSize 计算相关的动态字体（合理保留）
                    if trimmed.contains(".system(size:") && !trimmed.contains("cellSize") {
                        hardcodedCount += 1
                        hardcodedFiles.append("\(file):\(i+1): \(trimmed)")
                    }
                }
            }
            #expect(hardcodedCount == 0, "仍有 \(hardcodedCount) 处硬编码 .system(size:): \(hardcodedFiles)")
        }

        @MainActor
@Test("ChessBoardView 保留的 .system(size:) 基于 cellSize 计算（合理）")
        func chessBoardCellSizeFontIsValid() {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 ChessBoardView.swift")
                return
            }
            // 确认保留的是 cellSize * 0.3 这种动态计算
            #expect(content.contains("cellSize * 0.3"), "ChessBoardView 应保留基于 cellSize 的字体计算")
        }

        @MainActor
@Test("9 个文件已迁移到语义字体")
        func semanticFontMigrationCount() {
            let viewsDir = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess/Views"
            let fm = FileManager.default
            var filesWithSemanticFonts: Set<String> = []

            let semanticFonts = [".title", ".title2", ".title3", ".headline", ".subheadline",
                                ".body", ".callout", ".footnote", ".caption", ".caption2",
                                ".largeTitle"]

            guard let enumerator = fm.enumerator(atPath: viewsDir) else { return }
            for case let file as String in enumerator {
                guard file.hasSuffix(".swift") else { continue }
                let path = (viewsDir as NSString).appendingPathComponent(file)
                guard let content = try? String(contentsOfFile: path) else { continue }
                for font in semanticFonts {
                    if content.contains(".font(\(font)") || content.contains(".font(\(font).") {
                        filesWithSemanticFonts.insert(file)
                    }
                }
            }
            // 9 个文件应有语义字体
            #expect(filesWithSemanticFonts.count >= 9, "使用语义字体的文件数 \(filesWithSemanticFonts.count)，期望 ≥ 9。文件: \(filesWithSemanticFonts.sorted())")
        }
    }

    // MARK: - 3. VoiceOver accessibility 标签验证

    @Suite("VoiceOver accessibility 验证", .serialized)
    struct VoiceOverAccessibilityTests {

        @MainActor
@Test("ChessBoardView 有 accessibility 容器和标签")
        func chessBoardAccessibilityContainer() {
            let content = Self.readFile("ChineseChess/Views/ChessBoardView.swift")
            guard let content = content else {
                Issue.record("无法读取 ChessBoardView.swift")
                return
            }
            #expect(content.contains(".accessibilityElement(children: .contain)"), "ChessBoardView 应有 accessibility 容器")
            #expect(content.contains("accessibility.board"), "ChessBoardView 应有 accessibilityLabel")
        }

        @MainActor
@Test("PieceView 有 accessibilityLabel + Hint + isButton trait")
        func pieceViewAccessibility() {
            let content = Self.readFile("ChineseChess/Views/PieceView.swift")
            guard let content = content else {
                Issue.record("无法读取 PieceView.swift")
                return
            }
            #expect(content.contains(".accessibilityLabel(pieceAccessibleLabel)"), "PieceView 应有 accessibilityLabel")
            #expect(content.contains(".accessibilityHint("), "PieceView 应有 accessibilityHint")
            #expect(content.contains(".accessibilityAddTraits(.isButton)"), "PieceView 应有 isButton trait")
        }

        @MainActor
@Test("PieceView 使用 rowN/colN 格式（不再用 a-i 列号）")
        func pieceViewRowColFormat() {
            let content = Self.readFile("ChineseChess/Views/PieceView.swift")
            guard let content = content else { return }
            // 新格式使用 accessibility.rowN 和 accessibility.colN
            #expect(content.contains("accessibility.rowN"), "PieceView 应使用 accessibility.rowN")
            #expect(content.contains("accessibility.colN"), "PieceView 应使用 accessibility.colN")
            // 不应再有旧的 a-i 列号格式
            #expect(!content.contains("abcdefghi"), "PieceView 不应使用旧的 a-i 列号格式")
        }

        @MainActor
@Test("ReplayControlView 5 个按钮全部有 accessibilityLabel")
        func replayControlAccessibility() {
            let content = Self.readFile("ChineseChess/Views/ReplayControlView.swift")
            guard let content = content else {
                Issue.record("无法读取 ReplayControlView.swift")
                return
            }
            #expect(content.contains("replay.firstMove"), "首步按钮")
            #expect(content.contains("replay.previous"), "上一步按钮")
            #expect(content.contains("replay.play"), "播放按钮")
            #expect(content.contains("replay.pause"), "暂停按钮")
            #expect(content.contains("replay.next"), "下一步按钮")
            #expect(content.contains("replay.lastMove"), "末步按钮")
        }

        @MainActor
@Test("Overlay/Panel 组件有 accessibilityElement(children: .combine)")
        func overlayCombineAccessibility() {
            let files = ["StatusBarView.swift", "StatsPanelView.swift", "GameOverOverlay.swift", "GameHistoryView.swift"]
            for file in files {
                let content = Self.readFile("ChineseChess/Views/\(file)")
                guard let content = content else { continue }
                #expect(content.contains(".accessibilityElement(children: .combine)"),
                       "\(file) 应有 accessibilityElement(children: .combine)")
            }
        }

        @MainActor
@Test("PuzzleSelectView 成功/失败弹窗有 accessibility 标签")
        func puzzleOverlayAccessibility() {
            let content = Self.readFile("ChineseChess/Views/PuzzleSelectView.swift")
            guard let content = content else { return }
            #expect(content.contains("accessibility.puzzleSuccess"), "成功弹窗应有 accessibility 标签")
            #expect(content.contains("accessibility.puzzleFailed"), "失败弹窗应有 accessibility 标签")
        }

        @MainActor
@Test("ToolbarView 保持已有的 accessibilityLabel + Hint（iOS/macOS）")
        func toolbarAccessibilityRetained() {
            let content = Self.readFile("ChineseChess/Views/ToolbarView.swift")
            guard let content = content else { return }
            #expect(content.contains("accessibilityLabel"))
            #expect(content.contains("accessibilityHint"))
            #expect(content.contains("game.newGame"))
            #expect(content.contains("game.undoMove"))
            #expect(content.contains("game.hint"))
        }

        private static func readFile(_ relativePath: String) -> String? {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/\(relativePath)"
            return try? String(contentsOfFile: path)
        }
    }

    // MARK: - 4. macOS 英文布局适配

    @Suite("macOS 英文布局适配", .serialized)
    struct MacOSLayoutTests {

        @MainActor
@Test("SettingsView Picker 统一为 .menu（移除 #if os(iOS) 条件）")
        func settingsViewPickerUnified() {
            let content = Self.readFile("ChineseChess/Views/SettingsView.swift")
            guard let content = content else { return }
            // 不应再有 #if os(iOS) + .menu / #else + .segmented 的模式
            #expect(!content.contains(".pickerStyle(.segmented)"), "SettingsView 不应再使用 .segmented")
            #expect(content.contains(".pickerStyle(.menu)"), "SettingsView 应使用 .menu")
        }

        @MainActor
@Test("ToolbarView macOS Picker 从 .segmented 改为 .menu")
        func toolbarViewPickerChanged() {
            let content = Self.readFile("ChineseChess/Views/ToolbarView.swift")
            guard let content = content else { return }
            // macOS 端的 Picker 应改为 .menu（不再是 .segmented）
            #expect(!content.contains(".pickerStyle(.segmented)"), "ToolbarView 不应再使用 .segmented")
        }

        @MainActor
@Test("StatsPanelView 难度标签从 frame(width:40) 改为 frame(minWidth:50)")
        func statsPanelMinWidth() {
            let content = Self.readFile("ChineseChess/Views/StatsPanelView.swift")
            guard let content = content else { return }
            #expect(content.contains("minWidth: 50"), "StatsPanelView 应使用 frame(minWidth: 50)")
            #expect(!content.contains("width: 40"), "StatsPanelView 不应再有 frame(width: 40)")
        }

        private static func readFile(_ relativePath: String) -> String? {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/\(relativePath)"
            return try? String(contentsOfFile: path)
        }
    }

    // MARK: - 5. 硬编码中文遗漏检查（变更文件）

    @Suite("变更文件硬编码中文检查", .serialized)
    struct ChangedFilesHardcodedChineseTests {

        @MainActor
@Test("ReplayControlView 无硬编码中文（accessibilityLabel 使用 localized key）")
        func replayControlNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/ReplayControlView.swift")
            guard let content = content else { return }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                // 排除 defaultValue 参数中的中文（这些在 xcstrings 中会被提取）
                if trimmed.contains("defaultValue:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        Issue.record("ReplayControlView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @MainActor
@Test("PieceView 无硬编码中文（defaultValue 除外）")
        func pieceViewNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/PieceView.swift")
            guard let content = content else { return }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                if trimmed.contains("defaultValue:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        Issue.record("PieceView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @MainActor
@Test("PuzzleSelectView 变更部分无新增硬编码中文")
        func puzzleSelectNoNewHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/PuzzleSelectView.swift")
            guard let content = content else { return }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                if trimmed.contains("defaultValue:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        // 排除 "楚  河" / "汉  界"（已知文化元素）
                        let match = (trimmed as NSString).substring(with: matches[0].range)
                        if match.contains("楚") || match.contains("汉") { continue }
                        Issue.record("PuzzleSelectView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        private static func readFile(_ relativePath: String) -> String? {
            let path = "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/\(relativePath)"
            return try? String(contentsOfFile: path)
        }
    }

    // MARK: - 6. 全量回归

    @Suite("全量回归", .serialized)
    struct FullRegressionTests {

        @MainActor
@Test("新局 32 子，GameState = playing")
        func newGameRegression() {
            let vm = GameViewModel()
            #expect(vm.board.pieces.count == 32)
            #expect(vm.gameState == .playing)
        }

        @MainActor
@Test("AI 各难度正常走棋")
        func aiAllDifficulties() async {
            let difficulties: [AIDifficulty] = [.beginner, .easy, .medium, .hard, .master]
            for diff in difficulties {
                let engine = AIEngine()
                let board = Board()
                let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
                #expect(move != nil, "\(diff) 未返回有效走法")
            }
        }

        @MainActor
@Test("PuzzleViewModel 正常初始化")
        func puzzleViewModelRegression() {
            let puzzles = PuzzleStore.shared.puzzles
            guard let puzzle = puzzles.first else {
                Issue.record("无残局数据")
                return
            }
            let vm = PuzzleViewModel(puzzle: puzzle)
            #expect(vm.gameState == .playing)
            #expect(vm.board.pieces.count > 0)
        }

        @MainActor
@Test("ReplayViewModel 完整流程")
        func replayViewModelRegression() async {
            let record = await Self.makeTestRecord()
            let vm = ReplayViewModel(record: record)

            while vm.canGoForward { vm.goForward() }
            #expect(vm.currentIndex == record.moves.count)

            while vm.canGoBack { vm.goBack() }
            #expect(vm.currentIndex == 0)
        }

        @MainActor
@Test("ReplayViewModel 空记录不 crash")
        func replayViewModelEmptyNoCrash() async {
            let record = await Self.makeTestRecord(moves: [])
            let vm = ReplayViewModel(record: record)
            #expect(!vm.canGoForward)
            vm.goForward()
            vm.goBack()
            vm.goToStart()
            vm.goToEnd()
        }

        @MainActor
@Test("LanguageManager 语言切换回归")
        func languageManagerRegression() {
            let lm = L10n.shared
            lm.setLanguage("en")
            #expect(lm.language == "en")

            lm.setLanguage("zh-Hans")
            #expect(lm.language == "zh-Hans")

            lm.setLanguage("zh-Hans")
            let systemLang = "zh-Hans"
            #expect(lm.language == systemLang)
        }

        // MARK: Helper

        private static func makeTestRecord(moves: [GameMove]? = nil) async -> GameRecord {
            let tempBoard = Board()
            let engine = AIEngine()
            let gameMoves: [GameMove]
            if let moves {
                gameMoves = moves
            } else {
                var m: [GameMove] = []
                for i in 0..<6 {
                let side = tempBoard.currentTurn
                guard let move = await engine.bestMove(for: tempBoard.snapshot(), difficulty: .beginner) else { break }
                let notation = NotationGenerator.notation(for: move, on: tempBoard)
                let opponent: Side = (side == .red) ? .black : .red
                tempBoard.execute(move)
                let isCheck = MoveValidator.isInCheck(opponent, on: tempBoard)
                m.append(GameMove(
                id: UUID(),
                piece: move.piece,
                from: move.from,
                to: move.to,
                captured: move.captured,
                turnNumber: i / 2 + 1,
                notation: notation,
                timestamp: Date(),
                isCheck: isCheck,
                isCheckmate: false
                ))
                }
                gameMoves = m
            }

            return GameRecord(
                id: UUID(),
                title: "测试对局",
                date: Date(),
                redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
                blackPlayer: PlayerInfo(name: "AI-新手", isAI: true, difficulty: .beginner),
                difficulty: .beginner,
                result: .draw,
                totalMoves: gameMoves.count,
                moves: gameMoves,
                initialFEN: nil
            )
        }
    }
}
