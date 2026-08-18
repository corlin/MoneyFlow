import Foundation

enum RepaymentStrategy: String, CaseIterable, Identifiable, Codable {
    case standard = "standard"
    case avalanche = "avalanche"
    case snowball = "snowball"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "标准按期还款"
        case .avalanche: return "雪崩法 (利息最优)"
        case .snowball: return "滚雪球 (笔数优先)"
        }
    }

    var shortTitle: String {
        switch self {
        case .standard: return "标准"
        case .avalanche: return "雪崩法"
        case .snowball: return "滚雪球"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: return "calendar"
        case .avalanche: return "arrow.down.right.and.arrow.up.left"
        case .snowball: return "circle.grid.2x1.fill"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "按各贷款既定计划还款，月度结余全量灌溉至多目标。"
        case .avalanche:
            return "将自由结余优先用于提前偿还年化利率最高的贷款，节约最多总利息。"
        case .snowball:
            return "将自由结余优先偿还剩余本金最少的贷款，最快注销负债笔数，获得心理正反馈。"
        }
    }
}

struct PlanningScenario: Equatable {
    /// 收入波动百分比（如 -0.20 代表收入减少 20%，+0.10 代表增加 10%）
    var incomeAdjustmentPct: Double = 0.0

    /// 突发一次性开支金额（如医疗、意外维修等）
    var lumpSumExpense: Double = 0.0

    /// 突发开支发生月份（0 为首月/当月）
    var lumpSumExpenseMonth: Int = 0

    /// 负债加速清偿策略
    var repaymentStrategy: RepaymentStrategy = .standard

    /// 结余资金投入提前还贷的比例（0.0 ~ 1.0，默认 0.8 即 80% 结余用于提前还贷，20% 保留给目标）
    var debtSurplusAllocationRatio: Double = 0.80

    /// 生活开支临时调整额（加或减）
    var livingExpenseAdjustment: Double = 0.0

    init(
        incomeAdjustmentPct: Double = 0.0,
        lumpSumExpense: Double = 0.0,
        lumpSumExpenseMonth: Int = 0,
        repaymentStrategy: RepaymentStrategy = .standard,
        debtSurplusAllocationRatio: Double = 0.80,
        livingExpenseAdjustment: Double = 0.0
    ) {
        self.incomeAdjustmentPct = incomeAdjustmentPct
        self.lumpSumExpense = lumpSumExpense
        self.lumpSumExpenseMonth = lumpSumExpenseMonth
        self.repaymentStrategy = repaymentStrategy
        self.debtSurplusAllocationRatio = debtSurplusAllocationRatio
        self.livingExpenseAdjustment = livingExpenseAdjustment
    }

    static let baseline = PlanningScenario()

    var isModifiedFromBaseline: Bool {
        abs(incomeAdjustmentPct) > 0.001 ||
        lumpSumExpense > 0.01 ||
        repaymentStrategy != .standard ||
        abs(livingExpenseAdjustment) > 0.01
    }

    mutating func reset() {
        self = PlanningScenario.baseline
    }
}
