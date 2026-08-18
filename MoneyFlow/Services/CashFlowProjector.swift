import Foundation

struct MonthlyCashFlowItem: Identifiable, Equatable {
    var id: String { monthLabel }
    let date: Date                  // 所在月份第一天
    let monthLabel: String          // 如 "8月" 或 "2026-08"
    let startingCash: Double       // 期初现金资产
    let estimatedIncome: Double    // 当月预计收入
    let monthlyLivingExpense: Double // 当月刚性基础生活支出
    let loanPayment: Double        // 贷款还款支出 (本+息)
    let creditCardPayment: Double  // 信用卡欠款偿还
    let totalMustPay: Double       // 当月刚性总支出 (生活 + 房贷车贷 + 信用卡)
    let monthlySurplus: Double      // 当月净自由结余 (收入 - 刚性总支出)
    let goalIrrigation: Double     // 当月注入多目标的资金
    let strategyExtraPayment: Double // 当月策略提前偿还的本金
    let endingCash: Double         // 期末预计现金资产
    let isWarning: Bool             // 是否超出预警比例或现金不足
    let scenarioEndingCash: Double? // 情景模拟下的期末现金（双轨对比）

    init(
        date: Date,
        monthLabel: String,
        startingCash: Double,
        estimatedIncome: Double,
        monthlyLivingExpense: Double = 0,
        loanPayment: Double,
        creditCardPayment: Double,
        totalMustPay: Double,
        monthlySurplus: Double = 0,
        goalIrrigation: Double = 0,
        strategyExtraPayment: Double = 0,
        endingCash: Double,
        isWarning: Bool,
        scenarioEndingCash: Double? = nil
    ) {
        self.date = date
        self.monthLabel = monthLabel
        self.startingCash = startingCash
        self.estimatedIncome = estimatedIncome
        self.monthlyLivingExpense = monthlyLivingExpense
        self.loanPayment = loanPayment
        self.creditCardPayment = creditCardPayment
        self.totalMustPay = totalMustPay
        self.monthlySurplus = monthlySurplus
        self.goalIrrigation = goalIrrigation
        self.strategyExtraPayment = strategyExtraPayment
        self.endingCash = endingCash
        self.isWarning = isWarning
        self.scenarioEndingCash = scenarioEndingCash
    }
}

struct ProjectionAssumptions: Equatable {
    let includesMonthlyIncome: Bool
    let paysCurrentCreditCardBalanceInFirstMonth: Bool

    static let `default` = ProjectionAssumptions(
        includesMonthlyIncome: true,
        paysCurrentCreditCardBalanceInFirstMonth: true
    )

    var disclosureText: String {
        let income = includesMonthlyIncome ? "计入设置中的每月预计收入" : "不计未来收入"
        let creditCard = paysCurrentCreditCardBalanceInFirstMonth ? "当前信用卡欠款在首月偿还" : "信用卡欠款不自动计入"
        return "假设：\(income)；\(creditCard)。"
    }

    init(includesMonthlyIncome: Bool = true, paysCurrentCreditCardBalanceInFirstMonth: Bool = true) {
        self.includesMonthlyIncome = includesMonthlyIncome
        self.paysCurrentCreditCardBalanceInFirstMonth = paysCurrentCreditCardBalanceInFirstMonth
    }
}

struct CashFlowProjectionResult: Equatable {
    let baselineItems: [MonthlyCashFlowItem]
    let scenarioItems: [MonthlyCashFlowItem]
    let troughBalance: Double
    let troughMonthLabel: String
    let emergencyCoverageMonths: Double
    let strategyInterestSaved: Double
    let strategyMonthsSaved: Int
    let goalSummary: MultiGoalSummary
    let scenarioGoalSummary: MultiGoalSummary

    var currentMonthlyMustPay: Double {
        baselineItems.first?.totalMustPay ?? 0
    }
}

enum CashFlowProjector {

