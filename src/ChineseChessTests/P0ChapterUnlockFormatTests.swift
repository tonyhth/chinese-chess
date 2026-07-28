import Testing
@testable import ChineseChess

// MARK: - P0 修复验证：ChapterStore.unlockDescription 格式字符串崩溃
//
// Git commit: 59bf1da fix(l10n): use numbered format specifiers to prevent crash in non-CJK locales
// 修复内容：Localizable.xcstrings 中 chapter.unlock.completePrev 改为编号占位符（%1$@/%2$d）
//
// 背景：
// - 原始代码：String(format: l.t("chapter.unlock.completePrev"), l.t(chapterTitle), count)
// - 参数1: String (章节标题), 参数2: Int (通关局数)
// - zh-Hans 模板: "通关%1$@ %2$d 局" → %1$@=String ✅ %2$d=Int ✅
// - en 模板: "Complete %1$d puzzles in %2$@" → %1$d=Int ❌(应为%@) %2$@=String ❌(应为%d)
//
// ⚠️ 发现：en 模板占位符类型与参数不匹配（%1$d 应为 %1$@，%2$@ 应为 %2$d）
// 编号占位符解决了参数顺序问题，但 en 的类型 specifier 仍然不匹配

@Suite("P0 ChapterStore UnlockDescription Format String Fix", .serialized)
struct P0ChapterUnlockFormatTests {

    // ============================================================
    // 辅助
    // ============================================================

    /// 保存/恢复语言设置
    private func withLanguage(_ lang: String, _ body: () throws -> Void) rethrows {
        let l = L10n.shared
        let savedLang = l.language
        l.setLanguage(lang)
        defer { l.setLanguage(savedLang) }
        try body()
    }

    /// 简化的 unlockDescription（模拟 ChapterStore.private 方法逻辑）
    private func desc(_ condition: ChapterUnlockCondition) -> String {
        let l = L10n.shared
        switch condition {
        case .none:
            return ""
        case .completeChapter(let chId, let count):
            let chapterTitle = ChapterDefinitions.chapters.first { $0.id == chId }?.titleKey ?? chId
            return String(format: l.t("chapter.unlock.completePrev"), l.t(chapterTitle), count)
        case .rank(let rank):
            return String(format: l.t("chapter.unlock.rank"), l.t(rank.localizedTitleKey))
        case .and(let conditions):
            return conditions.map { desc($0) }.joined(separator: " + ")
        case .or(let conditions):
            return conditions.map { desc($0) }.joined(separator: " / ")
        }
    }

    // ============================================================
    // 1. 格式字符串不崩溃（核心回归测试）
    // ============================================================

    @Test("completeChapter unlockDescription 不崩溃（zh-Hans locale）")
    func unlockDescriptionNoCrashZhHans() async throws {
        try withLanguage("zh-Hans") {
            let result = desc(.completeChapter(chapterId: "ch1", count: 10))
            #expect(!result.isEmpty)
            #expect(result.contains("10"))
        }
    }

    @Test("completeChapter unlockDescription 不崩溃（en locale）")
    func unlockDescriptionNoCrashEn() async throws {
        try withLanguage("en") {
            // en 模板: "Complete %1$d puzzles in %2$@"
            // 参数1 = String, 参数2 = Int
            // %1$d 期望 Int 但收到 String → 可能输出垃圾但不崩溃
            let result = desc(.completeChapter(chapterId: "ch1", count: 10))
            // 如果没崩溃到这里，至少修复防止了 crash
            #expect(!result.isEmpty)
        }
    }

    @Test("rank unlockDescription 不崩溃（en locale）")
    func unlockDescriptionRankEn() async throws {
        try withLanguage("en") {
            let result = desc(.rank(.scholar))
            #expect(!result.isEmpty)
        }
    }

    @Test("rank unlockDescription 不崩溃（zh-Hans locale）")
    func unlockDescriptionRankZhHans() async throws {
        try withLanguage("zh-Hans") {
            let result = desc(.rank(.scholar))
            #expect(!result.isEmpty)
        }
    }

    // ============================================================
    // 2. zh-Hans 格式化内容正确性
    // ============================================================

    @Test("zh-Hans completeChapter 包含通关局数")
    func zhHansCompleteChapterContainsCount() async throws {
        try withLanguage("zh-Hans") {
            let result = desc(.completeChapter(chapterId: "ch1", count: 10))
            #expect(result.contains("10"))
        }
    }

