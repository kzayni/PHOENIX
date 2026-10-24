//
//  PHOENIXUITestsLaunchTests.swift
//  PHOENIXUITests
//
//  Created by Mohamad Karim ZAYNI on 2026-10-20.
//

import XCTest

/// Captures a fresh launch state for each supported UI-test configuration.
final class PHOENIXUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Keep this test navigation-free so the attachment represents the
        // application's actual initial presentation.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
