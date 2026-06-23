import Foundation

// MARK: - EvalWeights 有序字段映射

/// EvalWeights 字段名有序列表，保证编码/解码顺序一致（P1 修复）
/// 顺序必须与 Mirror.children 顺序完全匹配
private let evalWeightsFieldNames: [String] = [
    // 子力价值
    "generalValue", "chariotValue", "horseValueOpening", "horseValueEndgame",
    "cannonValueOpening", "cannonValueEndgame", "advisorValue", "elephantValue",
    "soldierValueEarly", "soldierValueCrossed", "soldierValueLateEndgame",
    "endgameThreshold", "lateEndgameThreshold",
    // 评估函数权重
    "materialWeight", "positionWeight", "patternWeight", "mobilityWeight", "safetyWeight",
    // 将帅安全
    "guardWeightOpening", "guardWeightEndgame", "elephantWeightModifier",
    "exposurePenaltyOpening", "exposurePenaltyEndgame", "airDefenseBonus",
    "airDefensePenaltyOpening", "attackPenaltyEndgame", "attackPenaltyOpening",
    "horsePalaceThreatDirect", "horsePalaceThreatNear",
    // 机动性
    "chariotRowColEmptyMultiplier", "chariotCenterBonus", "chariotNearCenterBonus",
    "chariotEndgameMultiplier", "chariotOpeningMultiplier", "cannonTargetBonus",
    "cannonCenterBonus", "cannonEndgameFactor", "horseJumpBonus", "horseEndgameJumpBonus",
    "horseBadPositionPenalty", "soldierForwardBonus", "soldierSideBonus",
    // 棋型识别
    "doubleChariotBonus", "singleChariotWithWeakBonus", "horseGeneralFacingBonus",
    "fishingHorseBonus", "ironGateBonus", "centralCannonBonus", "horseCenterBonus",
    "horseBadCenterPenalty", "chariotCannonLineBonus", "tandemCannonBonus",
    "riverCannonBonus", "stackedCannonBonus", "cornerAdvisorBonus", "flyingElephantBonus",
    "generalProximityBonusBase", "generalProximityBonusRange", "soldierStructureBonus",
    "soldierLineSyncBonus", "chariotCannonCoordBonus", "chariotCannonProtectBonus",
    "horseCannonCoordBonus",
    // 补充棋型
    "doubleChariotTandemBonus", "corneredHorseBonus", "centralCannonAttackBonus",
    "crossedSoldierBonus", "flyingGeneralBonus", "doubleChariotCoordBonus",
    "doubleHorseProtectBonus", "noCannonSafetyBonus",
    // 搜索参数
    "endgameEvalThreshold"
]

// MARK: - CMA-ES 参数向量

/// CMA-ES 优化参数向量
/// 将 EvalWeights 编码为 Double 数组，支持进化操作
struct CMAESIndividual: Codable {
    let id: UUID
    var parameters: [Double]       // 参数向量（与 evalWeightsFieldNames 顺序严格对应）
    var fitness: Double = 0.0      // 适应度（基于自对弈胜率）
    var generation: Int = 0
    
    init(parameters: [Double], generation: Int = 0) {
        self.id = UUID()
        self.parameters = parameters
        self.generation = generation
    }
    
    /// 从 EvalWeights 创建个体（P1 修复：使用有序字段列表）
    init(from weights: EvalWeights, generation: Int = 0) {
        self.id = UUID()
        self.generation = generation
        var params: [Double] = []
        let mirror = Mirror(reflecting: weights)
        for child in mirror.children {
            guard let label = child.label else { continue }
            switch child.value {
            case let v as Int: params.append(Double(v))
            case let v as Double: params.append(v)
            default: break
            }
        }
        self.parameters = params
    }
    
    /// 解码为 EvalWeights（P1 修复：使用有序字段列表）
    func toEvalWeights() -> EvalWeights {
        var weights = EvalWeights.default
        let mirror = Mirror(reflecting: weights)
        var mirrorChildren = Array(mirror.children)
        for i in 0..<min(parameters.count, mirrorChildren.count) {
            let child = mirrorChildren[i]
            guard let label = child.label else { continue }
            weights = weights.setValue(label: label, value: parameters[i])
        }
        return weights
    }
}

