import SwiftUI

struct PersistenceRecoveryView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onReset: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("暂时无法读取数据")
                    .font(.title2.bold())
                Text("MoneyFlow 没有自动删除任何记录。你可以先重试；只有明确选择重置时，应用才会备份并创建新数据库。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("重新尝试", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Button("备份并重置本地数据", role: .destructive) {
                confirmingReset = true
            }

            DisclosureGroup("技术信息") {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .confirmationDialog("重置本地数据？", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("备份并重置", role: .destructive, action: onReset)
            Button("取消", role: .cancel) {}
        } message: {
            Text("应用会先复制现有数据库到恢复备份目录。只有备份成功后才会删除原数据库。")
        }
    }
}
