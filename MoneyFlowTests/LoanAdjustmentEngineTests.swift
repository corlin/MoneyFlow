import XCTest
import SwiftData
@testable import MoneyFlow

final class LoanAdjustmentEngineTests: XCTestCase {

    // MARK: - 1. 连续多次 LPR 利率重定价测试

    func testMortgageLPRMultipleRateAdjustments() {
        // 初始 100 万房贷，30 年 (360期)，等额本息，初始 5.20%
        let p0 = 1000000.0
        let r0 = 0.052
        let n0 = 360

        // 模拟历经 3 次下调:
        // 第 12 期降至 4.20% (LPR -100bp)
        let ev1 = LoanAdjustmentEvent(periodIndex: 12, type: .rateAdjustment, newAnnualRate: 0.042)
        // 第 24 期降至 3.85% (LPR -35bp)
        let ev2 = LoanAdjustmentEvent(periodIndex: 24, type: .rateAdjustment, newAnnualRate: 0.0385)
        // 第 36 期降至 3.10% (存量房贷大降息)
        let ev3 = LoanAdjustmentEvent(periodIndex: 36, type: .rateAdjustment, newAnnualRate: 0.0310)

        let summary = RepaymentCalculator.calculateSchedule(
            principal: p0,
            annualRate: r0,
            totalPeriods: n0,
            method: .equalPayment,
            events: [ev1, ev2, ev3]
        )

        XCTAssertEqual(summary.schedule.count, 360)

        // 验证各分段月供与利率：
        // 第 1 期 (5.20% 利率下)
        let item1 = summary.schedule[0]
        XCTAssertEqual(item1.annualRate, 0.052, accuracy: 0.0001)
        XCTAssertEqual(item1.monthlyPayment, 5491.0, accuracy: 5.0)

        // 第 12 期 (已调至 4.20%)
        let item12 = summary.schedule[11]
        XCTAssertEqual(item12.annualRate, 0.042, accuracy: 0.0001)
        XCTAssertLessThan(item12.monthlyPayment, item1.monthlyPayment, "降息后月供必须显著低于初始月供")

        // 第 24 期 (已调至 3.85%)
        let item24 = summary.schedule[23]
        XCTAssertEqual(item24.annualRate, 0.0385, accuracy: 0.0001)
        XCTAssertLessThan(item24.monthlyPayment, item12.monthlyPayment)

        // 第 36 期 (已调至 3.10%)
        let item36 = summary.schedule[35]
        XCTAssertEqual(item36.annualRate, 0.0310, accuracy: 0.0001)
        XCTAssertLessThan(item36.monthlyPayment, item24.monthlyPayment)

        // 验证历次降息产生的累计利息节约
        XCTAssertGreaterThan(summary.cumulativeInterestSaved, 150000, "历经3次大降息累计节约利息必须超过 15 万元")
    }

    // MARK: - 2. 提前还款「月供减少」模式测试

    func testPrepaymentReduceMonthlyPayment() {
        // 100 万房贷，20 年 (240期)，4.0%
        let p0 = 1000000.0
        let r0 = 0.040
        let n0 = 240

        // 第 12 期提前偿还本金 20 万元 (保持期限不变)
        let prepayEvent = LoanAdjustmentEvent(
            periodIndex: 12,
            type: .prepayment,
            prepaymentAmount: 200000,
            prepaymentEffect: .reducePayment
        )

        let summary = RepaymentCalculator.calculateSchedule(
            principal: p0,
            annualRate: r0,
            totalPeriods: n0,
            method: .equalPayment,
            events: [prepayEvent]
        )

        // 期限保持 240 期
        XCTAssertEqual(summary.schedule.count, 240)

        // 第 1 期月供约为 6,059 元
        let initialPmt = summary.schedule[0].monthlyPayment
        // 第 13 期月供（扣减20万本金后在剩余228期重新摊销）约为 4,775 元
        let nextPmt = summary.schedule[12].monthlyPayment

        XCTAssertLessThan(nextPmt, initialPmt - 1000, "提前还本 20 万后月供应显著下降 1000 元以上")
        XCTAssertGreaterThan(summary.cumulativeInterestSaved, 80000, "提前还贷 20 万应节省超过 8 万元利息")
    }

    // MARK: - 3. 提前还款「期限缩短」模式测试

