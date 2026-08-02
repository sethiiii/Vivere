//
//  HabitTrackerUITests.swift
//  HabitTrackerUITests
//
//  Created by Hercules S on 5/17/25.
//

import XCTest

final class HabitTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCoreNavigationFitsAndRemainsReachable() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Habits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Journal"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
    }

    @MainActor
    func testCreateHabitFromToday() throws {
        let app = launchApp()
        app.tabBars.buttons["Habits"].tap()
        app.navigationBars["Today"].buttons["Add habit"].tap()

        let name = "UI Test Habit \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Habit name"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(name)
        app.navigationBars["New Habit"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGalleryProgramCanBeCustomized() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-gallery"]
        app.launch()

        let tools = app.navigationBars["Today"].buttons["Habit tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 5))
        tools.tap()
        app.buttons["Gallery"].tap()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 3))

        let program = app.staticTexts["75-Day Hard Reset"]
        XCTAssertTrue(program.waitForExistence(timeout: 3))
        program.tap()
        XCTAssertTrue(app.navigationBars["Customize Program"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Gentle"].exists)
        XCTAssertTrue(app.staticTexts["Move outdoors"].exists)
        app.navigationBars["Customize Program"].buttons["Cancel"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }
}