// MARK: - EvalWeights 反射辅助

extension EvalWeights {
    /// 根据字段名设置值（反射辅助）
    func setValue(label: String, value: Double) -> EvalWeights {
        var weights = self
        switch label {
        // 子力价值
        case "generalValue": weights.generalValue = Int(value)
        case "chariotValue": weights.chariotValue = Int(value)
        case "horseValueOpening": weights.horseValueOpening = Int(value)
        case "horseValueEndgame": weights.horseValueEndgame = Int(value)
        case "cannonValueOpening": weights.cannonValueOpening = Int(value)
        case "cannonValueEndgame": weights.cannonValueEndgame = Int(value)
        case "advisorValue": weights.advisorValue = Int(value)
        case "elephantValue": weights.elephantValue = Int(value)
        case "soldierValueEarly": weights.soldierValueEarly = Int(value)
        case "soldierValueCrossed": weights.soldierValueCrossed = Int(value)
        case "soldierValueLateEndgame": weights.soldierValueLateEndgame = Int(value)
        case "endgameThreshold": weights.endgameThreshold = Int(value)
        case "lateEndgameThreshold": weights.lateEndgameThreshold = Int(value)
        
        // 评估函数权重
        case "materialWeight": weights.materialWeight = value
        case "positionWeight": weights.positionWeight = value
        case "patternWeight": weights.patternWeight = value
        case "mobilityWeight": weights.mobilityWeight = value
        case "safetyWeight": weights.safetyWeight = value
        
        // 将帅安全
        case "guardWeightOpening": weights.guardWeightOpening = Int(value)
        case "guardWeightEndgame": weights.guardWeightEndgame = Int(value)
        case "elephantWeightModifier": weights.elephantWeightModifier = Int(value)
        case "exposurePenaltyOpening": weights.exposurePenaltyOpening = Int(value)
        case "exposurePenaltyEndgame": weights.exposurePenaltyEndgame = Int(value)
        case "airDefenseBonus": weights.airDefenseBonus = Int(value)
        case "airDefensePenaltyOpening": weights.airDefensePenaltyOpening = Int(value)
        case "attackPenaltyEndgame": weights.attackPenaltyEndgame = Int(value)
        case "attackPenaltyOpening": weights.attackPenaltyOpening = Int(value)
        case "horsePalaceThreatDirect": weights.horsePalaceThreatDirect = Int(value)
        case "horsePalaceThreatNear": weights.horsePalaceThreatNear = Int(value)
        
        // 机动性
        case "chariotRowColEmptyMultiplier": weights.chariotRowColEmptyMultiplier = Int(value)
        case "chariotCenterBonus": weights.chariotCenterBonus = Int(value)
        case "chariotNearCenterBonus": weights.chariotNearCenterBonus = Int(value)
        case "chariotEndgameMultiplier": weights.chariotEndgameMultiplier = Int(value)
        case "chariotOpeningMultiplier": weights.chariotOpeningMultiplier = Int(value)
        case "cannonTargetBonus": weights.cannonTargetBonus = Int(value)
        case "cannonCenterBonus": weights.cannonCenterBonus = Int(value)
        case "cannonEndgameFactor": weights.cannonEndgameFactor = Int(value)
        case "horseJumpBonus": weights.horseJumpBonus = Int(value)
        case "horseEndgameJumpBonus": weights.horseEndgameJumpBonus = Int(value)
        case "horseBadPositionPenalty": weights.horseBadPositionPenalty = Int(value)
        case "soldierForwardBonus": weights.soldierForwardBonus = Int(value)
        case "soldierSideBonus": weights.soldierSideBonus = Int(value)
        
        // 棋型识别
        case "doubleChariotBonus": weights.doubleChariotBonus = Int(value)
        case "singleChariotWithWeakBonus": weights.singleChariotWithWeakBonus = Int(value)
        case "horseGeneralFacingBonus": weights.horseGeneralFacingBonus = Int(value)
        case "fishingHorseBonus": weights.fishingHorseBonus = Int(value)
        case "ironGateBonus": weights.ironGateBonus = Int(value)
        case "centralCannonBonus": weights.centralCannonBonus = Int(value)
        case "horseCenterBonus": weights.horseCenterBonus = Int(value)
        case "horseBadCenterPenalty": weights.horseBadCenterPenalty = Int(value)
        case "chariotCannonLineBonus": weights.chariotCannonLineBonus = Int(value)
        case "tandemCannonBonus": weights.tandemCannonBonus = Int(value)
        case "riverCannonBonus": weights.riverCannonBonus = Int(value)
        case "stackedCannonBonus": weights.stackedCannonBonus = Int(value)
        case "cornerAdvisorBonus": weights.cornerAdvisorBonus = Int(value)
        case "flyingElephantBonus": weights.flyingElephantBonus = Int(value)
        case "generalProximityBonusBase": weights.generalProximityBonusBase = Int(value)
        case "generalProximityBonusRange": weights.generalProximityBonusRange = Int(value)
        case "soldierStructureBonus": weights.soldierStructureBonus = Int(value)
        case "soldierLineSyncBonus": weights.soldierLineSyncBonus = Int(value)
        case "chariotCannonCoordBonus": weights.chariotCannonCoordBonus = Int(value)
        case "chariotCannonProtectBonus": weights.chariotCannonProtectBonus = Int(value)
        case "horseCannonCoordBonus": weights.horseCannonCoordBonus = Int(value)
        
        // 补充棋型
        case "doubleChariotTandemBonus": weights.doubleChariotTandemBonus = Int(value)
        case "corneredHorseBonus": weights.corneredHorseBonus = Int(value)
        case "centralCannonAttackBonus": weights.centralCannonAttackBonus = Int(value)
        case "crossedSoldierBonus": weights.crossedSoldierBonus = Int(value)
        case "flyingGeneralBonus": weights.flyingGeneralBonus = Int(value)
        case "doubleChariotCoordBonus": weights.doubleChariotCoordBonus = Int(value)
        case "doubleHorseProtectBonus": weights.doubleHorseProtectBonus = Int(value)
        case "noCannonSafetyBonus": weights.noCannonSafetyBonus = Int(value)
        
        // 搜索参数
        case "endgameEvalThreshold": weights.endgameEvalThreshold = Int(value)
        
        default: break  // 忽略未知字段
        }
        return weights
    }
}

