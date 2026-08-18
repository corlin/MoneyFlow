import Foundation

struct RepaymentScheduleItem: Identifiable, Equatable {
    let period: Int                 // 期数 (1, 2, ...)
    let paymentDate: Date          // 预计还款日期
    let monthlyPayment: Double     // 当期还款总额 (本+息)
    let principal: Double          // 当期偿还本金
    let interest: Double           // 当期偿还利息
    let remainingPrincipal: Double // 偿还后剩余本金
    var annualRate: Double = 0.035 // 当期执行年化利率
    var prepaymentAmount: Double = 0 // 当期额外提前还本金额
    var adjustmentBadge: String? = nil // 调息或还贷事件标签提示

    var id: Int { period }
}

struct RepaymentSummary: Equatable {
    let totalPayment: Double          // 实际还款总额 (本+息+提前还款)
    let totalInterest: Double         // 实际累计支付利息
    let initialMonthlyPayment: Double // 首期初始月供
    let currentMonthlyPayment: Double // 当前执行月供 (最新一期或生效期)
    let baselineTotalInterest: Double // 原始无调息无提前还款下的基准利息
    let cumulativeInterestSaved: Double // 历次调息与提前还款已累计节约利息
    let monthsAheadSaved: Int         // 提前无债结清月数
    let schedule: [RepaymentScheduleItem]
}

enum RepaymentCalculator {

    /// 计算完整的还款计划表（支持分段多次调息与提前还款事件）
    /// - Parameters:
    ///   - principal: 初始贷款总本金 (P0)
    ///   - annualRate: 初始年化利率 (如 0.035 代表 3.5%)
    ///   - totalPeriods: 初始总期数 (月)
    ///   - method: 还款方式
    ///   - startDate: 贷款起始日
    ///   - paymentDay: 每月还款日
    ///   - events: 历史与规划中的调息及提前还款事件列表
    static func calculateSchedule(
        principal: Double,
        annualRate: Double,
        totalPeriods: Int,
        method: RepaymentMethod,
        startDate: Date = Date(),
        paymentDay: Int = 10,
        events: [LoanAdjustmentEvent] = []
    ) -> RepaymentSummary {
        guard principal > 0, totalPeriods > 0 else {
            return RepaymentSummary(
                totalPayment: 0,
                totalInterest: 0,
                initialMonthlyPayment: 0,
                currentMonthlyPayment: 0,
                baselineTotalInterest: 0,
                cumulativeInterestSaved: 0,
                monthsAheadSaved: 0,
                schedule: []
            )
        }

        let calendar = Calendar.current

        // 1. 先计算原始静态基准利息 (Baseline Total Interest)
        let baselineSummary = calculateStaticSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPeriods: totalPeriods,
            method: method,
            startDate: startDate,
            paymentDay: paymentDay
        )
        let baselineTotalInterest = baselineSummary.totalInterest
        let initialPayment = baselineSummary.initialMonthlyPayment

        // 若无任何变更事件，直接返回静态基准结果
        if events.isEmpty {
            return RepaymentSummary(
                totalPayment: baselineSummary.totalPayment,
                totalInterest: baselineSummary.totalInterest,
                initialMonthlyPayment: initialPayment,
                currentMonthlyPayment: initialPayment,
                baselineTotalInterest: baselineTotalInterest,
                cumulativeInterestSaved: 0,
                monthsAheadSaved: 0,
                schedule: baselineSummary.schedule
            )
        }

        // 2. 分段链式推演模拟 (Segmented Chronological Simulation)
        // 将事件按期数与日期统一排序
        let sortedEvents = events.sorted {
            if $0.periodIndex != $1.periodIndex {
                return $0.periodIndex < $1.periodIndex
            }
            return $0.date < $1.date
        }

        var schedule: [RepaymentScheduleItem] = []
        var currentPrincipal = principal
        var currentRate = annualRate
        var activeTotalPeriods = totalPeriods
        var totalInterestAccum: Double = 0
        var totalPaymentAccum: Double = 0
        var currentMonthlyPayment: Double = initialPayment

        var period = 1
        // 允许最大推演期数上限 (防止死循环)
        let maxIteration = max(totalPeriods * 2, 600)

