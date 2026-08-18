import Foundation

struct RepaymentScheduleItem: Identifiable, Equatable {
    let period: Int                 // 期数 (1, 2, ...)
    let paymentDate: Date          // 预计还款日期
    let monthlyPayment: Double     // 当期还款总额
    let principal: Double          // 当期偿还本金
    let interest: Double           // 当期偿还利息
    let remainingPrincipal: Double // 偿还后剩余本金

    var id: Int { period }
}

struct RepaymentSummary: Equatable {
    let totalPayment: Double      // 还款总额 (本+息)
    let totalInterest: Double     // 累计支付利息
    let initialMonthlyPayment: Double // 首期月供
    let schedule: [RepaymentScheduleItem]
}

enum RepaymentCalculator {

    /// 计算完整的还款计划表
    /// - Parameters:
    ///   - principal: 贷款总本金 (P)
    ///   - annualRate: 年化利率 (如 0.035 代表 3.5%)
    ///   - totalPeriods: 总期数 (月)
    ///   - method: 还款方式
    ///   - startDate: 贷款起始日
    ///   - paymentDay: 每月还款日
    static func calculateSchedule(
        principal: Double,
        annualRate: Double,
        totalPeriods: Int,
        method: RepaymentMethod,
        startDate: Date = Date(),
        paymentDay: Int = 10
    ) -> RepaymentSummary {
        guard principal > 0, totalPeriods > 0 else {
            return RepaymentSummary(totalPayment: 0, totalInterest: 0, initialMonthlyPayment: 0, schedule: [])
        }

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
            // 等额本息：每月还款额固定
            // M = P * r * (1+r)^n / ((1+r)^n - 1)
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

                // 最后一期微调，避免浮点舍入误差
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
                    remainingPrincipal: Double(currentRemaining)
                ))
            }

        case .equalPrincipal:
            // 等额本金：每月偿还本金固定，利息逐月递减
            // 每月本金 = P / n
            // 第 i 期利息 = (P - (i-1) * 每月本金) * r
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
                    remainingPrincipal: Double(currentRemaining)
                ))
            }

        case .interestFirst:
            // 先息后本：每月只付利息，最后一期付本金 + 当期利息
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
                    remainingPrincipal: Double(remaining)
                ))
            }

        case .lumpSum:
            // 一次性还本付息：到期一次性结清全部本金及累计单利/复利 (通常为单利: P * r * n)
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
                    remainingPrincipal: Double(remaining)
                ))
            }
        }

        return RepaymentSummary(
            totalPayment: Double(totalPaymentAccum),
            totalInterest: Double(totalInterestAccum),
            initialMonthlyPayment: Double(initialPayment),
            schedule: schedule
        )
    }

    private static func dateForPeriod(index: Int, from startDate: Date, targetDay: Int, calendar: Calendar) -> Date {
        guard let monthDate = calendar.date(byAdding: .month, value: index, to: startDate) else {
            return startDate
        }
        var comp = calendar.dateComponents([.year, .month], from: monthDate)
        comp.day = max(1, min(targetDay, 28))
        return calendar.date(from: comp) ?? monthDate
    }
}
