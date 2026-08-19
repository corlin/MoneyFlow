import Foundation
import SwiftData

@Model
public final class CustomCashFlowEvent {
    public var id: UUID = UUID()
    /// 事件标题 (如 "季度奖金"、"车险年保费"、"物业费")
    public var title: String = ""
    /// 金额 (元)
    public var amount: Double = 0
    /// 是否为收入 (true: 进账, false: 支出)
    public var isIncome: Bool = true
    /// 事件发生日期
    public var date: Date = Date()
    /// 是否每月周期性循环
    public var isRecurringMonthly: Bool = false
    /// 图标 SF Symbol
    public var icon: String = "calendar"
    /// 备注
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        isIncome: Bool = true,
        date: Date = Date(),
        isRecurringMonthly: Bool = false,
        icon: String = "calendar",
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.date = date
        self.isRecurringMonthly = isRecurringMonthly
        self.icon = icon
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
