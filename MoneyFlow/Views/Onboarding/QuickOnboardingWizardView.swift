import SwiftUI
import SwiftData

struct QuickOnboardingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var userSettingsList: [UserSettings]

    @State private var cashAmountString: String = "30000"
    @State private var monthlyIncomeString: String = "12000"
    @State private var monthlyDebtString: String = "4000"
    @State private var livingExpenseString: String = "3500"
    @State private var payday: Int = 15

    var onFinished: (() -> Void)? = nil

    private var cashAmount: Double {
        FinancialInputParser.number(from: cashAmountString) ?? 0
    }

    private var monthlyIncome: Double {
        FinancialInputParser.number(from: monthlyIncomeString) ?? 0
    }

    private var monthlyDebt: Double {
        FinancialInputParser.number(from: monthlyDebtString) ?? 0
    }

    private var livingExpense: Double {
        FinancialInputParser.number(from: livingExpenseString) ?? 0
    }

    // 实时大白话预估
    private var estimatedMonthlySurplus: Double {
        max(0, monthlyIncome - monthlyDebt - livingExpense)
    }

    private var estimatedDailySafeSpend: Double {
        max(0, (cashAmount + estimatedMonthlySurplus * 0.5) / 30.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部引导欢迎横幅
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.appPrimary)
                            .symbolRenderingMode(.hierarchical)

                        Text("30秒生成您的余钱晴雨表")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("无需复杂记账，只需填写 3 个大概数字，即可一眼看清每天能花多少钱与还贷压力。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)

                    // 实时大白话预估卡片
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("极速生成预览", systemImage: "sparkles")
                                .font(.caption.bold())
                                .foregroundStyle(Color.appPrimary)
                            Spacer()
                            Text("安心花 🟢")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.12), in: Capsule())
                                .foregroundStyle(.green)
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("预计今日安全可花")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("¥\(Int(estimatedDailySafeSpend))")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.appPrimary)
                                    .monospacedDigit()
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("每月预计净存钱")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("¥\(Int(estimatedMonthlySurplus))")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    // 3 步极简输入项
                    VStack(spacing: 14) {
                        inputCard(
                            step: "1",
                            title: "目前手头有多少活钱？",
                            subtitle: "微信、支付宝、银行活期存款总和",
                            icon: "banknote.fill",
                            iconColor: .blue,
                            text: $cashAmountString,
                            placeholder: "30000",
                            unit: "元"
                        )

                        inputCard(
                            step: "2",
                            title: "每月大概到手收入多少？",
                            subtitle: "工资实发或稳定月度收入",
                            icon: "arrow.down.left.circle.fill",
                            iconColor: .green,
                            text: $monthlyIncomeString,
                            placeholder: "12000",
                            unit: "元/月"
                        )

                        inputCard(
                            step: "3",
                            title: "每月固定还款大概多少？",
                            subtitle: "房贷、车贷或信用卡待还月供（没有填0）",
                            icon: "house.fill",
                            iconColor: .orange,
                            text: $monthlyDebtString,
                            placeholder: "4000",
                            unit: "元/月"
                        )
                    }

                    // 提交按钮
                    Button(action: generateAndFinish) {
                        HStack {
                            Text("生成我的余钱晴雨表")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color.appPrimary)
                    .padding(.top, 6)

                    Text("生成后可在 App 内随时补充具体银行卡、贷款明细或调整数字。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func inputCard(
        step: String,
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        text: Binding<String>,
        placeholder: String,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Text("第 \(step) 步")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("¥")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: text)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .keyboardType(.numberPad)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func generateAndFinish() {
        // 1. 初始化现金账户
        let account = CashAccount(
            name: "常用资金账户",
            balance: max(0, cashAmount),
            icon: "banknote.fill",
            note: "新手向导快速创建"
        )
        modelContext.insert(account)

        // 2. 初始化负债贷款（若有）
        if monthlyDebt > 0 {
            let loan = Loan(
                name: "房贷/固定月供",
                category: .mortgage,
                totalAmount: monthlyDebt * 240,
                remainingPrincipal: monthlyDebt * 200,
                annualRate: 0.035,
                repaymentMethod: .equalPayment,
                totalPeriods: 240,
                paidPeriods: 20,
                monthlyPayment: monthlyDebt,
                paymentDayOfMonth: 20,
                note: "新手向导快速创建"
            )
            modelContext.insert(loan)
        }

        // 3. 更新用户设置
        let living = livingExpense > 0 ? livingExpense : max(2500, monthlyIncome * 0.3)
        if let settings = userSettingsList.first {
            settings.monthlyEstimatedIncome = monthlyIncome
            settings.monthlyLivingExpense = living
            settings.paydayOfMonth = payday
        } else {
            let settings = UserSettings(
                monthlyEstimatedIncome: monthlyIncome,
                paydayOfMonth: payday,
                monthlyLivingExpense: living
            )
            modelContext.insert(settings)
        }

        try? modelContext.save()
        onFinished?()
        dismiss()
    }
}
