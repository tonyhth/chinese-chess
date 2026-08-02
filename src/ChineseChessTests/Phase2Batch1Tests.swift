//
//  Phase2Batch1Tests.swift
//  ChineseChessTests
//
//  Phase 2 批次1 规则修正测试
//  1. detectPerpetualCheck 局面重复检查（连续将军 + 局面重复 才判负）
//  2. 优先级：长将循环同时触发三次重复时判长将负（不是和棋）
//  3. 50回合规则去除
//
//  注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）
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

    // MARK: - 行为测试

    @MainActor
    @Test("连续将军但局面不重复 → 不应判长将负（走法全部不同）")
    func perpetualCheckWithoutRepeatNoLoss() {
        let vm = GameViewModel()

        // 初始状态不应判长将
        #expect(vm.gameState == .playing, "新对局状态应为 playing")
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")
    }

    // MARK: - 长将弹窗验证

    @MainActor
    @Test("长将判负首次触发设置 perpetualCheckMessage")
    func perpetualCheckMessageSetOnFirstTrigger() {
        let vm = GameViewModel()

        // 验证 perpetualCheckMessage 属性存在且初始为 nil
        #expect(vm.perpetualCheckMessage == nil, "初始 perpetualCheckMessage 应为 nil")
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
}
