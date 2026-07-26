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

    func testWardrobeMuteButtonTogglesWithoutOpeningDoors() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-skip-onboarding"]
        app.launch()

        let closetTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(closetTab.waitForExistence(timeout: 5))
        closetTab.tap()

        let toggle = app.buttons["closet.lobby.soundToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let originalLabel = toggle.label
        toggle.tap()

        XCTAssertNotEqual(toggle.label, originalLabel)
        let wardrobe = app.descendants(matching: .any)["closet.lobby.armoire"]
        XCTAssertTrue(wardrobe.waitForExistence(timeout: 2.5))
        XCTAssertEqual(wardrobe.value as? String, "closed")
    }

    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-skip-onboarding", "-ui-screenshot-content"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["main.tabs"].waitForExistence(timeout: 5))
        capture("01-home", app: app)

        selectTab(in: app, index: 2, identifier: "hanger")
        XCTAssertTrue(app.buttons["closet.lobby.armoire"].waitForExistence(timeout: 5))
        capture("02-wardrobe", app: app)

        app.buttons["closet.lobby.armoire"].tap()
        let closetTitle = app.navigationBars.staticTexts["Mi Armario"]
        XCTAssertTrue(closetTitle.waitForExistence(timeout: 5))
        capture("03-smart-closet", app: app)

        selectTab(in: app, index: 3, identifier: "camera.fill")
        capture("04-virtual-try-on", app: app)

        selectTab(in: app, index: 4, identifier: "person.fill")
        capture("05-profile", app: app)
    }

    private func selectTab(in app: XCUIApplication, index: Int, identifier: String) {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            tabBar.buttons.element(boundBy: index).tap()
        } else {
            let button = app.buttons.matching(identifier: identifier).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
        }
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
