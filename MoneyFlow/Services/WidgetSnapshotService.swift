import Foundation
import WidgetKit

final class WidgetSnapshotService {
    static let shared = WidgetSnapshotService()

    static let appGroupIdentifier = "group.com.moneyflow.app"
    static let snapshotKey = "moneyflow_widget_snapshot"

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupIdentifier) ?? UserDefaults.standard
    }

    private init() {}

    /// 生成最新财务快照并持久化至 App Group，触发小组件即时刷新
    func syncSnapshot(
        accounts: [CashAccount],
        loans: [Loan],
        creditCards: [CreditCard],
        settings: UserSettings
    ) {
        let totalCash = accounts.reduce(0.0) { $0 + $1.balance }

        // 计算本月待还与近期待还项目
        let reminders = RiskAnalyzer.getUpcomingReminders(loans: loans, creditCards: creditCards, daysAhead: 30)
        let totalMustPay = loans.reduce(0.0) { $0 + $1.monthlyPayment } + creditCards.reduce(0.0) { $0 + $1.currentBalance }

        // 简易预测月底安全结余 (现金 + 月收入 - 月生活支出 - 当月待还)
        let monthlyIncome = settings.monthlyEstimatedIncome
        let monthlyLiving = settings.monthlyLivingExpense
        let predictedEnding = max(0.0, totalCash + monthlyIncome - monthlyLiving - totalMustPay)

        // DSR 比率与风险健康度
        let dsrRatio = monthlyIncome > 0 ? (totalMustPay / monthlyIncome) : (totalMustPay > 0 ? 1.0 : 0.0)
        let riskText: String
        let riskColor: String
        if dsrRatio <= 0.35 {
            riskText = "结余充裕"
            riskColor = "#34C759"
        } else if dsrRatio <= 0.55 {
            riskText = "负债合理"
            riskColor = "#007AFF"
        } else if dsrRatio <= 0.70 {
            riskText = "需多关注"
            riskColor = "#FF9500"
        } else {
            riskText = "资金偏紧"
            riskColor = "#FF3B30"
        }

        let widgetItems = reminders.prefix(3).map { r in
            WidgetUpcomingItem(
                id: r.id,
                title: r.title,
                amount: r.amount,
                dueDate: r.dueDate,
                daysRemaining: r.daysRemaining,
                isLoan: r.isLoan,
                icon: r.isLoan ? "house.fill" : "creditcard.fill"
            )
        }

        let snapshot = WidgetSnapshotData(
            availableCash: totalCash,
            predictedEndingCash: predictedEnding,
            totalMustPayThisMonth: totalMustPay,
            dsrRatio: dsrRatio,
            riskStatusText: riskText,
            riskStatusColorHex: riskColor,
            nearestReminder: widgetItems.first,
            upcomingReminders: Array(widgetItems),
            lastUpdated: Date()
        )

        saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func saveSnapshot(_ snapshot: WidgetSnapshotData) {
        if let data = try? JSONEncoder().encode(snapshot) {
            sharedDefaults.set(data, forKey: Self.snapshotKey)
        }
    }

    public func loadSnapshot() -> WidgetSnapshotData {
        guard let data = sharedDefaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshotData.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}
