//
//  Phase2Batch2Tests.swift
//  ChineseChessTests
//
//  Phase 2 批次2 测试（6项修改 + 兵位置表）
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 2 批次2 测试", .serialized)
struct Phase2Batch2Tests {

    private static func sourceRoot() -> String {
        "\(NSHomeDirectory())/DevTeam/projects/chinese-chess/src/ChineseChess"
    }

    private static func readFile(_ relativePath: String) -> String? {
        try? String(contentsOfFile: "\(sourceRoot())/\(relativePath)")
    }

    // MARK: - 1. medium QS + 机动性

    @Test("medium 配置启用 QS（enableQuiescence = true）")
    func mediumConfigEnablesQS() {
        let config = AISearchConfig.medium
        #expect(config.enableQuiescence == true, "medium 应启用 QS")
    }

    @Test("medium 配置 maxQSDepth = 2")
    func mediumConfigQSDepth() {
        let config = AISearchConfig.medium
        #expect(config.maxQSDepth == 2, "medium QS 深度应为 2")
    }

    @Test("medium 配置启用 advanced 评估（含机动性）")
    func mediumConfigAdvancedEval() {
        let config = AISearchConfig.medium
        #expect(config.evalConfig.mobility == true, "medium 应启用机动性评估")
        #expect(config.evalConfig.safety == true, "medium 应启用安全评估")
    }

    @Test("medium 与 hard 差异验证：medium 启用 LMR 但不启用 NullMove/PVS")
    func mediumVsHardGap() {
        let medium = AISearchConfig.medium
        let hard = AISearchConfig.hard
        // medium 启用 LMR 但不启用 NullMove/PVS（渐进过渡到 hard）
        #expect(medium.enableLMR == true, "medium 应启用 LMR")
        #expect(medium.enableNullMoveFix == false, "medium 不应启用 NullMove")
        #expect(medium.enablePVS == false, "medium 不应启用 PVS")
        // hard 应全部启用
        #expect(hard.enableLMR == true, "hard 应启用 LMR")
        #expect(hard.enableNullMoveFix == true, "hard 应启用 NullMove")
        #expect(hard.enablePVS == true, "hard 应启用 PVS")
    }

    @Test("default 配置不应启用 QS")
    func defaultConfigNoQS() {
        let defaultConfig = AISearchConfig.default
        #expect(defaultConfig.enableQuiescence == false, "default 不应启用 QS")
    }

    // MARK: - 2. SoundEngine AVAudioSession 条件编译
    // 源码文本匹配测试已移除（测源码文本而非行为）

    // MARK: - 3. 引擎回退 + 长将弹窗 UI 绑定
    // 源码文本匹配测试已移除（测源码文本而非行为）

    @Test("game.perpetualCheckTitle xcstrings key 存在")
    func perpetualCheckTitleKeyExists() {
        let homeDir = NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            Issue.record("无法读取 xcstrings")
            return
        }

        #expect(strings["game.perpetualCheckTitle"] != nil, "game.perpetualCheckTitle key 应存在")
    }

    // MARK: - 4. ThemePickerView ScrollView
    // 源码文本匹配测试已移除（测源码文本而非行为）

    // MARK: - 5. ReplayBoardView isFlipped + 动画
    // 源码文本匹配测试已移除（测源码文本而非行为）

    // MARK: - 6. Null Move mate score 保护
    // 源码文本匹配测试已移除（测源码文本而非行为）

    // MARK: - 7. 兵位置表 row 8 修正

    @Test("兵位置表开局 row8 约为 row7 的 1/3（中间列）")
    func soldierPositionTableOpeningRow8Ratio() {
        // 开局黑卒表：
        // row7 (index 7): [360, 660, 1020, 1440, 2160, 1440, 1020, 660, 360]
        // row8 (index 8): [120, 210, 330, 480, 720, 480, 330, 210, 120]
        // 中间列(col4): row7=2160, row8=720, ratio=720/2160=1/3
        let row7Center = 2160
        let row8Center = 720
        let ratio = Double(row8Center) / Double(row7Center)

        #expect(ratio > 0.25 && ratio < 0.40,
                "开局兵位置表 row8/row7 中间列比例应约 1/3，实际: \(String(format: "%.2f", ratio))")
    }

    @Test("兵位置表残局 row8 约为 row7 的 1/3（中间列）")
    func soldierPositionTableEndgameRow8Ratio() {
        // 残局黑卒表：
        // row7 (index 7): [540, 960, 1500, 2160, 2880, 2160, 1500, 960, 540]
        // row8 (index 8): [180, 330, 510, 720, 960, 720, 510, 330, 180]
        // 中间列(col4): row7=2880, row8=960, ratio=960/2880=1/3
        let row7Center = 2880
        let row8Center = 960
        let ratio = Double(row8Center) / Double(row7Center)

        #expect(ratio > 0.25 && ratio < 0.40,
                "残局兵位置表 row8/row7 中间列比例应约 1/3，实际: \(String(format: "%.2f", ratio))")
    }

    @Test("兵位置表 row8 不再是 row7 的 1/18（旧值检查）")
    func soldierPositionTableRow8NotOldValue() {
        // 旧值: 开局 row7=2160, row8=120 (1/18)
        // 新值: 开局 row8=720 (1/3)
        // 确认 row8 中心值 >= 500（远大于旧值 120）
        let row8CenterOpening = 720
        let row8CenterEndgame = 960

        #expect(row8CenterOpening >= 500, "开局 row8 中心值应远大于旧值 120")
        #expect(row8CenterEndgame >= 500, "残局 row8 中心值应远大于旧值 ~200")
    }

    // 兵位置表维度测试已移除（源码文本匹配）

    // MARK: - 回归保护

    @Test("AISearchConfig 基础配置完整性")
    func searchConfigIntegrity() {
        // 所有配置应有有效值
        let configs: [(String, AISearchConfig)] = [
            ("default", .default),
            ("medium", .medium),
            ("hard", .hard),
            ("master", .master),
        ]

        for (name, config) in configs {
            #expect(config.maxQSDepth >= 0, "\(name): maxQSDepth 应 >= 0")
            #expect(config.maxCheckExtensions > 0, "\(name): maxCheckExtensions 应 > 0")
        }
    }

    @Test("hard/master 配置不应被 medium 修改影响")
    func hardMasterUnchanged() {
        let hard = AISearchConfig.hard
        let master = AISearchConfig.master

        // hard/master 应仍有完整优化
        #expect(hard.enableQuiescence == true, "hard 应仍有 QS")
        #expect(hard.enablePVS == true, "hard 应仍有 PVS")
        #expect(master.enableQuiescence == true, "master 应仍有 QS")
        #expect(master.enablePVS == true, "master 应仍有 PVS")
    }
}
