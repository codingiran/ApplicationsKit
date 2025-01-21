@testable import ApplicationsKit
import XCTest

final class ApplicationsKitTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }

    func testFetchSystemApplications() throws {
        let apps = ApplicationsKit.systemApplications()
        print(apps)
    }

    func testFetchUserApplications() throws {
        let apps = ApplicationsKit.userApplications()
        print(apps)
    }

    func testUserApplications() {
        let userApps = ApplicationsKit.userApplications()
        debugPrint(userApps)
    }

    func testSystemApplicationDirectory() {
        let systemApplicationsDirectory = ApplicationsKit.systemApplicationsDirectory
        debugPrint(systemApplicationsDirectory)
    }

    func testUserApplicationDirectory() {
        let userApplicationsDirectory = ApplicationsKit.userApplicationsDirectory
        debugPrint(userApplicationsDirectory)
    }

    func testAppIcon() throws {
//        let appURLs = ApplicationsKit.applicationURLs(at: "/Applications")
//        let app = ApplicationsKit.applications(of: appURLs).first { $0.appName == "ChatGPT" }
//        if let appIcon = app?.appIcon() {
//            debugPrint("---")
//        }
    }
}
