import SwiftUI
import SwiftData

// MARK: - v6.4 C4a：P9 复盘独立窗口（壳层，洪涛 R3 拍板"一步到位独立窗口"）
//
// 布局骨架（all14 P9 原型 + 设计单 §3.5）：
// - 窗口 760×820 起步可最大化（LayoutSpec.p9Window*）
// - 顶部控制条 = 对局页语言移植（上一步/播放/下一步/回到最新/调速——all14 P9 控制条五行）
// - 主区：棋盘 flex:3 + 分析侧 flex:1（min-width 190，25% 带下限 LayoutSpec.p9AnalysisMinWidth）
// - 分析侧占位容器：评估条 + 评估图表面板 + 走法列表 + 分支树面板（SwiftUI 占位，
//   芯=C4b Cody 域灌入）
//
// 壳芯契约：C4a 期 stub 注入 → C4b 件1 切真芯（analysisVM = AnalysisViewModel，
// 其 extension conformance 即 AnalysisPresentationProvider；.task 驱动 load/analyzeAll，
// recordId 透传启用 sidecar 持久化）。壳零依赖芯实现类——只持 VM 公共面。
// LAYOUT_DUMP：page=P9（窗口宽 + 分析侧带宽比），参数名只增不改。

/// P9 窗口投递中转件（SwiftData）：openWindow 只能传简单值（UUID 字符串经环境），
/// GameRecord 经本中转件按 uuid 检索（窗口独立 scene 无法直接持有 @State 引用）
@Model
final class ReplayWindowPayload {
    @Attribute(.unique) var uuidString: String
    var recordJSON: String
    var createdAt: Date

    init(uuidString: String, recordJSON: String, createdAt: Date = .now) {
        self.uuidString = uuidString
        self.recordJSON = recordJSON
        self.createdAt = createdAt
    }
}

/// 主窗→P9 窗口的投递 ID 环境键（openWindow(value:) 传 uuid 字符串）
private struct ReplayWindowPayloadIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// openWindow(value:) 注入的当前投递 uuid（nil = 非窗口投递上下文）
    var replayWindowPayloadID: String? {
        get { self[ReplayWindowPayloadIDKey.self] }
        set { self[ReplayWindowPayloadIDKey.self] = newValue }
    }
}

// MARK: - P9 投递中转 store（主窗写 / P9 窗读，SwiftData 隔离容器）

/// GameRecord 跨 scene 投递：主窗 insert(uuid, json) → P9 窗按 uuid fetch → 关窗即删。
/// 独立 ModelContainer（仅 ReplayWindowPayload 一表），不与主数据域混容器。
/// P2-5：瞬态投递队列——isStoredInMemoryOnly（同进程跨 scene 无需落盘，无孤儿行/免启动 GC）；
/// 容器失败降级 nil（scene 侧 modelContainer(nil) 无副作用），不再 fatalError 炸启动路径。
/// R2（P2-5 缺陷修复）：**单一长寿命 ModelContext**——原实现 context 为计算属性，
/// 每次访问新建上下文，delete() 跨上下文删除 SwiftData 静默无效 + try? 吞错，
/// 关窗清投递为哑操作（载荷内存累积）。@MainActor 单例单线程，三方法同源 context 一次根治。
@MainActor
final class ReplayWindowPayloadStore {
    static let shared = ReplayWindowPayloadStore()

    let container: ModelContainer?

    /// 长寿命单一 context：insert/fetch/delete 同源，跨上下文操作不再可能
    private let context: ModelContext?

