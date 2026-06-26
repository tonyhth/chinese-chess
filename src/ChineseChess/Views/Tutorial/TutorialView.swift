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
                    Button("上一步") {
                        viewModel.previousLesson()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Text("新手教程 \(viewModel.currentLesson + 1)/\(viewModel.lessons.count)")
                    .font(.headline)

                Spacer()

                Button("跳过") {
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
                    Button("完成教程") {
                        TutorialViewModel.markTutorialCompleted()
                        onComplete?()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("下一课") {
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
                Text("💡 提示")
                    .font(.headline)
                Text("在对局中点击你的棋子，绿色圆点表示可移动的位置。")
                    .foregroundColor(.secondary)
                Text("注意：马有蹩脚、象有塞眼，不是所有方向都能走！")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

        case 1:
            // 第 2 课：将军提示
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 练习")
                    .font(.headline)
                Text("开始一局对弈，AI 会对你将军。尝试用不同方式应将。")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

        case 2:
            // 第 3 课：将死练习
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 一步杀")
                    .font(.headline)
                Text("进入残局模式，尝试找到将死的走法。")
                    .foregroundColor(.secondary)
                Text("关键：不仅要将军，还要让对方无法应将！")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

        case 3:
            // 第 4 课：特殊规则
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ 重要区分")
                    .font(.headline)
                HStack {
                    Text("困毙")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("= 判负（输棋）")
                        .foregroundColor(.red)
                }
                HStack {
                    Text("长将/长捉")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("= 和棋")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

        case 4:
            // 第 5 课：实战
            VStack(alignment: .leading, spacing: 8) {
                Text("🎮 准备好了！")
                    .font(.headline)
                Text("完成教程后，点击「新对局」开始实战。")
                    .foregroundColor(.secondary)
                Text("新手难度 AI 会陪你练习，善用「提示」功能学习开局。")
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

            Text("欢迎使用中国象棋！")
                .font(.title2)
                .fontWeight(.bold)

            Text("你是否熟悉中国象棋的规则？")
                .font(.body)

            HStack(spacing: 16) {
                Button("不太熟悉") {
                    onShowTutorial()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("已了解") {
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
