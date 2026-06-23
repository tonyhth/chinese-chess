#if os(macOS)

import Foundation
import SwiftUI

// MARK: - 引擎状态观察器

/// 引擎状态观察器（@MainActor @Observable，供 UI 绑定）
/// P1 #4: 解决 ChessEngine.isReady 的 async 属性无法直接绑定到 SwiftUI 的问题
@MainActor
@Observable
final class EngineStateObserver {
    static let shared = EngineStateObserver()

    /// 当前引擎是否就绪（缓存值，由外部更新）
    private(set) var isEngineReady: Bool = false

    /// 当前引擎类型
    private(set) var currentEngineType: EngineType = .native

    /// 当前引擎显示名称
    private(set) var currentEngineName: String = "内置引擎"

    /// 当前引擎自报名称（如有）
    private(set) var resolvedEngineName: String?

    /// 当前引擎版本（如有）
    private(set) var resolvedEngineVersion: String?

    /// 是否正在切换引擎
    private(set) var isSwitching: Bool = false

    /// 待切换提示消息
    private(set) var pendingSwitchMessage: String? = nil

    /// 外部引擎启动失败消息（如有）
    private(set) var errorMessage: String? = nil

    private init() {}

    // MARK: - 状态更新

    /// 更新引擎就绪状态（由 EngineRouter 调用）
    func updateState(
        isReady: Bool,
        type: EngineType,
        name: String,
        resolvedName: String? = nil,
        resolvedVersion: String? = nil
    ) {
        self.isEngineReady = isReady
        self.currentEngineType = type
        self.currentEngineName = name
        self.resolvedEngineName = resolvedName
        self.resolvedEngineVersion = resolvedVersion
        self.errorMessage = nil
    }

    /// 标记正在切换引擎
    func setSwitching(_ value: Bool) {
        self.isSwitching = value
    }

    /// 设置待切换提示（菜单栏切换时调用）
    func setPendingSwitch(pendingId: UUID?) {
        if let id = pendingId,
           let config = EngineConfigStore.shared.engines.first(where: { $0.id == id }) {
            let displayName = config.resolvedName ?? config.name
            pendingSwitchMessage = "引擎将在下次对局生效: \(displayName)"
        } else if pendingId == nil {
            pendingSwitchMessage = "将使用内置引擎"
        } else {
            pendingSwitchMessage = nil
        }
    }

    /// 设置错误消息（外部引擎启动失败时调用）
    func setError(_ message: String) {
        self.errorMessage = message
        self.isEngineReady = false
    }

    /// 清除错误消息
    func clearError() {
        self.errorMessage = nil
    }
}

#endif