    @Test("zh-Hans completeChapter 包含章节名")
    func zhHansCompleteChapterContainsTitle() async throws {
        try withLanguage("zh-Hans") {
            let chapterTitle = ChapterDefinitions.chapters.first { $0.id == "ch1" }!.titleKey
            let translatedTitle = L10n.shared.t(chapterTitle)
            let result = desc(.completeChapter(chapterId: "ch1", count: 10))
            #expect(result.contains(translatedTitle))
        }
    }

    @Test("zh-Hans 不同 count 值格式化正确")
    func zhHansDifferentCounts() async throws {
        try withLanguage("zh-Hans") {
            for count in [1, 5, 30, 50] {
                let result = desc(.completeChapter(chapterId: "ch1", count: count))
                #expect(result.contains("\(count)"), "应包含数字 \(count)")
            }
        }
    }

    // ============================================================
    // 3. 模板占位符格式验证（回归防护）
    // ============================================================

    @Test("zh-Hans 模板使用编号占位符")
    func zhHansTemplateUsesNumberedSpecifiers() async throws {
        try withLanguage("zh-Hans") {
            let template = L10n.shared.t("chapter.unlock.completePrev")
            #expect(template.contains("%1$") || template.contains("%2$"),
                    "zh-Hans 模板应使用编号占位符，当前: \(template)")
        }
    }

    @Test("en 模板使用编号占位符")
    func enTemplateUsesNumberedSpecifiers() async throws {
        try withLanguage("en") {
            let template = L10n.shared.t("chapter.unlock.completePrev")
            #expect(template.contains("%1$") || template.contains("%2$"),
                    "en 模板应使用编号占位符，当前: \(template)")
        }
    }

    // ============================================================
    // 4. 复合条件格式化
    // ============================================================

    @Test(".and 条件用 + 连接")
    func andConditionJoinWithPlus() async throws {
        try withLanguage("zh-Hans") {
            // ch7: .and([.completeChapter(chapterId: "ch6", count: 30), .rank(.jinshi)])
            let condition = ChapterUnlockCondition.and([
                .completeChapter(chapterId: "ch6", count: 30),
                .rank(.jinshi)
            ])
            let result = desc(condition)
            #expect(result.contains("+"))
        }
    }

    @Test(".or 条件用 / 连接")
    func orConditionJoinWithSlash() async throws {
        try withLanguage("zh-Hans") {
            let condition = ChapterUnlockCondition.or([
                .completeChapter(chapterId: "ch1", count: 10),
                .rank(.scholar)
            ])
            let result = desc(condition)
            #expect(result.contains("/"))
        }
    }

    @Test(".none 条件返回空字符串")
    func noneConditionReturnsEmpty() async throws {
        try withLanguage("zh-Hans") {
            let result = desc(.none)
            #expect(result.isEmpty)
        }
    }

    // ============================================================
    // 5. en 模板类型匹配验证（P1 修复后应通过）
    // ============================================================

    @Test("en 模板占位符类型与参数匹配")
    func enTemplateSpecifierTypeMatch() async throws {
        try withLanguage("en") {
            let template = L10n.shared.t("chapter.unlock.completePrev")
            // 代码调用：String(format: template, l.t(chapterTitle), count)
            // 参数1: String → %1$@   参数2: Int → %2$d
            let hasCorrectTypes = template.contains("%1$@") && template.contains("%2$d")
            #expect(hasCorrectTypes,
                    "en 模板占位符类型应匹配参数，当前: \(template)")
        }
    }

    @Test("en locale completeChapter 输出包含通关局数")
    func enCompleteChapterContainsCount() async throws {
        try withLanguage("en") {
            let result = desc(.completeChapter(chapterId: "ch1", count: 5))
            #expect(result.contains("5"), "en 输出应包含数字 5，实际: \(result)")
        }
    }

    @Test("en locale completeChapter 输出包含章节名")
    func enCompleteChapterContainsTitle() async throws {
        try withLanguage("en") {
            let chapterTitle = ChapterDefinitions.chapters.first { $0.id == "ch1" }!.titleKey
            let translatedTitle = L10n.shared.t(chapterTitle)
            let result = desc(.completeChapter(chapterId: "ch1", count: 10))
            #expect(result.contains(translatedTitle),
                    "en 输出应包含章节名 \(translatedTitle)，实际: \(result)")
        }
    }

    @Test("en locale 不同 count 值格式化正确")
    func enDifferentCounts() async throws {
        try withLanguage("en") {
            for count in [1, 5, 30, 50] {
                let result = desc(.completeChapter(chapterId: "ch1", count: count))
                #expect(result.contains("\(count)"), "en 应包含数字 \(count)，实际: \(result)")
            }
        }
    }
}