// MARK: - CMA-ES 配置

struct CMAESConfig {
    var populationSize: Int = 20       // 种群大小
    var maxGenerations: Int = 100      // 最大进化代数
    var eliteCount: Int = 4            // 保留的优秀个体数
    var mutationRate: Double = 0.1     // 变异率
    var mutationStrength: Double = 0.2 // 变异强度（参数变化范围）
    var crossoverRate: Double = 0.7    // 交叉率
    
    // 自对弈评估配置
    var selfPlayGames: Int = 20        // 每个个体评估局数
    var selfPlayDifficulty: AIDifficulty = .hard  // 对手难度
    var convergenceThreshold: Double = 0.01  // 收敛阈值（平均适应度变化 < 此值停止）
}

// MARK: - CMA-ES 优化器

/// CMA-ES（协方差矩阵自适应进化策略）优化器
/// v3.1 Phase 1: 自动调参算法本体
final class CMAESOptimizer {
    
    private let config: CMAESConfig
    private var population: [CMAESIndividual] = []
    private var generation = 0
    private var bestIndividual: CMAESIndividual?
    private var history: [(generation: Int, avgFitness: Double, bestFitness: Double)] = []
    
    // 统计
    private var totalEvaluations = 0
    private var startTime = Date()
    
    init(config: CMAESConfig = CMAESConfig()) {
        self.config = config
    }
    
    // MARK: - 进化主循环
    
