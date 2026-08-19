import XCTest
@testable import MoneyFlow

final class OpportunityCostTests: XCTestCase {

    func testMortgagePrepaymentHigherRateRecommendsPrepay() {
        // 房贷 100 万，剩余 240 期 (20年)，年化利率 3.85%，等额本息
        // 闲钱 10 万，理财年化 2.50%，选择缩短年限
        let input = OpportunityCostInput(
            lumpSumAmount: 100_000,
            remainingPrincipal: 1_000_000,
            loanAnnualRate: 0.0385,
            remainingPeriods: 240,
            repaymentMethod: .equalPayment,
            prepaymentEffect: .shortenTerm,
            investmentAnnualRate: 0.025
        )

        let result = OpportunityCostEngine.calculate(input: input)

        XCTAssertEqual(result.effectiveAmount, 100_000)
        XCTAssertGreaterThan(result.loanInterestSaved, 0)
        XCTAssertGreaterThan(result.periodsSaved, 0)
        XCTAssertGreaterThan(result.investmentTotalReturn, 0)
        // 贷款利率 3.85% > 理财 2.50%，还贷必然更划算
        XCTAssertGreaterThan(result.netAdvantage, 0)
        XCTAssertTrue(result.recommendation == .stronglyPrepay || result.recommendation == .prepay)
        XCTAssertGreaterThan(result.breakEvenInvestmentRate, 0.025)
    }

    func testHighInvestmentRateRecommendsInvest() {
        // 房贷 50 万，剩余 120 期 (10年)，公积金利率 2.85%
        // 闲钱 10 万，假设有一款高息投资 4.50%
        let input = OpportunityCostInput(
            lumpSumAmount: 100_000,
            remainingPrincipal: 500_000,
            loanAnnualRate: 0.0285,
            remainingPeriods: 120,
            repaymentMethod: .equalPayment,
            prepaymentEffect: .reduceMonthlyPayment,
            investmentAnnualRate: 0.045
        )

        let result = OpportunityCostEngine.calculate(input: input)

        XCTAssertEqual(result.effectiveAmount, 100_000)
        XCTAssertLessThan(result.netAdvantage, 0) // 理财收益 > 节省利息
        XCTAssertTrue(result.recommendation == .stronglyInvest || result.recommendation == .invest)
    }

    func testFullPayoffScenario() {
        // 闲钱大于等于剩余本金，全额结清
        let input = OpportunityCostInput(
            lumpSumAmount: 150_000,
            remainingPrincipal: 100_000,
            loanAnnualRate: 0.040,
            remainingPeriods: 36,
            repaymentMethod: .equalPayment,
            prepaymentEffect: .shortenTerm,
            investmentAnnualRate: 0.020
        )

        let result = OpportunityCostEngine.calculate(input: input)

        XCTAssertEqual(result.effectiveAmount, 100_000)
        XCTAssertEqual(result.newRemainingPeriods, 0)
        XCTAssertEqual(result.periodsSaved, 36)
        XCTAssertEqual(result.newMonthlyPayment, 0)
        XCTAssertGreaterThan(result.loanInterestSaved, 0)
    }

    func testLiquidityEmergencyGuardWarning() {
        // 总可用资金 12 万，月必开支 1 万，拟还款 10 万 -> 结余仅剩 2 万（<3个月开支）
        let input = OpportunityCostInput(
            lumpSumAmount: 100_000,
            remainingPrincipal: 500_000,
            loanAnnualRate: 0.0385,
            remainingPeriods: 120,
            availableCash: 120_000,
            monthlyMustExpense: 10_000
        )

        let result = OpportunityCostEngine.calculate(input: input)
        XCTAssertNotNil(result.liquidityWarning)
        XCTAssertTrue(result.liquidityWarning?.contains("预警") == true)
    }
}
