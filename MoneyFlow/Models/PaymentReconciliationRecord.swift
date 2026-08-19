import Foundation
import SwiftData

@Model
public final class PaymentReconciliationRecord {
    public var id: UUID = UUID()
    /// 关联的负债源 ID (Loan.id 或 CreditCard.id)
    public var sourceID: UUID = UUID()
    /// 负债名称 (如 "招商银行房贷"、"工行信用卡")
    public var sourceName: String = ""
    /// 负债类型 ("loan" 或 "creditCard")
    public var sourceType: String = "loan"
    /// 归属年月 (格式 "YYYY-MM", 如 "2026-08")
    public var yearMonth: String = ""
    /// 计划应还款日期
    public var scheduledDate: Date = Date()
    /// 实际对账/还款日期
    public var reconciledDate: Date? = nil
    /// 计划应还金额 (元)
    public var scheduledAmount: Double = 0
    /// 实际扣款金额 (元)
    public var actualAmount: Double = 0
    /// 是否已对账结清
    public var isReconciled: Bool = false
    /// 扣款现金账户 ID (若进行了联动扣减)
    public var deductedAccountID: UUID? = nil
    /// 备注
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceName: String,
        sourceType: String = "loan",
        yearMonth: String,
        scheduledDate: Date,
        reconciledDate: Date? = nil,
        scheduledAmount: Double,
        actualAmount: Double? = nil,
        isReconciled: Bool = false,
        deductedAccountID: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.sourceType = sourceType
        self.yearMonth = yearMonth
        self.scheduledDate = scheduledDate
        self.reconciledDate = reconciledDate
        self.scheduledAmount = scheduledAmount
        self.actualAmount = actualAmount ?? scheduledAmount
        self.isReconciled = isReconciled
        self.deductedAccountID = deductedAccountID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
