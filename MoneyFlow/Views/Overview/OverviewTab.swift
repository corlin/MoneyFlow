import SwiftUI
import SwiftData

struct OverviewTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var accounts: [CashAccount]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var goals: [FinancialGoal]
    @Query private var userSettingsList: [UserSettings]

    @State private var settingsToEdit: UserSettings?
    @State private var showingAddChooser = false
    @State private var showingAddAssetSheet = false
    @State private var showingAddLoanSheet = false
    @State private var showingAddCreditCardSheet = false
    @State private var showingAddGoalSheet = false
    @State private var loanToOpen: Loan?
    @State private var creditCardToEdit: CreditCard?
    @State private var demoError: String?
    @State private var demoLoaded = false

    private var settings: UserSettings? { userSettingsList.first }
    private var rateThreshold: Double { settings?.rateThreshold ?? 0.05 }
    private var warningRatio: Double { settings?.cashFlowWarningRatio ?? 0.70 }
    private var monthlyIncome: Double { settings?.monthlyEstimatedIncome ?? 0 }
    private var monthlyLivingExpense: Double { settings?.monthlyLivingExpense ?? 0 }
    private var emergencyTargetMonths: Int { settings?.emergencyFundMonthsTarget ?? 3 }
    private var totalCash: Double { accounts.reduce(0) { $0 + $1.balance } }
    private var hasAnyData: Bool { !accounts.isEmpty || !loans.isEmpty || !creditCards.isEmpty || !goals.isEmpty }

    private var debtAnalysis: DebtHealthAnalysis {
        RiskAnalyzer.analyze(
            cashAccounts: accounts,
            loans: loans,
            creditCards: creditCards,
            goals: goals,
            rateThreshold: rateThreshold,
            monthlyIncome: monthlyIncome,
            monthlyLivingExpense: monthlyLivingExpense,
            emergencyTargetMonths: emergencyTargetMonths
        )
    }

    private var projectionResult: CashFlowProjectionResult {
        CashFlowProjector.projectAdvancedCashFlow(
            initialCash: totalCash,
            loans: loans,
            creditCards: creditCards,
            goals: goals,
            monthlyIncome: monthlyIncome,
            monthlyLivingExpense: monthlyLivingExpense,
            warningRatio: warningRatio,
            monthsCount: 12,
            assumptions: .default,
            scenario: .baseline
        )
    }

    private var reminders: [UpcomingPaymentReminder] {
        RiskAnalyzer.getUpcomingReminders(
            loans: loans,
            creditCards: creditCards,
            daysAhead: 30
        )
    }

    private var upcomingPaymentSummary: UpcomingPaymentSummary {
        UpcomingPaymentSummary.make(reminders: reminders)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if hasAnyData {
                    populatedOverview
                } else {
                    onboarding
                }
            }
            .background(Color.appBackground)
            .navigationTitle("概览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: prepareSettingsAndShow) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.92, pressedOpacity: 0.75))
                    .accessibilityLabel("设置")
                }
            }
            .confirmationDialog("添加第一笔数据", isPresented: $showingAddChooser, titleVisibility: .visible) {
                Button("添加资产", systemImage: "banknote") { showingAddAssetSheet = true }
                Button("添加贷款", systemImage: "house") { showingAddLoanSheet = true }
                Button("添加信用卡", systemImage: "creditcard") { showingAddCreditCardSheet = true }
                Button("添加规划目标", systemImage: "target") { showingAddGoalSheet = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("选择最方便的一项开始，其余内容以后随时可以补充。")
            }
            .sheet(item: $settingsToEdit) { SettingsView(settings: $0) }
            .sheet(isPresented: $showingAddAssetSheet) { CashAccountForm() }
            .sheet(isPresented: $showingAddLoanSheet) { LoanForm() }
            .sheet(isPresented: $showingAddCreditCardSheet) { CreditCardForm() }
            .sheet(isPresented: $showingAddGoalSheet) {
                GoalFormSheet(
                    goalToEdit: nil,
                    totalCash: totalCash,
                    totalExistingEarmarked: goals.reduce(0) { $0 + $1.currentEarmarkedAmount },
                    activeLoans: loans.filter { $0.remainingPrincipal > 0 },
                    estimatedMonthlyMustPay: projectionResult.currentMonthlyMustPay
                )
            }
            .sheet(item: $loanToOpen) { loan in
                NavigationStack { LoanDetailView(loan: loan, rateThreshold: rateThreshold) }
            }
            .sheet(item: $creditCardToEdit) { CreditCardForm(cardToEdit: $0) }
            .alert("无法载入示例", isPresented: Binding(
                get: { demoError != nil },
                set: { if !$0 { demoError = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(demoError ?? "未知错误")
            }
            .sensoryFeedback(.success, trigger: demoLoaded)
        }
    }

    private var populatedOverview: some View {
        LazyVStack(spacing: 16) {
            // 模块 1: CFP 财务韧性与健康中枢 (整合生命线指标、黄金建议与净现金头寸)
            FinancialResilienceHubView(analysis: debtAnalysis) {
                // 引导用户去规划 tab
            }

            // 模块 2: 12 个月确定性现金流走势图
            CashFlowChart(items: projectionResult.baselineItems, assumptions: .default)

            // 模块 3: 未来 30 天紧迫还款
            if !loans.isEmpty || !creditCards.isEmpty {
                UpcomingPaymentsCard(summary: upcomingPaymentSummary, onSelect: openPaymentSource)
            }
        }
        .padding()
    }

    private var onboarding: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.appPrimary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("看清未来还款压力与目标达成")
                    .font(.title2.bold())
                Text("引入 CFA/CFP 专业视角：记录资产、负债或规划目标，实时获得现金流推演与智能行动建议。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    showingAddChooser = true
                } label: {
                    Label("添加第一笔数据", systemImage: "plus")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.97, pressedOpacity: 0.85))
                .controlSize(.large)

                Button(action: loadDemoData) {
                    Label("载入示例体验", systemImage: "wand.and.stars")
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.97, pressedOpacity: 0.85))
                .controlSize(.large)
            }

            Label("数据仅保存在这台设备上", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private func loadDemoData() {
        do {
            try DemoDataService.load(into: modelContext, replacingExisting: false, persona: .debtRelief)
            AppMotion.perform(level: .momentum, reduceMotion: reduceMotion) {
                demoLoaded.toggle()
            }
        } catch {
            demoError = error.localizedDescription
        }
    }

    private func prepareSettingsAndShow() {
        if let settings {
            settingsToEdit = settings
        } else {
            let created = UserSettings()
            modelContext.insert(created)
            settingsToEdit = created
        }
    }

    private func openPaymentSource(_ reminder: UpcomingPaymentReminder) {
        guard let sourceID = reminder.sourceID else { return }
        if reminder.isLoan {
            loanToOpen = loans.first { $0.id == sourceID }
        } else {
            creditCardToEdit = creditCards.first { $0.id == sourceID }
        }
    }
}
