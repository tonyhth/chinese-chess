#if os(macOS)
import SwiftUI
import AppKit
import SwiftData

// macOS 退出钩子兜底：scenePhase 在 macOS 上不保证触发
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // v6.4 C0：截图 harness 骨架——LAYOUT_WIDTH 启动参数钉窗口宽（五档锚图 900/1000/1080/1280/1920）
        // 与 LAYOUT_DUMP 对偶：harness 设宽 → 采样流断言。仅 macOS，产品路径不受影响。
        // v6.4 C3-3：env 优先、文件桥兜底（open -a 通道 env 丢失；桥= /tmp/v64c2-layout-harness.json）
        #if DEBUG
        let bridge = LayoutDump.bridgeParams
        let widthStr = ProcessInfo.processInfo.environment["LAYOUT_WIDTH"] ?? bridge?["width"]
        if let wStr = widthStr, let w = Double(wStr), w >= 900 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for window in NSApplication.shared.windows where window.identifier?.rawValue != "ABPOverlay" {
                    var frame = window.frame
                    frame.origin.x = max(40, frame.origin.x)
                    frame.size.width = w
                    window.setFrame(frame, display: true, animate: false)
                }
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 同步紧急关闭引擎，不走 actor isolation 避免 MainActor 死锁
        EngineRouter.shared.emergencyShutdown()
    }
}