    /// 运行进化循环
    /// - Parameters:
    ///   - initialWeights: 初始权重（作为起点）
    ///   - progressCallback: 进度回调
    /// - Returns: 最优个体
    func run(
        initialWeights: EvalWeights = .default,
        progressCallback: ((Int, Double, Double) -> Void)? = nil
    ) -> CMAESIndividual {
        startTime = Date()
        
        // 1. 初始化种群
        initializePopulation(from: initialWeights)
        
        // 2. 进化循环
        for gen in 0..<config.maxGenerations {
            generation = gen
            
            // 2.1 评估适应度
            evaluatePopulation()
            
            // 2.2 记录统计
            let avgFitness = population.map { $0.fitness }.reduce(0, +) / Double(population.count)
            let bestFitness = population.map { $0.fitness }.max() ?? 0
            history.append((generation: gen, avgFitness: avgFitness, bestFitness: bestFitness))
            
            // 2.3 更新最优个体
            if let best = population.max(by: { $0.fitness < $1.fitness }) {
                if bestIndividual == nil || best.fitness > bestIndividual!.fitness {
                    bestIndividual = best
                }
            }
            
            // 2.4 进度回调
            progressCallback?(gen, avgFitness, bestFitness)
            
            // 2.5 收敛检查
            if gen > 10 {
                let recentAvg = history.suffix(10).map { $0.avgFitness }.reduce(0, +) / 10.0
                let olderAvg = history.dropLast(10).suffix(10).map { $0.avgFitness }.reduce(0, +) / 10.0
                if abs(recentAvg - olderAvg) < config.convergenceThreshold {
                    print("✅ CMA-ES 收敛于第 \(gen) 代")
                    break
                }
            }
            
            // 2.6 选择 + 进化
            evolvePopulation()
        }
        
        return bestIndividual ?? population.first!
    }
    
    // MARK: - 种群操作
    
    /// 初始化种群
    private func initializePopulation(from weights: EvalWeights) {
        population = []
        
        // 基础个体（从初始权重）
        let baseIndividual = CMAESIndividual(from: weights, generation: 0)
        population.append(baseIndividual)
        
        // 随机生成其余个体（在基础个体周围变异）
        for _ in 1..<config.populationSize {
            let mutatedParams = baseIndividual.parameters.map { param in
                // 在基础参数附近随机扰动
                param + (Double.random(in: -1...1) * config.mutationStrength * param)
            }
            let individual = CMAESIndividual(parameters: mutatedParams, generation: 0)
            population.append(individual)
        }
    }
    
    /// 评估种群适应度（基于自对弈胜率）
    private func evaluatePopulation() {
        for i in 0..<population.count {
            let individual = population[i]
            let weights = individual.toEvalWeights()
            
            // 运行自对弈评估棋力
            let fitness = evaluateFitness(weights: weights)
            population[i].fitness = fitness
            totalEvaluations += 1
        }
    }
    
    /// 评估单个权重配置的适应度（P0 修复：注入权重到 EvalConfigManager）
    private func evaluateFitness(weights: EvalWeights) -> Double {
        // P0 修复：注入权重到全局共享实例，使 SelfPlayRunner 使用当前个体权重
        let previousWeights = EvalConfigManager.shared.weights
        EvalConfigManager.shared.setWeights(weights)
        
        // 运行自对弈
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: config.selfPlayDifficulty,
            black: config.selfPlayDifficulty,
            games: config.selfPlayGames
        )
        
        let result = runner.run(config: config)
        
        // P0 修复：评估完成后恢复上一轮最优权重（如果有），否则恢复默认权重
        if let best = bestIndividual {
            EvalConfigManager.shared.setWeights(best.toEvalWeights())
        } else {
            EvalConfigManager.shared.setWeights(previousWeights)
        }
        
        // 计算适应度：胜率 + Elo 估值
        let winRate = Double(result.redWins + result.draws) / Double(result.games.count)
        let eloDelta = BayesElo.estimateDelta(
            wins: result.redWins,
            losses: result.blackWins,
            draws: result.draws
        )
        
        // 适应度 = 胜率 * 100 + EloDelta（综合指标）
        let fitness = winRate * 100 + Double(eloDelta)
        
