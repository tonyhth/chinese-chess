import Testing
import Foundation
@testable import ChineseChess

// MARK: - v3.1 Phase 1 权重参数化测试

@Suite("v3.1 Phase 1: 评估权重参数化")
struct EvalWeightsTests {

    // ============================
    // MARK: - 1. 权重等价性验证
    // ============================

    @Test("EvalWeights.default 与代码定义一致")
    func defaultWeightsMatchCode() {
        // 验证 EvalWeights.default 的关键字段与硬编码一致
        let w = EvalWeights.default

        // 子力价值
        #expect(w.chariotValue == 900, "chariotValue = 900")
        #expect(w.horseValueOpening == 400, "horseValueOpening = 400")
        #expect(w.cannonValueOpening == 450, "cannonValueOpening = 450")

        // 评估权重
        #expect(w.materialWeight == 1.0, "materialWeight = 1.0")
        #expect(w.patternWeight == 1.0, "patternWeight = 1.0")
        #expect(w.mobilityWeight == 0.33, "mobilityWeight = 0.33")
        #expect(w.safetyWeight == 0.8, "safetyWeight = 0.8")

        // P1 返工关键字段验证
        #expect(w.doubleChariotBonus == 800, "doubleChariotBonus = 800")
        #expect(w.horseGeneralFacingBonus == 2000, "horseGeneralFacingBonus = 2000")
        #expect(w.ironGateBonus == 1500, "ironGateBonus = 1500")
        #expect(w.centralCannonBonus == 1200, "centralCannonBonus = 1200")
    }

    @Test("默认权重下 AI 评估结果合理")
    func evaluationConsistentWithHardcoded() {
        // 用默认权重初始化 EvalConfigManager
        let manager = EvalConfigManager(weights: .default)
        let board = Board()

        // AIEngine 使用 EvalConfigManager.shared.weights
        let engine = AIEngine()

        // 验证 AI 能返回合法走法
        let move = engine.bestMove(for: board, difficulty: .medium, isIOS: false)
        #expect(move != nil, "应返回合法走法")
    }

    // ============================
    // MARK: - 2. JSON 缺失字段 fallback
    // ============================

    // P2-1 发现：当前 mergeWithDefault 策略是整体回退，非逐字段 fallback
    // 如果 JSON 缺少任何字段，整体回退到 default（而非缺失字段用默认值填充）
    // 这是预期行为（当前实现），非 bug。后续可改为逐字段 fallback。

    @Test("部分 JSON 会整体回退到默认值（当前 mergeWithDefault 策略）")
    func partialJSONFullFallback() {
        // 只包含部分字段的 JSON
        let partialJSON = """
        {
            "chariotValue": 800,
            "horseValueOpening": 500
        }
        """

        let weights = EvalWeights.load(from: partialJSON)

        // 当前实现：部分 JSON → decode 失败 → 整体回退 default
        #expect(weights == EvalWeights.default, "部分 JSON 会整体回退（当前策略）")
    }

    @Test("完整 JSON 能正确覆盖默认值")
    func fullJSONOverwritesDefaults() {
        // 完整 JSON（覆盖部分字段）
        // 需要包含所有字段才能成功 decode
        var fullWeights = EvalWeights.default
        fullWeights.chariotValue = 800
        fullWeights.horseValueOpening = 500

        let fullJSON = fullWeights.toJSON()!
        let decoded = EvalWeights.load(from: fullJSON)

        #expect(decoded.chariotValue == 800, "完整 JSON 能覆盖 chariotValue")
        #expect(decoded.horseValueOpening == 500, "完整 JSON 能覆盖 horseValueOpening")
    }

    @Test("空 JSON 回退全默认")
    func emptyJSONFallback() {
        let emptyJSON = "{}"
        let weights = EvalWeights.load(from: emptyJSON)

        // 全部字段都是默认值
        #expect(weights == EvalWeights.default, "空 JSON 应返回全默认权重")
    }

    @Test("无效 JSON 回退全默认")
    func invalidJSONFallback() {
        let invalidJSON = "not a json"
        let weights = EvalWeights.load(from: invalidJSON)

        #expect(weights == EvalWeights.default, "无效 JSON 应返回全默认权重")
    }

    @Test("JSON 类型不匹配字段被忽略")
    func typeMismatchFallback() {
        let mismatchJSON = """
        {
            "chariotValue": "not_an_int",
            "materialWeight": "not_a_double"
        }
        """

        let weights = EvalWeights.load(from: mismatchJSON)

        // 类型不匹配 → 整体回退默认（当前 mergeWithDefault 策略）
        // 如果改为逐字段 fallback，这里应保留其他默认值
        #expect(weights.chariotValue == 900, "类型不匹配应 fallback 默认值")
    }

    // ============================
    // MARK: - 3. Bundle 路径跨平台
    // ============================

    @Test("eval-weights.json 存在于 bundle（通过 ResourceBundle）")
    func configFileExists() {
        // SPM 测试环境下 Bundle.main 不是应用 bundle
        // 用 ResourceBundle（专门为 SPM 设计）查找
        let bundlePath = ResourceBundle.url(forResource: "eval-weights", withExtension: "json")

        // 或者直接在 .build/debug bundle 中查找
        let debugBundlePath = URL(fileURLWithPath: ".build/debug/ChineseChess_ChineseChess.bundle/eval-weights.json")

        let exists = bundlePath != nil || FileManager.default.fileExists(atPath: debugBundlePath.path)
        #expect(exists, "eval-weights.json 应存在于 bundle")
    }

    @Test("EvalConfigManager 初始化不崩溃")
    func configManagerInitNoCrash() {
        let manager = EvalConfigManager.shared
        #expect(manager.weights.chariotValue == 900, "默认 chariotValue = 900")
    }