    private init() {
        do {
            let c = try ModelContainer(
                for: ReplayWindowPayload.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            container = c
            context = ModelContext(c)
        } catch {
            assertionFailure("ReplayWindowPayloadStore 容器创建失败: \(error)")
            container = nil
            context = nil
        }
    }

    func insert(uuidString: String, recordJSON: String) throws {
        guard let context else {
            throw CocoaError(.userActivityConnectionUnavailable)  // 容器不可用→调用侧 catch 走 sheet 降级
        }
        let payload = ReplayWindowPayload(uuidString: uuidString, recordJSON: recordJSON)
        context.insert(payload)
        try context.save()   // insert 语义保持 throws（调用点走 sheet 降级路径）
    }

    func fetch(uuidString: String) -> ReplayWindowPayload? {
        guard let context else { return nil }
        let desc = FetchDescriptor<ReplayWindowPayload>(
            predicate: #Predicate { $0.uuidString == uuidString })
        return try? context.fetch(desc).first   // 读路径保持宽容语义（既有绿路径不破坏）
    }

    func delete(uuidString: String) {
        // R2：fetch 与 delete 同一长寿命 context——payload 注册本上下文，删除必然生效
        guard let context, let payload = fetch(uuidString: uuidString) else { return }
        context.delete(payload)
        do {
            try context.save()   // 显式处理，禁 try? 吞错（一次性投递语义的落库点）
        } catch {
            assertionFailure("P9 投递删除落库失败（一次性投递语义破坏）: \(error)")
        }
    }
}

// P9 独立窗口：macOS-only scene（iOS 无多窗口语义）——仅 View 层平台门；
// SwiftData/@Model 投递层保持跨平台（Ruby 13:21 修正：勿一刀切锁全文件）
#if os(macOS)
struct ReplayWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.replayWindowPayloadID) private var replayWindowPayloadID

    @State private var record: GameRecord? = nil
    /// P3-9：投递解码失败标记——与"空投递"空态可区分
    @State private var deliveryCorrupt = false

    /// 壳芯注入边界（C4a stub → C4b 真芯切换）
    // C4b 件1：真芯接入——AnalysisViewModel 自 8bc26cf+e0e3b06 已实现
    // AnalysisPresentationProvider conformance（extension），壳直接持有 VM 即持 provider。
    // 不经 Cody 工作区态的 ReplayAnalysisAdapter（未提交，时序解耦）：壳持 VM +
    // .task 驱动 load/analyzeAll（AnalysisView.startAnalysis 同款口径），provider
    // 语义 = vm 自身。芯未就绪段（引擎不可用）vm 查询自然返回空/nil，壳走既有
    // 降级形态（pendingPanel 保留），无需 stub 兜底对象。
    @State private var analysisVM: AnalysisViewModel? = nil

    // 回放驱动（真芯接入后步进/跳转需驱动棋盘与走法列表同步；C4a 壳期四钮
    // 禁用解禁的宿主）
    @State private var currentIndex = 0

    // 控制条状态（复用 ReplayViewModel 语义，壳层自持轻量态）
    @State private var isPlaying = false
    @State private var playSpeed: Double = 1.0
    /// 自动播放定时器句柄（speed 档映射间隔；关窗/暂停即止）
    @State private var playTask: Task<Void, Never>? = nil

    private let l10n = L10n.shared

