#if os(macOS)

import SwiftUI

// MARK: - 引擎设置视图

/// macOS 引擎设置面板
/// v3.1 Phase 2c: 外部引擎配置 + 测试连接
struct EngineSettingsView: View {
    @State private var store = EngineConfigStore.shared
    @State private var showingAddSheet = false
    @State private var editingEngine: ExternalEngineConfig?
    @State private var testingEngineId: UUID?
    @State private var testResult: String?

    var body: some View {
        Form {
            // 引擎来源选择
            Section("引擎来源") {
                Picker("AI 引擎", selection: Binding(
                    get: { store.useExternalEngine ? "external" : "native" },
                    set: { newValue in
                        if newValue == "native" {
                            store.selectedEngineId = nil
                        } else if newValue == "external" {
                            // 选择第一个已配置的引擎，如果没有则提示添加
                            if let firstEngine = store.engines.first {
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
            if store.useExternalEngine {
                Section("已配置的外部引擎") {
                    ForEach(store.engines) { engine in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(engine.name)
                                    .font(.headline)
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
                        showingAddSheet = true
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

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.hasPrefix("✅") ? .green : .red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            if let engine = editingEngine {
                EngineEditView(engine: engine, onSave: { newEngine in
                    store.addEngine(newEngine)
                    showingAddSheet = false
                })
            }
        }
    }

    private func testEngine(_ config: ExternalEngineConfig) {
        testingEngineId = config.id
        testResult = nil

        Task {
            let manager = ExternalEngineManager(config: config)
            do {
                try await manager.start()
                // 测试求走法
                let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
                let move = await manager.bestMove(fen: fen, moveHistory: [], difficulty: .medium, timeLimitMs: 3000)
                await manager.shutdown()

                if let move = move {
                    testResult = "✅ 成功：返回走法 \(move)"
                } else {
                    testResult = "❌ 失败：未返回走法"
                }
            } catch {
                testResult = "❌ 失败：\(error.localizedDescription)"
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
                    TextField("可执行文件路径", text: $engine.executablePath)
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