import Foundation
import SwiftData
import SwiftUI

enum AdjustmentType: String, Codable, CaseIterable, Identifiable {
    case rateAdjustment = "rateAdjustment"
    case prepayment = "prepayment"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rateAdjustment: return "利率调整"
        case .prepayment: return "提前还款"
        }
    }

    var systemImage: String {
        switch self {
        case .rateAdjustment: return "chart.line.uptrend.xyaxis"
        case .prepayment: return "bolt.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .rateAdjustment: return .blue
        case .prepayment: return .orange
        }
    }
}

enum PrepaymentEffect: String, Codable, CaseIterable, Identifiable {
    case reducePayment = "reducePayment"  // 月供减少，期限不变 (默认)
    case shortenTerm = "shortenTerm"      // 期限缩短，月供不变

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reducePayment: return "月供减少，期限不变"
        case .shortenTerm: return "期限缩短，月供基本不变"
        }
    }

    var shortTitle: String {
        switch self {
        case .reducePayment: return "月供降低"
        case .shortenTerm: return "缩短年限"
        }
    }

    var description: String {
        switch self {
        case .reducePayment: return "保持原定到期日，后续每月月供显著减少，有效减轻月度现金流压力。"
        case .shortenTerm: return "维持原月供水平，大幅缩减剩余还款期数，利息节约最大化并提前无债结清。"
        }
    }
}

@Model
final class LoanAdjustmentEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var periodIndex: Int = 1               // 发生所在期数 (从第 1 期开始)
    var typeRaw: String = AdjustmentType.rateAdjustment.rawValue
    var newAnnualRate: Double? = nil       // 仅限利率调整：新执行年化利率 (如 0.031 代表 3.1%)
    var prepaymentAmount: Double? = nil    // 仅限提前还款：提前偿还的本金金额
    var prepaymentEffectRaw: String? = PrepaymentEffect.reducePayment.rawValue
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var loan: Loan?

    @Transient
    var type: AdjustmentType {
        get { AdjustmentType(rawValue: typeRaw) ?? .rateAdjustment }
        set { typeRaw = newValue.rawValue }
    }

    @Transient
    var prepaymentEffect: PrepaymentEffect {
        get { PrepaymentEffect(rawValue: prepaymentEffectRaw ?? PrepaymentEffect.reducePayment.rawValue) ?? .reducePayment }
        set { prepaymentEffectRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        periodIndex: Int = 1,
        type: AdjustmentType,
        newAnnualRate: Double? = nil,
        prepaymentAmount: Double? = nil,
        prepaymentEffect: PrepaymentEffect? = .reducePayment,
        note: String = "",
        loan: Loan? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.periodIndex = periodIndex
        self.typeRaw = type.rawValue
        self.newAnnualRate = newAnnualRate
        self.prepaymentAmount = prepaymentAmount
        self.prepaymentEffectRaw = prepaymentEffect?.rawValue
        self.note = note
        self.loan = loan
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
