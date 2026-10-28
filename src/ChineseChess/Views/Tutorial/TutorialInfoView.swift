import SwiftUI

// MARK: - TutorialInfoView — info 类型课程视图（文字 + 图标）

struct TutorialInfoView: View {
    let lesson: TutorialLesson

    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: lesson.icon)
                .font(.system(size: LayoutSpec.fontSizeHeroMax))
                .foregroundColor(.accentColor)
                .padding(.top, 20)

            // 标题
            Text(L10n.shared.t(lesson.titleKey))
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // 副标题
            Text(L10n.shared.t(lesson.subtitleKey))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 描述
            Text(L10n.shared.t(lesson.descriptionKey))
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.controlBackground)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TutorialInfoView(lesson: TutorialLesson(
        id: 0,
        titleKey: "tutorial.lesson0.title",
        subtitleKey: "tutorial.lesson0.subtitle",
        descriptionKey: "tutorial.lesson0.description",
        icon: "rectangle.grid"
    ))
    // F7（T-1023 功能打磨批 2026-10-28）：视图层强制深色撤除——App 层 F2 已全局强制深色，此处重复声明为死代码面
}
