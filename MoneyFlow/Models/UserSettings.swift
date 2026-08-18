import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var id: UUID = UUID()
    // 用户自定的利率关注基准（例如 0.05 代表 5.0%）
    public var rateThreshold: Double = 0.05

    // 现金流预警比例（当月应还债务 / 现金资产 > 该比例触发预警，默认 0.7 即 70%）
    public var cashFlowWarningRatio: Double = 0.70

    // 临近还款日提前提醒天数（默认 5 天）
    public var reminderDaysBefore: Int = 5

    // 预计每月现金净流入（用于现金流时间线预测，如工资等，默认 0）
    public var monthlyEstimatedIncome: Double = 0

    // 每月刚性基础生活支出（用于计算自由现金流与应急缓冲金基数，默认 0）
    public var monthlyLivingExpense: Double = 0

    // 目标应急缓冲月数（CFP 标准建议 3~6 个月，默认 3）
    public var emergencyFundMonthsTarget: Int = 3

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        rateThreshold: Double = 0.05,
        cashFlowWarningRatio: Double = 0.70,
        reminderDaysBefore: Int = 5,
        monthlyEstimatedIncome: Double = 0,
        monthlyLivingExpense: Double = 0,
        emergencyFundMonthsTarget: Int = 3,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rateThreshold = rateThreshold
        self.cashFlowWarningRatio = cashFlowWarningRatio
        self.reminderDaysBefore = reminderDaysBefore
        self.monthlyEstimatedIncome = monthlyEstimatedIncome
        self.monthlyLivingExpense = monthlyLivingExpense
        self.emergencyFundMonthsTarget = emergencyFundMonthsTarget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