        while currentPrincipal > 0.01 && period <= activeTotalPeriods && period <= maxIteration {
            let payDate = dateForPeriod(index: period, from: startDate, targetDay: paymentDay, calendar: calendar)

            // 检查当前期是否有调息或提前还款事件
            let currentEvents = sortedEvents.filter { $0.periodIndex == period }

            var periodPrepayment: Double = 0
            var eventBadges: [String] = []

            for event in currentEvents {
                switch event.type {
                case .rateAdjustment:
                    if let newRate = event.newAnnualRate, newRate >= 0 {
                        currentRate = newRate
                        eventBadges.append("🏷️ 利率调至 \(newRate.formattedRatePercentage)")
                    }

                case .prepayment:
                    if let prepay = event.prepaymentAmount, prepay > 0 {
                        let actualPrepay = min(currentPrincipal, prepay)
                        currentPrincipal = max(0, currentPrincipal - actualPrepay)
                        periodPrepayment += actualPrepay
                        totalPaymentAccum += actualPrepay
                        eventBadges.append("⚡ 提前还本 \(actualPrepay.formattedCurrency(style: .compact))")

                        if event.prepaymentEffect == .shortenTerm && currentPrincipal > 0 {
                            // 期限缩短，月供保持不变: 计算新剩余期数
                            let monthlyRate = currentRate / 12.0
                            let targetPayment = currentMonthlyPayment
                            if targetPayment > currentPrincipal * monthlyRate {
                                let newRemainPeriods = calculateNPER(rate: monthlyRate, pmt: targetPayment, pv: currentPrincipal)
                                activeTotalPeriods = period + max(1, newRemainPeriods)
                            }
                        }
                    }
                }
            }

            if currentPrincipal <= 0.01 {
                // 已提前全部结清
                break
            }

            // 计算当期本息月供
            let monthlyRate = currentRate / 12.0
            let remainingPeriodsCount = max(1, activeTotalPeriods - period + 1)

            let monthlyPaymentDouble: Double
            if monthlyRate == 0 {
                monthlyPaymentDouble = currentPrincipal / Double(remainingPeriodsCount)
            } else {
                let factor = pow(1.0 + monthlyRate, Double(remainingPeriodsCount))
                monthlyPaymentDouble = currentPrincipal * (monthlyRate * factor) / max(0.00001, factor - 1.0)
            }

            currentMonthlyPayment = monthlyPaymentDouble

            let interestPart = currentPrincipal * monthlyRate
            var principalPart = monthlyPaymentDouble - interestPart

            if period >= activeTotalPeriods || principalPart > currentPrincipal {
                principalPart = currentPrincipal
            }

            currentPrincipal = max(0, currentPrincipal - principalPart)
            let actualPayment = principalPart + interestPart + periodPrepayment

            totalInterestAccum += interestPart
            totalPaymentAccum += (principalPart + interestPart)

            let badgeText = eventBadges.isEmpty ? nil : eventBadges.joined(separator: " · ")

            schedule.append(RepaymentScheduleItem(
                period: period,
                paymentDate: payDate,
                monthlyPayment: Double(actualPayment),
                principal: Double(principalPart),
                interest: Double(interestPart),
                remainingPrincipal: Double(currentPrincipal),
                annualRate: currentRate,
                prepaymentAmount: periodPrepayment,
                adjustmentBadge: badgeText
            ))

            period += 1
        }

        let totalSaved = max(0, baselineTotalInterest - totalInterestAccum)
        let monthsSaved = max(0, totalPeriods - schedule.count)