    var body: some View {
        Group {
            if let record {
                shellBody(record: record)
            } else {
                ContentUnavailableView(
                    deliveryCorrupt ? l10n.t("p9.shell.corrupt") : l10n.t("p9.shell.empty"),
                    systemImage: deliveryCorrupt ? "exclamationmark.triangle" : "rectangle.on.rectangle.slash"
                )
            }
        }
        .frame(minWidth: LayoutSpec.p9WindowMinWidth,
               idealWidth: LayoutSpec.p9WindowMinWidth,
               minHeight: LayoutSpec.p9WindowMinHeight,
               idealHeight: LayoutSpec.p9WindowMinHeight)
        .task {
            guard record == nil, let pid = replayWindowPayloadID else { return }
            // P3-9：投递竞态重试一次（主窗 insert 与窗口启动并行）；解码失败与空投递分态
            if !fetchDelivered(pid: pid) {
                try? await Task.sleep(nanoseconds: 200_000_000)
                _ = fetchDelivered(pid: pid)
            }
            // C4b 件1：真芯启动——投递落地即拉起分析（AnalysisView.startAnalysis 同款口径：
            // load(moves/initialFEN/gameMoves/recordId) + analyzeAll；recordId 透传启用
            // sidecar 持久化，二次打开 0 引擎调用）。VM 即 provider（extension conformance）。
            if let rec = record {
                let vm = AnalysisViewModel()
                analysisVM = vm
                let gameMoves = rec.moves
                let fen = rec.initialFEN ?? FENParser.standardInitial
                vm.load(moves: gameMoves.uciMoves, initialFEN: fen,
                        gameMoves: gameMoves,
                        playerColorOverride: p9PlayerColor(for: rec),
                        recordId: rec.id)
                await vm.analyzeAll()
            }
        }
        .onDisappear {
            // 窗口关闭即清 SwiftData 中转件（一次性投递语义）+ 停播放定时器
            stopAutoPlay()
            if let pid = replayWindowPayloadID {
                ReplayWindowPayloadStore.shared.delete(uuidString: pid)
            }
        }
    }

    // MARK: - 骨架

    private func shellBody(record: GameRecord) -> some View {
        VStack(spacing: 0) {
            windowHeader(record: record)
            controlBar
            Divider()
            mainArea(record: record)
        }
        .background(Color.controlBackground)
    }

