#if os(macOS)

import SwiftUI

// MARK: - 引擎设置视图

/// macOS 引擎设置面板
/// v3.1 Phase 2c: 外部引擎配置 + 测试连接
struct EngineSettingsView: View {
    @State private var store = EngineConfigStore.shared
    @State private var editingEngine: ExternalEngineConfig?
    @State private var testingEngineId: UUID?
    @State private var testResults: [UUID: EngineTestResult] = [:]  // P2 #14: 结构化测试结果
    private let l10n = L10n.shared

    var body: some View {
        Form {
            // 引擎来源选择
            Section("引擎来源") {
                Picker("AI 引擎", selection: Binding(
                    get: { store.wantsExternalEngine ? "external" : "native" },
                    set: { newValue in
                        if newValue == "native" {
                            store.wantsExternalEngine = false
                            store.selectedEngineId = nil
                        } else if newValue == "external" {
                            // P0 修复：无条件设为 true，使空引擎引导 UI 可达
                            store.wantsExternalEngine = true
                            // 如果有已配置引擎，自动选中第一个
                            if store.selectedEngineId == nil, let firstEngine = store.engines.first {
                                store.selectedEngineId = firstEngine.id
                            }
                        }
                    }
                )) {
                    Text("内置引擎").tag("native")
                    Text("外部引擎").tag("external")
                }
                .pickerStyle(.radioGroup)
            }

            // 外部引擎列表（仅 macOS）
            // P0 修复：用 wantsExternalEngine 判断，使空引擎引导可见
            if store.wantsExternalEngine {
                Section("已配置的外部引擎") {
                    if store.engines.isEmpty {
                        // P1-1: 空引擎引导
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(l10n.t("engine.emptyHint"))
                                    .foregroundColor(.secondary)
                            }
                            Button(action: {
                                editingEngine = ExternalEngineConfig(
                                    name: "新引擎",
                                    executablePath: "",
                                    arguments: nil,
                                    options: [],
                                    isEnabled: true
                                )
                            }) {
                                Label(l10n.t("engine.addEngine"), systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(store.engines) { engine in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 4) {
                        #if os(macOS)
                                        // P2 #12: 引擎类型提示图标
                                        Image(systemName: "gearshape.2")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                        #endif
                                        Text(engine.name)
                                            .font(.headline)
                                        // P2 #12: 显示引擎自报名称（如有）
                                        if let resolved = engine.resolvedName {
                                            Text("\(resolved)\(engine.resolvedVersion.map { " \($0)" } ?? "")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Text(engine.executablePath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if store.selectedEngineId == engine.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedEngineId = engine.id
                            }
                        #if os(macOS)
                            // P2 #11: 右键删除功能
                            .contextMenu {
                                Button("删除引擎", role: .destructive) {
                                    if let index = store.engines.firstIndex(where: { $0.id == engine.id }) {
                                        store.removeEngine(at: index)
                                    }
                                }
                                Divider()
                                Button("设为当前引擎") {
                                    store.selectedEngineId = engine.id
                                }
                            }
                        #endif
                        }
                        .onDelete { indices in
                            for index in indices {
                                store.removeEngine(at: index)
                            }
                        }

                        Button("添加引擎…") {
                            editingEngine = ExternalEngineConfig(
                                name: "新引擎",
                                executablePath: "",
                                arguments: nil,
                                options: [],
                                isEnabled: true
                            )
                        }
                    }
                }

                // 引擎测试
                if let selectedId = store.selectedEngineId,
                   let selectedEngine = store.engines.first(where: { $0.id == selectedId }) {
                    Section("测试连接") {
                        HStack {
                            Text(selectedEngine.name)
                            Spacer()
                            if testingEngineId == selectedEngine.id {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("测试") {
                                    testEngine(selectedEngine)
                                }
                            }
                        }

                        if let result = testResults[selectedId] {
                            Text(result.displayText)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                            if let name = result.resolvedName {
                                Text("引擎: \(name)\(result.resolvedVersion.map { " \($0)" } ?? "")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingEngine) { engine in
            EngineEditView(engine: engine, onSave: { newEngine in
                store.addEngine(newEngine)
                editingEngine = nil
            })
        }
    }

    private func testEngine(_ config: ExternalEngineConfig) {
        testingEngineId = config.id
        testResults[config.id] = EngineTestResult(engineId: config.id, status: .pending)

        Task {
            let startTime = Date()
            let manager = ExternalEngineManager(config: config)
            do {
                try await manager.start()
                // 测试求走法
                let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
                let move = await manager.bestMove(fen: fen, moveHistory: [], difficulty: .medium, timeLimitMs: 3000)
                await manager.shutdown()

                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)

                if let move = move {
                    let rName = await manager.resolvedName
                    let rVer = await manager.resolvedVersion
                    testResults[config.id] = EngineTestResult(
                        engineId: config.id,
                        status: .success,
                        message: "返回走法 \(move)",
                        moveReturned: move,
                        resolvedName: rName,
                        resolvedVersion: rVer,
                        durationMs: elapsed
                    )
                } else {
                    testResults[config.id] = EngineTestResult(
                        engineId: config.id,
                        status: .failure(.noMoveReturned),
                        durationMs: elapsed
                    )
                }
            } catch {
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                testResults[config.id] = EngineTestResult(
                    engineId: config.id,
                    status: .failure(.from(error)),
                    durationMs: elapsed
                )
            }
            testingEngineId = nil
        }
    }
}

// MARK: - 引擎编辑视图

/// 添加/编辑引擎配置的表单
struct EngineEditView: View {
    @State var engine: ExternalEngineConfig
    var onSave: (ExternalEngineConfig) -> Void

    @State private var showingFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("名称", text: $engine.name)
                HStack {
                    TextField("可执行文件路径", text: $engine.executablePath, prompt: Text("请填写引擎可执行文件路径"))
                    Button("选择…") {
                        showingFilePicker = true
                    }
                }
            }

            Section("启动参数（可选）") {
                TextField("参数（空格分隔）", text: Binding(
                    get: { engine.arguments?.joined(separator: " ") ?? "" },
                    set: { engine.arguments = $0.isEmpty ? nil : $0.split(separator: " ").map(String.init) }
                ))
            }

            Section("UCI 选项（可选）") {
                ForEach(engine.options) { option in
                    HStack {
                        TextField("名称", text: Binding(
                            get: { option.name },
                            set: { newValue in
                                if let idx = engine.options.firstIndex(where: { $0.id == option.id }) {
                                    engine.options[idx].name = newValue
                                }
                            }
                        ))
                        TextField("值", text: Binding(
                            get: { option.value },
                            set: { newValue in
                                if let idx = engine.options.firstIndex(where: { $0.id == option.id }) {
                                    engine.options[idx].value = newValue
                                }
                            }
                        ))
                    }
                }
                .onDelete { indices in
                    engine.options.remove(atOffsets: indices)
                }

                Button("添加选项") {
                    engine.options.append(UCIOption(name: "", value: ""))
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(engine)
                }
                .disabled(engine.name.isEmpty || engine.executablePath.isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.executable],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                engine.executablePath = url.path
            }
        }
    }
}

#endif