import Foundation

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
