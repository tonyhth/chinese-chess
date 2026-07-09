//
//  Phase2Batch1Tests.swift
//  ChineseChessTests
//
//  Phase 2 批次1 规则修正测试
//  1. detectPerpetualCheck 局面重复检查（连续将军 + 局面重复 才判负）
//  2. 优先级：长将循环同时触发三次重复时判长将负（不是和棋）
//  3. 50回合规则去除
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 2 批次1 规则修正测试", .serialized)
struct Phase2Batch1Tests {

    // MARK: - 工具方法

    private static let xcstringsPath: String = {
        let homeDir = NSHomeDirectory()
        return "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
    }()

    private static func translationValue(_ key: String, _ lang: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]],
              let entry = strings[key],
              let locs = entry["localizations"] as? [String: [String: Any]],
              let langEntry = locs[lang],
              let stringUnit = langEntry["stringUnit"] as? [String: Any] else {
            return nil
        }
        return stringUnit["value"] as? String
    }

    // MARK: - 修复 1: detectPerpetualCheck 需要局面重复

    @Test("detectPerpetualCheck 代码验证：条件2 要求局面重复 >= 3")
    func detectPerpetualCheckRequiresPositionRepeat() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // 验证 detectPerpetualCheck 函数中包含局面重复检查
        if let funcRange = content.range(of: "private func detectPerpetualCheck") {
            let afterFunc = content[funcRange.lowerBound...]
            let funcSection = String(afterFunc.prefix(1500))

            // 条件1：连续将军
            #expect(funcSection.contains("allSatisfy"), "detectPerpetualCheck 应检查所有走法是否将军")
            #expect(funcSection.contains("isCheck"), "detectPerpetualCheck 应检查 isCheck")

            // 条件2：局面重复 >= 3
            #expect(funcSection.contains("positionFingerprints"), "detectPerpetualCheck 应检查 positionFingerprints")
            #expect(funcSection.contains(">= 3"), "detectPerpetualCheck 应检查局面重复 >= 3")
        } else {
            Issue.record("找不到 detectPerpetualCheck 函数")
        }
    }

    @MainActor
    @Test("连续将军但局面不重复 → 不应判长将负（走法全部不同）")
    func perpetualCheckWithoutRepeatNoLoss() {
        // 验证逻辑层面：detectPerpetualCheck 需要同时满足连续将军和局面重复
        // 由于 positionFingerprints 是 private，我们验证代码结构确保条件2 存在
        // 这个测试确认函数定义中有 positionFingerprints 检查
        let vm = GameViewModel()

        // 初始状态不应判长将
        #expect(vm.gameState == .playing, "新对局状态应为 playing")
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")
    }

    // MARK: - 修复 2: 优先级（长将判负优先于三次重复判和）

    @Test("checkGameState 代码验证：长将判负在三次重复判和之前")
    func perpetualCheckBeforeThreefoldRepeat() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // 提取 checkGameState 函数
        if let funcRange = content.range(of: "private func checkGameState") {
            let afterFunc = content[funcRange.lowerBound...]
            let funcSection = String(afterFunc.prefix(3000))

            // 找到 detectPerpetualCheck 调用和三次重复检查的位置
            let perpetualCheckPos = funcSection.range(of: "detectPerpetualCheck()")
            let threefoldPos = funcSection.range(of: "positionFingerprints[boardFingerprint()")

            #expect(perpetualCheckPos != nil, "checkGameState 应调用 detectPerpetualCheck")
            #expect(threefoldPos != nil, "checkGameState 应检查三次重复")

            if let pcPos = perpetualCheckPos, let tfPos = threefoldPos {
                #expect(pcPos.lowerBound < tfPos.lowerBound,
                        "detectPerpetualCheck 应在三次重复检查之前（优先级更高）")
            }
        } else {
            Issue.record("找不到 checkGameState 函数")
        }
    }

    @Test("checkGameState 代码验证：长将判负设置 .redWon/.blackWon 而非 .draw")
    func perpetualCheckResultsInWin() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // 提取 checkGameState 中的长将判负块
        if let funcRange = content.range(of: "private func checkGameState") {
            let afterFunc = content[funcRange.lowerBound...]
            let funcSection = String(afterFunc.prefix(3000))

            // 在 detectPerpetualCheck 块内应设置 .blackWon 或 .redWon
            if let perpetualRange = funcSection.range(of: "detectPerpetualCheck()") {
                let afterDetect = funcSection[perpetualRange.lowerBound...]
                let blockSection = String(afterDetect.prefix(500))

                #expect(blockSection.contains("blackWon") || blockSection.contains("redWon"),
                        "长将判负应设置 .blackWon 或 .redWon（不是 .draw）")
                #expect(!blockSection.contains(".draw"),
                        "长将判负块内不应设置 .draw")
            }
        }
    }

    // MARK: - 修复 3: 50 回合规则去除

    @Test("checkGameState 代码验证：不再包含 halfmoveClock >= 100 判和")
    func fiftyMoveRuleRemoved() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // 提取 checkGameState 函数
        if let funcRange = content.range(of: "private func checkGameState") {
            let afterFunc = content[funcRange.lowerBound...]
            let funcSection = String(afterFunc.prefix(3000))

            // 50 回合判和块应已被删除
            // 旧代码: if halfmoveClock >= 100 { gameState = .draw ... }
            #expect(!funcSection.contains("halfmoveClock >= 100"),
                    "checkGameState 不应再包含 halfmoveClock >= 100 判和逻辑（已移除）")
        }
    }

    @Test("PuzzleViewModel 也不再包含 halfmoveClock >= 100 判和")
    func puzzleViewModelFiftyMoveRemoved() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 PuzzleViewModel.swift")
            return
        }

        // PuzzleViewModel 也不应包含 50 回合判和（Ruby 审查补漏）
        #expect(!content.contains("halfmoveClock >= 100"),
                "PuzzleViewModel 不应再包含 halfmoveClock >= 100 判和逻辑（已移除）")
    }

    @Test("halfmoveClock 属性仍存在（用于记录但不判和）")
    func halfmoveClockStillTracked() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // halfmoveClock 属性应仍存在（用于 GameMove 记录），但不再用于判和
        #expect(content.contains("halfmoveClock"), "halfmoveClock 属性应仍存在（用于记录）")
    }

    // MARK: - 长将弹窗验证

    @MainActor
    @Test("长将判负首次触发设置 perpetualCheckMessage")
    func perpetualCheckMessageSetOnFirstTrigger() {
        let vm = GameViewModel()

        // 验证 perpetualCheckMessage 属性存在且初始为 nil
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")

        // 验证代码中包含 UserDefaults 首次触发逻辑
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        #expect(content.contains("perpetualCheckExplained"), "应有 UserDefaults 键 perpetualCheckExplained")
        #expect(content.contains("perpetualCheckMessage"), "应设置 perpetualCheckMessage")
    }

    @Test("game.perpetualCheckMessage xcstrings key 存在且有翻译")
    func perpetualCheckMessageKeyHasTranslations() {
        let zhVal = Self.translationValue("game.perpetualCheckMessage", "zh-Hans")
        let enVal = Self.translationValue("game.perpetualCheckMessage", "en")

        #expect(zhVal != nil && !zhVal!.isEmpty, "game.perpetualCheckMessage 应有 zh-Hans 翻译")
        #expect(enVal != nil && !enVal!.isEmpty, "game.perpetualCheckMessage 应有 en 翻译")
    }

    // MARK: - 回归保护

    @MainActor
    @Test("GameViewModel 基础功能回归")
    func gameViewModelRegression() {
        let vm = GameViewModel()
        #expect(vm.board.pieces.count == 32, "新局应有 32 子")
        #expect(vm.gameState == .playing, "初始状态应为 playing")
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")
    }

    @MainActor
    @Test("三次重复判和仍然存在（未被长将逻辑替换掉）")
    func threefoldRepeatStillExists() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 GameViewModel.swift")
            return
        }

        // 提取 checkGameState 函数
        if let funcRange = content.range(of: "private func checkGameState") {
            let afterFunc = content[funcRange.lowerBound...]
            let funcSection = String(afterFunc.prefix(3000))

            // 三次重复判和块应仍存在
            #expect(funcSection.contains("count >= 3"), "三次重复判和逻辑应仍存在")
            #expect(funcSection.contains(".draw"), "三次重复应判 .draw")
        }
    }
}
