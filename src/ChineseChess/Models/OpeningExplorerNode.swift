import SwiftUI

// MARK: - v5.0 懒展开节点

/// 开局探索懒展开节点
/// VE-2/VE-3: 用 PositionSnapshot 替代 Board 快照，脱离 @Observable
/// VE-4: @MainActor 保证线程安全
/// P1 fix: weak parent 指针，selectNode 回溯 O(depth)，避免 DFS 触发懒加载
/// P1 fix: isLeaf 不触发懒加载（基于 _children 状态判断）
@MainActor
final class OpeningExplorerNode: Identifiable {
    let id = UUID()
    let move: String               // ICCS 走法
    let moveName: String           // 中文走法名
    let weight: Int                // 权重（大师对局中出现次数）
    let depth: Int                 // 深度（0 = 根候选走法）

    /// 轻量局面快照（执行此走法后的棋盘状态）
    let snapshot: PositionSnapshot

    /// 父节点弱引用（P1 fix: 回溯路径，避免 DFS）
    weak var parent: OpeningExplorerNode?

    /// 子节点（懒生成）
    private var _children: [OpeningExplorerNode]? = nil

    /// 获取子节点（首次访问时懒生成并设置 parent）
    var children: [OpeningExplorerNode] {
        if let c = _children { return c }
        let c = OpeningExplorerService.shared.expandChildren(of: self)
        // 设置 parent 指针
        for child in c {
            child.parent = self
        }
        _children = c
        return c
    }

    var isExpanded: Bool = false

    /// 是否是叶子节点（P1 fix: 不触发懒加载）
    /// - 已展开过且为空 → true
    /// - 已展开过且非空 → false
    /// - 尚未展开 → false（显示 chevron，用户点击后才查表）
    var isLeaf: Bool {
        guard let c = _children else { return false }
        return c.isEmpty
    }

    /// 从当前节点回溯到根节点的路径（P1 fix: O(depth) 替代 DFS）
    func pathFromRoot() -> [OpeningExplorerNode] {
        var path: [OpeningExplorerNode] = []
        var current: OpeningExplorerNode? = self
        while let node = current {
            path.insert(node, at: 0)
            current = node.parent
        }
        return path
    }

    init(move: String, moveName: String, weight: Int, depth: Int, snapshot: PositionSnapshot) {
        self.move = move
        self.moveName = moveName
        self.weight = weight
        self.depth = depth
        self.snapshot = snapshot
    }
}
