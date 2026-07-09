import SwiftUI

// MARK: - TutorialInfoView — info 类型课程视图（文字 + 图标）

struct TutorialInfoView: View {
    let lesson: TutorialLesson

    var body: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: lesson.icon)
                .font(.system(size: 56))
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
    .preferredColorScheme(.dark)
}