    /// 窗口头（all14 .wh 语义：标题 + 局信息）
    private func windowHeader(record: GameRecord) -> some View {
        HStack(spacing: LayoutSpec.space2) {
            SourceBadgeView(source: record.source, showLabel: false)
                .font(.caption2)
            Text(record.title)
                .font(.system(size: LayoutSpec.fontSizeBody, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(record.title)   // LJ-1 三件套
            Text("\(record.redPlayer.name) vs \(record.blackPlayer.name)")
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help("\(record.redPlayer.name) vs \(record.blackPlayer.name)")
            Spacer(minLength: 0)
            Text(l10n.t("p9.shell.windowBadge"))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, LayoutSpec.space3)
        .padding(.vertical, LayoutSpec.space2)
    }

    /// 控制条 = 对局页语言移植（all14 P9：上一步/播放/下一步/回到最新/调速）
    /// C4b 件1：四钮解禁（真芯在位 + currentIndex 驱动）；record 未落地仍禁用（空窗态防误触）
    private var controlsReady: Bool { record != nil }

    private var controlBar: some View {
        HStack(spacing: LayoutSpec.space2) {
            Button { step(-1) } label: {
                Label(l10n.t("p9.shell.prev"), systemImage: "backward.frame")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!controlsReady || currentIndex == 0)

            Button { toggleAutoPlay() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!controlsReady || currentIndex >= (record?.moves.count ?? 0))

            Button { step(1) } label: {
                Label(l10n.t("p9.shell.next"), systemImage: "forward.frame")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!controlsReady || currentIndex >= (record?.moves.count ?? 0))

            Button { jumpTo((record?.moves.count ?? 1) - 1) } label: {
                Label(l10n.t("p9.shell.toLatest"), systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!controlsReady)

            Spacer(minLength: 0)

            Menu {
                ForEach([0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { s in
                    Button(String(format: "%.1f×", s)) {
                        playSpeed = s
                        if isPlaying { restartAutoPlay() }   // 播放中调速即时生效
                    }
                }
            } label: {
                Text(String(format: "%.1f×", playSpeed))
                    .monospacedDigit()
            }
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, LayoutSpec.space3)
        .padding(.vertical, LayoutSpec.space2)
        .background(.bar)
    }

    // MARK: - C4b 件1：步进/跳转/自动播放（驱动走法列表 + 分析面板的 k 联动）

    private func step(_ delta: Int) {
        jumpTo(currentIndex + delta)
    }

    private func jumpTo(_ index: Int) {
        guard let rec = record else { return }
        let clamped = min(max(index, 0), rec.moves.count)
        if clamped != currentIndex { currentIndex = clamped }
    }

    private func toggleAutoPlay() {
        if isPlaying { stopAutoPlay() } else { restartAutoPlay() }
    }

    private func restartAutoPlay() {
        stopAutoPlay()
        guard let rec = record, currentIndex < rec.moves.count else { return }
        isPlaying = true
        // 间隔 = 基准 1.2s / speed；末步自然停（isPlaying 落 false）
        playTask = Task { @MainActor in
            while !Task.isCancelled, currentIndex < rec.moves.count {
                try? await Task.sleep(nanoseconds: UInt64(1_200_000_000 / max(playSpeed, 0.1)))
                guard !Task.isCancelled else { return }
                if currentIndex < rec.moves.count {
                    currentIndex += 1
                }
                if currentIndex >= rec.moves.count { break }
            }
            if !Task.isCancelled { isPlaying = false }
        }
    }

    private func stopAutoPlay() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }

    /// 主区：棋盘 flex:3 + 分析侧 flex:1 = 25% 带（min-width 190 下限，all14 比例语义）
    private func mainArea(record: GameRecord) -> some View {
        GeometryReader { geo in
            let analysisW = max(geo.size.width * LayoutSpec.p9AnalysisMinRatio,
                                LayoutSpec.p9AnalysisMinWidth)
            HStack(spacing: 0) {
            // 棋盘区（复用既有 ReplayBoardView 需 ReplayViewModel——C4a 壳期先占位容器，
            // C4b 芯合入时接入；占位显式标注，非静默零渲染（原则六b））
            boardPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

                // 分析侧（flex:1 = 25% 带，190 下限）
                analysisSidebar(record: record)
                    .frame(width: analysisW)
                    .frame(maxHeight: .infinity)
                    // LAYOUT_DUMP：侧栏实宽采样（验收锚 ≥25%，实测非推算）
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .onAppear { dumpRatio(measured: g.size.width, total: geo.size.width) }
                                .onChange(of: g.size.width) { _, w in
                                    dumpRatio(measured: w, total: geo.size.width)
                                }
                        }
                    )
            }
        }
        .padding(LayoutSpec.space3)
    }

    /// P3-9：单次投递拉取——false=暂无投递（可重试），true=终态（成功或解码失败已分态标记）
    private func fetchDelivered(pid: String) -> Bool {
        guard let payload = ReplayWindowPayloadStore.shared.fetch(uuidString: pid) else { return false }
        guard let data = payload.recordJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(GameRecord.self, from: data) else {
            deliveryCorrupt = true
            return true
        }
        record = decoded
        return true
    }

    private func dumpRatio(measured: CGFloat, total: CGFloat) {
        guard LayoutDump.isEnabled else { return }
        let ratio = total > 0 ? measured / total : 0
        LayoutDump.sample(
            page: "P9", width: total,
            params: [
                "analysisMeasured": String(Int(measured)),
                "analysisMin": String(Int(LayoutSpec.p9AnalysisMinWidth)),
                "ratioFloor": String(format: "%.2f", LayoutSpec.p9AnalysisMinRatio),
                "actual": String(format: "%.2f", ratio),
            ])
    }

    // MARK: - 占位容器（芯合入前的显式降级形态）

    /// 棋盘占位：显式标注"芯合入后接入"，非静默零渲染（LJ-3/ui-debt 案③纪律）
    private var boardPlaceholder: some View {
        VStack(spacing: LayoutSpec.space2) {
            Image(systemName: "checkerboard.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text(l10n.t("p9.shell.boardPending"))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 分析侧骨架（all14 P9 右列）：评估条 + 评估图 + 走法列表 + 分支树
    /// C4b 件1：三面板真数据化（provider = analysisVM；布局语言不变，pendingPanel
    /// 保留为芯未就绪段的显式降级形态——引擎不可用/分析中面板内轻提示）
    private func analysisSidebar(record: GameRecord) -> some View {
        VStack(spacing: LayoutSpec.space2) {
            // 评估条：当前 k 的最新评估（analyses[k-1]?.playerEval，红方视角 cp）
            evalBar

            // 评估曲线（芯域数据：MoveAnalysis 序列 playerEval 折线）
            evalChartPanel

            // 走法列表（真芯：全谱双列 + 当前步高亮 + 点击跳转；质量徽章玩家着）
            movesPanel(record: record)

            // 分支树（真芯：当前局面 k 的 top3 变招，variations）
            branchPanel
        }
        .padding(LayoutSpec.space2)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 评估条/曲线（C4b 件1；cp 红方视角，与 Variation.cpAfter 同口径）

    /// 当前局面评估（红方视角 cp；未分析段 nil → 中性条）
    private var currentEvalCp: Int? {
        guard let vm = analysisVM, currentIndex >= 1, currentIndex <= vm.analyses.count else { return nil }
        return vm.analyses[currentIndex - 1]?.playerEval
    }

    /// 评估条：cp → 红方优势占比（±600cp 饱和；mate 域暂以饱和呈现，芯域曲线组件
    /// 合入后接 EvalChartScale mate 特判——C4b Cody 侧交付件，本条为轻量速览）
    private var evalBar: some View {
        let ratio: Double = {
            guard let cp = currentEvalCp else { return 0.5 }
            let clamped = max(-600, min(600, Double(cp)))
            return (clamped + 600) / 1200
        }()
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Color.red.opacity(0.75))
                    .frame(width: max(6, g.size.width * ratio))
            }
        }
        .frame(height: 10)
        .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .help(evalBarHelp)
    }

    private var evalBarHelp: String {
        guard let cp = currentEvalCp else { return l10n.t("p9.shell.evalBarPending") }
        let sign = cp > 0 ? "+" : ""
        return "eval \(sign)\(cp)cp"   // 单语技术面（Debug 速览语义，help tooltip 面向键盘用户）
    }

    /// 评估曲线面板：已分析着的 playerEval 折线（Swift 原生 Path，无三方依赖；
    /// 当前 k 竖标线；芯域 EvalChartScale mate 特判合入后替换纵轴映射——接口面不变）
    private var evalChartPanel: some View {
        panelShell(title: l10n.t("p9.shell.evalPanel"), icon: "chart.line.uptrend.xyaxis") {
            if let vm = analysisVM, vm.analyses.contains(where: { $0 != nil }) {
                EvalSparkline(analyses: vm.analyses,
                              currentIndex: currentIndex)
                    .frame(height: 72)
            } else if let vm = analysisVM, vm.isAnalyzing {
                analyzingHint
            } else {
                pendingBody   // 芯未就绪（引擎不可用/未启动）显式降级
            }
        }
    }

    /// 走法列表面板（真芯：全谱回合双列；当前步高亮金带；点击跳转 k；
    /// 玩家着带质量色点——AnalysisView moveQualityBadge 同语言，AI 着灰）
    private func movesPanel(record: GameRecord) -> some View {
        panelShell(title: l10n.t("p9.shell.movesPanel"), icon: "list.bullet.rectangle") {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        let rounds = Dictionary(grouping: record.moves.indices, by: { record.moves[$0].turnNumber })
                        ForEach(rounds.keys.sorted(), id: \.self) { roundNo in
                            let idxs = (rounds[roundNo] ?? []).sorted()
                            HStack(spacing: LayoutSpec.space1) {
                                Text("\(roundNo).")
                                    .font(.system(size: LayoutSpec.fontSizeCaption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .leading)
                                ForEach(idxs, id: \.self) { i in
                                    moveRow(i: i)
                                }
                            }
                            .id(roundNo)
                            .padding(.horizontal, LayoutSpec.space1)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(roundNo == record.moves.indices.last.map({ record.moves[$0].turnNumber }) && currentIndex == record.moves.count
                                          ? Color.yellow.opacity(0.18) : Color.clear)
                            )
                        }
                    }
                    .padding(.vertical, LayoutSpec.space1)
                }
                .onChange(of: currentIndex) { _, k in
                    if k >= 1, k <= record.moves.count {
                        withAnimation { proxy.scrollTo(record.moves[k - 1].turnNumber, anchor: .center) }
                    }
                }
            }
        }
    }

