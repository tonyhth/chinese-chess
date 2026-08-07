import Foundation

// MARK: - v3.7.4: 开发者模式
// v5.5.9: 从 #if DEBUG 改为始终可用，方便开发阶段验证

/// 开发者模式工具类
///
/// 功能：
/// - 绕过段位门禁（所有功能解锁）
///
/// 测试棋局可通过"打开棋谱"功能载入测试用 .pgn 文件。
enum DeveloperMode {
    /// UserDefaults key
    private static let key = "chinesechess.developerMode"

    /// 开发者模式开关
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            // 触发通知让 UI 刷新
            NotificationCenter.default.post(name: .developerModeChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let developerModeChanged = Notification.Name("chinesechess.developerModeChanged")
}
