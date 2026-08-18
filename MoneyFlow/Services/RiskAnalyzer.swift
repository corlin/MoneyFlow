import Foundation
import SwiftData

enum DSRStatus: String, CaseIterable, Identifiable {
    case healthy = "healthy"   // < 35% 稳健
    case warning = "warning"   // 35% ~ 45% 警戒
    case danger = "danger"     // > 45% 高危

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthy: return "稳健 (<35%)"
        case .warning: return "警戒 (35%~45%)"
        case .danger: return "高危 (>45%)"
        }
    }

    var shortTitle: String {
        switch self {
        case .healthy: return "稳健"
        case .warning: return "警戒"
        case .danger: return "高危"
        }
    }
}

enum InsightType: String, CaseIterable {
    case urgent = "urgent"         // 紧急风险
    case warning = "warning"       // 重点关注
    case recommendation = "rec"    // 专业建议
    case milestone = "milestone"   // 积极进展

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .recommendation: return "lightbulb.fill"
        case .milestone: return "checkmark.seal.fill"
        }
    }
}

struct FinancialInsight: Identifiable, Equatable {
    let id: String
    let type: InsightType
    let title: String
    let detail: String
    let actionHint: String?

    init(
        id: String = UUID().uuidString,
        type: InsightType,
        title: String,
        detail: String,
        actionHint: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.actionHint = actionHint
    }
}

struct DebtHealthAnalysis: Equatable {
    let totalAssets: Double
    let totalLiabilities: Double
    let netCashPosition: Double

    // 流动性韧性 (Liquidity Resilience)
    let emergencyCoverageMonths: Double
    let emergencyTargetMonths: Int
    let isEmergencyFundAdequate: Bool
    let emergencyGapAmount: Double
    let freeCashAmount: Double // 扣除目标已锁定金额后的自由流动资金

    // 偿债承载力 (Solvency & DSR)
    let dsrRatio: Double               // 偿债收入比 (0.0 ~ 1.0+)
    let dsrStatus: DSRStatus
    let wacdAnnualRate: Double          // 加权平均负债利率
    let healthyDebtAmount: Double
    let warningDebtAmount: Double
    let healthyDebtRatio: Double       // 低于基准的负债占比
    let warningDebtRatio: Double       // 高于基准/需关注负债占比
    let totalMonthlyDebtService: Double // 每月固定还贷总支出
    let debtToAssetRatio: Double        // 资产负债率

    // 目标达成力 (Goal Feasibility)
    let savingsRate: Double             // 自由现金流结余率
    let totalGoalsCount: Int
    let onTrackGoalsCount: Int

    // CFP 智能行动建议
    let insights: [FinancialInsight]

