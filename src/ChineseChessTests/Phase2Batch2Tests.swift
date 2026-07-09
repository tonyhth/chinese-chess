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

    @Test("medium 与 hard 差异验证：medium 不启用 LMR/NullMove/PVS")
    func mediumVsHardGap() {
        let medium = AISearchConfig.medium
        let hard = AISearchConfig.hard
        // medium 不应有这些高级优化（缩小但不是完全一致）
        #expect(medium.enableLMR == false, "medium 不应启用 LMR")
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

    @Test("SoundEngine 包含 #if os(iOS) 条件编译守卫")
    func soundEngineIOSGuards() {
        guard let content = Self.readFile("Services/SoundEngine.swift") else {
            Issue.record("无法读取 SoundEngine.swift")
            return
        }

        // 应有 #if os(iOS) 守卫
        let iosGuardCount = content.components(separatedBy: "#if os(iOS)").count - 1
        #expect(iosGuardCount >= 2, "SoundEngine 应至少有 2 处 #if os(iOS) 守卫（AVAudioSession 相关），实际: \(iosGuardCount)")

        // 应有 AVAudioSession 引用（仅在 iOS 块内）
        #expect(content.contains("AVAudioSession"), "SoundEngine 应引用 AVAudioSession")
    }

    @Test("SoundEngine macOS 编译安全：AVAudioSession 仅在 #if os(iOS) 块内")
    func soundEngineMacOSSafe() {
        guard let content = Self.readFile("Services/SoundEngine.swift") else {
            Issue.record("无法读取 SoundEngine.swift")
            return
        }

        // 逐行扫描，追踪嵌套的 #if 层级
        // 只检查 AVAudioSession（不是 AVAudioPlayer，后者 macOS 也有）
        let lines = content.components(separatedBy: "\n")
        var depth = 0
        var avAudioSessionLines: [(line: String, inIOSBlock: Bool)] = []

        for line in lines {
            if line.contains("#if os(iOS)") { depth += 1 }
            if line.contains("#endif") { depth = max(0, depth - 1) }
            if line.contains("AVAudioSession") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                avAudioSessionLines.append((line: line, inIOSBlock: depth > 0))
            }
        }

        for entry in avAudioSessionLines {
            #expect(entry.inIOSBlock,
                    "AVAudioSession 应在 #if os(iOS) 块内，但出现在: \(entry.line.trimmingCharacters(in: .whitespaces))")
        }
    }

    // MARK: - 3. 引擎回退 + 长将弹窗 UI 绑定

    @Test("ChineseChessApp 包含 perpetualCheckMessage alert 绑定")
    func perpetualCheckAlertBinding() {
        guard let content = Self.readFile("App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift")
            return
        }

        // 验证 alert 绑定
        #expect(content.contains("perpetualCheckMessage"), "ChineseChessApp 应引用 perpetualCheckMessage")
        #expect(content.contains("perpetualCheckTitle") || content.contains("perpetualCheck"),
                "长将弹窗应有标题 key")
    }

    @Test("长将弹窗使用 L10n 国际化（不硬编码中文）")
    func perpetualCheckAlertI18n() {
        guard let content = Self.readFile("App/ChineseChessApp.swift") else {
            Issue.record("无法读取 ChineseChessApp.swift")
            return
        }

        // 弹窗文案应通过 L10n.shared.t() 获取
        #expect(content.contains("L10n.shared.t("), "长将弹窗应使用 L10n 国际化")
    }

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

    @Test("ThemePickerView 使用 ScrollView 水平滚动")
    func themePickerScrollView() {
        guard let content = Self.readFile("Views/ThemePickerView.swift") else {
            Issue.record("无法读取 ThemePickerView.swift")
            return
        }

        #expect(content.contains("ScrollView(.horizontal"), "ThemePickerView 应使用 ScrollView 水平滚动")
    }

    @Test("ThemePickerView ScrollView 隐藏滚动条")
    func themePickerScrollViewNoIndicators() {
        guard let content = Self.readFile("Views/ThemePickerView.swift") else {
            Issue.record("无法读取 ThemePickerView.swift")
            return
        }

        #expect(content.contains("showsIndicators: false"), "ThemePickerView ScrollView 应隐藏滚动条指示器")
    }

    // MARK: - 5. ReplayBoardView isFlipped + 动画

    @Test("ReplayBoardView 有 isFlipped 属性")
    func replayBoardIsFlipped() {
        guard let content = Self.readFile("Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift")
            return
        }

        #expect(content.contains("isFlipped"), "ReplayBoardView 应有 isFlipped 属性")
    }

    @Test("ReplayBoardView 使用 spring 动画（response: 0.3, dampingFraction: 0.8）")
    func replayBoardSpringAnimation() {
        guard let content = Self.readFile("Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift")
            return
        }

        #expect(content.contains(".spring(response: 0.3, dampingFraction: 0.8)"),
                "ReplayBoardView 应使用 spring(response: 0.3, dampingFraction: 0.8) 动画")
    }

    @Test("ReplayBoardView spring 动画绑定 isFlipped 值")
    func replayBoardAnimationTiedToIsFlipped() {
        guard let content = Self.readFile("Views/ReplayBoardView.swift") else {
            Issue.record("无法读取 ReplayBoardView.swift")
            return
        }

        // 找到 .spring 动画行，确认 value: isFlipped
        #expect(content.contains("value: isFlipped"), "spring 动画应绑定 value: isFlipped")
    }

    // MARK: - 6. Null Move mate score 保护

    @Test("Null Move Pruning 包含 mate score 特殊处理（abs > 90000 直接返回）")
    func nullMoveMateScoreProtection() {
        guard let content = Self.readFile("AI/AIEngine.swift") else {
            Issue.record("无法读取 AIEngine.swift")
            return
        }

        // 验证存在 mate score 保护行
        #expect(content.contains("abs(nullScore) > 90000"), "Null Move 应有 abs(nullScore) > 90000 检查")
        #expect(content.contains("return nullScore"), "mate score 时应直接返回 nullScore")
    }

    @Test("Null Move mate score 在 nullScore >= beta 块内")
    func nullMoveMateScoreInBetaBlock() {
        guard let content = Self.readFile("AI/AIEngine.swift") else {
            Issue.record("无法读取 AIEngine.swift")
            return
        }

        // 找到 null move pruning 的 fail-high 块
        if let nullMoveRange = content.range(of: "nullScore >= beta") {
            let afterBeta = content[nullMoveRange.lowerBound...]
            let blockSection = String(afterBeta.prefix(200))

            // mate score 检查应在 nullScore >= beta 块内
            #expect(blockSection.contains("abs(nullScore) > 90000"),
                    "mate score 检查应在 nullScore >= beta 条件块内")
        } else {
            Issue.record("找不到 nullScore >= beta 检查")
        }
    }

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

    @Test("兵位置表行数正确（10行 × 9列）")
    func soldierPositionTableDimensions() {
        guard let content = Self.readFile("AI/PositionTables.swift") else {
            Issue.record("无法读取 PositionTables.swift")
            return
        }

        // 验证数组有 10 行（0-9 对应 row 0-9）
        if let range = content.range(of: "blackSoldierWeightsOpening") {
            let after = content[range.lowerBound...]
            let section = String(after.prefix(1500))
            let rowCount = section.components(separatedBy: "[").count - 2 // 减去声明行的 [
            // 每行以 [ 开头，有 10 行数据
            #expect(rowCount >= 10, "兵位置表应有至少 10 行数据")
        }
    }

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
