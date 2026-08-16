import Testing
import Foundation
@testable import ChineseChess

@Suite("TutorialView i18n 提取测试", .serialized)
final class TutorialI18nTests {
    private var savedLang = ""
    init() { savedLang = TestL10nSupport.injectZhHans() }  // 基线污染单1：泄漏源接线（Alex L2 §1 要点4）
    deinit { TestL10nSupport.restore(savedLang) }

    /// xcstrings 文件路径
    private static let xcstringsPath: String = {
        let homeDir = NSHomeDirectory()
        return "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
    }()

    /// 加载 xcstrings strings 字典
    private static func loadStrings() -> [String: [String: Any]] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            return [:]
        }
        return strings
    }

    // MARK: - Key 存在性 + 译文正确性

    @Test("TutorialView 使用的 tutorial.* key 全部存在于 xcstrings")
    func allTutorialKeysExist() {
        let strings = Self.loadStrings()
        // 仅验证 TutorialView.swift 中实际使用的 key（8 个 UI key）
        let expectedKeys: Set<String> = [
            "tutorial.prev", "tutorial.progress", "tutorial.skip",
            "tutorial.complete", "tutorial.next",
            "tutorial.welcome", "tutorial.welcomeQuestion",
            "tutorial.notFamiliar", "tutorial.familiar",
        ]
        var missing: [String] = []
        for key in expectedKeys {
            if strings[key] == nil {
                missing.append(key)
            }
        }
        #expect(missing.isEmpty, "缺失的 key: \(missing)")
    }

    @Test("所有 tutorial.* key 都有 zh-Hans 和 en 翻译")
    func allTutorialKeysHaveBothTranslations() {
        let strings = Self.loadStrings()
        let tutorialKeys = strings.keys.filter { $0.hasPrefix("tutorial.") }
        var issues: [String] = []

        for key in tutorialKeys {
            guard let entry = strings[key],
                  let locs = entry["localizations"] as? [String: [String: Any]] else {
                issues.append("\(key): 缺少 localizations")
                continue
            }
            // zh-Hans
            let zhState = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["state"] as? String
            let zhVal = (locs["zh-Hans"]?["stringUnit"] as? [String: Any])?["value"] as? String
            if zhState != "translated" {
                issues.append("\(key): zh-Hans state=\(zhState ?? "nil")")
            }
            if zhVal == nil || zhVal!.isEmpty {
                issues.append("\(key): zh-Hans value 为空")
            }
            // en
            let enState = (locs["en"]?["stringUnit"] as? [String: Any])?["state"] as? String
            let enVal = (locs["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            if enState != "translated" {
                issues.append("\(key): en state=\(enState ?? "nil")")
            }
            if enVal == nil || enVal!.isEmpty {
                issues.append("\(key): en value 为空")
            }
        }

        #expect(issues.isEmpty, "翻译问题: \(issues)")
    }

    // MARK: - l10n.t() 运行时验证

    @MainActor
    @Test("中文环境下 tutorial key 返回中文译文")
    func tutorialChineseOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("zh-Hans")

        #expect(l10n.t("tutorial.prev") == "上一步")
        #expect(l10n.t("tutorial.skip") == "跳过")
        #expect(l10n.t("tutorial.complete") == "完成教程")
        #expect(l10n.t("tutorial.next") == "下一课")
        #expect(l10n.t("tutorial.welcome") == "欢迎使用中国象棋！")
        #expect(l10n.t("tutorial.notFamiliar") == "不太熟悉")
        #expect(l10n.t("tutorial.familiar") == "已了解")
    }

    @MainActor
    @Test("英文环境下 tutorial key 返回英文译文")
    func tutorialEnglishOutput() {
        let l10n = L10n.shared
        l10n.setLanguage("en")

        #expect(l10n.t("tutorial.prev") == "Previous")
        #expect(l10n.t("tutorial.skip") == "Skip")
        #expect(l10n.t("tutorial.complete") == "Complete Tutorial")
        #expect(l10n.t("tutorial.next") == "Next Lesson")
        #expect(l10n.t("tutorial.welcome") == "Welcome to Chinese Chess!")
        #expect(l10n.t("tutorial.notFamiliar") == "Not Familiar")
        #expect(l10n.t("tutorial.familiar") == "I Know the Rules")
    }

    @MainActor
    @Test("tutorial.progress 格式化字符串正确")
    func tutorialProgressFormatString() {
        let l10n = L10n.shared
        l10n.setLanguage("zh-Hans")
        let zhResult = l10n.t("tutorial.progress", "3", "5")
        #expect(zhResult.contains("3"), "中文格式化应包含参数 3")
        #expect(zhResult.contains("5"), "中文格式化应包含参数 5")

        l10n.setLanguage("en")
        let enResult = l10n.t("tutorial.progress", "3", "5")
        #expect(enResult.contains("3"), "英文格式化应包含参数 3")
        #expect(enResult.contains("5"), "英文格式化应包含参数 5")
    }

    @MainActor
    @Test("TutorialView 使用的 tutorial key 在两种语言下不返回 key 原文")
    func tutorialKeysDoNotReturnRawKey() {
        let l10n = L10n.shared
        // 仅测试 TutorialView 中实际使用的 key
        let keys = [
            "tutorial.prev", "tutorial.skip", "tutorial.complete", "tutorial.next",
            "tutorial.welcome", "tutorial.welcomeQuestion",
            "tutorial.notFamiliar", "tutorial.familiar",
        ]
        for lang in ["zh-Hans", "en"] {
            l10n.setLanguage(lang)
            for key in keys {
                let result = l10n.t(key)
                #expect(result != key, "[\(lang)] l10n.t(\"\(key)\") 返回了 key 原文")
            }
        }
    }

    // MARK: - 代码引用完整性

    @Test("TutorialView.swift 中的 L10n.shared.t() 调用与 xcstrings key 一致")
    func codeReferencesMatchXcstrings() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/Tutorial/TutorialView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 TutorialView.swift")
            return
        }

        // Extract all tutorial.* keys from code
        let pattern = #"L10n\.shared\.t\("tutorial\.([^"]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var codeKeys: Set<String> = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: content) {
                codeKeys.insert("tutorial." + content[range])
            }
        }

        // Verify all code keys exist in xcstrings
        let strings = Self.loadStrings()
        var missing: [String] = []
        for key in codeKeys {
            if strings[key] == nil {
                missing.append(key)
            }
        }
        #expect(missing.isEmpty, "代码中使用但 xcstrings 中缺失的 key: \(missing)")
        // 不再断言固定数量，避免新增/删除 key 时测试失败
        #expect(codeKeys.count >= 8, "代码中应有至少 8 个 tutorial.* 引用，实际 \(codeKeys.count)")
    }

    // MARK: - 无残留硬编码中文

    @Test("TutorialView.swift 中无残留硬编码中文字符串")
    func noHardcodedChinese() {
        let homeDir = NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/Tutorial/TutorialView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            Issue.record("无法读取 TutorialView.swift")
            return
        }

        // Find string literals containing Chinese chars (not l10n keys)
        let pattern = #""([^"]*[\u{4e00}-\u{9fff}][^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var violations: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: content) {
                let str = String(content[range])
                // Skip l10n key references
                if str.hasPrefix("tutorial.") || str.hasPrefix("chinesechess.") {
                    continue
                }
                violations.append(str)
            }
        }
        #expect(violations.isEmpty, "残留硬编码中文: \(violations)")
    }
}
