#!/usr/bin/env swift
// GamePlayView shouldShowLevelPicker fix test (Danny's root cause fix)
// Validates: levelId != nil → skip level picker → direct game entry

import Foundation

// MARK: - shouldShowLevelPicker logic (extracted)

enum GameMode { case adventure; case mistakeReview }

func shouldShowLevelPicker(mode: GameMode, levelId: Int?) -> Bool {
    return mode == .adventure && levelId == nil
}

// MARK: - Test engine

var passed = 0; var failed = 0; var errors: [String] = []

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 } else { failed += 1; errors.append("FAIL: \(message) (line \(line))") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}
func XCTAssertFalse(_ cond: Bool, _ message: String, file: String = #file, line: Int = #line) {
    assert(!cond, message, file: file, line: line)
}
func XCTAssertTrue(_ cond: Bool, _ message: String, file: String = #file, line: Int = #line) {
    assert(cond, message, file: file, line: line)
}

// =============================================
print("=== 1. 从关卡地图点击特定关卡 → 不闪关卡列表 ===")

do {
    // From level map: adventure + levelId = 1
    let result = shouldShowLevelPicker(mode: .adventure, levelId: 1)
    XCTAssertFalse(result, "levelId=1 → shouldShowLevelPicker=false → 直接显示游戏题目")
}

do {
    // From level map: adventure + levelId = 25
    let result = shouldShowLevelPicker(mode: .adventure, levelId: 25)
    XCTAssertFalse(result, "levelId=25 → shouldShowLevelPicker=false")
}

print("=== 2. 从首页闯关入口 → 显示关卡选择器 ===")

do {
    // From home: adventure + levelId = nil
    let result = shouldShowLevelPicker(mode: .adventure, levelId: nil)
    XCTAssertTrue(result, "levelId=nil → shouldShowLevelPicker=true → 显示关卡列表")
}

print("=== 3. 错题复习 → 不显示关卡选择器 ===")

do {
    let result = shouldShowLevelPicker(mode: .mistakeReview, levelId: nil)
    XCTAssertFalse(result, "mistakeReview + nil → false")
}

do {
    let result = shouldShowLevelPicker(mode: .mistakeReview, levelId: 1)
    XCTAssertFalse(result, "mistakeReview + levelId=1 → false")
}

print("=== 4. body 条件链验证（GamePlayView.body 逻辑） ===")

// Simulate the body rendering logic
func determineViewState(
    mode: GameMode, levelId: Int?,
    showingLevelPicker: Bool, session: Any?,
    isShowingResult: Bool, errorMessage: String?
) -> String {
    let showPicker = shouldShowLevelPicker(mode: mode, levelId: levelId)
    
    if showPicker && showingLevelPicker && mode == .adventure && session == nil {
        return "levelPicker"
    } else if let _ = session, !isShowingResult {
        return "gamePlay"
    } else if isShowingResult {
        return "result"
    } else if errorMessage == nil {
        return "fallback"
    } else {
        return "error"
    }
}

do {
    // Scenario 1: From level map, level 1, no session yet → game loads via onAppear
    let view = determineViewState(mode: .adventure, levelId: 1, showingLevelPicker: true, session: nil, isShowingResult: false, errorMessage: nil)
    // shouldShowLevelPicker=false, so levelPicker is skipped
    // session=nil, so falls to fallback temporarily before onAppear loads data
    assertEqual(view, "fallback", "levelId=1 + no session → fallback (短暂，onAppear 会 startLevel)")
}

do {
    // Scenario 2: From level map, level 1, after onAppear → session created
    let view = determineViewState(mode: .adventure, levelId: 1, showingLevelPicker: true, session: "session", isShowingResult: false, errorMessage: nil)
    assertEqual(view, "gamePlay", "levelId=1 + session存在 → gamePlay（不闪关卡列表）")
}

do {
    // Scenario 3: From home adventure, no level → shows level picker
    let view = determineViewState(mode: .adventure, levelId: nil, showingLevelPicker: true, session: nil, isShowingResult: false, errorMessage: nil)
    assertEqual(view, "levelPicker", "levelId=nil → 显示关卡选择器")
}

do {
    // Scenario 4: From level map, level 1, game completed → result view
    let view = determineViewState(mode: .adventure, levelId: 1, showingLevelPicker: false, session: "session", isShowingResult: true, errorMessage: nil)
    assertEqual(view, "result", "isShowingResult → 结果页面")
}

print("=== 5. ESC 退出后状态验证 ===")

do {
    // ESC → dismiss → MainTabView onDismiss: clearActiveSession + sheetId reset
    // Re-enter same level → new GamePlayView created (sheetId forces rebuild)
    // showingLevelPicker resets to true, but levelId=1 → shouldShowLevelPicker=false
    let showPicker = shouldShowLevelPicker(mode: .adventure, levelId: 1)
    XCTAssertFalse(showPicker, "ESC 后再进同一关卡 → 不显示关卡列表")
}

do {
    // ESC → enter different level
    let showPicker = shouldShowLevelPicker(mode: .adventure, levelId: 5)
    XCTAssertFalse(showPicker, "ESC 后进不同关卡 → 不显示关卡列表")
}

print("=== 6. 回归：空数据 errorMessage 不受影响 ===")

do {
    let view = determineViewState(mode: .adventure, levelId: 1, showingLevelPicker: false, session: nil, isShowingResult: false, errorMessage: "暂无题目数据")
    // errorMessage != nil → skip fallback, shows alert
    assertNotEqual(view, "levelPicker", "有 errorMessage 时不显示关卡选择器")
}
func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    assert(a != b, "\(message) — should not be \(b)", file: file, line: line)
}

// MARK: Results

print("\n" + String(repeating: "=", count: 50))
print("shouldShowLevelPicker 测试结果: \(passed) passed, \(failed) failed")
if !errors.isEmpty {
    print("\nFAILURES:")
    for e in errors { print("  \(e)") }
}
exit(failed > 0 ? 1 : 0)
