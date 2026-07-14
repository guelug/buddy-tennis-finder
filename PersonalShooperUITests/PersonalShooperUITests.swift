import XCTest

@MainActor
final class PersonalShooperUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompletesOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-reset-onboarding"]
        app.launch()

        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Alex")
        app.buttons["onboarding.continue"].tap()

        let gender = app.buttons["onboarding.gender.unspecified"]
        XCTAssertTrue(gender.waitForExistence(timeout: 3))
        gender.tap()

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        finish.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testWeeklyPlannerShowsEmptyClosetState() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-skip-onboarding"]
        app.launch()

        let homePlanner = app.buttons["home.weeklyPlanner"]
        XCTAssertTrue(homePlanner.waitForExistence(timeout: 5))
        homePlanner.tap()

        let calendarPlanner = app.buttons["calendar.weeklyPlanner"]
        XCTAssertTrue(calendarPlanner.waitForExistence(timeout: 5))
        calendarPlanner.tap()

        XCTAssertTrue(app.staticTexts["weeklyPlanner.empty"].waitForExistence(timeout: 5))
    }
}
