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

    /// 标记解析失败（用于剪贴板空等非解析错误）
    func fail(_ message: String) {
        state = .failure(message)
    }

    /// 从 PGN 文本解析
    /// 解析在后台执行，结果回调回 MainActor
    func parse(pgnText: String) {
        state = .parsing
        Task.detached {
            let result = PGNImporter.parse(pgnText)
            await MainActor.run {
                if result.records.isEmpty && result.totalGames == 0 {
                    self.state = .failure("无法识别有效的 PGN 内容")
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
        state = .idle
    }
}
