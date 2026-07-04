import SwiftUI

// MARK: - v3.0 Phase 5: 新手引导教程主视图

struct TutorialView: View {

    @State private var viewModel = TutorialViewModel()
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            HStack {
                if viewModel.currentLesson > 0 {
                    Button(L10n.shared.t("tutorial.prev")) {
                        viewModel.previousLesson()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text(L10n.shared.t("tutorial.progress", String(viewModel.currentLesson + 1), String(viewModel.lessons.count)))
                    .font(.headline)

                Spacer()

                Button(L10n.shared.t("tutorial.skip")) {
                    TutorialViewModel.markTutorialCompleted()
                    onComplete?()
                    dismiss()
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.windowBackground)

            // 进度条
            ProgressView(
                value: Double(viewModel.currentLesson + 1),
                total: Double(viewModel.lessons.count)
            )
            .padding(.horizontal)

            // 课程内容
            ScrollView {
                let lesson = viewModel.lessons[viewModel.currentLesson]
                VStack(spacing: 20) {
                    // 图标
                    Image(systemName: lesson.icon)
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                        .padding(.top, 20)

                    // 标题
                    Text(lesson.title)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(lesson.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // 描述
                    Text(lesson.description)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.controlBackground)
                        .cornerRadius(8)

                    // 课程特定交互
                    lessonInteraction(for: viewModel.currentLesson)
                }
                .padding()
            }

            // 底部按钮
            HStack {
                Spacer()
                if viewModel.isLastLesson {
                    Button(L10n.shared.t("tutorial.complete")) {
                        TutorialViewModel.markTutorialCompleted()
                        onComplete?()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(L10n.shared.t("tutorial.next")) {
                        viewModel.nextLesson()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    // MARK: - 课程特定交互

    @ViewBuilder
    private func lessonInteraction(for lessonId: Int) -> some View {
        switch lessonId {
        case 0:
            // 第 1 课：棋子走法提示
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.t("tutorial.lesson0.hint"))
                    .font(.headline)
                Text(L10n.shared.t("tutorial.lesson0.hintBody"))
                    .foregroundColor(.secondary)
                Text(L10n.shared.t("tutorial.lesson0.hintNote"))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

        case 1:
            // 第 2 课：将军提示
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.t("tutorial.lesson1.hint"))
                    .font(.headline)
                Text(L10n.shared.t("tutorial.lesson1.hintBody"))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

        case 2:
            // 第 3 课：将死练习
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.t("tutorial.lesson2.hint"))
                    .font(.headline)
                Text(L10n.shared.t("tutorial.lesson2.hintBody"))
                    .foregroundColor(.secondary)
                Text(L10n.shared.t("tutorial.lesson2.hintNote"))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

        case 3:
            // 第 4 课：特殊规则
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.t("tutorial.lesson3.hint"))
                    .font(.headline)
                HStack {
                    Text(L10n.shared.t("tutorial.lesson3.stalemate"))
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text(L10n.shared.t("tutorial.lesson3.stalemateDesc"))
                        .foregroundColor(.red)
                }
                HStack {
                    Text(L10n.shared.t("tutorial.lesson3.perpetual"))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text(L10n.shared.t("tutorial.lesson3.perpetualDesc"))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

        case 4:
            // 第 5 课：实战
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.t("tutorial.lesson4.hint"))
                    .font(.headline)
                Text(L10n.shared.t("tutorial.lesson4.hintBody"))
                    .foregroundColor(.secondary)
                Text(L10n.shared.t("tutorial.lesson4.hintNote"))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)

        default:
            EmptyView()
        }
    }
}

// MARK: - 首次启动弹窗

struct FirstLaunchDialog: View {
    @Binding var isPresented: Bool
    var onShowTutorial: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text(L10n.shared.t("tutorial.welcome"))
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.shared.t("tutorial.welcomeQuestion"))
                .font(.body)

            HStack(spacing: 16) {
                Button(L10n.shared.t("tutorial.notFamiliar")) {
                    onShowTutorial()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(L10n.shared.t("tutorial.familiar")) {
                    onSkip()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(minWidth: 400)
    }
}


// SideSelectionView 已移除（v3.4）：废弃组件
// 功能已被 ToolbarView 内联执边按钮替代
