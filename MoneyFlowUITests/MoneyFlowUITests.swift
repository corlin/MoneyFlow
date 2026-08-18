import XCTest

final class MoneyFlowUITests: XCTestCase {
    @MainActor
    func testEmptyStateCanLoadDemoAndReachPopulatedOverview() throws {
        let app = XCUIApplication()
        app.launch()

        let chartTitle = app.staticTexts["12个月现金余量"]
        if !chartTitle.exists {
            XCTAssertTrue(app.buttons["添加第一笔数据"].waitForExistence(timeout: 3))

            let demoButton = app.buttons["载入示例体验"]
            if !demoButton.isHittable { app.swipeUp() }
            XCTAssertTrue(demoButton.waitForExistence(timeout: 2))
            demoButton.tap()
        }

        XCTAssertTrue(chartTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["偿债缓冲"].exists)
        XCTAssertTrue(app.staticTexts["12个月现金余量"].exists)
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["debt-progress-card"].waitForExistence(timeout: 2))
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["upcoming-payments-card"].waitForExistence(timeout: 2))
    }
}
