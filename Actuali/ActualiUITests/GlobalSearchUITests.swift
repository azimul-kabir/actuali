import XCTest

final class GlobalSearchUITests: XCTestCase {
    @MainActor
    func testSearchFindsCategoriesAndCommandsNavigate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-loadDemoData", "-initialTab", "5"]
        app.launch()

        let search = app.searchFields["Accounts, categories, payees, transactions"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Groceries")
        XCTAssertTrue(app.staticTexts["Categories"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Groceries"].exists)

        search.buttons["Clear text"].tap()
        app.buttons["Open Reports"].tap()
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 10))
    }
}
