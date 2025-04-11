@testable import ApplicationsKit
import XCTest

final class ApplicationsKitTests: XCTestCase {
    // MARK: - Test Setup

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // MARK: - ApplicationsKit Tests

    func testApplicationsKitVersion() {
        // Given
        let expectedVersion = "0.0.2"

        // When
        let actualVersion = ApplicationsKit.version

        // Then
        XCTAssertEqual(actualVersion, expectedVersion, "ApplicationsKit version should match expected version")
    }

    // MARK: - Application Directory Tests

    func testSystemApplicationsDirectory() {
        // Given
        let expectedPath = "/Applications"

        // When
        let directory = ApplicationsKit.systemApplicationsDirectory

        // Then
        XCTAssertTrue(directory.filePath.contains(expectedPath), "System applications directory should contain '/Applications'")
    }

    func testUserApplicationsDirectory() {
        // Given
        let homeDirectory = NSHomeDirectory()

        // When
        let directory = ApplicationsKit.userApplicationsDirectory

        // Then
        XCTAssertTrue(directory.filePath.contains(homeDirectory), "User applications directory should be in user's home directory")
        XCTAssertTrue(directory.filePath.contains("Applications"), "User applications directory should contain 'Applications'")
    }

    // MARK: - Application Fetching Tests

    func testSystemApplications() {
        // When
        let applications = ApplicationsKit.systemApplications()

        // Then
        XCTAssertFalse(applications.isEmpty, "System applications list should not be empty")

        // Verify some common system apps exist
        let commonApps = ["Xcode", "Visual Studio Code", "Sketch"]
        let appNames = applications.map { $0.appName }
        let hasCommonApps = commonApps.contains { appName in
            appNames.contains { $0.contains(appName) }
        }
        XCTAssertTrue(hasCommonApps, "System applications should include common apps")
    }

    func testUserApplications() {
        // When
        let applications = ApplicationsKit.userApplications()

        // Then
        // Note: We can't guarantee user has apps installed, so we just verify the method works
        XCTAssertNotNil(applications, "User applications list should be accessible")
    }

    func testApplicationMetadata() {
        // Given
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first(where: { $0.appName.contains("Xcode") }) else {
            XCTFail("No system applications found")
            return
        }

        // Then
        XCTAssertFalse(firstApp.bundleIdentifier.isEmpty, "Application should have a bundle identifier")
        XCTAssertFalse(firstApp.appName.isEmpty, "Application should have a name")
        XCTAssertFalse(firstApp.appVersion.isEmpty, "Application should have a version")
        XCTAssertNotNil(firstApp.path, "Application should have a path")
    }

    // MARK: - Process Status Tests

    func testProcessStatus() {
        // When
        let processes = ProcessStatus.all()

        // Then
        XCTAssertFalse(processes.isEmpty, "Process list should not be empty")

        // Verify process properties
        if let firstProcess = processes.first {
            XCTAssertGreaterThan(firstProcess.pid, 0, "Process ID should be positive")
            XCTAssertGreaterThanOrEqual(firstProcess.uid, 0, "User ID should be non-negative")
            XCTAssertFalse(firstProcess.user.isEmpty, "Process should have a user name")
            XCTAssertFalse(firstProcess.command.isEmpty, "Process should have a command")
        }
    }

    // MARK: - Application Icon Tests

    @available(macOS 10.15, *)
    func testApplicationIcon() async {
        // Given
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first else {
            XCTFail("No system applications found")
            return
        }

        // When
        let icon = await ApplicationIcon.shared.icon(for: firstApp)

        // Then
        XCTAssertNotNil(icon, "Application icon should not be nil")
        XCTAssertGreaterThan(icon?.size.width ?? 0, 0, "Icon should have a width")
        XCTAssertGreaterThan(icon?.size.height ?? 0, 0, "Icon should have a height")
    }

    @available(macOS 10.15, *)
    func testApplicationIconWithSize() async {
        // Given
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first else {
            XCTFail("No system applications found")
            return
        }
        let preferredSize = NSSize(width: 64, height: 64)

        // When
        let icon = await ApplicationIcon.shared.icon(for: firstApp, preferedSize: preferredSize)

        // Then
        XCTAssertNotNil(icon, "Application icon should not be nil")
        XCTAssertEqual(icon?.size.width, preferredSize.width, "Icon width should match preferred size")
        XCTAssertEqual(icon?.size.height, preferredSize.height, "Icon height should match preferred size")
    }

    // MARK: - Application Architecture Tests

    func testApplicationArchitecture() {
        // Given
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first else {
            XCTFail("No system applications found")
            return
        }

        // Then
        XCTAssertNotNil(firstApp.arch, "Application should have an architecture type")
        XCTAssertFalse(firstApp.arch.type.isEmpty, "Application architecture type should not be empty")
    }

    // MARK: - Application Properties Tests

    func testApplicationProperties() {
        // Given
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first else {
            XCTFail("No system applications found")
            return
        }

        // Then
        XCTAssertFalse(firstApp.id.isEmpty, "Application should have an ID")
        XCTAssertNotNil(firstApp.creationDate, "Application should have a creation date")
        XCTAssertNotNil(firstApp.contentChangeDate, "Application should have a content change date")
        XCTAssertGreaterThanOrEqual(firstApp.bundleSize, 0, "Application bundle size should be non-negative")
    }

    // MARK: - Performance Tests

    func testPerformanceOfSystemApplications() {
        measure {
            _ = ApplicationsKit.systemApplications()
        }
    }

    func testPerformanceOfProcessStatus() {
        measure {
            _ = ProcessStatus.all()
        }
    }

    @available(macOS 10.15, *)
    func testPerformanceOfApplicationIcon() async {
        let systemApps = ApplicationsKit.systemApplications()
        guard let firstApp = systemApps.first else {
            XCTFail("No system applications found")
            return
        }

        measure {
            Task {
                _ = await ApplicationIcon.shared.icon(for: firstApp)
            }
        }
    }
}
