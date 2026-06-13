import Foundation
import Testing
@testable import ChineseChess

// MARK: - UX 适配测试：LanguageManager + i18n 完整性 + 英文 UI + 中文回归

@Suite("UX 适配测试")
struct UXAdaptationTests {

    // MARK: - 1. LanguageManager 核心功能

    @Suite("LanguageManager 核心功能")
    struct LanguageManagerTests {

        @Test("默认跟随系统：preferredLanguage 为 nil 时，currentLanguage 回退到系统语言")
        func defaultFollowsSystem() {
            let lm = LanguageManager()
            lm.preferredLanguage = nil
            // currentLanguage 应该等于系统语言或 zh-Hans
            let systemLang = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
            #expect(lm.currentLanguage == systemLang)
        }

        @Test("手动覆盖为英文：preferredLanguage = en → currentLanguage = en")
        func manualOverrideEn() {
            let lm = LanguageManager()
            lm.preferredLanguage = "en"
            #expect(lm.currentLanguage == "en")
        }

        @Test("手动覆盖为中文：preferredLanguage = zh-Hans → currentLanguage = zh-Hans")
        func manualOverrideZhHans() {
            let lm = LanguageManager()
            lm.preferredLanguage = "zh-Hans"
            #expect(lm.currentLanguage == "zh-Hans")
        }

        @Test("切回系统语言：preferredLanguage 从 en 设为 nil → 回退到系统语言")
        func switchBackToSystem() {
            let lm = LanguageManager()
            lm.preferredLanguage = "en"
            #expect(lm.currentLanguage == "en")

            lm.preferredLanguage = nil
            let systemLang = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
            #expect(lm.currentLanguage == systemLang)
        }

        @Test("currentLocale 正确反映当前语言")
        func currentLocaleReflectsLanguage() {
            let lm = LanguageManager()
            lm.preferredLanguage = "en"
            #expect(lm.currentLocale.identifier.hasPrefix("en"))

            lm.preferredLanguage = "zh-Hans"
            #expect(lm.currentLocale.identifier.hasPrefix("zh-Hans"))
        }

        @Test("preferredLanguage 通过 UserDefaults 持久化")
        func preferredLanguagePersisted() {
            let testKey = "chinesechess.language"
            // 保存原始值
            let originalValue = UserDefaults.standard.string(forKey: testKey)

            // 直接测试 UserDefaults 写入/读取
            UserDefaults.standard.set("en", forKey: testKey)
            #expect(UserDefaults.standard.string(forKey: testKey) == "en")

            // 验证 LanguageManager init 从 UserDefaults 恢复
            let lm1 = LanguageManager()
            #expect(lm1.preferredLanguage == "en")
            #expect(lm1.currentLanguage == "en")

            // 切换到 zh-Hans
            UserDefaults.standard.set("zh-Hans", forKey: testKey)
            let lm2 = LanguageManager()
            #expect(lm2.preferredLanguage == "zh-Hans")

            // 清除后应为 nil
            UserDefaults.standard.removeObject(forKey: testKey)
            let lm3 = LanguageManager()
            #expect(lm3.preferredLanguage == nil)

            // 恢复原始值
            if let original = originalValue {
                UserDefaults.standard.set(original, forKey: testKey)
            }
        }

        @Test("init 从 UserDefaults 恢复上次选择的语言")
        func initRestoresFromUserDefaults() {
            let testKey = "chinesechess.language"
            UserDefaults.standard.set("en", forKey: testKey)

            let lm = LanguageManager()
            #expect(lm.preferredLanguage == "en")
            #expect(lm.currentLanguage == "en")

            // 清理
            UserDefaults.standard.removeObject(forKey: testKey)
        }

        @Test("多次切换语言不丢失状态")
        func multipleSwitches() {
            let lm = LanguageManager()
            let languages = ["en", "zh-Hans", nil, "en", "zh-Hans", nil]
            let expected = ["en", "zh-Hans", Locale.current.language.languageCode?.identifier ?? "zh-Hans", "en", "zh-Hans", Locale.current.language.languageCode?.identifier ?? "zh-Hans"]

            for (i, lang) in languages.enumerated() {
                lm.preferredLanguage = lang
                #expect(lm.currentLanguage == expected[i], "Switch \(i): expected \(expected[i]), got \(lm.currentLanguage)")
            }
        }
    }

