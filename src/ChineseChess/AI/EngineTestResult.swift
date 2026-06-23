import Foundation

// MARK: - 引擎测试结果（P2 #14: 结构化错误传播）

/// 引擎连接测试的结构化结果
/// 替代原来的 String? testResult，提供类型安全的错误处理
struct EngineTestResult: Identifiable {
    let id: UUID
    let engineId: UUID
    let status: Status
    let message: String
    let moveReturned: String?
    let resolvedName: String?
    let resolvedVersion: String?
    let durationMs: Int

    enum Status: Equatable {
        case success
        case failure(EngineTestError)
        case pending
    }

    init(
        engineId: UUID,
        status: Status,
        message: String = "",
        moveReturned: String? = nil,
        resolvedName: String? = nil,
        resolvedVersion: String? = nil,
        durationMs: Int = 0
    ) {
        self.id = UUID()
        self.engineId = engineId
        self.status = status
        self.message = message
        self.moveReturned = moveReturned
        self.resolvedName = resolvedName
        self.resolvedVersion = resolvedVersion
        self.durationMs = durationMs
    }

    /// 是否成功
    var isSuccess: Bool {
        if case .success = status { return true }
        return false
    }

    /// 是否正在进行
    var isPending: Bool {
        if case .pending = status { return true }
        return false
    }

    /// UI 显示文本
    var displayText: String {
        switch status {
        case .success:
            if let move = moveReturned {
                return "✅ 成功：返回走法 \(move)"
            }
            return "✅ 连接成功"
        case .failure(let error):
            return "❌ \(error.displayMessage)"
        case .pending:
            return "测试中…"
        }
    }

    /// 状态颜色（用于 UI）
    var statusColor: String {
        switch status {
        case .success: return "green"
        case .failure: return "red"
        case .pending: return "yellow"
        }
    }
}

// MARK: - 引擎测试错误类型

/// 结构化引擎测试错误
enum EngineTestError: Error, Equatable {
    /// 引擎启动失败（路径错误、权限不足等）
    case startupFailed(String)

    /// 引擎未返回走法（超时或无响应）
    case noMoveReturned

    /// UCI 协议错误（引擎未正确响应 uciok/readyok）
    case uciProtocolError(String)

    /// 超时
    case timeout

    /// 未知错误
    case unknown(String)

    /// 用户可读的错误描述
    var displayMessage: String {
        switch self {
        case .startupFailed(let detail):
            return "启动失败：\(detail)"
        case .noMoveReturned:
            return "引擎未返回走法"
        case .uciProtocolError(let detail):
            return "UCI 协议错误：\(detail)"
        case .timeout:
            return "连接超时"
        case .unknown(let detail):
            return "未知错误：\(detail)"
        }
    }

    /// 从 Error 转换
    static func from(_ error: Error) -> EngineTestError {
        if let testError = error as? EngineTestError {
            return testError
        }
        let nsError = error as NSError
        switch nsError.domain {
        case NSPOSIXErrorDomain:
            return .startupFailed(error.localizedDescription)
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