    /// 兼容旧接口：快速预测未来 N 个月现金流
    static func projectCashFlow(
        initialCash: Double,
        loans: [Loan],
        creditCards: [CreditCard],
        warningRatio: Double = 0.70,
        monthsCount: Int = 12,
        monthlyIncome: Double = 0,
        assumptions: ProjectionAssumptions = .default
    ) -> [MonthlyCashFlowItem] {
        let result = projectAdvancedCashFlow(
            initialCash: initialCash,
            loans: loans,
            creditCards: creditCards,
            goals: [],
            monthlyIncome: monthlyIncome,
            monthlyLivingExpense: 0,
            warningRatio: warningRatio,
            monthsCount: monthsCount,
            assumptions: assumptions,
            scenario: .baseline
        )
        return result.baselineItems
    }

    /// 专业 CFP 双轨推演与动态沙盘计算引擎
    static func projectAdvancedCashFlow(
        initialCash: Double,
        loans: [Loan],
        creditCards: [CreditCard],
        goals: [FinancialGoal] = [],
        monthlyIncome: Double = 0,
        monthlyLivingExpense: Double = 0,
        warningRatio: Double = 0.70,
        monthsCount: Int = 12,
        assumptions: ProjectionAssumptions = .default,
        scenario: PlanningScenario = .baseline
    ) -> CashFlowProjectionResult {
        let now = Date()
        let calendar = Calendar.current

        // 1. 基准轨推演 (Baseline)
        let baselineItems = runProjection(
            initialCash: initialCash,
            loans: loans,
            creditCards: creditCards,
            monthlyIncome: monthlyIncome,
            monthlyLivingExpense: monthlyLivingExpense,
            warningRatio: warningRatio,
            monthsCount: monthsCount,
            assumptions: assumptions,
            scenario: .baseline,
            startDate: now,
            calendar: calendar
        )

        // 2. 情景轨推演 (Scenario)
        let scenarioItems = runProjection(
            initialCash: initialCash,
            loans: loans,
            creditCards: creditCards,
            monthlyIncome: monthlyIncome,
            monthlyLivingExpense: monthlyLivingExpense,
            warningRatio: warningRatio,
            monthsCount: monthsCount,
            assumptions: assumptions,
            scenario: scenario,
            startDate: now,
            calendar: calendar
        )

        // 将情景轨期末现金融合进基准轨（以便图表渲染双轨对比）
        var mergedBaselineItems: [MonthlyCashFlowItem] = []
        for i in 0..<baselineItems.count {
            let base = baselineItems[i]
            let scenEnding = i < scenarioItems.count ? scenarioItems[i].endingCash : nil
            mergedBaselineItems.append(MonthlyCashFlowItem(
                date: base.date,
                monthLabel: base.monthLabel,
                startingCash: base.startingCash,
                estimatedIncome: base.estimatedIncome,
                monthlyLivingExpense: base.monthlyLivingExpense,
                loanPayment: base.loanPayment,
                creditCardPayment: base.creditCardPayment,
                totalMustPay: base.totalMustPay,
                monthlySurplus: base.monthlySurplus,
                goalIrrigation: base.goalIrrigation,
                strategyExtraPayment: base.strategyExtraPayment,
                endingCash: base.endingCash,
                isWarning: base.isWarning,
                scenarioEndingCash: scenEnding
            ))
        }

        // 3. 计算最低现金筑底水位 (Trough)
        var minCash = initialCash
        var minMonthLabel = "当前"
        for item in (scenario.isModifiedFromBaseline ? scenarioItems : mergedBaselineItems) {
            if item.endingCash < minCash {
                minCash = item.endingCash
                minMonthLabel = item.monthLabel
            }
        }

        // 4. 计算流动性应急覆盖月数 (Emergency Coverage Months)
        let firstMonthMustPay = (mergedBaselineItems.first?.totalMustPay ?? 0)
        let emergencyCoverage: Double
        if firstMonthMustPay > 0 {
            emergencyCoverage = initialCash / firstMonthMustPay
        } else {
            emergencyCoverage = initialCash > 0 ? 99.0 : 0.0
        }

        // 5. 多目标动态灌溉推演
        let baselineSurpluses = mergedBaselineItems.map { $0.monthlySurplus }
        let scenarioSurpluses = scenarioItems.map { $0.monthlySurplus }
        let monthDates = mergedBaselineItems.map { $0.date }

        let goalSummary = MultiGoalEngine.projectGoals(
            totalCash: initialCash,
            monthlySurpluses: baselineSurpluses,
            monthDates: monthDates,
            goals: goals
        )

        let scenarioGoalSummary = MultiGoalEngine.projectGoals(
            totalCash: initialCash,
            monthlySurpluses: scenarioSurpluses,
            monthDates: monthDates,
            goals: goals
        )

        // 6. 提前还贷策略省息与提速计算
        let (savedInterest, savedMonths) = calculateStrategySavings(
            loans: loans,
            monthlySurpluses: baselineSurpluses,
            scenario: scenario
        )

        return CashFlowProjectionResult(
            baselineItems: mergedBaselineItems,
            scenarioItems: scenarioItems,
            troughBalance: minCash,
            troughMonthLabel: minMonthLabel,
            emergencyCoverageMonths: emergencyCoverage,
            strategyInterestSaved: savedInterest,
            strategyMonthsSaved: savedMonths,
            goalSummary: goalSummary,
            scenarioGoalSummary: scenarioGoalSummary
        )
    }

