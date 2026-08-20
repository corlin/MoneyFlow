import Foundation

enum SpendStatus: String, Codable, Equatable {
    case relaxed = "relaxed"   // 充裕安心花 🟢
    case moderate = "moderate" // 平稳适度花 🟡
    case tight = "tight"       // 紧绷需节制 🔴
    case deficit = "deficit"   // 资金告急/透支 ⚠️

    var title: String {
        switch self {
        case .relaxed: return "安心花 🟢"
        case .moderate: return "适度花 🟡"
        case .tight: return "需节制 🔴"
        case .deficit: return "透支预警 ⚠️"
        }
    }

    var colorHex: String {
        switch self {
        case .relaxed: return "#34C759"
        case .moderate: return "#FF9500"
        case .tight: return "#FF3B30"
        case .deficit: return "#AF52DE"
        }
    }
}

struct PrepaymentBufferAlert: Equatable {
    let isSufficient: Bool
    let title: String
    let message: String
    let shortfallAmount: Double
    let nearestDueDate: Date?
    let targetSourceName: String?

    init(
        isSufficient: Bool,
        title: String,
        message: String,
        shortfallAmount: Double = 0,
        nearestDueDate: Date? = nil,
        targetSourceName: String? = nil
    ) {
        self.isSufficient = isSufficient
        self.title = title
        self.message = message
        self.shortfallAmount = shortfallAmount
        self.nearestDueDate = nearestDueDate
        self.targetSourceName = targetSourceName
    }
}

struct SafeToSpendResult: Equatable {
    let dailySafeToSpend: Double
    let monthlySafeToSpend: Double
    let daysRemainingInMonth: Int
    let status: SpendStatus
    let statusDescription: String
    let bufferAlert: PrepaymentBufferAlert?
    let currentCash: Double
    let pendingIncomeThisMonth: Double
    let pendingMustPayThisMonth: Double
    let remainingLivingExpenseThisMonth: Double
    let emergencyReserveFloor: Double

    init(
        dailySafeToSpend: Double,
        monthlySafeToSpend: Double,
        daysRemainingInMonth: Int,
        status: SpendStatus,
        statusDescription: String,
        bufferAlert: PrepaymentBufferAlert?,
        currentCash: Double,
        pendingIncomeThisMonth: Double,
        pendingMustPayThisMonth: Double,
        remainingLivingExpenseThisMonth: Double,
        emergencyReserveFloor: Double
    ) {
        self.dailySafeToSpend = dailySafeToSpend
        self.monthlySafeToSpend = monthlySafeToSpend
        self.daysRemainingInMonth = daysRemainingInMonth
        self.status = status
        self.statusDescription = statusDescription
        self.bufferAlert = bufferAlert
        self.currentCash = currentCash
        self.pendingIncomeThisMonth = pendingIncomeThisMonth
        self.pendingMustPayThisMonth = pendingMustPayThisMonth
        self.remainingLivingExpenseThisMonth = remainingLivingExpenseThisMonth
        self.emergencyReserveFloor = emergencyReserveFloor
    }
}

enum SafeToSpendEngine {

