import XCTest
@testable import StayUp

/// Busy is a file growing. There is no status field in a Claude Code
/// transcript, so the newest modification date under the watched directories
/// is the whole signal.
final class AgentActivityTests: XCTestCase {
    private var room: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        room = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("agents-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: room, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: room)
        super.tearDown()
    }

    @discardableResult
    private func write(_ name: String, at written: Date) throws -> URL {
        let url = room.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("{}\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: written],
                                              ofItemAtPath: url.path)
        return url
    }

    private var activity: AgentActivity {
        AgentActivity(directories: [room.path])
    }

    func testTheNewestTranscriptWins() throws {
        let older = Date(timeIntervalSince1970: 1_788_000_000)
        let newer = Date(timeIntervalSince1970: 1_788_000_600)
        try write("old.jsonl", at: older)
        try write("new.jsonl", at: newer)
        XCTAssertEqual(activity.read()?.timeIntervalSince1970, newer.timeIntervalSince1970)
    }

    /// Only `.jsonl`. A directory full of logs and settings would otherwise
    /// read as an agent that never stops working.
    func testOnlyTranscriptsCount() throws {
        try write("note.txt", at: Date(timeIntervalSince1970: 1_788_009_000))
        try write("old.jsonl", at: Date(timeIntervalSince1970: 1_788_000_000))
        XCTAssertEqual(activity.read()?.timeIntervalSince1970, 1_788_000_000)
    }

    /// Subagents write beside the session, a directory down.
    func testItLooksAllTheWayDown() throws {
        try write("project/session.jsonl", at: Date(timeIntervalSince1970: 1_788_000_000))
        try write("project/subagents/helper.jsonl", at: Date(timeIntervalSince1970: 1_788_000_600))
        XCTAssertEqual(activity.read()?.timeIntervalSince1970, 1_788_000_600)
    }

    func testAnEmptyDirectoryReadsNil() {
        XCTAssertNil(activity.read())
    }

    /// A tool that is not installed is not a problem.
    func testAMissingDirectoryReadsNil() {
        let gone = room.appendingPathComponent("not-here")
        XCTAssertNil(AgentActivity(directories: [gone.path]).read())
    }

    /// Paths are written with a tilde in Settings, because that is how a
    /// person writes them in the Settings window.
    func testItExpandsATilde() {
        let activity = AgentActivity(directories: ["~/this-directory-does-not-exist-stayup"])
        XCTAssertNil(activity.read())
    }

    /// Both defaults are watched, and neither is spelled out anywhere else.
    func testTheDefaultsAreTheTwoAgentDirectories() {
        XCTAssertEqual(Settings.defaults.watchedDirectories,
                       ["~/.claude/projects", "~/.codex/sessions"])
    }
}
