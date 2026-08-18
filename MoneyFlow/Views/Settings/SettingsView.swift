import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var settings: UserSettings
    @Query private var accounts: [CashAccount]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]

    @State private var monthlyIncomeText = ""
    @State private var showingResetAlert = false
    @State private var showingDemoAlert = false
    @State private var errorMessage: String?
    @State private var saveSucceeded = false

    private var export: FinancialDataExport? {
        try? FinancialDataExport.make(accounts: accounts, loans: loans, cards: creditCards)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("预测假设") {
                    HStack {
                        Text("每月预计收入")
                        Spacer()
                        TextField("0.00", text: $monthlyIncomeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("每月预计收入")
                    }
                    Label(ProjectionAssumptions.default.disclosureText, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("利率关注基准") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("基准利率上限") {
                            Text(String(format: "%.1f%%", settings.rateThreshold * 100))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { settings.rateThreshold * 100 },
                                set: { settings.rateThreshold = $0 / 100 }
                            ),
                            in: 2...12,
                            step: 0.1
                        )
                        .tint(.appHealthyDebt)
                        Text("低于该基准的贷款显示为“低于基准”，其他贷款显示为“需关注”。这只是你的自定义分类，不构成财务建议。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("现金提醒") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("单月支出警戒线") {
                            Text("\(Int(settings.cashFlowWarningRatio * 100))%")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { settings.cashFlowWarningRatio * 100 },
                                set: { settings.cashFlowWarningRatio = $0 / 100 }
                            ),
                            in: 30...95,
                            step: 5
                        )
                        .tint(.appWarningDebt)
                    }
                    Stepper("提前 \(settings.reminderDaysBefore) 天提醒", value: $settings.reminderDaysBefore, in: 1...15)
                }

                Section {
                    if let export {
                        ShareLink(item: export, preview: SharePreview("MoneyFlow 本地备份", image: Image(systemName: "doc.badge.arrow.up"))) {
                            Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("当前数据无法导出", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingDemoAlert = true
                    } label: {
                        Label("用示例数据替换当前记录", systemImage: "wand.and.stars")
                    }

                    Button("清空所有数据", systemImage: "trash", role: .destructive) {
                        showingResetAlert = true
                    }
                } header: {
                    Text("数据与恢复")
                } footer: {
                    Text("建议在清空或替换前先导出备份。导出的文件由你决定保存或分享到哪里。")
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.0.0 (Build 1)")
                    LabeledContent("核心理念", value: "清晰偿债 · 操作可恢复")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: saveAndDismiss)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                monthlyIncomeText = settings.monthlyEstimatedIncome.formatted(.number.precision(.fractionLength(0...2)))
            }
            .alert("替换为示例数据？", isPresented: $showingDemoAlert) {
                Button("替换", role: .destructive, action: loadDemoData)
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前资产、贷款和信用卡记录会被示例数据替换。请先导出备份。")
            }
            .alert("清空所有数据？", isPresented: $showingResetAlert) {
                Button("清空", role: .destructive, action: clearAllData)
                Button("取消", role: .cancel) {}
            } message: {
                Text("资产、贷款和信用卡记录将被删除。请先导出备份。")
            }
            .sensoryFeedback(.success, trigger: saveSucceeded)
        }
    }

    private func saveAndDismiss() {
        guard let income = FinancialInputParser.number(from: monthlyIncomeText), income >= 0 else {
            errorMessage = "请输入有效的每月预计收入。"
            return
        }
        settings.monthlyEstimatedIncome = income
        settings.updatedAt = Date()
        do {
            try modelContext.save()
            saveSucceeded.toggle()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "设置保存失败：\(error.localizedDescription)"
        }
    }

    private func clearAllData() {
        do {
            for account in accounts { modelContext.delete(account) }
            for loan in loans { modelContext.delete(loan) }
            for card in creditCards { modelContext.delete(card) }
            try modelContext.save()
            saveSucceeded.toggle()
        } catch {
            modelContext.rollback()
            errorMessage = "清空失败：\(error.localizedDescription)"
        }
    }

    private func loadDemoData() {
        do {
            try DemoDataService.load(into: modelContext, replacingExisting: true)
            saveSucceeded.toggle()
        } catch {
            errorMessage = "示例数据载入失败：\(error.localizedDescription)"
        }
    }
}
