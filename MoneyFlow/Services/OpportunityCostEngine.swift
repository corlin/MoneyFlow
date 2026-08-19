import Foundation

/// 提前还贷策略效果
enum OpportunityCostPrepaymentEffect: String, CaseIterable, Identifiable, Codable {
    case shortenTerm = "shortenTerm"
    case reduceMonthlyPayment = "reduceMonthlyPayment"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortenTerm: return "缩短年限 (利息最省)"
        case .reduceMonthlyPayment: return "减少月供 (减压首选)"
        }
    }

    var shortTitle: String {
        switch self {
        case .shortenTerm: return "缩短年限"
        case .reduceMonthlyPayment: return "减少月供"
        }
    }
}

/// 决策建议评级
enum OpportunityCostRecommendation: String, Codable {
    case stronglyPrepay = "强烈建议提前还贷"
    case prepay = "建议提前还贷"
    case balanced = "收益均衡，视流动性需求决定"
    case invest = "建议稳健理财"
    case stronglyInvest = "强烈建议稳健理财"

    var iconName: String {
        switch self {
        case .stronglyPrepay, .prepay: return "arrow.down.right.and.arrow.up.left"
        case .balanced: return "equal.circle.fill"
        case .invest, .stronglyInvest: return "chart.line.uptrend.xyaxis"
        }
    }
}

/// 机会成本精算输入模型
struct OpportunityCostInput: Equatable {
    /// 用于对比的闲钱金额 (元)
    var lumpSumAmount: Double
    /// 贷款剩余本金 (元)
    var remainingPrincipal: Double
    /// 贷款当前年化利率 (如 0.0385 代表 3.85%)
    var loanAnnualRate: Double
    /// 贷款剩余期数 (月)
    var remainingPeriods: Int
    /// 贷款还款方式
    var repaymentMethod: RepaymentMethod
    /// 提前还款策略
    var prepaymentEffect: OpportunityCostPrepaymentEffect
    /// 理财预期年化收益率 (如 0.025 代表 2.5%)
    var investmentAnnualRate: Double
    /// 用户当前可用总流动资金 (可选，用于流动性安全校验)
    var availableCash: Double?
    /// 用户月度必要支出 (可选，用于应急金缓冲校验)
    var monthlyMustExpense: Double?

    init(
        lumpSumAmount: Double,
        remainingPrincipal: Double,
        loanAnnualRate: Double,
        remainingPeriods: Int,
        repaymentMethod: RepaymentMethod = .equalPayment,
        prepaymentEffect: OpportunityCostPrepaymentEffect = .shortenTerm,
        investmentAnnualRate: Double = 0.025,
        availableCash: Double? = nil,
        monthlyMustExpense: Double? = nil
    ) {
        self.lumpSumAmount = lumpSumAmount
        self.remainingPrincipal = remainingPrincipal
        self.loanAnnualRate = loanAnnualRate
        self.remainingPeriods = remainingPeriods
        self.repaymentMethod = repaymentMethod
        self.prepaymentEffect = prepaymentEffect
        self.investmentAnnualRate = investmentAnnualRate
        self.availableCash = availableCash
        self.monthlyMustExpense = monthlyMustExpense
    }
}

/// 机会成本精算结果模型
struct OpportunityCostResult: Equatable {
    /// 实际用于提前还款/理财的本金金额
    let effectiveAmount: Double
    /// 提前还贷累计节省的总利息 (元)
    let loanInterestSaved: Double
    /// 提前还款后新月供 (元)
    let newMonthlyPayment: Double
    /// 提前还款后缩短的期数 (月)
    let periodsSaved: Int
    /// 提前还款后剩余总期数 (月)
    let newRemainingPeriods: Int
    /// 理财在对标周期内的累计复利总收益 (元)
    let investmentTotalReturn: Double
    /// 对标周期时长 (月)
    let comparisonHorizonMonths: Int
    /// 净收益差额 (提前还贷省息 - 理财收益，正值代表还贷更划算，负值代表理财更划算)
    let netAdvantage: Double
    /// 临界保本年化理财收益率 (理财必须达到的年化收益，才能持平提前还贷)
    let breakEvenInvestmentRate: Double
    /// 决策建议
    let recommendation: OpportunityCostRecommendation
    /// 黄金一句话决策结论
    let verdictStatement: String
    /// 资金流动性安全提示 (若存在风险则返回具体建议)
    let liquidityWarning: String?
}

/// 机会成本精算核心引擎
enum OpportunityCostEngine {

