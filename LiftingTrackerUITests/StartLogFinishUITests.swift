import XCTest

/// Start a workout, check off a set, finish.
final class StartLogFinishUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testStartLogFinish() {
        let app = XCUIApplication()
        // In-memory store seeded with one workout, "Push Day".
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["nav-live"].tap()

        let workout = app.buttons["start-workout-Push Day"]
        XCTAssertTrue(workout.waitForExistence(timeout: 5))
        workout.tap()
        app.buttons["start-session"].tap()

        // Three pre-filled sets; check the first.
        let firstDone = app.buttons["done-0-1"]
        XCTAssertTrue(firstDone.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["done-0-3"].exists)
        firstDone.tap()

        app.buttons["finish-workout"].tap()

        // Back to the start list, with the session recorded against the workout.
        XCTAssertTrue(app.buttons["start-session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["finish-workout"].exists)

        // Starting again brings back only the one set that was checked.
        app.buttons["start-workout-Push Day"].tap()
        app.buttons["start-session"].tap()
        XCTAssertTrue(app.buttons["done-0-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["done-0-2"].exists)
    }
}
