import Foundation
import SwiftData

enum RepaymentMethod: String, Codable, CaseIterable, Identifiable {
    case equalPayment = "等额本息"
    case equalPrincipal = "等额本金"
    case interestFirst = "先息后本"
    case lumpSum = "一次性还本付息"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .equalPayment:
            return "每月还款总额固定，本金逐月增加，利息逐月减少"
        case .equalPrincipal:
            return "每月还款本金固定，利息逐月减少，月供逐月递减"
        case .interestFirst:
            return "每月仅偿还利息，最后一期偿还全部本金及当期利息"
        case .lumpSum:
            return "到期日一次性偿还全部本金和全部累计利息"
        }
    }
}

enum LoanCategory: String, Codable, CaseIterable, Identifiable {
    case mortgage = "房贷"
    case carLoan = "车贷"
    case consumerLoan = "消费贷"
    case businessLoan = "经营贷"
    case other = "其他贷款"

    var id: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .mortgage: return "house.fill"
        case .carLoan: return "car.fill"
        case .consumerLoan: return "cart.fill"
        case .businessLoan: return "briefcase.fill"
        case .other: return "doc.text.fill"
        }
    }
}

@Model
final class Loan {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = LoanCategory.mortgage.rawValue
    var totalAmount: Double = 0            // 贷款总额
    var remainingPrincipal: Double = 0     // 剩余本金
    var annualRate: Double = 0.035         // 起贷初始年化利率 (如 0.035 代表 3.5%)
    var repaymentMethodRaw: String = RepaymentMethod.equalPayment.rawValue
    var totalPeriods: Int = 360             // 总期数 (月)
    var paidPeriods: Int = 0                // 已还期数
    var monthlyPayment: Double = 0         // 当前月供金额 (参考)
    var paymentDayOfMonth: Int = 10         // 每月还款日 (1-28)
    var startDate: Date = Date()            // 贷款起始日
    var endDate: Date = Date()              // 贷款到期日
    var totalInterestPaid: Double = 0      // 已累计偿还利息
    var icon: String = "house.fill"
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LoanAdjustmentEvent.loan)
    var adjustmentEvents: [LoanAdjustmentEvent] = []

    @Transient
    var category: LoanCategory {
        get { LoanCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    @Transient
    var repaymentMethod: RepaymentMethod {
        get { RepaymentMethod(rawValue: repaymentMethodRaw) ?? .equalPayment }
        set { repaymentMethodRaw = newValue.rawValue }
    }

    @Transient
    var remainingPeriods: Int {
        max(0, totalPeriods - paidPeriods)
    }

    @Transient
    var progress: Double {
        guard totalPeriods > 0 else { return 0 }
        return min(1.0, max(0.0, Double(paidPeriods) / Double(totalPeriods)))
    }

    @Transient
    var sortedAdjustmentEvents: [LoanAdjustmentEvent] {
        adjustmentEvents.sorted {
            if $0.periodIndex != $1.periodIndex {
                return $0.periodIndex < $1.periodIndex
            }
            return $0.date < $1.date
        }
    }

    @Transient
    var latestAnnualRate: Double {
        let rateEvents = sortedAdjustmentEvents.filter { $0.type == .rateAdjustment && $0.newAnnualRate != nil }
        return rateEvents.last?.newAnnualRate ?? annualRate
    }

    @Transient
    var totalPrepaymentAmount: Double {
        adjustmentEvents.filter { $0.type == .prepayment }.reduce(0.0) { $0 + ($1.prepaymentAmount ?? 0.0) }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: LoanCategory = .mortgage,
        totalAmount: Double,
        remainingPrincipal: Double,
        annualRate: Double,
        repaymentMethod: RepaymentMethod = .equalPayment,
        totalPeriods: Int,
        paidPeriods: Int = 0,
        monthlyPayment: Double = 0,
        paymentDayOfMonth: Int = 10,
        startDate: Date = Date(),
        endDate: Date = Date(),
        totalInterestPaid: Double = 0,
        icon: String = "house.fill",
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.totalAmount = totalAmount
        self.remainingPrincipal = remainingPrincipal
        self.annualRate = annualRate
        self.repaymentMethodRaw = repaymentMethod.rawValue
        self.totalPeriods = totalPeriods
        self.paidPeriods = paidPeriods
        self.monthlyPayment = monthlyPayment
        self.paymentDayOfMonth = paymentDayOfMonth
        self.startDate = startDate
        self.endDate = endDate
        self.totalInterestPaid = totalInterestPaid
        self.icon = icon
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.adjustmentEvents = []
    }

    func detachedCopy() -> Loan {
        let copy = Loan(
            id: id,
            name: name,
            category: category,
            totalAmount: totalAmount,
            remainingPrincipal: remainingPrincipal,
            annualRate: annualRate,
            repaymentMethod: repaymentMethod,
            totalPeriods: totalPeriods,
            paidPeriods: paidPeriods,
            monthlyPayment: monthlyPayment,
            paymentDayOfMonth: paymentDayOfMonth,
            startDate: startDate,
            endDate: endDate,
            totalInterestPaid: totalInterestPaid,
            icon: icon,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        copy.adjustmentEvents = adjustmentEvents.map {
            LoanAdjustmentEvent(
                id: $0.id,
                date: $0.date,
                periodIndex: $0.periodIndex,
                type: $0.type,
                newAnnualRate: $0.newAnnualRate,
                prepaymentAmount: $0.prepaymentAmount,
                prepaymentEffect: $0.prepaymentEffect,
                note: $0.note,
                loan: copy,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        return copy
    }
}