    /// 核心精算方法
    static func calculate(input: OpportunityCostInput) -> OpportunityCostResult {
        guard input.remainingPrincipal > 0,
              input.loanAnnualRate > 0,
              input.remainingPeriods > 0,
              input.lumpSumAmount > 0 else {
            return emptyResult(input: input)
        }

        let effectiveAmount = min(input.lumpSumAmount, input.remainingPrincipal)
        let monthlyRate = input.loanAnnualRate / 12.0

        // 1. 基线原始计划总利息
        let baselineSummary = RepaymentCalculator.calculateSchedule(
            principal: input.remainingPrincipal,
            annualRate: input.loanAnnualRate,
            totalPeriods: input.remainingPeriods,
            method: input.repaymentMethod
        )
        let baselineTotalInterest = baselineSummary.totalInterest
        let baselineMonthlyPayment = baselineSummary.initialMonthlyPayment

        // 2. 提前还贷后的新计划与总利息
        let newPrincipal = max(0, input.remainingPrincipal - effectiveAmount)
        var newTotalInterest = 0.0
        var newMonthlyPayment = 0.0
        var periodsSaved = 0
        var newRemainingPeriods = input.remainingPeriods
        var comparisonMonths = input.remainingPeriods

        if newPrincipal <= 0.001 {
            // 全额结清
            newTotalInterest = 0.0
            newMonthlyPayment = 0.0
            periodsSaved = input.remainingPeriods
            newRemainingPeriods = 0
            comparisonMonths = input.remainingPeriods
        } else {
            switch input.prepaymentEffect {
            case .shortenTerm:
                // 缩短年限: 月供保持不变，期数缩短
                if input.repaymentMethod == .equalPayment {
                    if baselineMonthlyPayment > newPrincipal * monthlyRate {
                        let newPeriods = calculateNPER(rate: monthlyRate, pmt: baselineMonthlyPayment, pv: newPrincipal)
                        newRemainingPeriods = max(1, newPeriods)
                        periodsSaved = max(0, input.remainingPeriods - newRemainingPeriods)
                        let newSummary = RepaymentCalculator.calculateSchedule(
                            principal: newPrincipal,
                            annualRate: input.loanAnnualRate,
                            totalPeriods: newRemainingPeriods,
                            method: .equalPayment
                        )
                        newTotalInterest = newSummary.totalInterest
                        newMonthlyPayment = newSummary.currentMonthlyPayment
                        comparisonMonths = input.remainingPeriods
                    } else {
                        // 兜底保护
                        newRemainingPeriods = input.remainingPeriods
                        let newSummary = RepaymentCalculator.calculateSchedule(
                            principal: newPrincipal,
                            annualRate: input.loanAnnualRate,
                            totalPeriods: newRemainingPeriods,
                            method: input.repaymentMethod
                        )
                        newTotalInterest = newSummary.totalInterest
                        newMonthlyPayment = newSummary.currentMonthlyPayment
                    }
                } else {
                    // 等额本金或先息后本：按剩余本金等比例缩短期数
                    let ratio = newPrincipal / input.remainingPrincipal
                    newRemainingPeriods = max(1, Int(round(Double(input.remainingPeriods) * ratio)))
                    periodsSaved = max(0, input.remainingPeriods - newRemainingPeriods)
                    let newSummary = RepaymentCalculator.calculateSchedule(
                        principal: newPrincipal,
                        annualRate: input.loanAnnualRate,
                        totalPeriods: newRemainingPeriods,
                        method: input.repaymentMethod
                    )
                    newTotalInterest = newSummary.totalInterest
                    newMonthlyPayment = newSummary.currentMonthlyPayment
                }

            case .reduceMonthlyPayment:
                // 减少月供: 期数保持不变，月供降低
                newRemainingPeriods = input.remainingPeriods
                periodsSaved = 0
                let newSummary = RepaymentCalculator.calculateSchedule(
                    principal: newPrincipal,
                    annualRate: input.loanAnnualRate,
                    totalPeriods: newRemainingPeriods,
                    method: input.repaymentMethod
                )
                newTotalInterest = newSummary.totalInterest
                newMonthlyPayment = newSummary.currentMonthlyPayment
            }
        }

        let loanInterestSaved = max(0.0, baselineTotalInterest - newTotalInterest)

        // 3. 理财在对标周期内的累计复利总收益
        // 采用标准月度复利模型: Return = P * (1 + r_inv/12)^months - P
        let invMonthlyRate = input.investmentAnnualRate / 12.0
        let investmentTotalReturn: Double
        if invMonthlyRate > 0 {
            investmentTotalReturn = effectiveAmount * (pow(1.0 + invMonthlyRate, Double(comparisonMonths)) - 1.0)
        } else {
            investmentTotalReturn = 0.0
        }

        // 4. 净收益优势与临界保本利率
        let netAdvantage = loanInterestSaved - investmentTotalReturn

        // 临界保本利率求解:
        // P * (1 + r_bep/12)^months - P = loanInterestSaved
        // (1 + r_bep/12)^months = 1 + (loanInterestSaved / P)
        // 1 + r_bep/12 = (1 + loanInterestSaved / P) ^ (1 / months)
        // r_bep = 12 * [ (1 + loanInterestSaved / P) ^ (1 / months) - 1 ]
        let breakEvenInvestmentRate: Double
        if comparisonMonths > 0 && effectiveAmount > 0 {
            let ratio = 1.0 + (loanInterestSaved / effectiveAmount)
            if ratio > 0 {
                let monthlyBEP = pow(ratio, 1.0 / Double(comparisonMonths)) - 1.0
                breakEvenInvestmentRate = max(0.0, monthlyBEP * 12.0)
            } else {
                breakEvenInvestmentRate = 0.0
            }
        } else {
            breakEvenInvestmentRate = 0.0
        }

        // 5. 建议评级与黄金结论生成
        let (recommendation, verdictStatement) = makeVerdict(
            netAdvantage: netAdvantage,
            loanInterestSaved: loanInterestSaved,
            investmentTotalReturn: investmentTotalReturn,
            breakEvenRate: breakEvenInvestmentRate,
            currentInvRate: input.investmentAnnualRate
        )

        // 6. 资金流动性安全护栏评估
        let liquidityWarning = evaluateLiquidity(
            lumpSumAmount: effectiveAmount,
            availableCash: input.availableCash,
            monthlyMustExpense: input.monthlyMustExpense
        )

        return OpportunityCostResult(
            effectiveAmount: effectiveAmount,
            loanInterestSaved: loanInterestSaved,
            newMonthlyPayment: newMonthlyPayment,
            periodsSaved: periodsSaved,
            newRemainingPeriods: newRemainingPeriods,
            investmentTotalReturn: investmentTotalReturn,
            comparisonHorizonMonths: comparisonMonths,
            netAdvantage: netAdvantage,
            breakEvenInvestmentRate: breakEvenInvestmentRate,
            recommendation: recommendation,
            verdictStatement: verdictStatement,
            liquidityWarning: liquidityWarning
        )
    }

