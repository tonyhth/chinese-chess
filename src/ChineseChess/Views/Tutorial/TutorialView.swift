import SwiftUI

// MARK: - v3.0 Phase 5: 新手引导教程主视图（v3.9 Step 2 重构）

struct TutorialView: View {

    @State private var viewModel = TutorialViewModel()
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            navBar

            // 进度条
            ProgressView(
                value: Double(viewModel.currentLesson + 1),
                total: Double(viewModel.lessons.count)
            )
            .padding(.horizontal)

            // 课程内容区（根据 lesson.type 切换）
            ScrollView {
                let lesson = viewModel.lessons[viewModel.currentLesson]
                Group {
                    switch (lesson.type, lesson.id) {
                    case (.info, 0):
                        TutorialBoardIntroView()
                    case (.info, 1):
                        TutorialPieceIntroView()
                    case (.interactive, _):
                        TutorialInteractiveView(lesson: lesson)
                    default:
                        TutorialInfoView(lesson: lesson)
                    }
                }
                .padding()
                .frame(maxWidth: 560) // 限制最大宽度，大屏不会过宽
            }

            // 底部按钮栏
            buttonBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .frame(maxWidth: 400)
        #endif
    }

    // MARK: - 顶部导航栏

    private var navBar: some View {
        HStack {
            if viewModel.currentLesson > 0 {
                Button(L10n.shared.t("tutorial.prev")) {
                    viewModel.previousLesson()
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Text(L10n.shared.t(
                "tutorial.progress",
                String(viewModel.currentLesson + 1),
                String(viewModel.lessons.count)
            ))
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
    }

    // MARK: - 底部按钮栏

    private var buttonBar: some View {
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
        .frame(minWidth: 360)
    }
}

// SideSelectionView 已移除（v3.4）：废弃组件
// 功能已被 ToolbarView 内联执边按钮替代
