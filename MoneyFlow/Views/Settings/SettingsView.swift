import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var settings: UserSettings
    @Query private var accounts: [CashAccount]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var goals: [FinancialGoal]

    @State private var monthlyIncomeText = ""
    @State private var monthlyLivingExpenseText = ""
    @State private var showingResetAlert = false
    @State private var selectedDemoPersona: DemoPersona? = nil
    @State private var errorMessage: String?
    @State private var saveSucceeded = false

    private var export: FinancialDataExport? {
        try? FinancialDataExport.make(accounts: accounts, loans: loans, cards: creditCards, goals: goals)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("CFP 现金流与生活基准") {
                    HStack {
                        Text("每月预计净收入")
                        Spacer()
                        TextField("0.00", text: $monthlyIncomeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("每月预计收入")
                    }

                    HStack {
                        Text("每月刚性生活支出基准")
                        Spacer()
                        TextField("0.00", text: $monthlyLivingExpenseText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("每月生活支出基准")
                    }

                    Stepper("目标应急缓冲：\(settings.emergencyFundMonthsTarget) 个月", value: $settings.emergencyFundMonthsTarget, in: 1...12)

                    Text("用于计算自由结余、应急储备水位与 DSR 偿债承载力。")
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
                        Text("低于该基准的贷款显示为“低于基准”，其他贷款显示为“需关注”。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("现金预警") {
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

                Section("安全与隐私保护") {
                    Toggle(isOn: $settings.isBiometricLockEnabled) {
                        Label("开启\(BiometricLockService.shared.availableBiometryType.title)保护", systemImage: BiometricLockService.shared.availableBiometryType.systemImage)
                    }

                    if settings.isBiometricLockEnabled {
                        Picker("自动锁定时间", selection: $settings.autoLockIntervalSeconds) {
                            Text("立即锁定").tag(0)
                            Text("离开 1 分钟后").tag(60)
                            Text("离开 5 分钟后").tag(300)
                        }

                        Button("立即锁定 App", systemImage: "lock.fill") {
                            BiometricLockService.shared.lockNow()
                            dismiss()
                        }
                    }
                }

                Section("还款提醒与通知") {
                    Toggle("开启本地还款提醒", isOn: $settings.isPaymentReminderEnabled)
                        .onChange(of: settings.isPaymentReminderEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    await NotificationService.shared.requestAuthorization()
                                    NotificationService.shared.scheduleAllReminders(
                                        loans: loans,
                                        creditCards: creditCards,
                                        isEnabled: true,
                                        daysBefore: settings.reminderDaysBefore
                                    )
                                }
                            } else {
                                NotificationService.shared.cancelAllReminders()
                            }
                        }

                    if settings.isPaymentReminderEnabled {
                        Stepper("提前 \(settings.reminderDaysBefore) 天预警", value: $settings.reminderDaysBefore, in: 1...10)
                            .onChange(of: settings.reminderDaysBefore) { _, newDays in
                                NotificationService.shared.scheduleAllReminders(
                                    loans: loans,
                                    creditCards: creditCards,
                                    isEnabled: true,
                                    daysBefore: newDays
                                )
                            }
                        Text("将在还款日前 \(settings.reminderDaysBefore) 天上午 09:30 及还款日当天上午 09:00 发送本地通知。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("专业演示画像切换") {
                    Button {
                        selectedDemoPersona = .debtRelief
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("画像 1：负债突围与安全筑底", systemImage: "bolt.shield.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("高 DSR、7.2% 装修高息贷、体验雪崩法加速省息与建立应急金")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        selectedDemoPersona = .multiGoalGrowth
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("画像 2：多目标稳健积累", systemImage: "chart.line.uptrend.xyaxis.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("充裕结余、公积金贷、3 大梯队目标（应急金/车/首付）动态灌溉")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
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

                    Button("清空所有数据", systemImage: "trash", role: .destructive) {
                        showingResetAlert = true
                    }
                } header: {
                    Text("数据管理与备份")
                } footer: {
                    Text("建议在清空或替换前先导出备份。所有数据仅保存在本地设备。")
                }

                Section("关于") {
                    LabeledContent("版本", value: "2.0.0 (CFP Dynamic Suite)")
                    LabeledContent("规划模型", value: "GBWM 目标导向 · 瀑布流沙盘")
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
                monthlyLivingExpenseText = settings.monthlyLivingExpense.formatted(.number.precision(.fractionLength(0...2)))
            }
            .confirmationDialog(
                "载入演示画像？",
                isPresented: Binding(get: { selectedDemoPersona != nil }, set: { if !$0 { selectedDemoPersona = nil } }),
                titleVisibility: .visible
            ) {
                if let persona = selectedDemoPersona {
                    Button("确认载入：\(persona.shortTitle)", role: .destructive) {
                        loadDemoPersona(persona)
                    }
                }
                Button("取消", role: .cancel) { selectedDemoPersona = nil }
            } message: {
                Text("当前所有数据将被该画像替换。请确认是否继续。")
            }
            .alert("清空所有数据？", isPresented: $showingResetAlert) {
                Button("清空", role: .destructive, action: clearAllData)
                Button("取消", role: .cancel) {}
            } message: {
                Text("资产、贷款、信用卡与规划目标记录将被删除。请先导出备份。")
            }
            .sensoryFeedback(.success, trigger: saveSucceeded)
        }
    }

    private func saveAndDismiss() {
        guard let income = FinancialInputParser.number(from: monthlyIncomeText), income >= 0 else {
            errorMessage = "请输入有效的每月预计收入。"
            return
        }

        let livingExpense = FinancialInputParser.number(from: monthlyLivingExpenseText) ?? 0.0
        guard livingExpense >= 0 else {
            errorMessage = "请输入有效的每月刚性生活支出。"
            return
        }

        settings.monthlyEstimatedIncome = income
        settings.monthlyLivingExpense = livingExpense
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
            for goal in goals { modelContext.delete(goal) }
            try modelContext.save()
            saveSucceeded.toggle()
        } catch {
            modelContext.rollback()
            errorMessage = "清空失败：\(error.localizedDescription)"
        }
    }

    private func loadDemoPersona(_ persona: DemoPersona) {
        do {
            try DemoDataService.load(into: modelContext, replacingExisting: true, persona: persona)
            saveSucceeded.toggle()
            dismiss()
        } catch {
            errorMessage = "演示画像载入失败：\(error.localizedDescription)"
        }
    }
}