@main
struct ChineseChessApp: App {
    init() {
        // v3.0: 命令行自对弈模式（CLI-only，非用户路径）
        #if os(macOS)
        let args = CommandLine.arguments
        if args.count >= 2 && args[1] == "--selfplay" {
            Task.detached {
                await runSelfPlayFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            // 不应到达此处
            fatalError("selfplay CLI should have exited")
        }
        // v6.0 Phase 6: 交叉对弈校准 CLI
        if args.count >= 2 && args[1] == "--calibrate" {
            Task.detached {
                await runCalibrateFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("calibrate CLI should have exited")
        }
        // P4-③ C 项：双轨配对 CLI（校准主信号 harness，p34 v1.1 §2 C）
        if args.count >= 2 && args[1] == "--paired" {
            Task.detached {
                await runPairedFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("paired CLI should have exited")
        }
        // P5（Luke 08-19 合并单）：配对显式参数口径（A 档 CLI 注入，非 env）
        if args.count >= 2 && args[1] == "--paired-qs-full" {
            Task.detached {
                await runPairedQSFullFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("paired-qs-full CLI should have exited")
        }
        // P5（Luke 08-19 合并单）：单步引擎服务（stdin FEN+难度 / stdout ICCS，Tina python driver 用）
        if args.count >= 2 && args[1] == "--engine-server" {
            Task.detached {
                await runEngineServerFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("engine-server CLI should have exited")
        }
        // v6.0: 纯 Pikafish 自对弈梯度验证
        if args.count >= 2 && args[1] == "--pfmatch" {
            Task.detached {
                await runPikafishMatchFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("pfmatch CLI should have exited")
        }
        // 校准 v3.0: 自研内部对弈
        if args.count >= 2 && args[1] == "--calibrate-native" {
            Task.detached {
                await runCalibrateNativeFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("calibrate-native CLI should have exited")
        }
        // 校准 v3.0: Pikafish 内部对弈
        if args.count >= 2 && args[1] == "--calibrate-pf" {
            Task.detached {
                await runCalibratePfFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("calibrate-pf CLI should have exited")
        }
        // v3.1: CMA-ES 自动调参模式（CLI-only，非用户路径）
        if args.count >= 2 && args[1] == "--cmaes" {
            Task.detached {
                await runCMAESFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("cmaes CLI should have exited")
        }
        #endif

        // v3.7.1 fix: 迁移旧 Bundle ID 的偏好数据
        // 必须在所有读取 UserDefaults 的逻辑之前执行
        PreferencesMigration.migrateIfNeeded()

        FontRegistry.registerFonts()

        // P2: 一次性清理 bonus 脏数据（dailyStreak=0 但 bonusSpecialTheme=true 不可能）
        if !UserDefaults.standard.bool(forKey: "chinesechess.bonusDataCleaned_v1") {
            let store = PlayerProfileStore.shared
            let profile = store.profile
            if profile.dailyStreak == 0 && profile.bonusSpecialTheme {
                _ = store.update { p in
                    p.bonusSpecialTheme = false
                    p.bonusPuzzlesUnlocked = false
                    p.bonusMasterNoPenalty = false
                    p.bonusChapter7EarlyUnlock = false
                    p.bonusDoubleScore = false
                    p.bonusPieceStyle = false
                    p.bonusExtraHints = 0
                }
            }
            UserDefaults.standard.set(true, forKey: "chinesechess.bonusDataCleaned_v1")
        }

        // v3.7.0 Phase 4: UserDefaults 历史数据迁移到 JSON 文件
        DataMigration.migrateGameHistoryToFiles()

        // P0-1 fix: 首次启动引导标志读取（在 onAppear 中触发弹窗）
        _firstLaunchNeeded = State(initialValue: !UserDefaults.standard.bool(forKey: "chinesechess.firstLaunchDialogShown"))
    }

    // v3.7.1 P0: 统一 sheet 管理 — 解决多 .sheet 串联导致 sheet 弹不出的 bug
    enum SheetDestination: Identifiable {
        case record
        case stats
        case puzzles
        case themePicker
        case history
        case settings
        case dailyChallenge
        case achievements
        case rankPrivilege
        case rankUp(Rank)
        case toolbarReplay(GameRecord)
        case historyReplay(GameRecord)

        // ✅ v3.7.2: 新增 3 个 UI 入口
        case analysis(GameRecord)
        case coach(GameRecord)
        case studyHub
        case tutorial
        case openingExplorer   // FINAL-003: ⌘⇧O 快捷键入口
        #if DEBUG
        #endif

        var id: String {
            switch self {
            case .record: return "record"
            case .stats: return "stats"
            case .puzzles: return "puzzles"
            case .themePicker: return "themePicker"
            case .history: return "history"
            case .settings: return "settings"
            case .dailyChallenge: return "dailyChallenge"
            case .achievements: return "achievements"
            case .rankPrivilege: return "rankPrivilege"
            case .rankUp: return "rankUp"
            case .toolbarReplay: return "toolbarReplay"
            case .historyReplay: return "historyReplay"
            case .analysis: return "analysis"
            case .coach: return "coach"
            case .studyHub: return "studyHub"
            case .tutorial: return "tutorial"
            case .openingExplorer: return "openingExplorer"
            }
        }
    }

    @State private var activeSheet: SheetDestination?

    @State private var viewModel = GameViewModel()
    @State private var showImportFailAlert = false
    @State private var importFailMessage = ""
    @State private var rankUpRank: Rank?
    @State private var showFirstLaunchDialog = false
    @State private var firstLaunchNeeded = false

    // v3.7.2 Phase 4: 对弈结束复盘卡片
    @State private var showReviewCard = false
    @State private var reviewCardRecord: GameRecord?
    @State private var reviewCardData: GameReviewCard?
    @State private var pendingReviewRecord: GameRecord?  // RankUpView dismiss 后检查

    // v6.4 C0：对局页右通栏自适应状态机（迟滞 <1000 收 / >1080 展）
    @State private var railState = AdaptiveRailState()

    // v6.4 C4a：P9 复盘独立窗口
    @Environment(\.openWindow) private var openWindow
    /// P9 窗口投递中转（mainActor 隔离；uuid 传窗，GameRecord 走 SwiftData 检索）
    @MainActor private let replayPayloadStore = ReplayWindowPayloadStore.shared

    /// 打开 P9 独立窗口（GameRecord → JSON → SwiftData → openWindow(uuid)）
    @MainActor
    private func openReplayWindow() {
        guard let record = viewModel.buildGameRecord(), !record.moves.isEmpty else { return }
        let uuid = UUID().uuidString
        do {
            let data = try JSONEncoder().encode(record)
            guard let json = String(data: data, encoding: .utf8) else {
                // P3-8：编码降级不再静默 return，统一入 catch 走 sheet 回退（与 catch 对称）
                // C4b 件3：原借 CocoaError(.fileReadNoPermission)——语义借用（既无文件也无权限
                // 问题，误导日志归因）；utf8 编码失败属"输入值不可转化"语义，改近义码
                // .coderInvalidValue（仍走同一 catch 面回退 sheet，行为零变更）
                throw CocoaError(.coderInvalidValue)
            }
            try replayPayloadStore.insert(uuidString: uuid, recordJSON: json)
            openWindow(id: "replayWindow", value: uuid)
        } catch {
            // 投递失败回退旧 sheet 通道（降级不断链）
            // 分型注释（C4b 件3）：①编码失败（coderInvalidValue，JSONEncoder 罕见路径）
            // ②insert 抛错（userActivityConnectionUnavailable，容器不可用）③两者均降级 sheet
            activeSheet = .toolbarReplay(record)
        }
    }

    /// v6.4 P1 修复（09-06 返工单①）：harness 全窗替换——原 .harnessPlay sheet 呈现
    /// 在 resize sweep 下自发 dismiss（两轮独立复现，第二轮主窗口呈活跃对局态）。
    /// 触发机制属 sheet×窗口 resize 交互族（运行时未定谳，待 Tina 窗口批复跑定位），
    /// 结构性修复对任意触发免疫：无 sheet、无挂载重试 Task、主窗 UI（含迟滞状态机）
    /// 在 harness 会话中不存在。mode 进程内一次解析（env 优先、桥文件兜底——采集
    /// 脚本在起跑前写妥；运行中改桥文件不生效=有意为之，保证 harness 面 identity 恒定）。
    static let harnessPlayMode: String? = {
        #if DEBUG
        let envPlay = ProcessInfo.processInfo.environment["LAYOUT_PLAY"]
        let bridgePlay = LayoutDump.bridgeParams?["play"]
        guard let play = envPlay ?? bridgePlay,
              ["master", "puzzle", "p13", "p7", "p2", "p2more", "p5"].contains(play) else { return nil }
        return play
        #else
        return nil  // 产品路径（Release）恒不走 harness——与原 onAppear 入口 #if DEBUG 门语义一致
        #endif
    }()

    /// harness 全窗根（原 sheet case 迁移；frame/ready 采样语义逐行保留）
    @ViewBuilder
    private func harnessRoot(mode: String) -> some View {
        Group {
            if mode == "master" {
                NavigationStack { MasterGameBrowserView() }
            } else if mode == "p2" || mode == "p2more" {
                // v6.4 C3-4：P2 浏览态锚图（不触发 autoEnterPlay——那是 master=播放态通道）
                // p2more：P0-1 修复自测通道（player:more 扩容分支可达性验证）
                NavigationStack { MasterGameBrowserView() }
            } else if mode == "p5" {
                // v6.4 C3-5：P5 学棋中心锚图（hero 卡 + 卡片栅格）
                NavigationStack { StudyHubView() }
            } else if mode == "p13" {
                // v6.4 C3：P13 残局列表锚图采集（无章节 = 全部残局池）
                NavigationStack { PuzzleSelectView() }
            } else if mode == "p7" {
                // v6.4 C3-3：P7 开局教练选择锚图采集
                NavigationStack { OpeningCoachSelectView() }
            } else {
                NavigationStack { PuzzleDemoView() }
            }
        }
        // v6.4 C2 语义保留：迟滞状态机测的是 harness 面宽（LAYOUT_WIDTH 钉窗），
        // 全窗替换后直接测窗口真宽，消除 f5bf81c 注记的 sheet 溢出屏缘采样失真边角
        .frame(minWidth: LayoutSpec.compactWindowMin, idealWidth: 1920,
               minHeight: 700, idealHeight: 900)
        // C2 harness 健壮化语义保留：attach 补一行 "ready @WxH"（mode+宽高真值），
        // 即便外部无 resize 也至少给 Tina 一行可判 harness 通断
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    let h = Int(geo.size.height)
                    let w = Int(geo.size.width)
                    LayoutDump.sample(
                        page: ["master": "P3", "p13": "P13", "p7": "P7", "p2": "P2", "p2more": "P2", "p5": "P5"][mode] ?? "P4",
                        width: geo.size.width,
                        params: ["ready": "\(w)x\(h)", "h": String(h)])
                }
            }
        )
    }

    @Environment(\.scenePhase) private var scenePhase

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // v6.4 C1（LJ-2 根治）：低频操作收敛工具栏溢出菜单（原底部操作栏整栏入册）
    private func p1OverflowItems() -> [ToolbarOverflowItem] {
        let l10n = L10n.shared
        // T-1020-OC-02 随批修 A：四功能域分组（学棋/对局/数据/外观与设置）；studyHub 已提权内联（裁 B）
        return [
            // 学棋域
            .init(id: "puzzles", title: l10n.t("toolbar.puzzle"), icon: "puzzlepiece",
                  disabled: false, action: { activeSheet = .puzzles }),
            .init(id: "coach", title: l10n.t("toolbar.coach"), icon: "brain.head.profile",
                  disabled: viewModel.gameMoves.isEmpty,
                  action: { if let r = viewModel.buildGameRecord() { activeSheet = .coach(r) } }),
            .init(id: "dailyChallenge", title: l10n.t("toolbar.dailyChallenge"), icon: "calendar.badge.clock",
                  disabled: false, action: { activeSheet = .dailyChallenge }),
            .divider(id: "d1"),
            // 对局域
            .init(id: "resign", title: l10n.t("game.resign"), icon: "flag.fill",
                  disabled: viewModel.isThinking || viewModel.gameState != .playing,
                  action: { viewModel.requestResign() }),
            .init(id: "replay", title: l10n.t("game.replay"), icon: "arrow.uturn.forward.circle",
                  disabled: viewModel.gameMoves.isEmpty,
                  action: { openReplayWindow() }),
            .init(id: "analysis", title: l10n.t("toolbar.analysis"), icon: "chart.line.uptrend.xyaxis",
                  disabled: viewModel.gameMoves.isEmpty,
                  action: { if let r = viewModel.buildGameRecord() { activeSheet = .analysis(r) } }),
            .init(id: "record", title: l10n.t("toolbar.record"), icon: "doc.text",
                  disabled: false, action: { activeSheet = .record }),
            .divider(id: "d2"),
            // 数据域
            .init(id: "stats", title: l10n.t("toolbar.stats"), icon: "chart.bar",
                  disabled: false, action: { activeSheet = .stats }),
            .init(id: "history", title: l10n.t("toolbar.history"), icon: "clock.arrow.circlepath",
                  disabled: false, action: { activeSheet = .history }),
            .divider(id: "d3"),
            // 外观与设置域
            .init(id: "theme", title: l10n.t("toolbar.theme"), icon: "paintpalette",
                  disabled: false, action: { activeSheet = .themePicker }),
            .init(id: "achievements", title: l10n.t("toolbar.achievements"), icon: "trophy",
                  disabled: false, action: { activeSheet = .achievements }),
            .init(id: "rankPrivilege", title: l10n.t("toolbar.rankPrivilege"), icon: "medal",
                  disabled: false, action: { activeSheet = .rankPrivilege }),
            .init(id: "settings", title: l10n.t("toolbar.settings"), icon: "gearshape",
                  disabled: false, action: { activeSheet = .settings }),
        ]
    }

    var body: some Scene {
        mainWindowScene
        replayWindowScene
    }

    private var mainWindowScene: some Scene {
        WindowGroup(L10n.shared.t("app.title")) {            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                if let harnessMode = Self.harnessPlayMode {
                    // v6.4 P1 修复（0206d07 rebase）：harness 全窗替换——原 .harnessPlay
                    // sheet 在 resize sweep 下自发 dismiss（09-06 返工单①），结构性修复
                    // 对任意触发免疫：无 sheet、无挂载重试，主窗 UI 不存在于 harness 会话。
                    harnessRoot(mode: harnessMode)
                } else {
                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel, onReplayRequest: {
                        if let record = viewModel.buildGameRecord() {
                            activeSheet = .toolbarReplay(record)
                        }
                    }, onStudyHubRequest: {
                        activeSheet = .studyHub
                    }, overflowItems: p1OverflowItems())

                    // v6.4 C1：状态栏+棋钟合并单行信息带（原 ChessClockView+StatusBarView）
                    GameInfoBandView(viewModel: viewModel)

                    // v6.4 C1：大屏三栏——棋盘最大化 + 右通栏（窄屏收起走 C0 状态机）
                    HStack(spacing: 0) {
                        BoardView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(minHeight: 280)
                            .layoutPriority(1)

                        if railState.isExpanded {
                            Divider().opacity(0.4)
                            GameRailView(viewModel: viewModel, onReplayRequest: {
                                if let record = viewModel.buildGameRecord() {
                                    activeSheet = .toolbarReplay(record)
                                }
                            })
                        }
                    }
                    .padding(.horizontal, LayoutSpec.space3)
                    .padding(.vertical, LayoutSpec.space3)
                    .background(
                        // v6.4 C0/C2：状态机输入通道 = background GeometryReader + onChange
                        // （Ruby R2 约束：禁用 onGeometryChange，部署目标 macOS 14 不达）
                        // C2 健壮化：onAppear 也 emit 一行（初始 width + rail 真实态），
                        // 无外部 resize 也能见至少 1 行，便于 Tina 判 harness 通断
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    railState.update(width: geo.size.width)
                                    LayoutDump.sample(page: "P1", width: geo.size.width,
                                      params: ["rail": railState.isExpanded ? "expanded" : "collapsed"])
                                }
                                .onChange(of: geo.size.width) { _, w in
                                    railState.update(width: w)
                                    LayoutDump.sample(page: "P1", width: w,
                                      params: ["rail": railState.isExpanded ? "expanded" : "collapsed"])
                                }
                        }
                    )
                }

                // 游戏结束弹窗
                if viewModel.gameState != .playing {
                    GameOverOverlay(gameState: viewModel.gameState) {
                        viewModel.newGame()
                    } onViewRecord: {
                        if let record = viewModel.buildGameRecord() {
                            activeSheet = .toolbarReplay(record)
                        }
                    }
                }

                // v3.7.2 Phase 4: 对弈结束复盘卡片
                if showReviewCard, let card = reviewCardData, let record = reviewCardRecord {
                    VStack {
                        Spacer()
                        ReviewCardView(
                            card: card,
                            onViewDetail: {
                                showReviewCard = false
                                activeSheet = .coach(record)
                            },
                            onClose: {
                                showReviewCard = false
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showReviewCard)
                }

                // P0-1 fix: 首次启动引导弹窗
                if showFirstLaunchDialog {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    FirstLaunchDialog(
                        isPresented: $showFirstLaunchDialog,
                        onShowTutorial: {
                            UserDefaults.standard.set(true, forKey: "chinesechess.firstLaunchDialogShown")
                            showFirstLaunchDialog = false
                            activeSheet = .tutorial
                        },
                        onSkip: {
                            UserDefaults.standard.set(true, forKey: "chinesechess.firstLaunchDialogShown")
                            TutorialViewModel.markTutorialCompleted()
                            showFirstLaunchDialog = false
                        }
                    )
                    .frame(maxWidth: 500)
                }

                }
            }
            // Q2: 监听段位升级通知
            .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                if let newRank = notification.object as? Rank {
                    rankUpRank = newRank
                    // 竟态防护：段位升级优先，暂停 review card
                    showReviewCard = false
                    if let record = reviewCardRecord {
                        pendingReviewRecord = record
                    }
                    activeSheet = .rankUp(newRank)
                }
            }
            // v3.7.2 Phase 4: 对弈结束触发复盘卡片
            .onChange(of: viewModel.gameState) { _, newState in
                if newState != .playing {
                    generateReviewCard()
                } else {
                    // 新局开始，清理
                    showReviewCard = false
                    reviewCardRecord = nil
                    reviewCardData = nil
                    pendingReviewRecord = nil
                }
            }
            // v6.2 minHeight 600 口径（m1 定案）+ v6.4 C1 横向打样 ideal（合并窗口各取所长）
            .frame(minWidth: LayoutSpec.compactWindowMin, idealWidth: 1280, minHeight: 600, idealHeight: 860)
            // v6.4 P1 修复：原 harness sheet 入口（onAppear 置 activeSheet + C3-3 挂载重试 Task）
            // 已随全窗替换退役——迁移至 harnessPlayMode/harnessRoot（见上方注释）
            .onAppear {
                TutorialViewModel.markLaunched()
                if firstLaunchNeeded {
                    showFirstLaunchDialog = true
                }
            }
            .preferredColorScheme(.dark)
            // P0-1 fix: 长将判负首次触发解释弹窗
            .alert(
                L10n.shared.t("game.perpetualCheckTitle"),
                isPresented: Binding(
                    get: { viewModel.perpetualCheckMessage != nil },
                    set: { if !$0 { viewModel.perpetualCheckMessage = nil } }
                )
            ) {
                Button(L10n.shared.t("common.gotIt")) { viewModel.perpetualCheckMessage = nil }
            } message: {
                Text(viewModel.perpetualCheckMessage ?? "")
            }
            // v4.0 Phase 6: 长捉判负提示
            .alert(
                L10n.shared.t("game.perpetualChaseTitle"),
                isPresented: Binding(
                    get: { viewModel.perpetualChaseMessage != nil },
                    set: { if !$0 { viewModel.perpetualChaseMessage = nil } }
                )
            ) {
                Button(L10n.shared.t("common.gotIt")) { viewModel.perpetualChaseMessage = nil }
            } message: {
                Text(viewModel.perpetualChaseMessage ?? "")
            }
            // v3.7.1 P0: 统一 sheet — 解决多 .sheet 串联导致弹不出的 bug
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .puzzles:
                    NavigationStack {
                        ChapterSelectView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 816, minHeight: 700)  // v6.4 C2：P3/P4 sheet 容器允许窄至 900 内（面板 <1000 迟滞收起，棋盘吃满）

                case .toolbarReplay(let record):
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 750)

                case .themePicker:
                    NavigationStack {
                        VStack(spacing: 16) {
                            ThemePickerView()
                        }
                        .padding()
                        .navigationTitle(L10n.shared.t("theme.title"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { activeSheet = nil }
                            }
                        }
                    }
                    .frame(minWidth: 300, minHeight: 200)

                case .history:
                    NavigationStack {
                        GameHistoryView(onReplayRequest: { record in
                            activeSheet = .historyReplay(record)
                        })
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { activeSheet = nil }
                            }
                        }
                    }
                    .frame(minWidth: 350, minHeight: 400)

                case .historyReplay(let record):
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 750)