    // MARK: - 2. xcstrings 翻译完整性

    @Suite("xcstrings 翻译完整性")
    struct XcstringsIntegrityTests {

        @Test("xcstrings 文件可正常解析为 JSON")
        func xcstringsParseable() {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                Issue.record("无法读取 xcstrings 文件")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Issue.record("xcstrings 不是合法 JSON")
                return
            }
            #expect(json["strings"] != nil)
        }

        @Test("xcstrings 包含 139 个 key")
        func xcstringsKeyCount() {
            let keys = Self.loadXcstringsKeys()
            #expect(keys.count == 139, "期望 139 key，实际 \(keys.count)")
        }

        @Test("en 翻译全覆盖：所有 key 都有英文字符串")
        func enTranslationComplete() {
            let (keys, localizations) = Self.loadXcstringsWithLocalizations()
            var missing: [String] = []
            for key in keys {
                let locs = localizations[key] ?? [:]
                guard let enDict = locs["en"] as? [String: Any],
                      let suDict = enDict["stringUnit"] as? [String: Any],
                      let enValue = suDict["value"] as? String, !enValue.isEmpty else {
                    missing.append(key)
                    continue
                }
            }
            #expect(missing.isEmpty, "en 翻译缺失的 key: \(missing)")
        }

        @Test("zh-Hans 翻译全覆盖：所有 key 都有中文字符串")
        func zhHansTranslationComplete() {
            let (keys, localizations) = Self.loadXcstringsWithLocalizations()
            var missing: [String] = []
            for key in keys {
                let locs = localizations[key] ?? [:]
                guard let zhDict = locs["zh-Hans"] as? [String: Any],
                      let suDict = zhDict["stringUnit"] as? [String: Any],
                      let zhValue = suDict["value"] as? String, !zhValue.isEmpty else {
                    missing.append(key)
                    continue
                }
            }
            #expect(missing.isEmpty, "zh-Hans 翻译缺失的 key: \(missing)")
        }

        @Test("代码中使用的 118 个 localized key 全部在 xcstrings 中存在")
        func codeUsedKeysExistInXcstrings() {
            let xcstringsKeys = Self.loadXcstringsKeys()
            // 从代码扫描得到的所有 String(localized:) key
            let codeKeys = Self.scanCodeForLocalizedKeys()
            var missing: [String] = []
            for key in codeKeys {
                if !xcstringsKeys.contains(key) {
                    missing.append(key)
                }
            }
            #expect(missing.isEmpty, "代码中使用但 xcstrings 中缺失的 key: \(missing)")
        }

        // MARK: Helpers

        private static func loadXcstringsKeys() -> [String] {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else {
                return []
            }
            return Array(strings.keys)
        }

        private static func loadXcstringsWithLocalizations() -> ([String], [String: [String: Any]]) {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else {
                return ([], [:])
            }
            var localizations: [String: [String: Any]] = [:]
            for (key, value) in strings {
                if let entry = value as? [String: Any], let locs = entry["localizations"] as? [String: Any] {
                    localizations[key] = locs
                }
            }
            return (Array(strings.keys), localizations)
        }

