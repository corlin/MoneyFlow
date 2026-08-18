import Foundation
import SwiftData

struct DebtHealthAnalysis {
    let totalAssets: Double
    let totalLiabilities: Double
    let netCashPosition: Double

    let healthyDebtAmount: Double
    let warningDebtAmount: Double
    let healthyDebtRatio: Double      // 低于基准的负债占比 (0.0 ~ 1.0)
    let warningDebtRatio: Double      // 高息负债占总负债比例 (0.0 ~ 1.0)

    let totalMonthlyDebtService: Double // 每月固定还贷总支出
    let debtToAssetRatio: Double        // 资产负债率 (负债 / 资产)

    var isLiquidShortage: Bool {
        totalAssets < totalMonthlyDebtService * 3 // 现金不足3个月月供
    }
}

struct UpcomingPaymentReminder: Identifiable, Equatable {
    var id: String { "\(title)_\(dueDate.timeIntervalSince1970)" }
    let title: String
    let amount: Double
    let dueDate: Date
    let daysRemaining: Int
    let isLoan: Bool
    let sourceID: UUID?

    init(
        title: String,
        amount: Double,
        dueDate: Date,
        daysRemaining: Int,
        isLoan: Bool,
        sourceID: UUID? = nil
    ) {
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.daysRemaining = daysRemaining
        self.isLoan = isLoan
        self.sourceID = sourceID
    }
}

enum RiskAnalyzer {

    /// 分析整体资产与负债结构
    static func analyze(
        cashAccounts: [CashAccount],
        loans: [Loan],
        creditCards: [CreditCard],
        rateThreshold: Double
    ) -> DebtHealthAnalysis {
        let totalAssets = cashAccounts.reduce(Double(0)) { $0 + $1.balance }

        var healthyDebt: Double = 0
        var warningDebt: Double = 0
        var totalMonthlyService: Double = 0

        for loan in loans {
            let principal = loan.remainingPrincipal
            if loan.annualRate <= rateThreshold {
                healthyDebt += principal
            } else {
                warningDebt += principal
            }
            totalMonthlyService += loan.monthlyPayment
        }

        for card in creditCards {
            // 信用卡未结清账款归入需关注部分，不推断具体循环利率。
            warningDebt += card.currentBalance
        }

        let totalLiabilities = healthyDebt + warningDebt
        let netCashPosition = totalAssets - totalLiabilities

        let totalLiabDouble = totalLiabilities
        let healthyRatio: Double
        let warningRatio: Double

        if totalLiabDouble > 0 {
            healthyRatio = healthyDebt / totalLiabDouble
            warningRatio = warningDebt / totalLiabDouble
        } else {
            healthyRatio = 1.0
            warningRatio = 0.0
        }

        let totalAssetDouble = totalAssets
        let debtToAsset = totalAssetDouble > 0 ? totalLiabDouble / totalAssetDouble : (totalLiabDouble > 0 ? 999.0 : 0.0)

        return DebtHealthAnalysis(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netCashPosition: netCashPosition,
            healthyDebtAmount: healthyDebt,
            warningDebtAmount: warningDebt,
            healthyDebtRatio: healthyRatio,
            warningDebtRatio: warningRatio,
            totalMonthlyDebtService: totalMonthlyService,
            debtToAssetRatio: debtToAsset
        )
    }

    /// 获取即将在指定天数内到期的还款提醒
    static func getUpcomingReminders(
        loans: [Loan],
        creditCards: [CreditCard],
        daysAhead: Int = 7
    ) -> [UpcomingPaymentReminder] {
        var reminders: [UpcomingPaymentReminder] = []
        let today = Date()
        let calendar = Calendar.current

        for loan in loans where loan.remainingPrincipal > 0 {
            let nextDate = today.nextOccurrenceOf(day: loan.paymentDayOfMonth)
            let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: nextDate))
            let days = components.day ?? 0

            if days >= 0 && days <= daysAhead {
                reminders.append(UpcomingPaymentReminder(
                    title: loan.name,
                    amount: loan.monthlyPayment,
                    dueDate: nextDate,
                    daysRemaining: days,
                    isLoan: true,
                    sourceID: loan.id
                ))
            }
        }

        for card in creditCards where card.currentBalance > 0 {
            let nextDate = today.nextOccurrenceOf(day: card.dueDay)
            let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: nextDate))
            let days = components.day ?? 0

            if days >= 0 && days <= daysAhead {
                reminders.append(UpcomingPaymentReminder(
                    title: "\(card.name) 还款",
                    amount: card.currentBalance,
                    dueDate: nextDate,
                    daysRemaining: days,
                    isLoan: false,
                    sourceID: card.id
                ))
            }
        }

        return reminders.sorted { $0.daysRemaining < $1.daysRemaining }
    }

}
