import Foundation

struct LiquidityBufferSummary: Equatable {
    let coveredMonths: Int
    let horizonMonths: Int
    let firstShortfall: MonthlyCashFlowItem?
    let minimumBalance: Double
    let hasMonthlyIncomeAssumption: Bool

    static func make(items: [MonthlyCashFlowItem], monthlyIncome: Double) -> LiquidityBufferSummary {
        let firstShortfall = items.first { $0.endingCash < 0 }
        let coveredMonths = items.prefix { $0.endingCash >= 0 }.count

        return LiquidityBufferSummary(
            coveredMonths: coveredMonths,
            horizonMonths: items.count,
            firstShortfall: firstShortfall,
            minimumBalance: items.map(\.endingCash).min() ?? 0,
            hasMonthlyIncomeAssumption: monthlyIncome > 0
        )
    }
}

struct DebtProgressSummary: Equatable {
    let currentDebt: Double
    let projectedPrincipalReduction: Double
    let projectedRemainingDebt: Double
    let remainingRatio: Double

    static func make(
        loans: [Loan],
        creditCards: [CreditCard],
        horizonMonths: Int = 12
    ) -> DebtProgressSummary {
        let loanDebt = loans.reduce(0) { $0 + max(0, $1.remainingPrincipal) }
        let cardDebt = creditCards.reduce(0) { $0 + max(0, $1.currentBalance) }
        let currentDebt = loanDebt + cardDebt

        let scheduledLoanReduction = loans.reduce(0.0) { partialResult, loan in
            let schedule = RepaymentCalculator.calculateSchedule(
                principal: loan.totalAmount,
                annualRate: loan.annualRate,
                totalPeriods: loan.totalPeriods,
                method: loan.repaymentMethod,
                startDate: loan.startDate,
                paymentDay: loan.paymentDayOfMonth
            ).schedule
            let endPeriod = min(loan.totalPeriods, loan.paidPeriods + max(0, horizonMonths))
            let reduction = schedule
                .filter { $0.period > loan.paidPeriods && $0.period <= endPeriod }
                .reduce(0) { $0 + $1.principal }
            return partialResult + min(max(0, loan.remainingPrincipal), reduction)
        }

        // 现金流预测把已记录信用卡欠款作为首月应还，因此同步计入预测本金减少。
        let projectedReduction = min(currentDebt, scheduledLoanReduction + cardDebt)
        let projectedRemaining = max(0, currentDebt - projectedReduction)

        return DebtProgressSummary(
            currentDebt: currentDebt,
            projectedPrincipalReduction: projectedReduction,
            projectedRemainingDebt: projectedRemaining,
            remainingRatio: currentDebt > 0 ? projectedRemaining / currentDebt : 0
        )
    }
}

struct UpcomingPaymentSummary: Equatable {
    let horizonDays: Int
    let totalAmount: Double
    let totalCount: Int
    let visibleReminders: [UpcomingPaymentReminder]

    static func make(
        reminders: [UpcomingPaymentReminder],
        horizonDays: Int = 30,
        visibleLimit: Int = 3
    ) -> UpcomingPaymentSummary {
        let included = reminders
            .filter { $0.daysRemaining >= 0 && $0.daysRemaining <= horizonDays }
            .sorted { $0.daysRemaining < $1.daysRemaining }

        return UpcomingPaymentSummary(
            horizonDays: horizonDays,
            totalAmount: included.reduce(0) { $0 + $1.amount },
            totalCount: included.count,
            visibleReminders: Array(included.prefix(max(0, visibleLimit)))
        )
    }
}

enum CashFlowChartSummary {
    static func text(for items: [MonthlyCashFlowItem]) -> String {
        guard let minimum = items.map(\.endingCash).min() else {
            return "暂无偿债后现金余额数据"
        }
        let warnings = items.filter(\.isWarning).count
        return "未来\(items.count)个月偿债后现金余额，最低预计余额\(minimum.formattedCurrencyCompact)，\(warnings)个月需关注。"
    }
}