    /// 计算大白话「今日安全可花」与备款诊断
    static func calculate(
        today: Date = Date(),
        accounts: [CashAccount],
        loans: [Loan],
        creditCards: [CreditCard],
        settings: UserSettings,
        reconciliations: [PaymentReconciliationRecord] = [],
        customEvents: [CustomCashFlowEvent] = []
    ) -> SafeToSpendResult {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let yearMonthKey = String(format: "%04d-%02d", currentYear, currentMonth)

        // 1. 本月天数与剩余天数 (含今日)
        guard let rangeOfDays = calendar.range(of: .day, in: .month, for: today) else {
            return fallbackResult(currentCash: accounts.reduce(0) { $0 + $1.balance })
        }
        let totalDaysInMonth = rangeOfDays.count
        let daysRemaining = max(1, totalDaysInMonth - currentDay + 1)
        let dayRatioRemaining = Double(daysRemaining) / Double(totalDaysInMonth)

        // 2. 当前总流动现金
        let currentCash = max(0, accounts.reduce(0.0) { $0 + $1.balance })

        // 3. 本月对账记录索引
        let monthRecs = reconciliations.filter { $0.yearMonth == yearMonthKey }
        var recMap: [UUID: PaymentReconciliationRecord] = [:]
        for r in monthRecs {
            recMap[r.sourceID] = r
        }
        let salaryRec = monthRecs.first { $0.sourceType == "salary" }

        // 4. 本月剩余待入账收入 (Pending Income)
        var pendingIncome = 0.0
        if currentDay <= settings.paydayOfMonth && settings.monthlyEstimatedIncome > 0 {
            if salaryRec?.isReconciled != true {
                pendingIncome += settings.monthlyEstimatedIncome
            }
        }
        for event in customEvents where event.isIncome {
            let evDay = calendar.component(.day, from: event.date)
            let evMonth = calendar.component(.month, from: event.date)
            let evYear = calendar.component(.year, from: event.date)
            let matches = event.isRecurringMonthly || (evYear == currentYear && evMonth == currentMonth)
            if matches && evDay >= currentDay {
                if recMap[event.id]?.isReconciled != true {
                    pendingIncome += event.amount
                }
            }
        }

        // 5. 本月剩余待还刚性支出 (Pending Debt Service)
        var pendingDebtService = 0.0
        for loan in loans where loan.remainingPrincipal > 0 {
            if loan.paymentDayOfMonth >= currentDay {
                if recMap[loan.id]?.isReconciled != true {
                    pendingDebtService += loan.monthlyPayment
                }
            }
        }
        for card in creditCards where card.currentBalance > 0 {
            if card.dueDay >= currentDay {
                if recMap[card.id]?.isReconciled != true {
                    pendingDebtService += card.currentBalance
                }
            }
        }
        for event in customEvents where !event.isIncome {
            let evDay = calendar.component(.day, from: event.date)
            let evMonth = calendar.component(.month, from: event.date)
            let evYear = calendar.component(.year, from: event.date)
            let matches = event.isRecurringMonthly || (evYear == currentYear && evMonth == currentMonth)
            if matches && evDay >= currentDay {
                if recMap[event.id]?.isReconciled != true {
                    pendingDebtService += event.amount
                }
            }
        }

        // 6. 本月剩余刚性生活费底线
        let remainingLivingExpense = settings.monthlyLivingExpense * dayRatioRemaining

        // 7. 基础安全应急垫底 (设为 1 个月生活底线，保护基本盘)
        let emergencyReserveFloor = max(3000.0, settings.monthlyLivingExpense * 1.0)

        // 8. 自由零花钱总池与单日可花额度
        let totalFunds = currentCash + pendingIncome
        let totalMustCommitted = pendingDebtService + remainingLivingExpense

        let netSurplus = totalFunds - totalMustCommitted
        let monthlySafeToSpend: Double
        if netSurplus > emergencyReserveFloor {
            monthlySafeToSpend = netSurplus - (emergencyReserveFloor * 0.5) // 保留一半应急金，其余可自由支配
        } else if netSurplus > 0 {
            monthlySafeToSpend = netSurplus * 0.5
        } else {
            monthlySafeToSpend = 0
        }

        let dailySafeToSpend = max(0, monthlySafeToSpend / Double(daysRemaining))

        // 9. 状态与大白话描述
        let status: SpendStatus
        let statusDesc: String

        if totalFunds < totalMustCommitted {
            status = .deficit
            statusDesc = "当前资金无法覆盖本月剩余支出，请停止非必要消费并备款。"
        } else if dailySafeToSpend < 50 {
            status = .tight
            statusDesc = "本月剩余可用闲钱偏紧，建议控制餐饮聚会与非必要开销。"
        } else if dailySafeToSpend < 150 {
            status = .moderate
            statusDesc = "收支相对平稳，今日可适度消费，注意保留还贷底线。"
        } else {
            status = .relaxed
            statusDesc = "已备足本月所有房贷车贷与生活费，今日可随心放心花！"
        }

        // 10. 近 7 天备款缺口与充足性诊断 (Smart Buffer Advisor)
        let bufferAlert = diagnoseNextSevenDaysBuffer(
            today: today,
            currentDay: currentDay,
            loans: loans,
            creditCards: creditCards,
            accounts: accounts,
            recMap: recMap
        )

        return SafeToSpendResult(
            dailySafeToSpend: dailySafeToSpend,
            monthlySafeToSpend: monthlySafeToSpend,
            daysRemainingInMonth: daysRemaining,
            status: status,
            statusDescription: statusDesc,
            bufferAlert: bufferAlert,
            currentCash: currentCash,
            pendingIncomeThisMonth: pendingIncome,
            pendingMustPayThisMonth: pendingDebtService,
            remainingLivingExpenseThisMonth: remainingLivingExpense,
            emergencyReserveFloor: emergencyReserveFloor
        )
    }