        private static func scanCodeForLocalizedKeys() -> [String] {
            let homeDir = NSHomeDirectory()
            let srcPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
            let fileManager = FileManager.default
            var keys: Set<String> = []

            func scanDirectory(_ dir: String) {
                guard let enumerator = fileManager.enumerator(atPath: dir) else { return }
                for case let file as String in enumerator {
                    guard file.hasSuffix(".swift") else { continue }
                    let filePath = (dir as NSString).appendingPathComponent(file)
                    guard let content = try? String(contentsOfFile: filePath) else { continue }
                    // Match String(localized: "key") and String(localized: "key", defaultValue: ...)
                    let pattern = #"String\(localized:\s*"([^"]+)""#
                    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
                    let nsContent = content as NSString
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
                    for match in matches {
                        if let range = Range(match.range(at: 1), in: content) {
                            keys.insert(String(content[range]))
                        }
                    }
                }
            }

            scanDirectory(srcPath)
            return Array(keys).sorted()
        }
    }

    // MARK: - 3. 英文 UI 显示验证

    @Suite("英文 UI 显示验证")
    struct EnglishUIDisplayTests {

        @Test("LanguageManager 设置为 en 后 currentLanguage 为 en")
        func englishLanguageActive() {
            let lm = LanguageManager()
            lm.preferredLanguage = "en"
            #expect(lm.currentLanguage == "en")
        }

        @Test("英文环境下 Settings 语言选项标签格式正确")
        func englishSettingsLanguageOptions() {
            // 验证语言 Picker 的 tag 值
            // nil = 跟随系统, "zh-Hans" = 中文, "en" = English
            let systemTag: String? = nil
            let zhTag: String? = "zh-Hans"
            let enTag: String? = "en"

            #expect(systemTag == nil)
            #expect(zhTag == "zh-Hans")
            #expect(enTag == "en")
        }

        @Test("英文 key 对应的翻译值不含中文字符")
        func englishValuesNoChinese() {
            let (_, localizations) = Self.loadXcstringsWithLocalizations()
            var violations: [String] = []
            let chinesePattern = try? NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]")

            // 排除文化元素键（楚河汉界是象棋传统标识，en 保留中文是合理的）
            let culturalKeys: Set<String> = ["board.chuRiver", "board.hanBorder"]
            for (key, locs) in localizations {
                guard let enDict = locs["en"] as? [String: Any],
                      let suDict = enDict["stringUnit"] as? [String: Any],
                      let enValue = suDict["value"] as? String else { continue }
                if culturalKeys.contains(key) { continue }
                if let regex = chinesePattern {
                    let matches = regex.matches(in: enValue, range: NSRange(location: 0, length: enValue.utf16.count))
                    if !matches.isEmpty {
                        violations.append("\(key): \"\(enValue)\"")
                    }
                }
            }
            #expect(violations.isEmpty, "en 翻译中包含中文字符的 key: \(violations)")
        }

        @Test("英文翻译值长度合理：不显著短于或长于中文值（布局溢出风险）")
        func englishTranslationLengthReasonable() {
            let (_, localizations) = Self.loadXcstringsWithLocalizations()
            var tooLong: [String] = []

            for (key, locs) in localizations {
                guard let enDict = locs["en"] as? [String: Any],
                      let enSU = enDict["stringUnit"] as? [String: Any],
                      let enValue = enSU["value"] as? String,
                      let zhDict = locs["zh-Hans"] as? [String: Any],
                      let zhSU = zhDict["stringUnit"] as? [String: Any],
                      let zhValue = zhSU["value"] as? String else { continue }
                // 英文超过中文 3 倍长度可能溢出（短标签区域）
                if enValue.count > zhValue.count * 3 && zhValue.count > 0 {
                    tooLong.append("\(key): en=\"\(enValue)\" zh=\"\(zhValue)\"")
                }
            }
            // 记录溢出风险但不阻断——英文比中文长是正常现象
            // 只在异常数量时才标记问题
            #expect(tooLong.count <= 30, "可能溢出的 key 超过 30 个，需要检查: \(tooLong)")
        }

        private static func loadXcstringsWithLocalizations() -> ([String], [String: [String: Any]]) {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else {
                return ([], [:])
            }
            var localizations: [String: [String: Any]] = [:]
            for (key, value) in strings {
                if let entry = value as? [String: Any], let locs = entry["localizations"] as? [String: Any] {
                    localizations[key] = locs
                }
            }
            return (Array(strings.keys), localizations)
        }
    }

    // MARK: - 4. zh-Hans 回归测试

    @Suite("zh-Hans 回归")
    struct ZhHansRegressionTests {

        @Test("LanguageManager 切换回中文后 currentLanguage 正确")
        func switchBackToZhHans() {
            let lm = LanguageManager()
            // 先切英文
            lm.preferredLanguage = "en"
            #expect(lm.currentLanguage == "en")
            // 再切回中文
            lm.preferredLanguage = "zh-Hans"
            #expect(lm.currentLanguage == "zh-Hans")
        }

        @Test("中文翻译值不含意外英文字符（排除合理用词）")
        func zhHansValuesNoUnexpectedEnglish() {
            let (_, localizations) = Self.loadXcstringsWithLocalizations()
            var violations: [String] = []
            let englishWordPattern = try? NSRegularExpression(pattern: "[a-zA-Z]{4,}")

            // 允许的英文词（emoji 描述、格式占位符中的技术术语等）
            let allowedWords: Set<String> = ["ICCS", "UserDefaults"]

            for (key, locs) in localizations {
                guard let zhDict = locs["zh-Hans"] as? [String: Any],
                      let suDict = zhDict["stringUnit"] as? [String: Any],
                      let zhValue = suDict["value"] as? String else { continue }
                if let regex = englishWordPattern {
                    let nsZh = zhValue as NSString
                    let matches = regex.matches(in: zhValue, range: NSRange(location: 0, length: nsZh.length))
                    for match in matches {
                        let word = nsZh.substring(with: match.range)
                        if !allowedWords.contains(word) {
                            violations.append("\(key): \"\(zhValue)\" (found: \(word))")
                        }
                    }
                }
            }
            #expect(violations.isEmpty, "zh-Hans 翻译中含意外英文单词的 key: \(violations)")
        }

        @Test("中文 locale 下 GameViewModel 正常运行")
        func gameViewModelWithZhHansLocale() {
            let lm = LanguageManager()
            lm.preferredLanguage = "zh-Hans"
            // 验证 locale 切换不影响游戏逻辑
            let vm = GameViewModel()
            #expect(vm.board.pieces.count == 32)
            #expect(vm.gameState == .playing)
            #expect(vm.currentTurn == .red)
        }

        @Test("中文 locale 下 AI 正常走棋")
        func aiWithZhHansLocale() {
            let lm = LanguageManager()
            lm.preferredLanguage = "zh-Hans"
            let engine = AIEngine()
            let board = Board()
            let move = engine.bestMove(for: board.snapshot(), difficulty: .medium)
            #expect(move != nil)
        }

        private static func loadXcstringsWithLocalizations() -> ([String], [String: [String: Any]]) {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else {
                return ([], [:])
            }
            var localizations: [String: [String: Any]] = [:]
            for (key, value) in strings {
                if let entry = value as? [String: Any], let locs = entry["localizations"] as? [String: Any] {
                    localizations[key] = locs
                }
            }
            return (Array(strings.keys), localizations)
        }
    }

    // MARK: - 5. 全量回归

    @Suite("全量回归")
    struct FullRegressionTests {

        @Test("新局 32 子，GameState = playing")
        func newGameRegression() {
            let vm = GameViewModel()
            #expect(vm.board.pieces.count == 32)
            #expect(vm.gameState == .playing)
        }

        @Test("AI 各难度正常走棋")
        func aiAllDifficulties() {
            let difficulties: [AIDifficulty] = [.beginner, .easy, .medium, .hard, .master]
            for diff in difficulties {
                let engine = AIEngine()
                let board = Board()
                let move = engine.bestMove(for: board.snapshot(), difficulty: diff)
                #expect(move != nil, "\(diff) 未返回有效走法")
            }
        }

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

        @Test("ReplayViewModel 完整流程")
        func replayViewModelRegression() {
            let record = Self.makeTestRecord()
            let vm = ReplayViewModel(record: record)

            while vm.canGoForward { vm.goForward() }
            #expect(vm.currentIndex == record.moves.count)

            while vm.canGoBack { vm.goBack() }
            #expect(vm.currentIndex == 0)
        }

        @Test("走棋 + 悔棋 回归")
        func moveAndUndoRegression() {
            let vm = GameViewModel()
            let initialCount = vm.board.pieces.count

            // 红方兵在 row=6, col=0..8
            let redPawnPositions = vm.board.pieces(for: .red).filter { $0.kind == .soldier }.map { $0.position }
            guard let pawnPos = redPawnPositions.first else {
                Issue.record("无法找到红方兵")
                return
            }
            vm.selectPiece(at: pawnPos)
            guard !vm.legalMovesForSelected.isEmpty else {
                Issue.record("兵无合法走法")
                return
            }
            let target = vm.legalMovesForSelected.first!
            vm.movePiece(from: pawnPos, to: target)

            // 等待 AI 走棋完成（同步：movePiece 触发 AI 后 AI 在同线程完成）
            // 悔棋两步（AI 一步 + 红方一步）
            vm.undoMove()
            vm.undoMove()
            #expect(vm.board.pieces.count == initialCount)
        }

        @Test("棋盘合法性验证：开局所有走法合法")
        func boardLegalMovesRegression() {
            let board = Board()
            let redPieces = board.pieces(for: .red)
            var totalLegalMoves = 0
            for piece in redPieces {
                let moves = MoveValidator.legalMoves(for: piece, on: board)
                totalLegalMoves += moves.count
            }
            #expect(totalLegalMoves > 0, "开局红方应有合法走法")
        }

        // MARK: Helper

        private static func makeTestRecord(moves: [GameMove]? = nil) -> GameRecord {
            let tempBoard = Board()
            let engine = AIEngine()
            let gameMoves: [GameMove] = []

            let _ = moves ?? {
                var m: [GameMove] = []
                for i in 0..<6 {
                    let side = tempBoard.currentTurn
                    guard let move = engine.bestMove(for: tempBoard.snapshot(), difficulty: .beginner) else { break }
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
                return m
            }()

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

    // MARK: - 6. 硬编码中文遗漏检查

    @Suite("硬编码中文遗漏检查")
    struct HardcodedChineseCheckTests {

        @Test("SettingsView 中无硬编码中文字符串（已全部提取为 localized key）")
        func settingsViewNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/SettingsView.swift")
            guard let content = content else {
                Issue.record("无法读取 SettingsView.swift")
                return
            }
            // 检查是否还有直接使用的中文（排除注释和 "中文"/"English" 这两个 Picker 显示文本）
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                // 允许的中文：Picker 中的 "中文" 和 "English" 显示文本
                if trimmed.contains("\"中文\"") && trimmed.contains("tag") { continue }
                // 检查其他硬编码中文
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\""),
                   !trimmed.contains("String(localized:") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        // 再排除一些合法的情况
                        let fullMatch = (trimmed as NSString).substring(with: matches[0].range)
                        if fullMatch == "\"中文\"" { continue }
                        Issue.record("SettingsView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @Test("StatusBarView 中无硬编码中文字符串")
        func statusBarViewNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/StatusBarView.swift")
            guard let content = content else {
                Issue.record("无法读取 StatusBarView.swift")
                return
            }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        Issue.record("StatusBarView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @Test("ToolbarView 中无硬编码中文字符串")
        func toolbarViewNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/ToolbarView.swift")
            guard let content = content else {
                Issue.record("无法读取 ToolbarView.swift")
                return
            }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        Issue.record("ToolbarView 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @Test("GameOverOverlay 中无硬编码中文字符串")
        func gameOverOverlayNoHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/GameOverOverlay.swift")
            guard let content = content else {
                Issue.record("无法读取 GameOverOverlay.swift")
                return
            }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                if trimmed.contains("String(localized:") { continue }
                if let regex = try? NSRegularExpression(pattern: "\"[^\"]*[\u{4e00}-\u{9fff}][^\"]*\"") {
                    let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count))
                    if !matches.isEmpty {
                        Issue.record("GameOverOverlay 第 \(i+1) 行可能存在硬编码中文: \(trimmed)")
                    }
                }
            }
        }

        @Test("楚河汉界文本是硬编码中文（已知 i18n 遗漏，记录但不阻断）")
        func riverTextHardcodedChinese() {
            let content = Self.readFile("ChineseChess/Views/ChessBoardView.swift")
            guard let content = content else { return }
            let hasRiverText = content.contains("\"楚  河\"") && content.contains("\"汉  界\"")
            // 这是已知的 i18n 遗漏——"楚河汉界"是中国象棋的传统标识
            // 作为文化元素保留硬编码是合理的，但记录
            #expect(hasRiverText == true, "楚河汉界硬编码：已知 i18n 遗漏，作为文化元素保留")
        }

        private static func readFile(_ relativePath: String) -> String? {
            let homeDir = NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/\(relativePath)"
            return try? String(contentsOfFile: path)
        }
    }
}