        return fitness
    }
    
    /// 进化种群（选择 + 交叉 + 变异）
    private func evolvePopulation() {
        // 1. 选择：按适应度排序，保留精英
        population.sort { $0.fitness > $1.fitness }
        let elites = population.prefix(config.eliteCount).map { $0 }
        
        // 2. 生成新种群
        var newPopulation: [CMAESIndividual] = elites.map { ind in
            var newInd = ind
            newInd.generation = generation + 1
            return newInd
        }
        
        // 3. 交叉 + 变异填充剩余个体
        while newPopulation.count < config.populationSize {
            // 选择父母（从精英池）
            let parent1 = elites.randomElement()!
            let parent2 = elites.randomElement()!
            
            // 交叉
            var childParams: [Double] = []
            for i in 0..<parent1.parameters.count {
                if Double.random(in: 0...1) < config.crossoverRate {
                    // 从父母随机选择
                    childParams.append(Double.random(in: 0...1) < 0.5 ? parent1.parameters[i] : parent2.parameters[i])
                } else {
                    // 平均值
                    childParams.append((parent1.parameters[i] + parent2.parameters[i]) / 2.0)
                }
            }
            
            // 变异
            for i in 0..<childParams.count {
                if Double.random(in: 0...1) < config.mutationRate {
                    childParams[i] += Double.random(in: -1...1) * config.mutationStrength * abs(childParams[i])
                }
            }
            
            let child = CMAESIndividual(parameters: childParams, generation: generation + 1)
            newPopulation.append(child)
        }
        
        population = newPopulation
    }
    
    // MARK: - 结果报告
    
    /// 生成进化报告
    func generateReport() -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        
        var report = """
        CMA-ES 进化结果
        
        ============================
        
        总代数：\(generation + 1)
        总评估次数：\(totalEvaluations)
        耗时：\(String(format: "%.1f", elapsed)) 秒
        
        最优适应度：\(String(format: "%.2f", bestIndividual?.fitness ?? 0))
        
        ============================
        
        进化历史：
        
        """
        
        for entry in history {
            report += "  第\(entry.generation)代：平均 \(String(format: "%.2f", entry.avgFitness)) | 最优 \(String(format: "%.2f", entry.bestFitness))\n"
        }
        
        if let best = bestIndividual {
            report += "\n最优参数：\n"
            let weights = best.toEvalWeights()
            report += weights.toJSON() ?? "(无法序列化)"
        }
        
        return report
    }
    
    /// 导出最优权重
    func exportBestWeights(to url: URL) -> Bool {
        guard let best = bestIndividual else { return false }
        let weights = best.toEvalWeights()
        return weights.save(to: url)
    }
}

// MARK: - 命令行入口

#if os(macOS)
/// 命令行 CMA-ES 入口
func runCMAESFromCLI() {
    let args = CommandLine.arguments
    
    guard args.count >= 3 else {
        print("""
        用法: ChineseChess --cmaes <种群大小> <最大代数> [每代评估局数]
        
        示例:
          ChineseChess --cmaes 20 100 20
        """)
        return
    }
    
    guard let popSize = Int(args[2]), popSize > 0 else {
        print("❌ 无效的种群大小: \(args[2])")
        return
    }
    guard let maxGen = Int(args[3]), maxGen > 0 else {
        print("❌ 无效的最大代数: \(args[3])")
        return
    }
    let gamesPerEval = args.count > 4 ? (Int(args[4]) ?? 20) : 20
    
    let config = CMAESConfig(
        populationSize: popSize,
        maxGenerations: maxGen,
        selfPlayGames: gamesPerEval
    )
    
    print("═══════════════════════════════════════════")
    print("  CMA-ES 自动调参")
    print("  种群: \(popSize) | 最大代数: \(maxGen) | 每代评估: \(gamesPerEval)局")
    print("═══════════════════════════════════════════")
    print("")
    
    let optimizer = CMAESOptimizer(config: config)
    
    let result = optimizer.run(progressCallback: { gen, avg, best in
        print("  [第\(gen)代] 平均适应度: \(String(format: "%.2f", avg)) | 最优: \(String(format: "%.2f", best))")
    })
    
    print("")
    print(optimizer.generateReport())
    
    // 导出最优权重
    let outputURL = URL(fileURLWithPath: "best_weights.json")
    if optimizer.exportBestWeights(to: outputURL) {
        print("\n最优权重已导出：\(outputURL.path)")
    }
}
#endif