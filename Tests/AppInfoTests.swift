import XCTest
@testable import StayUp

final class AppInfoTests: XCTestCase {
    /// The bundle id is the log's subsystem, the sudoers rule's name and the
    /// launchd labels' prefix. If it drifts, three things stop matching.
    func testBundleID() {
        XCTAssertEqual(AppInfo.bundleID, "com.meric.stayup")
    }

    /// The test run is hosted by a build in DerivedData, which is exactly the
    /// case the launch-at-login toggle has to refuse: `SMAppService` reports
    /// success there and nothing ever launches.
    func testABuildDirectoryIsNotAnInstall() {
        XCTAssertFalse(AppInfo.isInApplications)
        XCTAssertNotEqual(Copy.launchAtLogin, Copy.launchAtLoginNeedsInstall)
        XCTAssertTrue(Copy.launchAtLoginNeedsInstall.contains("make install"))
    }
}