    private static func runProjection(
        initialCash: Double,
        loans: [Loan],
        creditCards: [CreditCard],
        monthlyIncome: Double,
        monthlyLivingExpense: Double,
        warningRatio: Double,
        monthsCount: Int,
        assumptions: ProjectionAssumptions,
        scenario: PlanningScenario,
        startDate: Date,
        calendar: Calendar
    ) -> [MonthlyCashFlowItem] {
        var items: [MonthlyCashFlowItem] = []
        var runningCash = initialCash
        let initialCreditCardDebt = creditCards.reduce(0.0) { $0 + $1.currentBalance }

        let loanSchedules: [(loan: Loan, schedule: [RepaymentScheduleItem])] = loans.map { loan in
            let summary = RepaymentCalculator.calculateSchedule(
                principal: loan.totalAmount,
                annualRate: loan.annualRate,
                totalPeriods: loan.totalPeriods,
                method: loan.repaymentMethod,
                startDate: loan.startDate,
                paymentDay: loan.paymentDayOfMonth
            )
            return (loan, summary.schedule)
        }

        // 应用情景调整
        let effectiveIncomeBase = assumptions.includesMonthlyIncome
            ? max(0.0, monthlyIncome * (1.0 + scenario.incomeAdjustmentPct))
            : 0.0
        let effectiveLivingExpenseBase = max(0.0, monthlyLivingExpense + scenario.livingExpenseAdjustment)

        for monthIndex in 0..<monthsCount {
            guard let targetDate = calendar.date(byAdding: .month, value: monthIndex, to: startDate) else { continue }
            let monthLabel = targetDate.monthShortString
            let startCashThisMonth = runningCash

            // 贷款固定月供
            var loanPaymentThisMonth: Double = 0
            for item in loanSchedules {
                let loan = item.loan
                let schedule = item.schedule
                let targetPeriodIndex = loan.paidPeriods + monthIndex + 1
                if targetPeriodIndex <= loan.totalPeriods {
                    if let schedItem = schedule.first(where: { $0.period == targetPeriodIndex }) {
                        loanPaymentThisMonth += schedItem.monthlyPayment
                    } else if loan.monthlyPayment > 0 {
                        loanPaymentThisMonth += loan.monthlyPayment
                    }
                }
            }

            // 信用卡欠款
            let ccPaymentThisMonth: Double = (assumptions.paysCurrentCreditCardBalanceInFirstMonth && monthIndex == 0)
                ? initialCreditCardDebt
                : 0.0

            // 突发支出
            let lumpSumThisMonth = (scenario.lumpSumExpense > 0 && scenario.lumpSumExpenseMonth == monthIndex)
                ? scenario.lumpSumExpense
                : 0.0

            let mustPayThisMonth = effectiveLivingExpenseBase + loanPaymentThisMonth + ccPaymentThisMonth + lumpSumThisMonth
            let grossIncomeThisMonth = effectiveIncomeBase

            // 当月结余
            let surplusThisMonth = max(0.0, grossIncomeThisMonth - mustPayThisMonth)

            // 期末现金
            let endCashThisMonth = startCashThisMonth + grossIncomeThisMonth - mustPayThisMonth

            // 预警判定
            let isWarning: Bool
            if startCashThisMonth <= 0 {
                isWarning = mustPayThisMonth > 0
            } else {
                let ratio = mustPayThisMonth / startCashThisMonth
                isWarning = ratio >= warningRatio || endCashThisMonth < 0
            }

            items.append(MonthlyCashFlowItem(
                date: targetDate,
                monthLabel: monthLabel,
                startingCash: startCashThisMonth,
                estimatedIncome: grossIncomeThisMonth,
                monthlyLivingExpense: effectiveLivingExpenseBase,
                loanPayment: loanPaymentThisMonth,
                creditCardPayment: ccPaymentThisMonth,
                totalMustPay: mustPayThisMonth,
                monthlySurplus: surplusThisMonth,
                goalIrrigation: 0,
                strategyExtraPayment: 0,
                endingCash: endCashThisMonth,
                isWarning: isWarning
            ))

            runningCash = endCashThisMonth
        }

        return items
    }