        return RepaymentSummary(
            totalPayment: Double(totalPaymentAccum),
            totalInterest: Double(totalInterestAccum),
            initialMonthlyPayment: Double(initialPayment),
            currentMonthlyPayment: Double(currentMonthlyPayment),
            baselineTotalInterest: Double(baselineTotalInterest),
            cumulativeInterestSaved: Double(totalSaved),
            monthsAheadSaved: monthsSaved,
            schedule: schedule
        )
    }

    /// 计算静态还款计划
    private static func calculateStaticSchedule(
        principal: Double,
        annualRate: Double,
        totalPeriods: Int,
        method: RepaymentMethod,
        startDate: Date,
        paymentDay: Int
    ) -> RepaymentSummary {
        let monthlyRate = annualRate / 12.0
        let pDouble = principal
        let n = totalPeriods

        var schedule: [RepaymentScheduleItem] = []
        var totalInterestAccum: Double = 0
        var totalPaymentAccum: Double = 0
        var initialPayment: Double = 0

        let calendar = Calendar.current

        switch method {
        case .equalPayment:
            let monthPaymentDouble: Double
            if monthlyRate == 0 {
                monthPaymentDouble = pDouble / Double(n)
            } else {
                let factor = pow(1.0 + monthlyRate, Double(n))
                monthPaymentDouble = pDouble * (monthlyRate * factor) / (factor - 1.0)
            }

            initialPayment = monthPaymentDouble
            var currentRemaining = pDouble

            for i in 1...n {
                let interestPart = currentRemaining * monthlyRate
                var principalPart = monthPaymentDouble - interestPart

                if i == n || principalPart > currentRemaining {
                    principalPart = currentRemaining
                }

                currentRemaining = max(0, currentRemaining - principalPart)
                let actualPayment = principalPart + interestPart

                totalInterestAccum += interestPart
                totalPaymentAccum += actualPayment

                let payDate = dateForPeriod(index: i, from: startDate, targetDay: paymentDay, calendar: calendar)

                schedule.append(RepaymentScheduleItem(
                    period: i,
                    paymentDate: payDate,
                    monthlyPayment: Double(actualPayment),
                    principal: Double(principalPart),
                    interest: Double(interestPart),
                    remainingPrincipal: Double(currentRemaining),
                    annualRate: annualRate
                ))
            }

        case .equalPrincipal:
            let fixedPrincipal = pDouble / Double(n)
            var currentRemaining = pDouble

            for i in 1...n {
                let interestPart = currentRemaining * monthlyRate
                var principalPart = fixedPrincipal
                if i == n {
                    principalPart = currentRemaining
                }
                currentRemaining = max(0, currentRemaining - principalPart)
                let payment = principalPart + interestPart

                if i == 1 {
                    initialPayment = payment
                }

                totalInterestAccum += interestPart
                totalPaymentAccum += payment

                let payDate = dateForPeriod(index: i, from: startDate, targetDay: paymentDay, calendar: calendar)

                schedule.append(RepaymentScheduleItem(
                    period: i,
                    paymentDate: payDate,
                    monthlyPayment: Double(payment),
                    principal: Double(principalPart),
                    interest: Double(interestPart),
                    remainingPrincipal: Double(currentRemaining),
                    annualRate: annualRate
                ))
            }

        case .interestFirst:
            let monthlyInterest = pDouble * monthlyRate
            initialPayment = monthlyInterest

            for i in 1...n {
                let isLast = (i == n)
                let principalPart = isLast ? pDouble : 0.0
                let interestPart = monthlyInterest
                let payment = principalPart + interestPart
                let remaining = isLast ? 0.0 : pDouble

                totalInterestAccum += interestPart
                totalPaymentAccum += payment

                let payDate = dateForPeriod(index: i, from: startDate, targetDay: paymentDay, calendar: calendar)

                schedule.append(RepaymentScheduleItem(
                    period: i,
                    paymentDate: payDate,
                    monthlyPayment: Double(payment),
                    principal: Double(principalPart),
                    interest: Double(interestPart),
                    remainingPrincipal: Double(remaining),
                    annualRate: annualRate
                ))
            }

        case .lumpSum:
            let totalInterest = pDouble * monthlyRate * Double(n)
            initialPayment = 0

            for i in 1...n {
                let isLast = (i == n)
                let principalPart = isLast ? pDouble : 0.0
                let interestPart = isLast ? totalInterest : 0.0
                let payment = principalPart + interestPart
                let remaining = isLast ? 0.0 : pDouble

                if isLast {
                    totalInterestAccum = totalInterest
                    totalPaymentAccum = payment
                }

                let payDate = dateForPeriod(index: i, from: startDate, targetDay: paymentDay, calendar: calendar)

                schedule.append(RepaymentScheduleItem(
                    period: i,
                    paymentDate: payDate,
                    monthlyPayment: Double(payment),
                    principal: Double(principalPart),
                    interest: Double(interestPart),
                    remainingPrincipal: Double(remaining),
                    annualRate: annualRate
                ))
            }
        }

        return RepaymentSummary(
            totalPayment: Double(totalPaymentAccum),
            totalInterest: Double(totalInterestAccum),
            initialMonthlyPayment: Double(initialPayment),
            currentMonthlyPayment: Double(initialPayment),
            baselineTotalInterest: Double(totalInterestAccum),
            cumulativeInterestSaved: 0,
            monthsAheadSaved: 0,
            schedule: schedule
        )
    }

    /// 计算剩余期数 NPER (基于剩余本金与目标月供)
    private static func calculateNPER(rate: Double, pmt: Double, pv: Double) -> Int {
        guard rate > 0 else {
            return Int(ceil(pv / pmt))
        }
        guard pmt > pv * rate else { return 360 } // 月供需大于当期利息

        // NPER = -ln(1 - (PV * r) / PMT) / ln(1 + r)
        let numerator = -log(1.0 - (pv * rate) / pmt)
        let denominator = log(1.0 + rate)
        let nperDouble = numerator / denominator
        return max(1, Int(ceil(nperDouble)))
    }

    private static func dateForPeriod(index: Int, from startDate: Date, targetDay: Int, calendar: Calendar) -> Date {
        guard let monthDate = calendar.date(byAdding: .month, value: index - 1, to: startDate) else {
            return startDate
        }
        var comp = calendar.dateComponents([.year, .month], from: monthDate)
        comp.day = max(1, min(targetDay, 28))
        return calendar.date(from: comp) ?? monthDate
    }
}
