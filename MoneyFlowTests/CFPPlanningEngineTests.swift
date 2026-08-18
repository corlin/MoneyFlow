import XCTest
import SwiftData
@testable import MoneyFlow

final class CFPPlanningEngineTests: XCTestCase {

    // MARK: - 1. MultiGoalEngine 单元测试

    func testFreeCashCalculationAndOverAllocationDetection() {
        let goal1 = FinancialGoal(name: "应急金", category: .emergencyBuffer, targetAmount: 30000, currentEarmarkedAmount: 20000)
        let goal2 = FinancialGoal(name: "心愿单", category: .capitalMilestone, targetAmount: 50000, currentEarmarkedAmount: 15000)

        // 场景 1：现金充裕 (总现金 50,000，分账 35,000，自由现金 15,000)
        let (freeCash1, totalEarmarked1, isOver1) = MultiGoalEngine.calculateFreeCash(totalCash: 50000, goals: [goal1, goal2])
        XCTAssertEqual(freeCash1, 15000)
        XCTAssertEqual(totalEarmarked1, 35000)
        XCTAssertFalse(isOver1)

        // 场景 2：超额分账 (总现金 20,000，分账 35,000，自由现金 0，触发警告)
        let (freeCash2, totalEarmarked2, isOver2) = MultiGoalEngine.calculateFreeCash(totalCash: 20000, goals: [goal1, goal2])
        XCTAssertEqual(freeCash2, 0)
        XCTAssertEqual(totalEarmarked2, 35000)
        XCTAssertTrue(isOver2)
    }

    func testMultiGoalPriorityDynamicIrrigationAndETA() {
        let calendar = Calendar.current
        let baseDate = Date()
        let monthDates = (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: baseDate) }
        // 每月净结余 5,000 元
        let monthlySurpluses = Array(repeating: 5000.0, count: 12)

        // 目标 1: 必需应急金 (目标 10,000，已分账 0) -> 需 2 个月 (第 2 个月达成)
        let essentialGoal = FinancialGoal(
            name: "必需应急金",
            category: .emergencyBuffer,
            targetAmount: 10000,
            currentEarmarkedAmount: 0,
            priority: .essential
        )

        // 目标 2: 重要置业基金 (目标 20,000，已分账 5,000，缺口 15,000) -> 紧随目标1完成后，需 3 个月 (第 2+3=5 个月达成)
        let importantGoal = FinancialGoal(
            name: "置业基金",
            category: .capitalMilestone,
            targetAmount: 20000,
            currentEarmarkedAmount: 5000,
            priority: .important,
            targetDate: calendar.date(byAdding: .month, value: 3, to: baseDate) // 期望第 4 个月完成 (偏移3个月)，实际第 5 个月完成
        )

        // 目标 3: 心愿旅行 (目标 30,000，已分账 0) -> 溢出结余最后灌溉
        let aspirationalGoal = FinancialGoal(
            name: "心愿旅行",
            category: .capitalMilestone,
            targetAmount: 30000,
            currentEarmarkedAmount: 0,
            priority: .aspirational
        )

        let summary = MultiGoalEngine.projectGoals(
            totalCash: 20000,
            monthlySurpluses: monthlySurpluses,
            monthDates: monthDates,
            goals: [aspirationalGoal, importantGoal, essentialGoal] // 故意乱序输入
        )

        XCTAssertEqual(summary.goalProjections.count, 3)

        // 验证排序为：essential -> important -> aspirational
        let p1 = summary.goalProjections[0]
        let p2 = summary.goalProjections[1]
        let p3 = summary.goalProjections[2]

        XCTAssertEqual(p1.goal.priority, .essential)
        XCTAssertEqual(p1.completionMonthIndex, 2)
        XCTAssertEqual(p1.projectedTotal, 10000)

        XCTAssertEqual(p2.goal.priority, .important)
        XCTAssertEqual(p2.completionMonthIndex, 5)
        XCTAssertEqual(p2.projectedTotal, 20000)
        // 期望在第4个月完成，实际第5个月完成 -> 延期 1 个月
        XCTAssertFalse(p2.isOnTrack)
        XCTAssertEqual(p2.delayedMonths, 1)

