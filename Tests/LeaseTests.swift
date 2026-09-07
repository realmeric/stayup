import XCTest
@testable import StayUp

final class LeaseTests: XCTestCase {
    private var base: URL!

    override func setUp() {
        super.setUp()
        base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lease-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: base)
        super.tearDown()
    }

    /// Written to the second, read back to the second. Fractional seconds
    /// would round-trip here and then fail in `guard.sh`, which parses this
    /// with a format string that cannot skip them.
    func testWriteAndReadBack() {
        let until = Date(timeIntervalSince1970: 1_788_000_000)
        Lease.renew(until: until, base: base)
        XCTAssertEqual(Lease.read(base: base), until)
    }

    /// The directory does not exist before the first session.
    func testCreatesItsDirectory() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.path))
        Lease.renew(until: Date(), base: base)
        XCTAssertTrue(FileManager.default.fileExists(atPath: Lease.url(base: base).path))
    }

    func testClearRemovesIt() {
        Lease.renew(until: Date(), base: base)
        Lease.clear(base: base)
        XCTAssertNil(Lease.read(base: base))
    }

    func testMissingReadsNil() {
        XCTAssertNil(Lease.read(base: base))
    }

    /// Clearing a lease that is not there is the state we wanted, not an
    /// error, and it must not log its way into looking like one.
    func testClearingNothingIsFine() {
        Lease.clear(base: base)
        XCTAssertNil(Lease.read(base: base))
    }

    /// The file is one line of ISO-8601 UTC, because a shell script has to
    /// read it with `date -j -f "%Y-%m-%dT%H:%M:%SZ"`.
    func testTheFileShape() throws {
        Lease.renew(until: Date(timeIntervalSince1970: 1_788_000_000), base: base)
        let text = try String(contentsOf: Lease.url(base: base), encoding: .utf8)
        XCTAssertEqual(text.trimmingCharacters(in: .whitespacesAndNewlines), "2026-08-29T10:40:00Z")
    }
}
