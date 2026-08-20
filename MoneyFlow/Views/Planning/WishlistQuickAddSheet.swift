import SwiftUI
import SwiftData

struct WishlistQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTemplate: WishlistTemplate?
    @State private var customAmountString: String = ""
    @State private var showingFullCustomSheet = false

    var onOpenFullCustom: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 顶部引导文案
                    VStack(alignment: .leading, spacing: 4) {
                        Text("选择生活心愿罐")
                            .font(.title2.bold())
                        Text("为心仪的好物、旅行或家庭备用金建立专属存钱罐")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)

                    // 模版网格
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(WishlistTemplate.presets) { preset in
                            Button {
                                createFromTemplate(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: preset.icon)
                                            .font(.title2)
                                            .foregroundStyle(preset.category.themeColor)
                                            .frame(width: 36, height: 36)
                                            .background(preset.category.themeColor.opacity(0.12), in: Circle())

                                        Spacer()

                                        Text(preset.badgeText)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.tertiarySystemFill), in: Capsule())
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(preset.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text("建议预算 ¥\(Int(preset.defaultTargetAmount))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // 自定义心愿入口
                    Button {
                        dismiss()
                        onOpenFullCustom()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                            Text("自定义其他心愿与大额目标...")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
            .background(Color(.systemBackground))
            .navigationTitle("新建生活心愿罐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createFromTemplate(_ preset: WishlistTemplate) {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()

        let goal = FinancialGoal(
            name: preset.name,
            category: preset.category,
            targetAmount: preset.defaultTargetAmount,
            currentEarmarkedAmount: 0,
            priority: .important,
            targetDate: targetDate,
            note: preset.promptDescription
        )
        modelContext.insert(goal)
        try? modelContext.save()
        dismiss()
    }
}
