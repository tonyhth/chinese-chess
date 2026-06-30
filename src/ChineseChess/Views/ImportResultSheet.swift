import SwiftUI

struct ImportResultSheet: View {
    let result: ImportResult
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var showDetail = false
    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(l10n.t("import.resultTitle"))
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            // 统计
            HStack(spacing: 20) {
                VStack {
                    Text("\(result.records.count)")
                        .font(.title.weight(.bold))
                        .foregroundColor(.green)
                    Text(l10n.t("import.successCount"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if result.skippedCount > 0 {
                    VStack {
                        Text("\(result.skippedCount)")
                            .font(.title.weight(.bold))
                            .foregroundColor(.orange)
                        Text(l10n.t("import.skippedCount"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 警告列表
            if result.hasWarnings {
                Button {
                    showDetail.toggle()
                } label: {
                    Label(l10n.t("import.viewDetails"), systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

                if showDetail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.warnings, id: \.self) { warning in
                                Text("· \(warning)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            // 操作按钮
            HStack(spacing: 16) {
                Button(l10n.t("common.cancel")) {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.brown)

                Button(l10n.t("import.confirm")) {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .disabled(result.records.isEmpty)
            }
        }
        .padding(20)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(12)
    }
}