        XCTAssertEqual(p3.goal.priority, .aspirational)
        // 剩余月数(第6~12月=7个月*5000=35000) -> 在第11个月完成(5000*6=30000)
        XCTAssertEqual(p3.completionMonthIndex, 11)
        XCTAssertEqual(p3.projectedTotal, 30000)
    }

    // MARK: - 2. CashFlowProjector 双轨沙盘与策略测试

    func testCashFlowDualTrackScenarioSimulation() {
        let loan = Loan(
            name: "车贷",
            category: .carLoan,
            totalAmount: 120000,
            remainingPrincipal: 100000,
            annualRate: 0.0, // 0利率免息等额还款，每月正好 5,000
            repaymentMethod: .equalPayment,
            totalPeriods: 24,
            paidPeriods: 0,
            monthlyPayment: 5000,
            paymentDayOfMonth: 10
        )

        let scenario = PlanningScenario(
            incomeAdjustmentPct: -0.20, // 收入减少 20%
            lumpSumExpense: 10000,      // 首月突发支出 10,000
            lumpSumExpenseMonth: 0,
            repaymentStrategy: .standard
        )

        let result = CashFlowProjector.projectAdvancedCashFlow(
            initialCash: 50000,
            loans: [loan],
            creditCards: [],
            goals: [],
            monthlyIncome: 10000,
            monthlyLivingExpense: 3000,
            warningRatio: 0.70,
            monthsCount: 12,
            assumptions: .default,
            scenario: scenario
        )

        XCTAssertEqual(result.baselineItems.count, 12)
        XCTAssertEqual(result.scenarioItems.count, 12)

        // 基准轨：月收入 10,000，生活 3,000，还贷 5,000 -> 月支出 8,000，月结余 2,000，期末现金 52,000
        let baseFirst = result.baselineItems[0]
        XCTAssertEqual(baseFirst.estimatedIncome, 10000)
        XCTAssertEqual(baseFirst.totalMustPay, 8000)
        XCTAssertEqual(baseFirst.monthlySurplus, 2000)
        XCTAssertEqual(baseFirst.endingCash, 52000)

        // 情景轨：月收入 8,000 (-20%)，首月支出 8,000 + 10,000 = 18,000 -> 首月赤字 -10,000，期末现金 50000+8000-18000 = 40000
        let scenFirst = result.scenarioItems[0]
        XCTAssertEqual(scenFirst.estimatedIncome, 8000)
        XCTAssertEqual(scenFirst.totalMustPay, 18000)
        XCTAssertEqual(scenFirst.endingCash, 40000)

        // 验证双轨数据已合并至 baselineItems.scenarioEndingCash
        XCTAssertEqual(baseFirst.scenarioEndingCash, 40000)
    }

    func testAvalancheStrategyCalculatesInterestAndMonthsSaved() {
        let highRateLoan = Loan(
            name: "高息装修贷",
            category: .consumerLoan,
            totalAmount: 100000,
            remainingPrincipal: 80000,
            annualRate: 0.08, // 8% 高息
            repaymentMethod: .equalPayment,
            totalPeriods: 36,
            paidPeriods: 6,
            monthlyPayment: 3000,
            paymentDayOfMonth: 15
        )

        let scenario = PlanningScenario(
            repaymentStrategy: .avalanche,
            debtSurplusAllocationRatio: 1.0
        )

        let result = CashFlowProjector.projectAdvancedCashFlow(
            initialCash: 30000,
            loans: [highRateLoan],
            creditCards: [],
            goals: [],
            monthlyIncome: 15000,
            monthlyLivingExpense: 5000,
            warningRatio: 0.70,
            monthsCount: 12,
            scenario: scenario
        )

        XCTAssertGreaterThan(result.strategyInterestSaved, 0, "雪崩法加速清偿高息贷款必须产生利息节约")
        XCTAssertGreaterThan(result.strategyMonthsSaved, 0, "雪崩法加速清偿必须提前结清月数")
    }

    // MARK: - 3. RiskAnalyzer CFA/CFP 三维健康指标与智能建议测试

    func testRiskAnalyzerDSRStatusAndInsights() {
        let loan = Loan(
            name: "车贷",
            category: .carLoan,
            totalAmount: 100000,
            remainingPrincipal: 80000,
            annualRate: 0.07,
            repaymentMethod: .equalPayment,
            totalPeriods: 36,
            paidPeriods: 10,
            monthlyPayment: 5000,
            paymentDayOfMonth: 10
        )

        // 场景 1：高危 DSR (月还款 5,000 / 月收入 10,000 = 50% > 45%)
        let dangerAnalysis = RiskAnalyzer.analyze(
            cashAccounts: [CashAccount(name: "储蓄卡", balance: 5000)],
            loans: [loan],
            creditCards: [],
            goals: [],
            rateThreshold: 0.05,
            monthlyIncome: 10000,
            monthlyLivingExpense: 4000,
            emergencyTargetMonths: 3
        )

        XCTAssertEqual(dangerAnalysis.dsrRatio, 0.50, accuracy: 0.01)
        XCTAssertEqual(dangerAnalysis.dsrStatus, .danger)
        XCTAssertTrue(dangerAnalysis.insights.contains { $0.id == "dsr_danger" })
        XCTAssertTrue(dangerAnalysis.insights.contains { $0.id == "emergency_gap" })
        XCTAssertTrue(dangerAnalysis.insights.contains { $0.id == "high_rate_debt" })

        // 场景 2：稳健 DSR (月还款 5,000 / 月收入 25,000 = 20% <= 35%)
        let healthyAnalysis = RiskAnalyzer.analyze(
            cashAccounts: [CashAccount(name: "储蓄卡", balance: 100000)],
            loans: [loan],
            creditCards: [],
            goals: [],
            rateThreshold: 0.08, // 提高阈值
            monthlyIncome: 25000,
            monthlyLivingExpense: 5000,
            emergencyTargetMonths: 3
        )

        XCTAssertEqual(healthyAnalysis.dsrRatio, 0.20, accuracy: 0.01)
        XCTAssertEqual(healthyAnalysis.dsrStatus, .healthy)
        XCTAssertTrue(healthyAnalysis.isEmergencyFundAdequate)
        XCTAssertTrue(healthyAnalysis.insights.contains { $0.id == "healthy_milestone" })
    }

    // MARK: - 4. DemoDataService 双画像加载测试

    @MainActor
    func testDemoDataServiceLoadsBothPersonas() throws {
        let schema = Schema([CashAccount.self, Loan.self, CreditCard.self, UserSettings.self, FinancialGoal.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        // 测试加载画像 1：负债突围型
        try DemoDataService.load(into: context, replacingExisting: true, persona: .debtRelief)
        let accounts1 = try context.fetch(FetchDescriptor<CashAccount>())
        let loans1 = try context.fetch(FetchDescriptor<Loan>())
        let goals1 = try context.fetch(FetchDescriptor<FinancialGoal>())
        let settings1 = try context.fetch(FetchDescriptor<UserSettings>()).first!

        XCTAssertEqual(accounts1.count, 2)
        XCTAssertEqual(loans1.count, 2)
        XCTAssertEqual(goals1.count, 2)
        XCTAssertEqual(settings1.monthlyEstimatedIncome, 18000)
        XCTAssertEqual(settings1.monthlyLivingExpense, 5000)

        // 测试切换加载画像 2：多目标积累型
        try DemoDataService.load(into: context, replacingExisting: true, persona: .multiGoalGrowth)
        let accounts2 = try context.fetch(FetchDescriptor<CashAccount>())
        let loans2 = try context.fetch(FetchDescriptor<Loan>())
        let goals2 = try context.fetch(FetchDescriptor<FinancialGoal>())
        let settings2 = try context.fetch(FetchDescriptor<UserSettings>()).first!

        XCTAssertEqual(accounts2.count, 3)
        XCTAssertEqual(loans2.count, 1)
        XCTAssertEqual(goals2.count, 3)
        XCTAssertEqual(settings2.monthlyEstimatedIncome, 26000)
        XCTAssertEqual(settings2.monthlyLivingExpense, 6500)
        XCTAssertEqual(settings2.emergencyFundMonthsTarget, 6)
    }
}
