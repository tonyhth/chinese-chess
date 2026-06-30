import SwiftUI

@Observable
class ImportViewModel {
    enum ImportState {
        case idle           // 等待选择文件
        case parsing        // 解析中
        case success(ImportResult)  // 解析完成
        case failure(String)        // 解析失败
    }

    private(set) var state: ImportState = .idle
    private var parseTask: Task<Void, Never>?

    /// 标记解析失败（用于剪贴板空等非解析错误）
    func fail(_ message: String) {
        state = .failure(message)
    }

    /// 从 PGN 文本解析
    /// 解析在后台线程执行（Task.detached），结果通过 MainActor.run 回调
    /// 调用方通过观察 state 属性变化感知结果（.success / .failure）
    func parse(pgnText: String) {
        // 取消前一次解析（如果有）
        parseTask?.cancel()
        state = .parsing
        parseTask = Task.detached { [weak self] in
            let result = PGNImporter.parse(pgnText)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if result.records.isEmpty {
                    self.state = .failure(L10n.shared.t("import.noValidContent"))
                } else {
                    self.state = .success(result)
                }
            }
        }
    }

    /// 确认导入，将记录写入 Store
    func confirmImport() -> Int {
        guard case .success(let result) = state else { return 0 }
        let added = GameRecordStore.shared.batchAdd(result.records)
        state = .idle
        return added
    }

    /// 重置
    func reset() {
        parseTask?.cancel()
        parseTask = nil
        state = .idle
    }
}