    /// 估算雪崩法/滚雪球法相对于标准还款的利息节省与提前月数
    private static func calculateStrategySavings(
        loans: [Loan],
        monthlySurpluses: [Double],
        scenario: PlanningScenario
    ) -> (savedInterest: Double, savedMonths: Int) {
        guard scenario.repaymentStrategy != .standard, !loans.isEmpty else {
            return (0.0, 0)
        }

        // 获取当前所有有剩余本金的贷款
        let activeLoans = loans.filter { $0.remainingPrincipal > 0 }
        guard !activeLoans.isEmpty else { return (0.0, 0) }

        // 计算基准总利息
        var baselineTotalInterest: Double = 0
        var maxBaselinePeriods = 0
        for loan in activeLoans {
            let remPeriods = max(1, loan.totalPeriods - loan.paidPeriods)
            let summary = RepaymentCalculator.calculateSchedule(
                principal: loan.remainingPrincipal,
                annualRate: loan.annualRate,
                totalPeriods: remPeriods,
                method: loan.repaymentMethod
            )
            baselineTotalInterest += summary.totalInterest
            maxBaselinePeriods = max(maxBaselinePeriods, remPeriods)
        }

        let avgMonthlySurplus = monthlySurpluses.isEmpty ? 0 : monthlySurpluses.reduce(0, +) / Double(monthlySurpluses.count)
        let extraMonthlyFund = avgMonthlySurplus * scenario.debtSurplusAllocationRatio

        guard extraMonthlyFund > 50 else {
            return (0.0, 0)
        }

        // 根据策略排序
        let sortedLoans: [Loan]
        switch scenario.repaymentStrategy {
        case .avalanche:
            sortedLoans = activeLoans.sorted { $0.annualRate > $1.annualRate }
        case .snowball:
            sortedLoans = activeLoans.sorted { $0.remainingPrincipal < $1.remainingPrincipal }
        case .standard:
            sortedLoans = activeLoans
        }

        // 简化的多贷款加速摊销仿真
        var remainingBalances = sortedLoans.map { $0.remainingPrincipal }
        var rates = sortedLoans.map { $0.annualRate / 12.0 }
        var monthlyPayments = sortedLoans.map { $0.monthlyPayment }
        var simulatedInterest: Double = 0
        var monthsElapsed = 0
        let maxSimulationMonths = 360

        while remainingBalances.reduce(0, +) > 1.0 && monthsElapsed < maxSimulationMonths {
            monthsElapsed += 1
            var extraBudget = extraMonthlyFund

            for i in 0..<remainingBalances.count {
                guard remainingBalances[i] > 0 else { continue }
                let interestPart = remainingBalances[i] * rates[i]
                simulatedInterest += interestPart

                var normalPrincipal = max(0, monthlyPayments[i] - interestPart)
                if normalPrincipal > remainingBalances[i] {
                    normalPrincipal = remainingBalances[i]
                }
                remainingBalances[i] -= normalPrincipal

                // 加速额外偿还
                if extraBudget > 0 && remainingBalances[i] > 0 {
                    let extraPay = min(extraBudget, remainingBalances[i])
                    remainingBalances[i] -= extraPay
                    extraBudget -= extraPay
                }
            }
        }

        let savedInterest = max(0.0, baselineTotalInterest - simulatedInterest)
        let savedMonths = max(0, maxBaselinePeriods - monthsElapsed)

        return (savedInterest, savedMonths)
    }
}
