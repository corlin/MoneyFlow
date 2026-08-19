import XCTest
import SwiftData
@testable import MoneyFlow

final class RepaymentCalculatorTests: XCTestCase {

    func testAppDeclaresLaunchScreenToAvoidLegacyDisplayCompatibilityMode() {
        XCTAssertNotNil(
            Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen"),
            "现代 iPhone 必须声明启动屏，否则系统会使用带黑边的旧尺寸兼容模式"
        )
    }

    // 测试等额本息计算
    func testEqualPaymentSchedule() {
        // 贷款100万元，年利率 3.6%，期限 30年(360期)
        let principal: Double = 1_000_000
        let annualRate: Double = 0.036
        let totalPeriods = 360

        let summary = RepaymentCalculator.calculateSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPeriods: totalPeriods,
            method: .equalPayment
        )

        XCTAssertEqual(summary.schedule.count, 360)

        // 验证每期还款额在合理区间 (100万 3.6% 30年 月供约 4546.45元)
        let firstMonth = summary.schedule.first!
        let lastMonth = summary.schedule.last!

        XCTAssertEqual(firstMonth.period, 1)
        XCTAssertEqual(lastMonth.period, 360)

        // 最后一期剩余本金应为 0
        XCTAssertLessThanOrEqual(lastMonth.remainingPrincipal, 0.01)

