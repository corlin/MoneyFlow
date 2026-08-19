import XCTest
@testable import MoneyFlow

final class CashFlowCalendarTests: XCTestCase {

    func testPaydayIncomeInjectionAndDailyBalanceProgression() {
        let settings = UserSettings(
            monthlyEstimatedIncome: 20000,
            paydayOfMonth: 10,
            monthlyLivingExpense: 6000
        )
        let initialCash = 10000.0

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 1
        let testDate = calendar.date(from: components)!

        let projection = CashFlowCalendarEngine.projectMonth(
            for: testDate,
            currentTotalCash: initialCash,
            settings: settings,
            loans: [],
            creditCards: []
        )

        XCTAssertEqual(projection.yearMonth, "2026-08")
        XCTAssertEqual(projection.startingBalance, 10000.0)
        XCTAssertEqual(projection.totalMonthInflow, 20000.0)
        XCTAssertEqual(projection.totalMonthOutflow, 0.0)
        XCTAssertEqual(projection.endingBalance, 30000.0)

        // 验证 10 号发薪日前后余额
        let day9 = projection.dailySummaries.first { $0.dayNumber == 9 }!
        let day10 = projection.dailySummaries.first { $0.dayNumber == 10 }!

        XCTAssertEqual(day9.endingBalance, 10000.0)
        XCTAssertEqual(day10.startingBalance, 10000.0)
        XCTAssertEqual(day10.totalInflow, 20000.0)
        XCTAssertEqual(day10.endingBalance, 30000.0)
        XCTAssertTrue(day10.inflows.contains { $0.type == .salary })
    }

    func testMultipleLoansAndCreditCardDeductionAndReconciliation() {
        let settings = UserSettings(
            monthlyEstimatedIncome: 25000,
            paydayOfMonth: 10,
            monthlyLivingExpense: 8000
        )
        let initialCash = 50000.0

        let mortgage = Loan(
            name: "招商银行房贷",
            totalAmount: 1000000,
            remainingPrincipal: 800000,
            annualRate: 0.0385,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 60,
            monthlyPayment: 5200,
            paymentDayOfMonth: 15
        )

        let creditCard = CreditCard(
            name: "工行信用卡",
            creditLimit: 50000,
            currentBalance: 3000,
            billingDay: 5,
            dueDay: 25
        )

        // 模拟房贷已对账结清
        let rec = PaymentReconciliationRecord(
            sourceID: mortgage.id,
            sourceName: mortgage.name,
            sourceType: "loan",
            yearMonth: "2026-08",
            scheduledDate: Date(),
            scheduledAmount: 5200,
            actualAmount: 5200,
            isReconciled: true
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 1
        let testDate = calendar.date(from: components)!

        let projection = CashFlowCalendarEngine.projectMonth(
            for: testDate,
            currentTotalCash: initialCash,
            settings: settings,
            loans: [mortgage],
            creditCards: [creditCard],
            reconciliations: [rec]
        )

        XCTAssertEqual(projection.totalMonthOutflow, 5200 + 3000)
        XCTAssertEqual(projection.totalReconciledCount, 1)
        XCTAssertEqual(projection.totalPendingCount, 1)

        // 15 号房贷出账且已对账
        let day15 = projection.dailySummaries.first { $0.dayNumber == 15 }!
        XCTAssertEqual(day15.totalOutflow, 5200)
        XCTAssertTrue(day15.allOutflowsReconciled)

        // 25 号信用卡出账且待还
        let day25 = projection.dailySummaries.first { $0.dayNumber == 25 }!
        XCTAssertEqual(day25.totalOutflow, 3000)
        XCTAssertFalse(day25.allOutflowsReconciled)
        XCTAssertEqual(day25.pendingReconciliationCount, 1)
    }

    func testLiquidityShortfallAndDeficitWarning() {
        let settings = UserSettings(
            monthlyEstimatedIncome: 5000,
            paydayOfMonth: 28,
            monthlyLivingExpense: 10000 // 刚性支出高
        )
        // 初始资金极低
        let initialCash = 2000.0

        let heavyLoan = Loan(
            name: "大额月供",
            totalAmount: 500000,
            remainingPrincipal: 400000,
            annualRate: 0.05,
            repaymentMethod: .equalPayment,
            totalPeriods: 120,
            paidPeriods: 20,
            monthlyPayment: 4500,
            paymentDayOfMonth: 5
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 1
        let testDate = calendar.date(from: components)!

        let projection = CashFlowCalendarEngine.projectMonth(
            for: testDate,
            currentTotalCash: initialCash,
            settings: settings,
            loans: [heavyLoan],
            creditCards: []
        )

        // 5 号还贷后 2000 - 4500 = -2500，发生透支穿底
        let day5 = projection.dailySummaries.first { $0.dayNumber == 5 }!
        XCTAssertEqual(day5.endingBalance, -2500.0)
        XCTAssertTrue(day5.isDeficitRisk)
        XCTAssertTrue(day5.isShortfallRisk)
        XCTAssertGreaterThan(projection.deficitDaysCount, 0)
    }

    func testCustomIncomeAndExpenseEventsMapping() {
        let settings = UserSettings(monthlyEstimatedIncome: 10000, paydayOfMonth: 10)
        let initialCash = 20000.0

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 20
        let eventDate = calendar.date(from: components)!

        let bonusEvent = CustomCashFlowEvent(
            title: "项目奖金",
            amount: 8000,
            isIncome: true,
            date: eventDate,
            isRecurringMonthly: false,
            icon: "gift.fill"
        )

        let insuranceEvent = CustomCashFlowEvent(
            title: "年度车险",
            amount: 3500,
            isIncome: false,
            date: eventDate,
            isRecurringMonthly: false,
            icon: "car.fill"
        )

        var monthComponents = DateComponents()
        monthComponents.year = 2026
        monthComponents.month = 8
        monthComponents.day = 1
        let testDate = calendar.date(from: monthComponents)!

        let projection = CashFlowCalendarEngine.projectMonth(
            for: testDate,
            currentTotalCash: initialCash,
            settings: settings,
            loans: [],
            creditCards: [],
            customEvents: [bonusEvent, insuranceEvent]
        )

        let day20 = projection.dailySummaries.first { $0.dayNumber == 20 }!
        XCTAssertEqual(day20.totalInflow, 8000)
        XCTAssertEqual(day20.totalOutflow, 3500)
        XCTAssertEqual(day20.netChange, 4500)
    }
}
