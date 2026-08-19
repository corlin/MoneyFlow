import Foundation

enum CalendarFlowItemType: String, Codable {
    case salary = "salary"
    case customIncome = "customIncome"
    case loanPayment = "loanPayment"
    case creditCardPayment = "creditCardPayment"
    case customExpense = "customExpense"

    var defaultIcon: String {
        switch self {
        case .salary: return "banknote.fill"
        case .customIncome: return "arrow.down.circle.fill"
        case .loanPayment: return "house.fill"
        case .creditCardPayment: return "creditcard.fill"
        case .customExpense: return "arrow.up.circle.fill"
        }
    }
}

struct CalendarFlowItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var sourceID: UUID?
    var title: String
    var amount: Double
    var isIncome: Bool
    var type: CalendarFlowItemType
    var isReconciled: Bool = false
    var icon: String
    var badgeText: String? = nil

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        title: String,
        amount: Double,
        isIncome: Bool,
        type: CalendarFlowItemType,
        isReconciled: Bool = false,
        icon: String? = nil,
        badgeText: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.type = type
        self.isReconciled = isReconciled
        self.icon = icon ?? type.defaultIcon
        self.badgeText = badgeText
    }
}

struct DailyCashFlowSummary: Identifiable, Equatable {
    var id: String { dateKey }
    var dateKey: String
    var date: Date
    var dayNumber: Int
    var isToday: Bool
    var startingBalance: Double
    var totalInflow: Double
    var totalOutflow: Double
    var endingBalance: Double
    var inflows: [CalendarFlowItem]
    var outflows: [CalendarFlowItem]
    var isShortfallRisk: Bool
    var isDeficitRisk: Bool
    var allOutflowsReconciled: Bool
    var pendingReconciliationCount: Int

    var netChange: Double {
        totalInflow - totalOutflow
    }

    var hasEvents: Bool {
        !inflows.isEmpty || !outflows.isEmpty
    }
}

struct MonthlyCalendarProjection: Equatable {
    var yearMonth: String
    var monthTitle: String
    var startingBalance: Double
    var totalMonthInflow: Double
    var totalMonthOutflow: Double
    var endingBalance: Double
    var lowestBalance: Double
    var lowestBalanceDate: Date?
    var shortfallDaysCount: Int
    var deficitDaysCount: Int
    var totalReconciledCount: Int
    var totalPendingCount: Int
    var dailySummaries: [DailyCashFlowSummary]
}

enum CashFlowCalendarEngine {

    /// 生成指定月份的完整逐日现金流水推演表
    static func projectMonth(
        for targetDate: Date = Date(),
        currentTotalCash: Double,
        settings: UserSettings,
        loans: [Loan],
        creditCards: [CreditCard],
        customEvents: [CustomCashFlowEvent] = [],
        reconciliations: [PaymentReconciliationRecord] = []
    ) -> MonthlyCalendarProjection {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: targetDate)
        let month = calendar.component(.month, from: targetDate)
        let yearMonthKey = String(format: "%04d-%02d", year, month)
        let monthTitle = String(format: "%d年%d月", year, month)

        guard let monthInterval = calendar.dateInterval(of: .month, for: targetDate),
              let rangeOfDays = calendar.range(of: .day, in: .month, for: targetDate) else {
            return MonthlyCalendarProjection(
                yearMonth: yearMonthKey,
                monthTitle: monthTitle,
                startingBalance: currentTotalCash,
                totalMonthInflow: 0,
                totalMonthOutflow: 0,
                endingBalance: currentTotalCash,
                lowestBalance: currentTotalCash,
                lowestBalanceDate: targetDate,
                shortfallDaysCount: 0,
                deficitDaysCount: 0,
                totalReconciledCount: 0,
                totalPendingCount: 0,
                dailySummaries: []
            )
        }

        // 安全应急资金红线 (默认以 1 个月必要生活支出与负债服务为基准)
        let monthlyDebtService = loans.reduce(0.0) { $0 + ($1.remainingPrincipal > 0 ? $1.monthlyPayment : 0) }
            + creditCards.reduce(0.0) { $0 + $1.currentBalance }
        let safetyThreshold = max(5000, settings.monthlyLivingExpense + (monthlyDebtService * 0.5))

