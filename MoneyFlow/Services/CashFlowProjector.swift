import Foundation

struct MonthlyCashFlowItem: Identifiable, Equatable {
    var id: String { monthLabel }
    let date: Date                  // 所在月份第一天
    let monthLabel: String          // 如 "8月" 或 "2026-08"
    let startingCash: Double       // 期初现金资产
    let estimatedIncome: Double    // 当月预计收入
    let loanPayment: Double        // 贷款还款支出 (本+息)
    let creditCardPayment: Double  // 信用卡欠款偿还
    let totalMustPay: Double       // 当月必须支出
    let endingCash: Double         // 期末预计现金资产
    let isWarning: Bool             // 是否超出预警比例或现金不足
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
}

enum CashFlowProjector {

    /// 预测未来 N 个月的逐月现金流状况
    /// - Parameters:
    ///   - initialCash: 当前流动性资产总额
    ///   - loans: 当前所有的贷款列表
    ///   - creditCards: 信用卡列表
    ///   - warningRatio: 负债支出/现金预警比例 (如 0.70)
    ///   - monthsCount: 预测期数（默认12个月）
    static func projectCashFlow(
        initialCash: Double,
        loans: [Loan],
        creditCards: [CreditCard],
        warningRatio: Double = 0.70,
        monthsCount: Int = 12,
        monthlyIncome: Double = 0,
        assumptions: ProjectionAssumptions = .default
    ) -> [MonthlyCashFlowItem] {
        var items: [MonthlyCashFlowItem] = []
        var runningCash = initialCash

        let now = Date()
        let calendar = Calendar.current

        // 信用卡当前欠款默认在第1个月（当期/近期账单）偿还完毕
        let initialCreditCardDebt = creditCards.reduce(Double(0)) { $0 + $1.currentBalance }

        // 针对每笔贷款，生成其完整的还款日程表
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

        for monthIndex in 0..<monthsCount {
            guard let targetDate = calendar.date(byAdding: .month, value: monthIndex, to: now) else { continue }
            let monthLabel = targetDate.monthShortString
            let startCashThisMonth = runningCash

            // 计算当月所有贷款的月供之和
            var loanPaymentThisMonth: Double = 0
            for item in loanSchedules {
                let loan = item.loan
                let schedule = item.schedule
                // 未结清的贷款，根据 paidPeriods 加上当前预测月份的偏移
                let targetPeriodIndex = loan.paidPeriods + monthIndex + 1
                if targetPeriodIndex <= loan.totalPeriods {
                    if let schedItem = schedule.first(where: { $0.period == targetPeriodIndex }) {
                        loanPaymentThisMonth += schedItem.monthlyPayment
                    } else if loan.monthlyPayment > 0 {
                        loanPaymentThisMonth += loan.monthlyPayment
                    }
                }
            }

            // 信用卡：仅在第1个月计入已存在的欠款
            let ccPaymentThisMonth: Double = assumptions.paysCurrentCreditCardBalanceInFirstMonth && monthIndex == 0 ? initialCreditCardDebt : 0
            let incomeThisMonth = assumptions.includesMonthlyIncome ? monthlyIncome : 0

            let totalMustPay = loanPaymentThisMonth + ccPaymentThisMonth
            let endCashThisMonth = startCashThisMonth + incomeThisMonth - totalMustPay

            // 预警判定：若当月必须支出超过期初现金的 warningRatio 或者期末现金为负
            let isWarning: Bool
            if startCashThisMonth <= 0 {
                isWarning = totalMustPay > 0
            } else {
                let ratio = totalMustPay / startCashThisMonth
                isWarning = ratio >= warningRatio || endCashThisMonth < 0
            }

            items.append(MonthlyCashFlowItem(
                date: targetDate,
                monthLabel: monthLabel,
                startingCash: startCashThisMonth,
                estimatedIncome: incomeThisMonth,
                loanPayment: loanPaymentThisMonth,
                creditCardPayment: ccPaymentThisMonth,
                totalMustPay: totalMustPay,
                endingCash: endCashThisMonth,
                isWarning: isWarning
            ))

            // 滚动到下个月的期初现金
            runningCash = endCashThisMonth
        }

        return items
    }
}
