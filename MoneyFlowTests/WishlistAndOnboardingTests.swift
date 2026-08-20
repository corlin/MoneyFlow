import XCTest
import SwiftData
@testable import MoneyFlow

final class WishlistAndOnboardingTests: XCTestCase {

    func testWishlistPresetsIntegrity() {
        let presets = WishlistTemplate.presets
        XCTAssertGreaterThanOrEqual(presets.count, 6)

        // 确保所有模版 ID 唯一且金额大于 0
        let ids = presets.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count)

        for preset in presets {
            XCTAssertGreaterThan(preset.defaultTargetAmount, 0)
            XCTAssertFalse(preset.name.isEmpty)
            XCTAssertFalse(preset.icon.isEmpty)
        }
    }

    func testQuickOnboardingDataInitialization() throws {
        let schema = Schema([
            CashAccount.self,
            Loan.self,
            CreditCard.self,
            FinancialGoal.self,
            UserSettings.self,
            PaymentReconciliationRecord.self,
            CustomCashFlowEvent.self,
            LoanAdjustmentEvent.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // 模拟 30 秒新手输入
        let initialCash = 30000.0
        let monthlyIncome = 12000.0
        let monthlyDebt = 4000.0
        let living = 3500.0

        let account = CashAccount(name: "常用资金账户", balance: initialCash)
        context.insert(account)

        let loan = Loan(
            name: "房贷/固定月供",
            category: .mortgage,
            totalAmount: monthlyDebt * 240,
            remainingPrincipal: monthlyDebt * 200,
            annualRate: 0.035,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 20,
            monthlyPayment: monthlyDebt,
            paymentDayOfMonth: 20
        )
        context.insert(loan)

        let settings = UserSettings(
            monthlyEstimatedIncome: monthlyIncome,
            paydayOfMonth: 15,
            monthlyLivingExpense: living
        )
        context.insert(settings)
        try context.save()

        // 验证计算结果
        let result = SafeToSpendEngine.calculate(
            today: Date(),
            accounts: [account],
            loans: [loan],
            creditCards: [],
            settings: settings
        )

        XCTAssertEqual(result.status, .relaxed)
        XCTAssertGreaterThan(result.dailySafeToSpend, 0)
        XCTAssertGreaterThan(result.monthlySafeToSpend, 0)
    }

    func testWishlistJarProgressAndDeposit() {
        let goal = FinancialGoal(
            name: "换新手机",
            category: .capitalMilestone,
            targetAmount: 8000,
            currentEarmarkedAmount: 2000,
            priority: .important,
            targetDate: Date().addingMonths(4)
        )

        XCTAssertEqual(goal.currentEarmarkedAmount, 2000)
        let remaining = goal.targetAmount - goal.currentEarmarkedAmount
        XCTAssertEqual(remaining, 6000)

        // 模拟存入 500
        goal.currentEarmarkedAmount += 500
        XCTAssertEqual(goal.currentEarmarkedAmount, 2500)
        XCTAssertEqual(goal.targetAmount - goal.currentEarmarkedAmount, 5500)
    }
}
