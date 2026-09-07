import XCTest
@testable import StayUp

final class SettingsStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "settings-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private var store: SettingsStore { SettingsStore(defaults: defaults) }

    func testARoundTrip() {
        var settings = Settings.defaults
        settings.batteryFloor = 90
        settings.watchedDirectories = ["~/somewhere"]
        settings.thermalPauseLevel = .serious
        settings.indefiniteCap = 0
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testNothingSavedReadsTheDefaults() {
        XCTAssertEqual(store.load(), .defaults)
    }

    /// A settings blob this app cannot read is a settings blob worth losing.
    /// Refusing to start would be the worse answer.
    func testGarbageReadsTheDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)
        XCTAssertEqual(store.load(), .defaults)
    }

    /// And so does a blob written by a version with fewer fields in it. The
    /// synthesized decoder wants every key, so adding a setting resets the
    /// ones already chosen; that is the price of one key holding the whole
    /// struct, and it is worth knowing rather than discovering.
    func testAnOlderShapeReadsTheDefaults() {
        defaults.set(Data(#"{"batteryFloor":42}"#.utf8), forKey: SettingsStore.key)
        XCTAssertEqual(store.load(), .defaults)
    }
}