    /// 单着行：记谱 + 质量点（玩家着 AnalysisView 徽章同语言；当前 k 着金框）
    @ViewBuilder
    private func moveRow(i: Int) -> some View {
        let isCurrent = (currentIndex == i + 1)
        let analysis: MoveAnalysis? = {
            guard let vm = analysisVM, i >= 0, i < vm.analyses.count else { return nil }
            return vm.analyses[i] ?? nil
        }()
        HStack(spacing: 3) {
            if let a = analysis {
                Circle()
                    .fill(qualityColor(a.quality))
                    .frame(width: 5, height: 5)
            } else if let vm = analysisVM, i < vm.moves.count, !vm.isPlayerMove(at: i) {
                Text("AI")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
            }
            Text(record.map({ i < $0.moves.count ? $0.moves[i].notation : "" }) ?? "")
                .font(.system(size: LayoutSpec.fontSizeBody, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCurrent ? Color.yellow.opacity(0.25) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { jumpTo(i + 1) }
        // 三要素小卡（同 AnalysisView contextMenu 语言：实际/推荐/亏损）
        .contextMenu {
            if let review = analysisVM?.moveReview(atMove: i) {
                Text("\(l10n.t("p1.rail.review.played"))：\(review.played)")
                Text("\(l10n.t("p1.rail.review.best"))：\(review.recommended)")
                Text(String(format: l10n.t("analysis.lossCp"), review.lossCp))
            } else {
                Text(l10n.t("analysis.noReviewData"))
            }
        }
    }

    /// 质量色（AnalysisView qualityColor 同表——单一语言，双窗一致）
    private func qualityColor(_ q: MoveQuality) -> Color {
        switch q {
        case .brilliant: return .green
        case .good:      return .blue
        case .normal:    return .gray
        case .doubtful:  return .yellow
        case .blunder:   return .orange
        case .losing:    return .red
        }
    }

    /// 分支树面板（真芯：当前局面 k 的 top3——rank/中文着法/cpAfter）
    private var branchPanel: some View {
        panelShell(title: l10n.t("p9.shell.branchPanel"), icon: "point.3.connected.trianglepath.dotted") {
            if let vm = analysisVM {
                let vars = vm.variations(atPosition: currentIndex)
                if vars.isEmpty {
                    // 降级链（v1.1 §3.5）：k=0/未分析段/AI 着后——统一轻提示
                    VStack(spacing: LayoutSpec.space1) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: LayoutSpec.fontSizeCaption))
                            .foregroundStyle(.tertiary)
                        Text(l10n.t(currentIndex == 0 ? "analysis.noVariationPosition" : "analysis.noVariations"))
                            .font(.system(size: LayoutSpec.fontSizeCaption))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(LayoutSpec.space2)
                } else {
                    VStack(spacing: LayoutSpec.space1) {
                        ForEach(vars, id: \.rank) { v in
                            HStack(spacing: LayoutSpec.space1) {
                                Text("\(v.rank).")
                                    .font(.system(size: LayoutSpec.fontSizeCaption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(v.sanZh)
                                    .font(.system(size: LayoutSpec.fontSizeBody, weight: .medium))
                                Spacer(minLength: 0)
                                Text("\(v.cpAfter > 0 ? "+" : "")\(v.cpAfter)")
                                    .font(.system(size: LayoutSpec.fontSizeCaption, design: .monospaced))
                                    .foregroundStyle(v.cpAfter >= 0 ? .red : .secondary)
                            }
                            .padding(.horizontal, LayoutSpec.space1)
                        }
                    }
                    .padding(.vertical, LayoutSpec.space1)
                }
            } else {
                pendingBody
            }
        }
    }

    /// 分析中轻提示（面板内嵌，不弹窗不打扰）
    private var analyzingHint: some View {
        HStack(spacing: LayoutSpec.space2) {
            ProgressView().controlSize(.small)
            Text(l10n.t("analysis.analyzingPlayerMoves"))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(LayoutSpec.space2)
    }

    /// 芯未就绪段占位体（原 pendingPanel 体内芯，保留显式降级形态）
    private var pendingBody: some View {
        HStack(spacing: LayoutSpec.space1) {
            Image(systemName: "hourglass")
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.tertiary)
            Text(l10n.t("p9.shell.corePending"))
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(LayoutSpec.space2)
    }

    /// 面板容器（C4a pendingPanel 头部语言保留：色签+标题+图标；体内芯真数据化）
    private func panelShell<Body: View>(title: String, icon: String,
                                        @ViewBuilder content: () -> Body) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: LayoutSpec.space2) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 14)
                Text(title)
                    .font(.system(size: LayoutSpec.fontSizeBody))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, LayoutSpec.space2)
            .padding(.vertical, LayoutSpec.space1)

            Divider()
            content()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .fill(Color.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius))
    }

    // MARK: - C4b 件1：playerColor 推断（P9 无"玩家"概念——人执哪方哪方是玩家）

    /// .load 的 playerColorOverride 注入（public 参数，非 protocol 改动）：
    /// 人执红 → .red；人执黑 → .black；双 AI / 双人 → 先手方口径（对局页语义，
    /// isPlayerMove 退化为先手方着——徽章/分析照常，"玩家着"语义按先手方解释）
    private func p9PlayerColor(for rec: GameRecord) -> Side? {
        let redAI = rec.redPlayer.isAI, blackAI = rec.blackPlayer.isAI
        if !redAI && blackAI { return .red }
        if redAI && !blackAI { return .black }
        return nil   // nil = VM 内默认先手方
    }
}