        // 建立该月的对账记录索引表 [sourceID: PaymentReconciliationRecord]
        let monthReconciliations = reconciliations.filter { $0.yearMonth == yearMonthKey }
        var reconciliationMap: [UUID: PaymentReconciliationRecord] = [:]
        for record in monthReconciliations {
            reconciliationMap[record.sourceID] = record
        }

        let today = Date()
        let todayDayKey = formatDateKey(today)

        var runningBalance = max(0, currentTotalCash)
        var summaries: [DailyCashFlowSummary] = []
        var totalInflow = 0.0
        var totalOutflow = 0.0
        var lowestBalance = runningBalance
        var lowestBalanceDate: Date? = monthInterval.start
        var shortfallCount = 0
        var deficitCount = 0
        var totalReconciled = 0
        var totalPending = 0

        for day in rangeOfDays {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            guard let dayDate = calendar.date(from: dateComponents) else { continue }
            let dayKey = formatDateKey(dayDate)
            let isToday = (dayKey == todayDayKey)

            var dayInflows: [CalendarFlowItem] = []
            var dayOutflows: [CalendarFlowItem] = []

            // 1. 发薪日注入与对账匹配
            if day == settings.paydayOfMonth && settings.monthlyEstimatedIncome > 0 {
                let rec = monthReconciliations.first { $0.sourceType == "salary" }
                let isReconciled = rec?.isReconciled ?? false
                let amount = (rec?.isReconciled == true) ? (rec?.actualAmount ?? settings.monthlyEstimatedIncome) : settings.monthlyEstimatedIncome
                let salarySourceID = rec?.sourceID ?? settings.id

                dayInflows.append(CalendarFlowItem(
                    sourceID: salarySourceID,
                    title: "工资收入",
                    amount: amount,
                    isIncome: true,
                    type: .salary,
                    isReconciled: isReconciled,
                    icon: "banknote.fill",
                    badgeText: isReconciled ? "已到账" : "待到账"
                ))

                if isReconciled {
                    totalReconciled += 1
                } else {
                    totalPending += 1
                }
            }

            // 2. 贷款还款日出账与对账状态匹配
            for loan in loans where loan.remainingPrincipal > 0 {
                let paymentDay = min(loan.paymentDayOfMonth, rangeOfDays.count)
                if day == paymentDay {
                    let rec = reconciliationMap[loan.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = rec?.isReconciled == true ? (rec?.actualAmount ?? loan.monthlyPayment) : loan.monthlyPayment

                    dayOutflows.append(CalendarFlowItem(
                        sourceID: loan.id,
                        title: loan.name,
                        amount: amount,
                        isIncome: false,
                        type: .loanPayment,
                        isReconciled: isReconciled,
                        icon: "house.fill",
                        badgeText: isReconciled ? "已结清" : "待还"
                    ))

                    if isReconciled {
                        totalReconciled += 1
                    } else {
                        totalPending += 1
                    }
                }
            }

            // 3. 信用卡账单还款日出账与对账状态匹配
            for card in creditCards where card.currentBalance > 0 {
                let paymentDay = min(card.dueDay, rangeOfDays.count)
                if day == paymentDay {
                    let rec = reconciliationMap[card.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = rec?.isReconciled == true ? (rec?.actualAmount ?? card.currentBalance) : card.currentBalance

                    dayOutflows.append(CalendarFlowItem(
                        sourceID: card.id,
                        title: card.name,
                        amount: amount,
                        isIncome: false,
                        type: .creditCardPayment,
                        isReconciled: isReconciled,
                        icon: "creditcard.fill",
                        badgeText: isReconciled ? "已结清" : "待还"
                    ))

                    if isReconciled {
                        totalReconciled += 1
                    } else {
                        totalPending += 1
                    }
                }
            }

            // 4. 自定义收支事件与对账状态匹配
            for event in customEvents {
                let eventDay = calendar.component(.day, from: event.date)
                let eventMonth = calendar.component(.month, from: event.date)
                let eventYear = calendar.component(.year, from: event.date)

                let matchesMonth = event.isRecurringMonthly || (eventYear == year && eventMonth == month)
                if matchesMonth && eventDay == day {
                    let rec = reconciliationMap[event.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = (rec?.isReconciled == true) ? (rec?.actualAmount ?? event.amount) : event.amount

                    let flowItem = CalendarFlowItem(
                        sourceID: event.id,
                        title: event.title,
                        amount: amount,
                        isIncome: event.isIncome,
                        type: event.isIncome ? .customIncome : .customExpense,
                        isReconciled: isReconciled,
                        icon: event.icon,
                        badgeText: isReconciled ? (event.isIncome ? "已到账" : "已结清") : (event.isIncome ? "待到账" : "待还")
                    )
                    if event.isIncome {
                        dayInflows.append(flowItem)
                    } else {
                        dayOutflows.append(flowItem)
                    }

                    if isReconciled {
                        totalReconciled += 1
                    } else {
                        totalPending += 1
                    }
                }
            }

            let startBal = runningBalance
            let dayIn = dayInflows.reduce(0.0) { $0 + $1.amount }
            let dayOut = dayOutflows.reduce(0.0) { $0 + $1.amount }
            let endBal = startBal + dayIn - dayOut

            runningBalance = endBal
            totalInflow += dayIn
            totalOutflow += dayOut

            if endBal < lowestBalance {
                lowestBalance = endBal
                lowestBalanceDate = dayDate
            }

            let isShortfall = (endBal < safetyThreshold)
            let isDeficit = (endBal < 0)
            if isShortfall { shortfallCount += 1 }
            if isDeficit { deficitCount += 1 }

            let allOutflowsReconciled = dayOutflows.isEmpty || dayOutflows.allSatisfy { $0.isReconciled }
            let pendingCount = dayOutflows.filter { !$0.isReconciled }.count

            summaries.append(DailyCashFlowSummary(
                dateKey: dayKey,
                date: dayDate,
                dayNumber: day,
                isToday: isToday,
                startingBalance: startBal,
                totalInflow: dayIn,
                totalOutflow: dayOut,
                endingBalance: endBal,
                inflows: dayInflows,
                outflows: dayOutflows,
                isShortfallRisk: isShortfall,
                isDeficitRisk: isDeficit,
                allOutflowsReconciled: allOutflowsReconciled,
                pendingReconciliationCount: pendingCount
            ))
        }

        return MonthlyCalendarProjection(
            yearMonth: yearMonthKey,
            monthTitle: monthTitle,
            startingBalance: currentTotalCash,
            totalMonthInflow: totalInflow,
            totalMonthOutflow: totalOutflow,
            endingBalance: runningBalance,
            lowestBalance: lowestBalance,
            lowestBalanceDate: lowestBalanceDate,
            shortfallDaysCount: shortfallCount,
            deficitDaysCount: deficitCount,
            totalReconciledCount: totalReconciled,
            totalPendingCount: totalPending,
            dailySummaries: summaries
        )
    }

    /// 获取未来 30 天滑动窗口的逐日现金流数据
    static func projectNextThirtyDays(
        from startDate: Date = Date(),
        currentTotalCash: Double,
        settings: UserSettings,
        loans: [Loan],
        creditCards: [CreditCard],
        customEvents: [CustomCashFlowEvent] = [],
        reconciliations: [PaymentReconciliationRecord] = []
    ) -> [DailyCashFlowSummary] {
        let calendar = Calendar.current
        var results: [DailyCashFlowSummary] = []
        var runningBalance = max(0, currentTotalCash)

        let monthlyDebtService = loans.reduce(0.0) { $0 + ($1.remainingPrincipal > 0 ? $1.monthlyPayment : 0) }
            + creditCards.reduce(0.0) { $0 + $1.currentBalance }
        let safetyThreshold = max(5000, settings.monthlyLivingExpense + (monthlyDebtService * 0.5))

        let todayKey = formatDateKey(Date())

        for dayOffset in 0..<30 {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dayKey = formatDateKey(targetDay)
            let dayNumber = calendar.component(.day, from: targetDay)
            let year = calendar.component(.year, from: targetDay)
            let month = calendar.component(.month, from: targetDay)
            let yearMonthKey = String(format: "%04d-%02d", year, month)

            let monthReconciliations = reconciliations.filter { $0.yearMonth == yearMonthKey }
            var reconciliationMap: [UUID: PaymentReconciliationRecord] = [:]
            for record in monthReconciliations {
                reconciliationMap[record.sourceID] = record
            }

            var dayInflows: [CalendarFlowItem] = []
            var dayOutflows: [CalendarFlowItem] = []

            // 发薪
            if dayNumber == settings.paydayOfMonth && settings.monthlyEstimatedIncome > 0 {
                let rec = monthReconciliations.first { $0.sourceType == "salary" }
                let isReconciled = rec?.isReconciled ?? false
                let amount = (rec?.isReconciled == true) ? (rec?.actualAmount ?? settings.monthlyEstimatedIncome) : settings.monthlyEstimatedIncome
                let salarySourceID = rec?.sourceID ?? settings.id

                dayInflows.append(CalendarFlowItem(
                    sourceID: salarySourceID,
                    title: "工资收入",
                    amount: amount,
                    isIncome: true,
                    type: .salary,
                    isReconciled: isReconciled,
                    icon: "banknote.fill",
                    badgeText: isReconciled ? "已到账" : "待到账"
                ))
            }

            // 贷款
            for loan in loans where loan.remainingPrincipal > 0 {
                if dayNumber == loan.paymentDayOfMonth {
                    let rec = reconciliationMap[loan.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = rec?.isReconciled == true ? (rec?.actualAmount ?? loan.monthlyPayment) : loan.monthlyPayment

                    dayOutflows.append(CalendarFlowItem(
                        sourceID: loan.id,
                        title: loan.name,
                        amount: amount,
                        isIncome: false,
                        type: .loanPayment,
                        isReconciled: isReconciled,
                        icon: "house.fill",
                        badgeText: isReconciled ? "已结清" : "待还"
                    ))
                }
            }

            // 信用卡
            for card in creditCards where card.currentBalance > 0 {
                if dayNumber == card.dueDay {
                    let rec = reconciliationMap[card.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = rec?.isReconciled == true ? (rec?.actualAmount ?? card.currentBalance) : card.currentBalance

                    dayOutflows.append(CalendarFlowItem(
                        sourceID: card.id,
                        title: card.name,
                        amount: amount,
                        isIncome: false,
                        type: .creditCardPayment,
                        isReconciled: isReconciled,
                        icon: "creditcard.fill",
                        badgeText: isReconciled ? "已结清" : "待还"
                    ))
                }
            }

            // 自定义事件
            for event in customEvents {
                let eventDay = calendar.component(.day, from: event.date)
                let eventMonth = calendar.component(.month, from: event.date)
                let eventYear = calendar.component(.year, from: event.date)
                let matches = event.isRecurringMonthly || (eventYear == year && eventMonth == month)
                if matches && eventDay == dayNumber {
                    let rec = reconciliationMap[event.id]
                    let isReconciled = rec?.isReconciled ?? false
                    let amount = (rec?.isReconciled == true) ? (rec?.actualAmount ?? event.amount) : event.amount

                    let flowItem = CalendarFlowItem(
                        sourceID: event.id,
                        title: event.title,
                        amount: amount,
                        isIncome: event.isIncome,
                        type: event.isIncome ? .customIncome : .customExpense,
                        isReconciled: isReconciled,
                        icon: event.icon,
                        badgeText: isReconciled ? (event.isIncome ? "已到账" : "已结清") : (event.isIncome ? "待到账" : "待还")
                    )
                    if event.isIncome {
                        dayInflows.append(flowItem)
                    } else {
                        dayOutflows.append(flowItem)
                    }
                }
            }

            let startBal = runningBalance
            let dayIn = dayInflows.reduce(0.0) { $0 + $1.amount }
            let dayOut = dayOutflows.reduce(0.0) { $0 + $1.amount }
            let endBal = startBal + dayIn - dayOut
            runningBalance = endBal

            let isShortfall = (endBal < safetyThreshold)
            let isDeficit = (endBal < 0)
            let allReconciled = dayOutflows.isEmpty || dayOutflows.allSatisfy { $0.isReconciled }
            let pendingCount = dayOutflows.filter { !$0.isReconciled }.count

            results.append(DailyCashFlowSummary(
                dateKey: dayKey,
                date: targetDay,
                dayNumber: dayNumber,
                isToday: (dayKey == todayKey),
                startingBalance: startBal,
                totalInflow: dayIn,
                totalOutflow: dayOut,
                endingBalance: endBal,
                inflows: dayInflows,
                outflows: dayOutflows,
                isShortfallRisk: isShortfall,
                isDeficitRisk: isDeficit,
                allOutflowsReconciled: allReconciled,
                pendingReconciliationCount: pendingCount
            ))
        }

        return results
    }

    private static func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