                case .settings:
                    NavigationStack {
                        SettingsView(viewModel: viewModel)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 320, minHeight: 300, maxHeight: 500)

                case .dailyChallenge:
                    NavigationStack {
                        DailyChallengeView()
                            .navigationTitle(L10n.shared.t("toolbar.dailyChallenge"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .achievements:
                    NavigationStack {
                        AchievementView(profile: PlayerProfileStore.shared.profile)
                            .navigationTitle(L10n.shared.t("toolbar.achievements"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .rankPrivilege:
                    NavigationStack {
                        RankPrivilegeView(profile: PlayerProfileStore.shared.profile)
                            .navigationTitle(L10n.shared.t("toolbar.rankPrivilege"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .rankUp(let rank):
                    RankUpView(newRank: rank) {
                        activeSheet = nil
                        // 竟态防护：RankUpView dismiss 后检查 pending review card
                        if let record = pendingReviewRecord {
                            pendingReviewRecord = nil
                            reviewCardRecord = record
                            showReviewCard = true
                        }
                    }
                    .frame(minWidth: 320, minHeight: 300)

                case .record:
                    RecordPanelView(viewModel: viewModel, onExportRequest: {
                        if let record = viewModel.buildGameRecord() {
                            copyRecordToClipboard(record)
                        }
                    })
                    .frame(minWidth: 280, minHeight: 250, maxHeight: 600)

                case .stats:
                    StatsPanelView()
                        .frame(minWidth: 280, minHeight: 180, maxHeight: 400)

                // ✅ v3.7.2: 新增 UI 入口 placeholder
                case .analysis(let record):
                    AnalysisView(record: record)
                        .frame(minWidth: 600, minHeight: 700)

                case .coach(let record):
                    NavigationStack {
                        CoachSessionView(record: record)
                            .navigationTitle(L10n.shared.t("coach.title"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 500, minHeight: 600)

                case .studyHub:
                    NavigationStack {
                        StudyHubView()  // 学棋中心
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 816, minHeight: 700)  // v6.4 C2：sheet 容器同 .puzzles 口径（P3/P4 迟滞收起后棋盘吃满）


                case .tutorial:
                    TutorialView(onComplete: { activeSheet = nil })
                        .frame(minWidth: 400, minHeight: 400)

                case .openingExplorer:
                    NavigationStack {
                        OpeningExplorerView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    // v6.4 C4a：P8 三区（树 320+统计 240+边距 48）起步宽；窄窗迟滞区间可收至 900 内
                    .frame(minWidth: LayoutSpec.compactWindowMin, idealWidth: 1280, minHeight: 700)
                }
            }
            // v3.7.0 Phase 3: 打开 .pgn 文件
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .alert(L10n.shared.t("import.resultTitle"), isPresented: $showImportFailAlert) {
                Button(L10n.shared.t("common.ok"), role: .cancel) {}
            } message: {
                Text(importFailMessage)
            }
        }
        .windowStyle(.titleBar)
        // v6.4 C1：主窗改为 automatic（contentSize 会把窗口钉在内容理想宽=900，
        // 横向三栏默认窗宽出不来；min 仍由内容 frame(minWidth:900) 兜底）
        .windowResizability(.automatic)
        // v6.4 C1：横向布局打样默认窗宽 1280（三栏可见；窄窗收起走 C0 状态机）
        .defaultSize(width: 1280, height: 860)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await EngineRouter.shared.shutdown() }
            } else if newPhase == .active {
                // P1 fix L2-10: 后台 shutdown 后回到前台需要重新启动引擎
                Task { await EngineRouter.shared.switchEngineIfNeeded() }
            }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.shared.t("game.settings")) {
                    activeSheet = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu(L10n.shared.t("game.menuLabel")) {
                Button(L10n.shared.t("game.newGame")) {
                    viewModel.newGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(L10n.shared.t("game.undoMove")) {
                    viewModel.undoMove()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)

                Divider()

                Button(L10n.shared.t("game.hint")) {
                    viewModel.requestHint()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)

                // FINAL-003: ⌘⇧O 开局浏览器
                Button(L10n.shared.t("toolbar.openingExplorer")) {
                    activeSheet = .openingExplorer
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            // v6.3 E5: 引擎开关退场（Toggle/binding 删除），菜单仅保留配置入口
            CommandMenu(L10n.shared.t("engine.menuLabel")) {
                Button(L10n.shared.t("engine.configureLabel")) {
                    activeSheet = .settings
                }
            }
        }
    }

    // v6.4 C4a：P9 复盘独立窗口（壳——洪涛 R3 拍板“一步到位”）。
    // 760×820 起步可最大化；芯（评估/回跳/变招）C4b Cody 域，经
    // AnalysisPresentationProvider 注入（本壳默认 Stub）。投递链：主窗
    // openReplayWindow() → SwiftData 中转件 → openWindow(value: uuid)。
    private var replayWindowScene: some Scene {
        WindowGroup(L10n.shared.t("p9.window.title"), id: "replayWindow", for: String.self) { uuid in
            // P2-5：容器降级 nil 时省挂 modelContainer（视图空态兑底），不炸 scene 构建
            if let container = replayPayloadStore.container {
                ReplayWindow()
                    .environment(\.replayWindowPayloadID, uuid.wrappedValue)
                    .modelContainer(container)
            } else {
                ReplayWindow()
                    .environment(\.replayWindowPayloadID, uuid.wrappedValue)
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: LayoutSpec.p9WindowMinWidth, height: LayoutSpec.p9WindowMinHeight)
    }

    // MARK: - 导出辅助

    private func copyRecordToClipboard(_ record: GameRecord) {
        let pgn = PGNExporter.export(record)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
    }

    // MARK: - v3.7.2 Phase 4: 复盘卡片生成

    private func generateReviewCard() {
        guard let record = viewModel.buildGameRecord() else { return }
        guard !record.moves.isEmpty else { return }

        reviewCardRecord = record

        // 异步分析 + 生成 review card
        Task {
            let uciMoves = record.moves.uciMoves

            let fen = record.initialFEN ?? FENParser.standardInitial
            let analysisVM = AnalysisViewModel()
            analysisVM.load(moves: uciMoves, initialFEN: fen, gameMoves: record.moves)
            await analysisVM.analyzeAll()

            let card = await CoachExplainer.shared.generateReviewCard(analyses: analysisVM.analyses)

            await MainActor.run {
                reviewCardData = card
                // 如果正在显示 RankUpView，延后显示
                if activeSheet?.id == "rankUp" {
                    pendingReviewRecord = record
                } else {
                    showReviewCard = true
                }
            }
        }
    }

    // MARK: - v3.7.0 Phase 3: 打开 .pgn 文件

    private func handleOpenURL(_ url: URL) {
        guard url.pathExtension == "pgn" else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importFailMessage = L10n.shared.t("import.readFileFail")
            showImportFailAlert = true
            return
        }
        let result = PGNImporter.parse(text)
        for record in result.records {
            GameRecordStore.shared.addRecord(record)
        }
        if !result.records.isEmpty {
            activeSheet = .history
        } else {
            importFailMessage = L10n.shared.t("import.parseFail")
            showImportFailAlert = true
        }
    }
}
#endif