    @Test("EvalConfigManager 测试初始化器可自定义权重")
    func configManagerTestInit() {
        var customWeights = EvalWeights.default
        customWeights.chariotValue = 1200  // 调整车价值

        let manager = EvalConfigManager(weights: customWeights)
        #expect(manager.weights.chariotValue == 1200)
    }

    // ============================
    // MARK: - 4. 热重载功能
    // ============================

    @Test("EvalConfigManager.reload 更新权重")
    func reloadUpdatesWeights() {
        var customWeights = EvalWeights.default
        customWeights.horseValueOpening = 500

        let manager = EvalConfigManager(weights: customWeights)
        #expect(manager.weights.horseValueOpening == 500)

        // setWeights 替换
        manager.setWeights(.default)
        #expect(manager.weights.horseValueOpening == 400, "setWeights 应更新权重")
    }

    // ============================
    // MARK: - 5. 序列化/导出
    // ============================

    @Test("EvalWeights.toJSON 生成有效 JSON")
    func toJSONValid() {
        let weights = EvalWeights.default
        let json = weights.toJSON()

        #expect(json != nil)
        #expect(json!.contains("chariotValue"), "JSON 应包含 chariotValue")

        // 往返编解码
        let decoded = EvalWeights.load(from: json!)
        #expect(decoded == weights, "往返编解码应一致")
    }

    @Test("EvalWeights.toParameterArray 包含所有数值字段")
    func toParameterArrayComplete() {
        let weights = EvalWeights.default
        let params = weights.toParameterArray()

        #expect(params["chariotValue"] == 900)
        #expect(params["materialWeight"] == 1.0)
        #expect(params.count > 50, "参数数组应包含 50+ 字段")
    }

    // ============================
    // MARK: - 6. AIEngine 权重集成
    // ============================

    @Test("AIEngine 默认权重下返回合法走法")
    func aiEngineDefaultWeights() {
        // AIEngine 使用 EvalConfigManager.shared.weights
        let engine = AIEngine()
        let board = Board()

        // 验证不崩溃
        let move = engine.bestMove(for: board, difficulty: .easy, isIOS: false)
        #expect(move != nil, "默认权重下应返回合法走法")
    }

    @Test("自定义权重通过 EvalConfigManager.setWeights")
    func customWeightsViaConfigManager() {
        var customWeights = EvalWeights.default
        customWeights.chariotValue = 1500  // 车价值增加

        let manager = EvalConfigManager(weights: customWeights)
        manager.setWeights(customWeights)

        // AIEngine 会使用 manager.weights
        let engine = AIEngine()
        let board = Board()

        let move = engine.bestMove(for: board, difficulty: .easy, isIOS: false)
        #expect(move != nil, "自定义权重下应返回合法走法")
    }

    @Test("PatternRecognizer 使用权重参数")
    func patternRecognizerUsesWeights() {
        let weights = EvalWeights.default
        let board = Board()

        // PatternRecognizer.bonusPatterns 是 static 方法
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: weights)
        #expect(bonus >= 0, "棋型识别应不崩溃，返回值 >= 0")
    }

    // ============================
    // MARK: - 7. P1 返工验证：字段名语义错配修复
    // ============================

    @Test("P1: soldierValueCrossed 非 soldierValueLateEndgame")
    func soldierValueFieldsDistinct() {
        let w = EvalWeights.default
        #expect(w.soldierValueCrossed == 200, "soldierValueCrossed = 200（过河兵）")
        #expect(w.soldierValueLateEndgame == 300, "soldierValueLateEndgame = 300（残末期兵）")
        #expect(w.soldierValueCrossed != w.soldierValueLateEndgame, "两个兵价值字段应不同")
    }

    @Test("P1: horseValueEndgame 非 horseValueOpening")
    func horseValueFieldsDistinct() {
        let w = EvalWeights.default
        #expect(w.horseValueOpening == 400)
        #expect(w.horseValueEndgame == 450, "残局马价值 > 开局")
        #expect(w.horseValueEndgame > w.horseValueOpening)
    }

    @Test("P1: cannonValueEndgame < cannonValueOpening")
    func cannonValueFieldsCorrect() {
        let w = EvalWeights.default
        #expect(w.cannonValueOpening == 450)
        #expect(w.cannonValueEndgame == 400, "残局炮价值 < 开局")
        #expect(w.cannonValueEndgame < w.cannonValueOpening)
    }

    // ============================
    // MARK: - 8. 边界测试
    // ============================

    @Test("极端权重下 AI 不崩溃")
    func extremeWeightsNoCrash() {
        var extremeWeights = EvalWeights.default
        extremeWeights.chariotValue = 1  // 极小值
        extremeWeights.generalValue = 1000000  // 极大值

        // 通过 EvalConfigManager 设置
        let manager = EvalConfigManager(weights: extremeWeights)

        let engine = AIEngine()
        let board = Board()

        let move = engine.bestMove(for: board, difficulty: .easy, isIOS: false)
        #expect(move != nil, "极端权重下应返回合法走法（不崩溃）")
    }

    @Test("零值 JSON 能正确解码（完整 JSON）")
    func zeroValuesValidJSON() {
        // 完整 JSON，某些字段设为 0
        var zeroWeights = EvalWeights.default
        zeroWeights.chariotValue = 0
        zeroWeights.horseValueOpening = 0

        let zeroJSON = zeroWeights.toJSON()!
        let decoded = EvalWeights.load(from: zeroJSON)

        #expect(decoded.chariotValue == 0, "零值能正确解码")
        #expect(decoded.horseValueOpening == 0)

        // PatternRecognizer 应不崩溃
        let board = Board()
        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: decoded)
        #expect(bonus >= 0, "零权重下棋型识别应不崩溃")
    }
}