import Foundation

// MARK: - 评估配置

/// 控制评估函数中哪些高级维度被启用
struct AIEvalConfig {
    var mobility: Bool  // 简化机动性评估
    var safety: Bool    // 将帅安全评估
    var contempt: Int   // 单向 contempt factor（均势局面下给当前走方的正向偏置，0=禁用）

    static let basic = AIEvalConfig(mobility: false, safety: true, contempt: 0)       // 初级/中级
    static let advanced = AIEvalConfig(mobility: true, safety: true, contempt: 0)     // 高级/大师
}

// MARK: - 搜索配置

/// 搜索优化配置（运行时，非编译常量）
/// 集中管理所有搜索参数，支持热修复和难度差异化
struct AISearchConfig {
    var enableQuiescence: Bool = false
    var enableKillerMove: Bool = false
    var enableCheckExtension: Bool = false
    var enableNullMoveFix: Bool = false
    var enableLMR: Bool = false
    var enableSmartTime: Bool = false
    var enablePVS: Bool = false
    var enableCountermove: Bool = false
    // v3.0 Phase 2b
    var enableFutility: Bool = false
    var enableRazoring: Bool = false
    var enableIID: Bool = false

    var evalConfig: AIEvalConfig = .advanced
    var maxQSDepth: Int = 4
    var maxCheckExtensions: Int = 8
    var nullMoveMaterialThreshold: Int = 2000

    /// P4-②（v1.2 §5.3 + phase4 §1 开关边界裁定）：QS standPat 评估策略。
    /// false（默认）= cheapEval（M1 V2 主张路径，P4-0 通过前提已满足）；
    /// true = 全量 evaluate（回退档 L1，零 rebuild 实例切换）。
    /// 仅 V2 态生效（Legacy 六点全走原路全量，无效位）；razor/futility 不设开关
    /// （margin 容差吸收）。默认值入口处读 env QS_STANDPAT_FULL=1（不进程缓存）。
    var qsStandPatFullEval: Bool = false

    /// 默认配置：所有优化关闭（中级及以下安全）
    static let `default` = AISearchConfig()

    /// 完整优化配置（高级/大师）
    static let fullOptimization = AISearchConfig(
        enableQuiescence: true,
        enableKillerMove: true,
        enableCheckExtension: true,
        enableNullMoveFix: true,
        enableLMR: true,
        enableSmartTime: false,
        enablePVS: true,
        enableCountermove: true,
        enableFutility: true,
        enableRazoring: true,
        enableIID: true,
        evalConfig: .advanced,
        maxQSDepth: 4,
        maxCheckExtensions: 8
    )

    /// 中级配置（v4.0: 启用 QS + advanced eval + LMR + futility，渐进过渡到 hard）
    static let medium = AISearchConfig(
        enableQuiescence: true,
        enableKillerMove: true,
        enableCheckExtension: true,
        enableNullMoveFix: false,
        enableLMR: true,
        enableSmartTime: false,
        enablePVS: false,
        enableCountermove: false,
        enableFutility: true,
        enableRazoring: false,
        enableIID: false,
        evalConfig: .advanced,
        maxQSDepth: 2,
        maxCheckExtensions: 8
    )

    /// v4.2: lvl3 专用 — .medium 去掉 QS（killer + checkExtension + LMR + futility，无 QS/PVS）
    static let mediumNoQS = AISearchConfig(
        enableQuiescence: false,
        enableKillerMove: true,
        enableCheckExtension: true,
        enableNullMoveFix: false,
        enableLMR: true,
        enableSmartTime: false,
        enablePVS: false,
        enableCountermove: false,
        enableFutility: true,
        enableRazoring: false,
        enableIID: false,
        evalConfig: .advanced,
        maxQSDepth: 0,
        maxCheckExtensions: 8
    )

    /// 高级配置
    static let hard = AISearchConfig(
        enableQuiescence: true,
        enableKillerMove: true,
        enableCheckExtension: true,
        enableNullMoveFix: true,
        enableLMR: true,
        enableSmartTime: false,
        enablePVS: true,
        enableCountermove: true,
        enableFutility: true,
        enableRazoring: true,
        enableIID: true,
        evalConfig: .advanced,
        maxQSDepth: 4,
        maxCheckExtensions: 6
    )

    /// 大师配置
    static let master = AISearchConfig(
        enableQuiescence: true,
        enableKillerMove: true,
        enableCheckExtension: true,
        enableNullMoveFix: true,
        enableLMR: true,
        enableSmartTime: true,
        enablePVS: true,
        enableCountermove: true,
        enableFutility: true,
        enableRazoring: true,
        enableIID: true,
        evalConfig: .advanced,
        maxQSDepth: 6,
        maxCheckExtensions: 8
    )
}
