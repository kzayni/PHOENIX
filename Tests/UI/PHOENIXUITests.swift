//
//  PHOENIXUITests.swift
//  PHOENIXUITests
//
//  Created by Mohamad Karim ZAYNI on 2026-10-20.
//

import XCTest

final class PHOENIXUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        ensureLaunchWindow(in: app)

        let skipButton = app.buttons["skipLaunchButton"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.click()
        }
        let newProjectButton = app.buttons["newProjectButton"]
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 2))
        newProjectButton.click()

        let geometryPicker = app.descendants(matching: .any)["geometryTypePicker"]
        let designationField = app.descendants(matching: .any)["nacaDesignationField"]

        XCTAssertTrue(geometryPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(designationField.exists)
        XCTAssertEqual(designationField.value as? String, "0012")
        XCTAssertTrue(app.descendants(matching: .any)["nacaChordField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["nacaPointCountField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["nacaPointDistributionPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["nacaSharpTrailingEdgeToggle"].exists)
        let normalsToggle = app.descendants(matching: .any)["showSurfaceNormalsToggle"]
        XCTAssertTrue(normalsToggle.exists)
        XCTAssertTrue(app.descendants(matching: .any)["fitToViewButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["generateGeometryButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometryViewport"].exists)
        attachScreenshot(of: app, named: "NACA 0012")

        normalsToggle.click()
        attachScreenshot(of: app, named: "NACA Surface Normals")

        designationField.click()
        designationField.typeKey("a", modifierFlags: .command)
        designationField.typeText("2412")
        XCTAssertEqual(designationField.value as? String, "2412")
        XCTAssertFalse(app.descendants(matching: .any)["geometryErrorMessage"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometryViewport"].exists)
        attachScreenshot(of: app, named: "NACA 2412")

        geometryPicker.click()
        app.menuItems["NACA Five-Digit"].click()

        let fiveDigitField = app.descendants(matching: .any)["naca5DesignationField"]
        XCTAssertTrue(fiveDigitField.waitForExistence(timeout: 2))
        XCTAssertEqual(fiveDigitField.value as? String, "23012")
        XCTAssertTrue(app.descendants(matching: .any)["naca5ChordField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["naca5PointCountField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["naca5PointDistributionPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["naca5SharpTrailingEdgeToggle"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["geometryErrorMessage"].exists)
        attachScreenshot(of: app, named: "NACA 23012")

        geometryPicker.click()
        app.menuItems["Circular Cylinder"].click()

        XCTAssertTrue(app.descendants(matching: .any)["cylinderRadiusField"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["cylinderCenterXField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cylinderCenterYField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cylinderPointCountField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cylinderStartingAngleField"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["geometryViewport"].exists)
        attachScreenshot(of: app, named: "Circular Cylinder")
    }

    @MainActor
    func testLaunchSequenceReachesInteractiveLandingScreen() throws {
        let app = XCUIApplication()
        app.launch()
        ensureLaunchWindow(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["singularityView"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["phoenixTitle"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "PHOENIX Title Reveal")
        XCTAssertTrue(app.buttons["newProjectButton"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["newProjectButton"].isEnabled)
        XCTAssertTrue(app.buttons["openProjectButton"].exists)
        XCTAssertFalse(app.buttons["openProjectButton"].isEnabled)
        attachScreenshot(of: app, named: "PHOENIX Landing")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let target = app.windows.firstMatch.exists ? app.windows.firstMatch : app
        let attachment = XCTAttachment(screenshot: target.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func ensureLaunchWindow(in app: XCUIApplication) {
        let singularity = app.descendants(matching: .any)["singularityView"]
        if !singularity.waitForExistence(timeout: 2) {
            app.typeKey("n", modifierFlags: .command)
        }
    }
}