    var isLiquidShortage: Bool {
        emergencyCoverageMonths < Double(emergencyTargetMonths)
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

    /// 核心三维健康诊断与 CFP 建议分析
    static func analyze(
        cashAccounts: [CashAccount],
        loans: [Loan],
        creditCards: [CreditCard],
        goals: [FinancialGoal] = [],
        rateThreshold: Double = 0.05,
        monthlyIncome: Double = 0,
        monthlyLivingExpense: Double = 0,
        emergencyTargetMonths: Int = 3
    ) -> DebtHealthAnalysis {
        let totalAssets = cashAccounts.reduce(0.0) { $0 + $1.balance }

        var healthyDebt: Double = 0
        var warningDebt: Double = 0
        var totalMonthlyService: Double = 0
        var weightedInterestSum: Double = 0

        for loan in loans {
            let principal = loan.remainingPrincipal
            let rate = loan.latestAnnualRate
            if rate <= rateThreshold {
                healthyDebt += principal
            } else {
                warningDebt += principal
            }
            totalMonthlyService += loan.monthlyPayment
            weightedInterestSum += principal * rate
        }

        for card in creditCards {
            warningDebt += card.currentBalance
            weightedInterestSum += card.currentBalance * 0.15
        }

        let totalLiabilities = healthyDebt + warningDebt
        let netCashPosition = totalAssets - totalLiabilities

        let healthyRatio = totalLiabilities > 0 ? healthyDebt / totalLiabilities : 1.0
        let warningRatio = totalLiabilities > 0 ? warningDebt / totalLiabilities : 0.0
        let debtToAsset = totalAssets > 0 ? totalLiabilities / totalAssets : (totalLiabilities > 0 ? 999.0 : 0.0)
        let wacd = totalLiabilities > 0 ? weightedInterestSum / totalLiabilities : 0.0

        // 1. 流动性计算
        let monthlyMustPay = monthlyLivingExpense + totalMonthlyService
        let emergencyMonths: Double
        if monthlyMustPay > 0 {
            emergencyMonths = totalAssets / monthlyMustPay
        } else {
            emergencyMonths = totalAssets > 0 ? 99.0 : 0.0
        }

        let targetEmergencyFund = monthlyMustPay * Double(emergencyTargetMonths)
        let emergencyGap = max(0.0, targetEmergencyFund - totalAssets)
        let isEmergencyAdequate = emergencyMonths >= Double(emergencyTargetMonths)

        let totalEarmarked = goals.reduce(0.0) { $0 + $1.currentEarmarkedAmount }
        let freeCash = max(0.0, totalAssets - totalEarmarked)

        // 2. DSR 偿债比计算
        let dsr: Double
        if monthlyIncome > 0 {
            dsr = totalMonthlyService / monthlyIncome
        } else {
            dsr = totalMonthlyService > 0 ? 1.0 : 0.0
        }

        let dsrStatus: DSRStatus
        if dsr <= 0.35 {
            dsrStatus = .healthy
        } else if dsr <= 0.45 {
            dsrStatus = .warning
        } else {
            dsrStatus = .danger
        }

        // 3. 储蓄率
        let freeSurplus = max(0.0, monthlyIncome - monthlyMustPay)
        let savingsRate = monthlyIncome > 0 ? freeSurplus / monthlyIncome : 0.0

        // 4. 目标按期情况
        let onTrackCount = goals.filter { $0.isCompleted || ($0.targetDate != nil) }.count

        // 5. 生成 CFP 智能行动建议
        var insights: [FinancialInsight] = []

        // 诊断 1：偿债收入比 (DSR)
        if dsr > 0.45 {
            insights.append(FinancialInsight(
                id: "dsr_danger",
                type: .urgent,
                title: "偿债压力过高 (DSR \(Int(dsr * 100))%)",
                detail: "每月还贷已占据收入的 \(Int(dsr * 100))%，超过 45% 国际安全红线。强烈建议启动雪崩法或置换高息贷款降低月供。",
                actionHint: "前往规划沙盘推演雪崩法还贷"
            ))
        } else if dsr > 0.35 {
            insights.append(FinancialInsight(
                id: "dsr_warning",
                type: .warning,
                title: "偿债比处于警戒区间 (DSR \(Int(dsr * 100))%)",
                detail: "月还贷占收入 \(Int(dsr * 100))%，在收入波动时容易挤占生活与目标蓄水。建议适度控制新增杠杆。",
                actionHint: "查看负债结构与利息占比"
            ))
        }

        // 诊断 2：应急缓冲金
        if !isEmergencyAdequate && monthlyMustPay > 0 {
            insights.append(FinancialInsight(
                id: "emergency_gap",
                type: emergencyMonths < 1.0 ? .urgent : .warning,
                title: "应急备用金不足 (\(String(format: "%.1f", emergencyMonths)) 个月)",
                detail: "当前流动现金仅能支撑 \(String(format: "%.1f", emergencyMonths)) 个月刚性支出，距离 \(emergencyTargetMonths) 个月目标尚有缺口。建议优先筑牢防线后再进行大额心愿投资。",
                actionHint: "设立应急金目标并虚拟锁定"
            ))
        }

        // 诊断 3：高息负债加速清偿建议
        if warningDebt > 0 {
            let maxRateLoan = loans.filter { $0.annualRate > rateThreshold }.max(by: { $0.annualRate < $1.annualRate })
            if let loan = maxRateLoan {
                insights.append(FinancialInsight(
                    id: "high_rate_debt",
                    type: .recommendation,
                    title: "存在高息负债可优化 (年化 \(String(format: "%.1f", loan.annualRate * 100))%)",
                    detail: "「\(loan.name)」利率偏高。若利用月度自由结余实施雪崩法优先还款，可大幅节约未来利息支出。",
                    actionHint: "启动加速还贷策略推演"
                ))
            }
        }

        // 诊断 4：良性财务里程碑
        if dsr <= 0.30 && isEmergencyAdequate && totalLiabilities > 0 {
            insights.append(FinancialInsight(
                id: "healthy_milestone",
                type: .milestone,
                title: "财务底线坚实稳健",
                detail: "偿债比与应急储备均处于良好状态，可稳步将月度自由结余 (\(Int(savingsRate * 100))% 储蓄率) 注入长期心愿与资产目标。",
                actionHint: "查看规划目标达成时间表"
            ))
        }

        return DebtHealthAnalysis(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netCashPosition: netCashPosition,
            emergencyCoverageMonths: emergencyMonths,
            emergencyTargetMonths: emergencyTargetMonths,
            isEmergencyFundAdequate: isEmergencyAdequate,
            emergencyGapAmount: emergencyGap,
            freeCashAmount: freeCash,
            dsrRatio: dsr,
            dsrStatus: dsrStatus,
            wacdAnnualRate: wacd,
            healthyDebtAmount: healthyDebt,
            warningDebtAmount: warningDebt,
            healthyDebtRatio: healthyRatio,
            warningDebtRatio: warningRatio,
            totalMonthlyDebtService: totalMonthlyService,
            debtToAssetRatio: debtToAsset,
            savingsRate: savingsRate,
            totalGoalsCount: goals.count,
            onTrackGoalsCount: onTrackCount,
            insights: insights
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
