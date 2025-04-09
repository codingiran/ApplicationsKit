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

    func testAppIcon() async throws {
        guard let app = ApplicationsKit.systemApplications().first(where: { $0.appName == "ChatGPT" }) else {
            return
        }
        let icon = await ApplicationIcon.shared.icon(for: app, preferedSize: .init(width: 160, height: 160))
        debugPrint(icon?.size)
    }

    func testRiskyApp() async {
        let apps = ApplicationsKit.systemApplications()
        for app in apps {
            switch app.checkCodeSign() {
            case .success:
                continue
            case .failure(let reason):
                debugPrint("⚠️ Risky App: \(app.appName), Reason: \(reason.localizedDescription)")
            }
        }
    }

    func testProcessStatus() throws {
        let all = ProcessStatus.all()
        print(all)
    }
}
