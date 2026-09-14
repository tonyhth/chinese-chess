import SwiftUI

// MARK: - v6.4 C3-1：分类 sidebar 统一组件（P2/P7/P13 共用，治"分类三态不一"）
//
// 依据：v6.4-layout-redesign.md §3.4 + docs/plans/v6.4-c3-design-prep.md §1 C3-1
// - 设计语言=v6.4-pages-all14 .sidebar（cat 行 = 标题+计数；选中=wood 底白字；hover 浅底）
// - Luke 裁决（C3 预研 R1 定案）：NavigationSplitView sidebar 系统托管 columnVisibility，
//   不编程接管、不自动收起；C0 迟滞状态机只管右通栏（<1000/>1080），不管 sidebar
// - sidebar 宽：LayoutSpec.panelWidthNarrow(320) ideal，可拖 240…panelWidthMedium(400)
//   ——落 LayoutSpec 三档面板宽的窄/中档，不新造 token（C0 铁律）
// - LJ-1 截断三件套：单行截断 + 尾部省略 + hover tooltip（分类项标题与计数 badge 均适用）
// - LAYOUT_DUMP：外层 onAppear/resize 采样（page 由各页传入；params 只增不改名：
//   sidebar=shown/hidden、sw=sidebar 实宽、sel=当前选中项标题）

/// sidebar 分类项协议（C3-1 规格：id / 标题 / 计数 / 分组）
protocol SidebarCategory: Identifiable, Hashable {
    /// 行标题（LJ-1：超宽单行截断 + 尾部省略 + tooltip）
    var title: String { get }
    /// 右侧计数/标签（nil 不显示；同样受 LJ-1 约束）
    var badge: String? { get }
    /// 分组标题（nil = 顶部不分组区；渲染按"连续同 section"折叠成带组头的段）
    var section: String? { get }
}

extension SidebarCategory {
    var badge: String? { nil }
    var section: String? { nil }
}

/// 通用分类项（页面无需自定义类型即可构造 sidebar 数据）
struct SidebarItem: SidebarCategory {
    let id: String
    let title: String
    var badge: String? = nil
    var section: String? = nil
}

// MARK: - sidebar 页模板

/// 左分类列（搜索框置顶）+ 右内容区的 NavigationSplitView 包装模板。
///
/// 用法（P13 为例）：categories 按 section 分组传入；isSelected/onSelect 由页面
/// 映射到既有 @State（多维度筛选页按"每 section 单选"映射，保持过滤能力不回退）。
/// searchText 传 nil 则 sidebar 不显示搜索框（P2 搜索在 sidebar 顶、P7/P13 同；
/// 有页面无搜索需求时省略）。
struct CategorySidebarView<C: SidebarCategory, Detail: View>: View {
    let categories: [C]
    var isSelected: (C) -> Bool
    var onSelect: (C) -> Void
    var searchPlaceholder: String = ""
    var searchText: Binding<String>? = nil
    /// LAYOUT_DUMP 页标识（"P2"/"P7"/"P13"…，仅 Debug 生效）
    var page: String = "P13"
    @ViewBuilder var detail: () -> Detail

    /// 系统托管可见性（Luke 裁决：仅给初值，宽度变化不编程接管）
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// 行高亮圆角（v6.4-pages-all14 .cat border-radius:7px，组件内单点常量）
    private let rowCornerRadius: CGFloat = 7

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarColumn
                .navigationSplitViewColumnWidth(
                    min: 240,
                    ideal: LayoutSpec.panelWidthNarrow,
                    max: LayoutSpec.panelWidthMedium)
        } detail: {
            detail()
        }
        .navigationSplitViewStyle(.balanced)
        // v6.4 C3：页级采样（窗口宽 + sidebar 可见性 + 选中项），onAppear 也发一行
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { dump(width: geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in dump(width: w) }
            }
        )
    }

    private func dump(width: CGFloat) {
        guard LayoutDump.isEnabled else { return }
        LayoutDump.sample(
            page: page, width: width,
            params: [
                "sidebar": columnVisibility == .detailOnly ? "hidden" : "shown",
                "sel": selectedTitle,
            ])
    }

    private var selectedTitle: String {
        categories.first(where: { isSelected($0) })?.title ?? "—"
    }

    // MARK: sidebar 列

    private var sidebarColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutSpec.space2) {
                if let searchText {
                    searchField(text: searchText)
                }
                rows
            }
            .padding(LayoutSpec.space2)
        }
        .background(
            // sidebar 实宽采样（验收锚 4：sidebar 宽落在 320/400 档）
            GeometryReader { geo in
                Color.clear
                    .onAppear { dumpSidebarWidth(geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in dumpSidebarWidth(w) }
            }
        )
    }

    private func dumpSidebarWidth(_ w: CGFloat) {
        guard LayoutDump.isEnabled else { return }
        LayoutDump.sample(page: page, width: w, params: ["part": "sidebar"])
    }

    @ViewBuilder
    private var rows: some View {
        // 按"连续同 section"折叠：section 变化处插组头，nil section 不插
        let grouped = groupBySection(categories)
        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
            if let section = group.section {
                Text(section)
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, LayoutSpec.space2)
                    .padding(.top, LayoutSpec.space2)
            }
            ForEach(group.items) { item in
                row(item)
            }
        }
    }

    private struct SectionGroup<C: SidebarCategory> {
        let section: String?
        var items: [C]
    }

    private func groupBySection(_ items: [C]) -> [SectionGroup<C>] {
        var result: [SectionGroup<C>] = []
        for item in items {
            if let last = result.last, last.section == item.section {
                result[result.count - 1].items.append(item)
            } else {
                result.append(SectionGroup(section: item.section, items: [item]))
            }
        }
        return result
    }

    // MARK: 行（LJ-1 三件套）

    private func row(_ item: C) -> some View {
        let selected = isSelected(item)
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: LayoutSpec.space2) {
                Text(item.title)
                    .font(.system(size: LayoutSpec.fontSizeBody))
                    .lineLimit(1)                    // LJ-1 ①单行
                    .truncationMode(.tail)           // LJ-1 ②尾部省略
                    .help(item.title)                // LJ-1 ③hover tooltip
                Spacer(minLength: LayoutSpec.space1)
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: LayoutSpec.fontSizeCaption))
                        .monospacedDigit()
                        .foregroundStyle(selected ? AnyShapeStyle(.white.opacity(0.75))
                                                  : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(badge)
                }
            }
            .padding(.horizontal, LayoutSpec.space2 + LayoutSpec.space1)
            .padding(.vertical, LayoutSpec.space2 - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            selected ? AnyShapeStyle(Color.accentColor)
                     : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: rowCornerRadius)
        )
        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
    }

    // MARK: 搜索框（置顶，v6.4-pages-all14 .sidebar .search）

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: LayoutSpec.space2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
            TextField(searchPlaceholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: LayoutSpec.fontSizeBody))
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: LayoutSpec.fontSizeCaption))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.shared.t("common.clear"))
            }
        }
        .padding(.horizontal, LayoutSpec.space2)
        .padding(.vertical, LayoutSpec.space2 - 2)
        .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: rowCornerRadius)
        )
        .padding(.bottom, LayoutSpec.space1)
    }
}