    func testPrepaymentShortenTerm() {
        // 100 万房贷，20 年 (240期)，4.0%
        let p0 = 1000000.0
        let r0 = 0.040
        let n0 = 240

        // 第 12 期提前偿还本金 20 万元 (选择缩短期限)
        let shortenEvent = LoanAdjustmentEvent(
            periodIndex: 12,
            type: .prepayment,
            prepaymentAmount: 200000,
            prepaymentEffect: .shortenTerm
        )

        let summary = RepaymentCalculator.calculateSchedule(
            principal: p0,
            annualRate: r0,
            totalPeriods: n0,
            method: .equalPayment,
            events: [shortenEvent]
        )

        // 验证总期数显著缩短（少于 240 期）
        XCTAssertLessThan(summary.schedule.count, 200, "提前还贷 20 万并缩短期限，总期数应缩短至 200 期以内")
        XCTAssertGreaterThan(summary.monthsAheadSaved, 40, "至少提前 40 个月（3年以上）结清")
        XCTAssertGreaterThan(summary.cumulativeInterestSaved, 100000, "缩短期限模式下节约利息应超过 10 万元")
    }

    // MARK: - 4. 混合场景：连续调息 + 提前还贷组合推演

    func testCombinedRateAdjustmentsAndPrepayments() {
        let loan = Loan(
            name: "组合测算房贷",
            category: .mortgage,
            totalAmount: 1200000,
            remainingPrincipal: 1000000,
            annualRate: 0.045,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 24,
            monthlyPayment: 7590,
            paymentDayOfMonth: 10
        )

        let ev1 = LoanAdjustmentEvent(periodIndex: 12, type: .rateAdjustment, newAnnualRate: 0.0385)
        let ev2 = LoanAdjustmentEvent(periodIndex: 20, type: .prepayment, prepaymentAmount: 100000, prepaymentEffect: .reducePayment)
        let ev3 = LoanAdjustmentEvent(periodIndex: 30, type: .rateAdjustment, newAnnualRate: 0.0310)

        loan.adjustmentEvents = [ev1, ev2, ev3]

        let summary = RepaymentCalculator.calculateSchedule(
            principal: loan.totalAmount,
            annualRate: loan.annualRate,
            totalPeriods: loan.totalPeriods,
            method: loan.repaymentMethod,
            events: loan.adjustmentEvents
        )

        XCTAssertEqual(loan.latestAnnualRate, 0.0310, "最新执行利率应为最后一次调息值 3.10%")
        XCTAssertEqual(loan.totalPrepaymentAmount, 100000)
        XCTAssertGreaterThan(summary.cumulativeInterestSaved, 100000)
    }

    // MARK: - 5. SwiftData 级联删除测试

    @MainActor
    func testSwiftDataCascadeDeletion() throws {
        let schema = Schema([CashAccount.self, Loan.self, CreditCard.self, UserSettings.self, FinancialGoal.self, LoanAdjustmentEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let loan = Loan(name: "测试房贷", category: .mortgage, totalAmount: 500000, remainingPrincipal: 400000, annualRate: 0.04, totalPeriods: 120)
        context.insert(loan)

        let event = LoanAdjustmentEvent(periodIndex: 10, type: .rateAdjustment, newAnnualRate: 0.035, loan: loan)
        loan.adjustmentEvents.append(event)
        context.insert(event)
        try context.save()

        let fetchedEventsBefore = try context.fetch(FetchDescriptor<LoanAdjustmentEvent>())
        XCTAssertEqual(fetchedEventsBefore.count, 1)

        // 删除贷款，验证关联的变更事件自动被级联删除
        context.delete(loan)
        try context.save()

        let fetchedEventsAfter = try context.fetch(FetchDescriptor<LoanAdjustmentEvent>())
        XCTAssertEqual(fetchedEventsAfter.count, 0)
    }

    // MARK: - 6. 小数点后 4 位高精度利率测试 (如 3.1250% / 0.03125)

    func testFourDecimalPlacesAnnualRateFormattingAndPrecision() {
        let rate1 = 0.03125 // 3.1250% (例如 LPR 3.85% - 72.5bp)
        let rate2 = 0.03875 // 3.8750%

        XCTAssertEqual(rate1.formattedRatePercentage, "3.125%")
        XCTAssertEqual(rate2.formattedRatePercentage, "3.875%")

        let summary = RepaymentCalculator.calculateSchedule(
            principal: 1000000,
            annualRate: rate1,
            totalPeriods: 360,
            method: .equalPayment
        )

        XCTAssertEqual(summary.schedule[0].annualRate, 0.03125, accuracy: 0.00001)
        XCTAssertGreaterThan(summary.initialMonthlyPayment, 4200)
    }
}
