import XCTest
@testable import MoneyFlow

final class SafeToSpendEngineTests: XCTestCase {

    func testSafeToSpendRelaxedStatusWhenAbundant() {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 10
        let today = calendar.date(from: comps)!

        let account = CashAccount(name: "招行", balance: 50000)
        let settings = UserSettings(
            monthlyEstimatedIncome: 20000,
            paydayOfMonth: 15,
            monthlyLivingExpense: 3000
        )
        let loan = Loan(
            name: "房贷",
            category: .mortgage,
            totalAmount: 1000000,
            remainingPrincipal: 800000,
            annualRate: 0.035,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 20,
            monthlyPayment: 5000,
            paymentDayOfMonth: 20
        )

        let result = SafeToSpendEngine.calculate(
            today: today,
            accounts: [account],
            loans: [loan],
            creditCards: [],
            settings: settings
        )

        // 8月有31天，10号开始还剩 22 天
        XCTAssertEqual(result.daysRemainingInMonth, 22)
        XCTAssertEqual(result.status, .relaxed)
        XCTAssertGreaterThan(result.dailySafeToSpend, 150)
        XCTAssertGreaterThan(result.monthlySafeToSpend, 10000)
    }

    func testSafeToSpendDeficitStatusWhenCashInsufficient() {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 10
        let today = calendar.date(from: comps)!

        let account = CashAccount(name: "招行", balance: 1000)
        let settings = UserSettings(
            monthlyEstimatedIncome: 0,
            paydayOfMonth: 1,
            monthlyLivingExpense: 5000
        )
        let loan = Loan(
            name: "房贷",
            category: .mortgage,
            totalAmount: 1000000,
            remainingPrincipal: 800000,
            annualRate: 0.035,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 20,
            monthlyPayment: 6000,
            paymentDayOfMonth: 20
        )

        let result = SafeToSpendEngine.calculate(
            today: today,
            accounts: [account],
            loans: [loan],
            creditCards: [],
            settings: settings
        )

        XCTAssertEqual(result.status, .deficit)
        XCTAssertEqual(result.dailySafeToSpend, 0)
        XCTAssertEqual(result.monthlySafeToSpend, 0)
    }

    func testBufferAlertIdentifiesShortfallWithinSevenDays() {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 10
        let today = calendar.date(from: comps)!

        let account = CashAccount(name: "招行", balance: 2000)
        let settings = UserSettings(
            monthlyEstimatedIncome: 10000,
            paydayOfMonth: 25,
            monthlyLivingExpense: 3000
        )
        let card = CreditCard(
            name: "招行信用卡",
            creditLimit: 20000,
            currentBalance: 5000,
            billingDay: 1,
            dueDay: 15 // 5天后还款
        )

        let result = SafeToSpendEngine.calculate(
            today: today,
            accounts: [account],
            loans: [],
            creditCards: [card],
            settings: settings
        )

        XCTAssertNotNil(result.bufferAlert)
        XCTAssertFalse(result.bufferAlert!.isSufficient)
        XCTAssertEqual(result.bufferAlert!.shortfallAmount, 3000) // 5000 - 2000 = 3000
        XCTAssertTrue(result.bufferAlert!.message.contains("缺口"))
    }
}