// MARK: - 评估曲线 sparkline（C4b 件1：MoveAnalysis 序列 → 折线 + 当前步标线）

/// 已分析着的 playerEval 折线（红方视角 cp；±600 饱和映射，缺口跳线处理 nil 段；
/// mate 特判由芯域 EvalChartScale 合入后接管——本组件纵轴映射预留替换点）
private struct EvalSparkline: View {
    let analyses: [MoveAnalysis?]
    let currentIndex: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(analyses.count - 1, 1)
            let y: (Int?) -> CGFloat = { cp in
                let v = cp.map { max(-600, min(600, $0)) } ?? 0
                return h / 2 - CGFloat(v) / 1200 * h
            }
            ZStack {
                // 中线（均势）
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)

                // 评估折线（nil 段断线：跳到下一点重起）
                Path { p in
                    var penDown = false
                    for (i, a) in analyses.enumerated() {
                        let x = CGFloat(i) / CGFloat(n) * w
                        let pt = CGPoint(x: x, y: y(a?.playerEval))
                        if a != nil {
                            if penDown { p.addLine(to: pt) } else { p.move(to: pt); penDown = true }
                        } else {
                            penDown = false
                        }
                    }
                }
                .stroke(Color.red.opacity(0.8), lineWidth: 1.5)

                // 当前步竖标线
                if currentIndex >= 1, currentIndex <= analyses.count {
                    let x = CGFloat(currentIndex - 1) / CGFloat(n) * w
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
        }
    }
}
#endif  // os(macOS) P9 View 层平台门（SwiftData 投递层跨平台）
