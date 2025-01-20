@testable import ApplicationsKit
import XCTest

final class ApplicationsKitTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }

    func testFetchApplications() throws {
        let appURLs = ApplicationsKit.applicationURLs(at: "/Applications")
        let apps = ApplicationsKit.applications(of: appURLs)
        print(apps)
    }

    func testAppIcon() throws {
        let appURLs = ApplicationsKit.applicationURLs(at: "/Applications")
        let app = ApplicationsKit.applications(of: appURLs).first { $0.appName == "ChatGPT" }
        if let appIcon = app?.appIcon() {
            debugPrint("---")
        }
    }
    
    func testUserApplications() {
        let userApps = ApplicationsKit.userApplications()
        debugPrint(userApps)
    }

    func testApplicationDirectory() {
        let applicationDirectory = URL.applicationDirectory
        debugPrint(applicationDirectory)
    }
}
