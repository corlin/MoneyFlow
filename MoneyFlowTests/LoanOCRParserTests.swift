import XCTest
import SwiftData
@testable import MoneyFlow

final class LoanOCRParserTests: XCTestCase {

    // MARK: - 1. 真实截图文本流逆向解析测试

    func testUserScreenshotParsingExtractsAllFourLoansAccurately() {
        let lines = LoanOCRScannerService.sampleScreenshotTextLines
        let drafts = LoanOCRScannerService.parseLoanDrafts(fromTextLines: lines)

        XCTAssertEqual(drafts.count, 4, "必须准确识别出截图中的全部 4 笔消费借款")

        // 第 1 笔：2025.09.02 借款 20,000 元 (第 12/12 期)
        let d1 = drafts[0]
        XCTAssertTrue(d1.name.contains("2025.09.02"))
        XCTAssertEqual(d1.totalAmount, 20000.0, accuracy: 0.01)
        XCTAssertEqual(d1.totalPeriods, 12)
        XCTAssertEqual(d1.paidPeriods, 11) // 第 12 期说明已还 11 期
        XCTAssertEqual(d1.remainingPrincipal, 1666.74, accuracy: 0.5)
        XCTAssertEqual(d1.monthlyPayment, 1675.35, accuracy: 0.01)
        XCTAssertEqual(d1.annualRate, 0.0620, accuracy: 0.0005, "由利息 8.61 / 本金 1666.74 * 12 逆推年化必须为 6.2000%")

        // 第 2 笔：2025.09.08 借款 10,000 元 (第 12/12 期)
        let d2 = drafts[1]
        XCTAssertTrue(d2.name.contains("2025.09.08"))
        XCTAssertEqual(d2.totalAmount, 10000.0, accuracy: 0.01)
        XCTAssertEqual(d2.totalPeriods, 12)
        XCTAssertEqual(d2.paidPeriods, 11)
        XCTAssertEqual(d2.remainingPrincipal, 833.37, accuracy: 0.5)
        XCTAssertEqual(d2.monthlyPayment, 837.68, accuracy: 0.01)
        XCTAssertEqual(d2.annualRate, 0.0620, accuracy: 0.0005)

        // 第 3 笔：2025.09.22 借款 12,000 元 (第 11/12 期)
        let d3 = drafts[2]
        XCTAssertTrue(d3.name.contains("2025.09.22"))
        XCTAssertEqual(d3.totalAmount, 12000.0, accuracy: 0.01)
        XCTAssertEqual(d3.totalPeriods, 12)
        XCTAssertEqual(d3.paidPeriods, 10) // 第 11 期说明已还 10 期
        XCTAssertEqual(d3.remainingPrincipal, 2000.0, accuracy: 1.0)
        XCTAssertEqual(d3.monthlyPayment, 1010.33, accuracy: 0.01)
        XCTAssertEqual(d3.annualRate, 0.0620, accuracy: 0.0005)

        // 第 4 笔：2025.09.26 借款 95,000 元 (第 11/12 期)
        let d4 = drafts[3]
        XCTAssertTrue(d4.name.contains("2025.09.26"))
        XCTAssertEqual(d4.totalAmount, 95000.0, accuracy: 0.01)
        XCTAssertEqual(d4.totalPeriods, 12)
        XCTAssertEqual(d4.paidPeriods, 10)
        XCTAssertEqual(d4.remainingPrincipal, 15833.32, accuracy: 5.0)
        XCTAssertEqual(d4.monthlyPayment, 7998.47, accuracy: 0.01)
        XCTAssertEqual(d4.annualRate, 0.0620, accuracy: 0.0005)
    }

    // MARK: - 2. 批量导入必须生成多条独立的负债记录 (持久化验证)

    @MainActor
    func testBatchImportGeneratesMultipleDistinctLoansInSwiftData() throws {
        let schema = Schema([CashAccount.self, Loan.self, CreditCard.self, UserSettings.self, FinancialGoal.self, LoanAdjustmentEvent.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let lines = LoanOCRScannerService.sampleScreenshotTextLines
        let drafts = LoanOCRScannerService.parseLoanDrafts(fromTextLines: lines)

        let platform = "微粒贷"
        for draft in drafts {
            let entity = draft.createLoanEntity(platformPrefix: platform)
            context.insert(entity)
        }
        try context.save()

        // 验证数据库中存入的确实是 4 条各自独立的负债记录
        let fetchedLoans = try context.fetch(FetchDescriptor<Loan>())
        XCTAssertEqual(fetchedLoans.count, 4, "数据库中必须存储 4 条独立的 Loan 实体，而不是被合并为单条")

        // 验证每笔名称均包含统一前缀与具体日期
        for loan in fetchedLoans {
            XCTAssertTrue(loan.name.hasPrefix("微粒贷-2025.09"))
            XCTAssertEqual(loan.category, .consumerLoan)
            XCTAssertEqual(loan.annualRate, 0.0620, accuracy: 0.0005)
            XCTAssertGreaterThan(loan.monthlyPayment, 0)
        }
    }
}
