import XCTest
@testable import StayUp

final class AppInfoTests: XCTestCase {
    /// The bundle id is the log's subsystem, the sudoers rule's name and the
    /// launchd labels' prefix. If it drifts, three things stop matching.
    func testBundleID() {
        XCTAssertEqual(AppInfo.bundleID, "com.meric.stayup")
    }
}
