//
//  RiverTextView.swift
//  ChineseChess
//
//  楚河汉界共享组件（T-1023-OC-01 P4-B7 单源化，dim6 §7.4 根治处方①②）
//

import SwiftUI

/// 楚河汉界河界文字共享组件
///
/// - 单源：翻转语义单点定义——isFlipped 时"汉界"在左、"楚河"在右（黑方视角）；
///   此前 5 视图各自硬编码（含 BoardCanvasView 固定顺序失翻转变体 = B4 N-1）
/// - 键消费：文案经 board.chuRiver / board.hanBorder 键（xcstrings 领域语言，恒中文，
///   D5I18nAuditVerificationTests 键存在钉在位）
/// - 教程面 Canvas 内嵌场景（TutorialBoardIntroView）不经本组件，isFlipped 恒 false
struct RiverTextView: View {
    let cellSize: CGFloat
    let color: Color
    /// 黑方视角翻转（顺序对调；默认 false = 红方视角）
    var isFlipped: Bool = false
    /// 字号相对 cellSize 的系数（主棋盘 0.45，预览面 0.4）
    var fontSizeFactor: CGFloat = 0.45
    /// 双侧文字间距相对 cellSize 的系数
    var spacingFactor: CGFloat = 2

    var body: some View {
        HStack(spacing: cellSize * spacingFactor) {
            if isFlipped {
                riverText("board.hanBorder")
                riverText("board.chuRiver")
            } else {
                riverText("board.chuRiver")
                riverText("board.hanBorder")
            }
        }
        .foregroundColor(color)
    }

    private func riverText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * fontSizeFactor))
    }
}
