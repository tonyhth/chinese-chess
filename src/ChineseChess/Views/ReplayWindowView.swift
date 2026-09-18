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
// 壳芯契约：analysisProvider 注入（AnalysisPresentationProvider protocol），
// C4a 默认 StubAnalysisPresentationProvider，C4b 替换实现类，本文件零改动。
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
@MainActor
final class ReplayWindowPayloadStore {
    static let shared = ReplayWindowPayloadStore()

    let container: ModelContainer?

    private init() {
        do {
            container = try ModelContainer(
                for: ReplayWindowPayload.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            assertionFailure("ReplayWindowPayloadStore 容器创建失败: \(error)")
            container = nil
        }
    }

    private var context: ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    func insert(uuidString: String, recordJSON: String) throws {
        guard let context else {
            throw CocoaError(.userActivityConnectionUnavailable)  // 容器不可用→调用侧 catch 走 sheet 降级
        }
        let payload = ReplayWindowPayload(uuidString: uuidString, recordJSON: recordJSON)
        context.insert(payload)
        try context.save()
    }

    func fetch(uuidString: String) -> ReplayWindowPayload? {
        guard let context else { return nil }
        let desc = FetchDescriptor<ReplayWindowPayload>(
            predicate: #Predicate { $0.uuidString == uuidString })
        return try? context.fetch(desc).first
    }

    func delete(uuidString: String) {
        guard let context else { return }
        if let payload = fetch(uuidString: uuidString) {
            context.delete(payload)
            try? context.save()
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

    /// 壳芯注入边界（C4a stub / C4b 替换实现）
    @State private var analysisProvider: AnalysisPresentationProvider = StubAnalysisPresentationProvider()

    // 控制条状态（复用 ReplayViewModel 语义，壳层自持轻量态）
    @State private var isPlaying = false
    @State private var playSpeed: Double = 1.0

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
        }
        .onDisappear {
            // 窗口关闭即清 SwiftData 中转件（一次性投递语义）
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
    private var controlBar: some View {
        HStack(spacing: LayoutSpec.space2) {
            // 壳期降级：prev/next/toLatest 空 action、play 无实效——统一禁用态防误判（Ruby P3-10；C4b 芯接入解禁）
            Button { } label: {
                Label(l10n.t("p9.shell.prev"), systemImage: "backward.frame")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(true)

            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(true)

            Button { } label: {
                Label(l10n.t("p9.shell.next"), systemImage: "forward.frame")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(true)

            Button { } label: {
                Label(l10n.t("p9.shell.toLatest"), systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(true)

            Spacer(minLength: 0)

            Menu {
                ForEach([0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { s in
                    Button(String(format: "%.1f×", s)) { playSpeed = s }
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
    private func analysisSidebar(record: GameRecord) -> some View {
        VStack(spacing: LayoutSpec.space2) {
            // 评估条（芯合入后接 eval 数据；壳期静态占位）
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.7), Color.primary.opacity(0.1)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .help(l10n.t("p9.shell.evalBarPending"))

            // 评估图表面板（芯域：评估曲线单组件复用含 mate 特判——C4b）
            pendingPanel(title: l10n.t("p9.shell.evalPanel"), icon: "chart.line.uptrend.xyaxis")

            // 走法列表（芯域：局面口径回跳——C4b）
            pendingPanel(title: l10n.t("p9.shell.movesPanel"), icon: "list.bullet.rectangle")

            // 分支树面板（芯域：变招三要素/top3——C4b）
            pendingPanel(title: l10n.t("p9.shell.branchPanel"), icon: "point.3.connected.trianglepath.dotted")

            Spacer(minLength: 0)
        }
        .padding(LayoutSpec.space2)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func pendingPanel(title: String, icon: String) -> some View {
        VStack(spacing: 0) {
            // 面板头（all14 .panel-h 语言：色签+标题）
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

            // 占位体：芯合入前显式降级（显示 stub 标注而非空白）
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
}
#endif  // os(macOS) P9 View 层平台门（SwiftData 投递层跨平台）
