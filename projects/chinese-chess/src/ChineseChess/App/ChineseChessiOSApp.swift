#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    @State private var gameViewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing: 0) {
                    ToolbarView(viewModel: gameViewModel)

                    BoardView(viewModel: gameViewModel)
                        .padding()

                    StatusBarView(viewModel: gameViewModel)
                }
                .navigationTitle("中国象棋")
                .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)
        }
    }
}
#endif