    /// 诊断未来 7 天内的还款备款情况
    private static func diagnoseNextSevenDaysBuffer(
        today: Date,
        currentDay: Int,
        loans: [Loan],
        creditCards: [CreditCard],
        accounts: [CashAccount],
        recMap: [UUID: PaymentReconciliationRecord]
    ) -> PrepaymentBufferAlert? {
        let maxLookaheadDay = currentDay + 7
        let totalCash = accounts.reduce(0.0) { $0 + $1.balance }

        // 寻找 7 天内即将到期的第一笔负债
        var upcomingItems: [(name: String, amount: Double, dueDay: Int)] = []

        for loan in loans where loan.remainingPrincipal > 0 {
            if loan.paymentDayOfMonth >= currentDay && loan.paymentDayOfMonth <= maxLookaheadDay {
                if recMap[loan.id]?.isReconciled != true {
                    upcomingItems.append((loan.name, loan.monthlyPayment, loan.paymentDayOfMonth))
                }
            }
        }

        for card in creditCards where card.currentBalance > 0 {
            if card.dueDay >= currentDay && card.dueDay <= maxLookaheadDay {
                if recMap[card.id]?.isReconciled != true {
                    upcomingItems.append((card.name, card.currentBalance, card.dueDay))
                }
            }
        }

        guard let nearest = upcomingItems.sorted(by: { $0.dueDay < $1.dueDay }).first else {
            return PrepaymentBufferAlert(
                isSufficient: true,
                title: "近7天无紧迫扣款",
                message: "未来 7 天内无待扣款项目，资金安全无忧。"
            )
        }

        let daysUntil = nearest.dueDay - currentDay
        let daysText = daysUntil == 0 ? "今天" : "\(daysUntil)天后"

        if totalCash < nearest.amount {
            let shortfall = nearest.amount - totalCash
            return PrepaymentBufferAlert(
                isSufficient: false,
                title: "\(daysText)还款备款提醒",
                message: "「\(nearest.name)」将于\(daysText)扣款 ¥\(Int(nearest.amount))，当前总现金仅 ¥\(Int(totalCash))，缺口 ¥\(Int(shortfall))，建议尽快转入备齐。",
                shortfallAmount: shortfall,
                targetSourceName: nearest.name
            )
        } else {
            return PrepaymentBufferAlert(
                isSufficient: true,
                title: "\(daysText)还款资金已备齐",
                message: "「\(nearest.name)」将于\(daysText)扣款 ¥\(Int(nearest.amount))，当前可用资金充足，扣款无忧。"
            )
        }
    }

    private static func fallbackResult(currentCash: Double) -> SafeToSpendResult {
        SafeToSpendResult(
            dailySafeToSpend: max(0, currentCash / 30.0),
            monthlySafeToSpend: currentCash,
            daysRemainingInMonth: 30,
            status: .relaxed,
            statusDescription: "资金平稳",
            bufferAlert: nil,
            currentCash: currentCash,
            pendingIncomeThisMonth: 0,
            pendingMustPayThisMonth: 0,
            remainingLivingExpenseThisMonth: 0,
            emergencyReserveFloor: 0
        )
    }
}