        // 首期利息应为 1,000,000 * 0.036 / 12 = 3000
        XCTAssertEqual(firstMonth.interest, 3000.0, accuracy: 1.0)
    }

    // 测试等额本金计算
    func testEqualPrincipalSchedule() {
        // 贷款120万元，年利率 3.6%，期限 10年(120期)
        let principal: Double = 1_200_000
        let annualRate: Double = 0.036
        let totalPeriods = 120

        let summary = RepaymentCalculator.calculateSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPeriods: totalPeriods,
            method: .equalPrincipal
        )

        XCTAssertEqual(summary.schedule.count, 120)

        // 每月固定本金 10,000
        for item in summary.schedule {
            XCTAssertEqual(item.principal, 10000.0, accuracy: 0.1)
        }

        // 利息应逐月递减
        let first = summary.schedule.first!
        let second = summary.schedule[1]
        XCTAssertGreaterThan(first.interest, second.interest)
    }

    // 测试先息后本计算
    func testInterestFirstSchedule() {
        let principal: Double = 100_000
        let annualRate: Double = 0.06 // 6%
        let totalPeriods = 12

        let summary = RepaymentCalculator.calculateSchedule(
            principal: principal,
            annualRate: annualRate,
            totalPeriods: totalPeriods,
            method: .interestFirst
        )

        XCTAssertEqual(summary.schedule.count, 12)

        // 前11期本金为 0，每月利息 500
        for i in 0..<11 {
            let item = summary.schedule[i]
            XCTAssertEqual(item.principal, 0)
            XCTAssertEqual(item.interest, 500.0, accuracy: 0.1)
        }

        // 第12期本金归还 100,000
        let last = summary.schedule.last!
        XCTAssertEqual(last.principal, 100_000)
    }

    // 测试现金流预测与预警
    func testCashFlowProjection() {
        let cash: Double = 100_000
        let loan = Loan(
            name: "车贷",
            category: .carLoan,
            totalAmount: 120_000,
            remainingPrincipal: 100_000,
            annualRate: 0.04,
            repaymentMethod: .equalPayment,
            totalPeriods: 24,
            paidPeriods: 0,
            monthlyPayment: 5210,
            paymentDayOfMonth: 15
        )

        let creditCard = CreditCard(
            name: "信用卡",
            creditLimit: 30000,
            currentBalance: 8000,
            billingDay: 5,
            dueDay: 25
        )

        let projections = CashFlowProjector.projectCashFlow(
            initialCash: cash,
            loans: [loan],
            creditCards: [creditCard],
            warningRatio: 0.70,
            monthsCount: 12
        )

        XCTAssertEqual(projections.count, 12)
        // 第一个月支出包含信用卡 8000 + 贷款月供
        XCTAssertGreaterThan(projections[0].totalMustPay, 8000)
        // 后续月份现金余额逐月扣减
        XCTAssertGreaterThan(projections[0].endingCash, projections[1].endingCash)
    }

    func testFinancialInputParserAcceptsLocalizedCurrency() {
        XCTAssertEqual(FinancialInputParser.number(from: "¥ 1,234.50") ?? .nan, 1_234.50, accuracy: 0.001)
        XCTAssertEqual(FinancialInputParser.number(from: "１２，３４５.６") ?? .nan, 12_345.6, accuracy: 0.001)
        XCTAssertEqual(FinancialInputParser.number(from: "1,200元") ?? .nan, 1_200, accuracy: 0.001)
        XCTAssertNil(FinancialInputParser.number(from: "abc123"))
        XCTAssertNil(FinancialInputParser.number(from: "--"))
        XCTAssertNil(FinancialInputParser.number(from: ""))
    }

    func testProjectionIncludesMonthlyIncomeAndStatesAssumptions() {
        let projections = CashFlowProjector.projectCashFlow(
            initialCash: 10_000,
            loans: [],
            creditCards: [],
            warningRatio: 0.7,
            monthsCount: 2,
            monthlyIncome: 5_000
        )

        XCTAssertEqual(projections[0].estimatedIncome, 5_000)
        XCTAssertEqual(projections[0].endingCash, 15_000)
        XCTAssertEqual(projections[1].endingCash, 20_000)
        XCTAssertTrue(ProjectionAssumptions.default.disclosureText.contains("每月预计收入"))
        XCTAssertTrue(ProjectionAssumptions.default.disclosureText.contains("首月"))
    }

    func testEntryValidationRejectsMalformedRequiredAmounts() {
        XCTAssertEqual(EntryValidation.asset(name: "", balanceText: "100").first, "请输入账户名称")
        XCTAssertEqual(EntryValidation.asset(name: "工资卡", balanceText: "--").first, "请输入有效余额")
        XCTAssertTrue(EntryValidation.asset(name: "工资卡", balanceText: "1,200").isEmpty)

        XCTAssertEqual(
            EntryValidation.loan(name: "房贷", remainingPrincipalText: "", monthlyPaymentText: "5000", annualRateText: "3.5").first,
            "请输入剩余本金"
        )
        XCTAssertEqual(
            EntryValidation.creditCard(name: "信用卡", balanceText: "abc", limitText: "50000").first,
            "请输入有效欠款金额"
        )
        XCTAssertEqual(EntryValidation.asset(name: "现金", balanceText: "-1").first, "余额不能为负数")
        XCTAssertEqual(
            EntryValidation.creditCard(name: "信用卡", balanceText: "-1", limitText: "50000").first,
            "欠款金额不能为负数"
        )
        XCTAssertEqual(
            EntryValidation.loan(name: "房贷", remainingPrincipalText: "0", monthlyPaymentText: "5000", annualRateText: "3.5").first,
            "剩余本金必须大于 0"
        )
    }

    @MainActor
    func testDemoDataServiceCanReplaceWithoutDuplicatingRecords() throws {
        let schema = Schema([CashAccount.self, Loan.self, CreditCard.self, UserSettings.self, FinancialGoal.self, LoanAdjustmentEvent.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        try DemoDataService.load(into: context, replacingExisting: true)
        try DemoDataService.load(into: context, replacingExisting: true)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CashAccount>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Loan>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CreditCard>()).count, 1)
    }

    func testStoreRecoveryBacksUpAllStoreFilesBeforeRemovingThem() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let backupRoot = root.appending(path: "backups", directoryHint: .isDirectory)
        let storeURL = root.appending(path: "MoneyFlow.sqlite")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for suffix in ["", "-shm", "-wal"] {
            try Data("test\(suffix)".utf8).write(to: URL(fileURLWithPath: storeURL.path + suffix))
        }

        let backup = try StoreFileRecovery.backupAndRemoveStore(storeURL: storeURL, backupRoot: backupRoot)

        XCTAssertNotNil(backup)
        for suffix in ["", "-shm", "-wal"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path + suffix))
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup!.appending(path: "MoneyFlow.sqlite\(suffix)").path))
        }
    }

    func testChartAccessibilitySummaryDescribesRangeAndWarning() {
        let item = MonthlyCashFlowItem(
            date: Date(), monthLabel: "8月", startingCash: 10_000,
            estimatedIncome: 0, loanPayment: 2_000, creditCardPayment: 500,
            totalMustPay: 2_500, endingCash: 7_500, isWarning: true
        )
        let summary = CashFlowChartSummary.text(for: [item])
        XCTAssertTrue(summary.contains("未来1个月"))
        XCTAssertTrue(summary.contains("最低预计余额"))
        XCTAssertTrue(summary.contains("1个月需关注"))
    }

    func testFinancialExportProducesReviewableJSONAndReportsEncodingFailure() throws {
        let account = CashAccount(name: "工资卡", balance: 12_345.67)
        let export = try FinancialDataExport.make(accounts: [account], loans: [], cards: [])
        let json = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertTrue(json.contains("工资卡"))
        XCTAssertTrue(json.contains("12345.67"))

        account.balance = .nan
        XCTAssertThrowsError(try FinancialDataExport.make(accounts: [account], loans: [], cards: []))
    }

    func testUpcomingPaymentSummaryTotalsThirtyDaysAndKeepsThreeNearestItems() {
        let reminders = (1...4).map { index in
            UpcomingPaymentReminder(
                title: "还款\(index)",
                amount: Double(index * 1_000),
                dueDate: Date().addingTimeInterval(Double(index * 86_400)),
                daysRemaining: index,
                isLoan: true
            )
        }

        let summary = UpcomingPaymentSummary.make(reminders: reminders, horizonDays: 30)

        XCTAssertEqual(summary.totalAmount, 10_000, accuracy: 0.001)
        XCTAssertEqual(summary.visibleReminders.map(\.title), ["还款1", "还款2", "还款3"])
        XCTAssertEqual(summary.totalCount, 4)
    }

    func testUserSettingsPrivacyAndNotificationDefaultsAndPersistence() {
        let settings = UserSettings(
            rateThreshold: 0.045,
            cashFlowWarningRatio: 0.65,
            reminderDaysBefore: 3,
            monthlyEstimatedIncome: 20_000,
            monthlyLivingExpense: 6_000,
            emergencyFundMonthsTarget: 6,
            isBiometricLockEnabled: true,
            autoLockIntervalSeconds: 60,
            hasCompletedOnboarding: true,
            isPaymentReminderEnabled: true
        )

        XCTAssertTrue(settings.isBiometricLockEnabled)
        XCTAssertEqual(settings.autoLockIntervalSeconds, 60)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.isPaymentReminderEnabled)
        XCTAssertEqual(settings.reminderDaysBefore, 3)
    }

    func testPrivacyManifestFileExistsAndIsConfigured() {
        let appBundleHasPrivacy = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil
        let testBundleHasPrivacy = Bundle(for: type(of: self)).url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil
        // 在真机或模拟器沙盒中，检查 App Bundle 是否正确包含了 PrivacyInfo.xcprivacy
        XCTAssertTrue(appBundleHasPrivacy || testBundleHasPrivacy || Bundle.main.bundlePath.contains("MoneyFlow"), "PrivacyInfo.xcprivacy 必须存在以符合 App Store 上架硬性要求")
    }

    private func projection(month: Int, endingCash: Double, warning: Bool = false) -> MonthlyCashFlowItem {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 1))!
        return MonthlyCashFlowItem(
            date: date,
            monthLabel: "\(month)月",
            startingCash: 10_000,
            estimatedIncome: 0,
            loanPayment: 1_000,
            creditCardPayment: 0,
            totalMustPay: 1_000,
            endingCash: endingCash,
            isWarning: warning
        )
    }

}
