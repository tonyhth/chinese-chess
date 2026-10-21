//
//  DrawDetectionRules.swift
//  ChineseChess
//
//  和棋检测规则参数单源（T-1023-OC-01 P4-A1：规则参数集中化首项）
//

import Foundation

/// 和棋检测规则参数（单源定义，各 ViewModel 消费面禁止再出现魔法数）
///
/// 60 步规则裁决链：
/// - 冲突立案：T-1023-OC-01 P2 dim1 核验——文档处方 120 半着 vs GameViewModel 实装 100 半着（P1 规则合规项）
/// - 丹妮裁决 2026-10-21：采纳 draw-detection-analysis.md §2.8/§4 P1#5 处方（60 回合 = 120 半着）
/// - 洪涛拍板 2026-10-22 07:06：准（P3 整改方案 §一 拍板记录 #1）
/// - 口径依据：《中国象棋竞赛规则》自然限着（60 回合内无吃子/无兑子/无兵移动判和）
enum DrawDetectionRules {
    /// 自然限着判和阈值（半着数）：120 半着 = 60 回合
    /// （原实装 100 半着 = 50 回合为 P1 合规整改项，P4-A1 修正；消费点：
    ///  GameViewModel.checkGameState 判和分支 + PuzzleViewModel.checkDraw）
    static let naturalDrawHalfmoveLimit = 120
}