    // MARK: - 辅助精算与判定逻辑

    private static func emptyResult(input: OpportunityCostInput) -> OpportunityCostResult {
        OpportunityCostResult(
            effectiveAmount: 0,
            loanInterestSaved: 0,
            newMonthlyPayment: 0,
            periodsSaved: 0,
            newRemainingPeriods: input.remainingPeriods,
            investmentTotalReturn: 0,
            comparisonHorizonMonths: input.remainingPeriods,
            netAdvantage: 0,
            breakEvenInvestmentRate: 0,
            recommendation: .balanced,
            verdictStatement: "请输入有效的贷款与闲钱金额以开始机会成本精算。",
            liquidityWarning: nil
        )
    }

    private static func makeVerdict(
        netAdvantage: Double,
        loanInterestSaved: Double,
        investmentTotalReturn: Double,
        breakEvenRate: Double,
        currentInvRate: Double
    ) -> (OpportunityCostRecommendation, String) {
        let diffPct = (loanInterestSaved - investmentTotalReturn) / max(1.0, investmentTotalReturn)
        let breakEvenFormatted = breakEvenRate.formattedRatePercentage
        let currentInvFormatted = currentInvRate.formattedRatePercentage
        let netAbs = abs(netAdvantage).formattedCurrencyCompact

        if netAdvantage > 500 {
            let rec: OpportunityCostRecommendation = diffPct > 0.25 ? .stronglyPrepay : .prepay
            let statement = "理财年化收益需达到 \(breakEvenFormatted) 才能持平还贷；在当前理财预期（\(currentInvFormatted)）下，提前还贷可净多省 \(netAbs)。"
            return (rec, statement)
        } else if netAdvantage < -500 {
            let rec: OpportunityCostRecommendation = diffPct < -0.25 ? .stronglyInvest : .invest
            let statement = "当前理财收益（\(currentInvFormatted)）已高出保本平衡线（\(breakEvenFormatted)），稳健理财比提前还贷可多赚 \(netAbs)。"
            return (rec, statement)
        } else {
            let statement = "两者收益基本持平（差距在 \(netAbs) 以内）；建议优先保留流动资金应对生活突发开支。"
            return (.balanced, statement)
        }
    }

    private static func evaluateLiquidity(
        lumpSumAmount: Double,
        availableCash: Double?,
        monthlyMustExpense: Double?
    ) -> String? {
        guard let availableCash, availableCash > 0 else { return nil }

        let ratio = lumpSumAmount / availableCash
        let remainingCash = availableCash - lumpSumAmount

        if let monthlyMust = monthlyMustExpense, monthlyMust > 0 {
            let safetyMonths = remainingCash / monthlyMust
            if safetyMonths < 3.0 {
                return "⚠️ 预警：提前还贷后剩余可用现金仅可支撑 \(String(format: "%.1f", max(0, safetyMonths))) 个月必须支出（建议保留至少 3~6 个月应急备用金）。提前还贷本金将不可撤回，请谨慎操作。"
            }
        }

        if ratio > 0.60 {
            return "💡 提示：本次拟投入金额占可用总现金的 \(Int(ratio * 100))%，资金集中度较高，请确保已预留充足日常生活开支。"
        }

        return nil
    }

    private static func calculateNPER(rate: Double, pmt: Double, pv: Double) -> Int {
        guard rate > 0, pmt > pv * rate else { return 0 }
        let num = log(pmt / (pmt - pv * rate))
        let den = log(1.0 + rate)
        return Int(ceil(num / den))
    }
}
