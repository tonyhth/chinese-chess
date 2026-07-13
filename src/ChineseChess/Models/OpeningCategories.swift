import Foundation

// MARK: - 开局分类

/// 二级开局分类（基于红方前 2-3 步 + 黑方应手）
struct OpeningSubcategory: Identifiable, Sendable {
    let id: String               // "zhong_pao_pingfengma"
    let name: String             // "中炮对屏风马"
    let firstMoves: [String]     // 前 N 步走法序列（用于匹配）
    let gameCount: Int
}

/// 一级开局分类（基于红方第一步走法）
struct OpeningCategory: Identifiable, Sendable {
    let id: String               // "zhong_pao" 等
    let name: String             // "中炮"
    let firstMove: String        // "h2e2"
    let gameCount: Int           // 该开局下的对局数
    let description: String      // "炮二平五，最常见开局"
    let subcategories: [OpeningSubcategory]
}

// MARK: - 预定义开局分类

/// 预定义的一级开局分类 + 二级开局分类
/// gameCount 由构建脚本统计后写入 master-stats.json，运行时从统计结果填充
/// 此处硬编码的 gameCount 为初始默认值，运行时由 MasterGameStore 加载后覆盖
enum OpeningCategories {
    static let categories: [OpeningCategory] = [
        OpeningCategory(
            id: "zhong_pao", name: "中炮", firstMove: "h2e2",
            gameCount: 0, description: "炮二平五，最常见开局",
            subcategories: [
                OpeningSubcategory(id: "zhong_pao_pingfengma", name: "中炮对屏风马",
                                   firstMoves: ["h2e2", "b9c7", "b0c2"], gameCount: 0),
                OpeningSubcategory(id: "zhong_pao_fangongma", name: "中炮对反宫马",
                                   firstMoves: ["h2e2", "b9c7", "h0g2"], gameCount: 0),
                OpeningSubcategory(id: "zhong_pao_shunpao", name: "顺炮",
                                   firstMoves: ["h2e2", "h7e7"], gameCount: 0),
                OpeningSubcategory(id: "zhong_pao_liepao", name: "列炮",
                                   firstMoves: ["h2e2", "h7e7", "h0g2", "b9c7"], gameCount: 0),
            ]
        ),
        OpeningCategory(
            id: "xianren_zhilu", name: "仙人指路", firstMove: "c3c4",
            gameCount: 0, description: "兵七进一，试探应手",
            subcategories: [
                OpeningSubcategory(id: "xianren_zhilu_zudipao", name: "仙人指路对卒底炮",
                                   firstMoves: ["c3c4", "b7b3"], gameCount: 0),
            ]
        ),
        OpeningCategory(
            id: "fei_xiang", name: "飞相", firstMove: "g0e2",
            gameCount: 0, description: "相三进五，稳健开局",
            subcategories: []
        ),
        OpeningCategory(
            id: "qi_ma", name: "起马", firstMove: "b0c2",
            gameCount: 0, description: "马八进七，灵活开局",
            subcategories: []
        ),
        OpeningCategory(
            id: "qi_bing", name: "起兵", firstMove: "g3g4",
            gameCount: 0, description: "兵三进一，稳步推进",
            subcategories: []
        ),
        OpeningCategory(
            id: "guo_gong_pao", name: "过宫炮", firstMove: "h2f2",
            gameCount: 0, description: "炮二平四，集中火力",
            subcategories: []
        ),
        OpeningCategory(
            id: "other", name: "其他开局", firstMove: "",
            gameCount: 0, description: "非预定义开局",
            subcategories: []
        ),
    ]
}
