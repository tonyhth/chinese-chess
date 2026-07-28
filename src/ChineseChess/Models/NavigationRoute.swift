import Foundation

/// 统一导航路由类型（与 SheetDestination 设计哲学一致）
/// 用于 NavigationStack 内的路由，编译期类型安全
enum NavigationRoute: Hashable {
    case chapter(PuzzleChapter)
    case puzzleDemo
    case masterGame     // StudyHubView → MasterGameBrowserView
    case openingExplorer  // Step 2 后续: StudyHubView 内部走 NavigationLink(value:) 时启用
}
