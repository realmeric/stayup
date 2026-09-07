import XCTest
@testable import StayUp

/// Every notice the keeper can send, and the words it turns into. A banner
/// that says what happened and not what to do about it is a banner that gets
/// switched off.
final class NoticeCopyTests: XCTestCase {
    private func notice(_ notice: Notice, _ settings: Settings = .defaults)
        -> (title: String, body: String) {
        Copy.notice(notice, settings: settings)
    }

    func testTooHotSaysWhatTheLidMeans() {
        let said = notice(.paused(.thermal))
        XCTAssertEqual(said.title, "Paused: too hot")
        XCTAssertEqual(said.body,
                       "The Mac will sleep if the lid is closed. Open it when it has cooled and StayUp resumes.")
    }

    func testBatteryLow() {
        XCTAssertEqual(notice(.paused(.battery)).title, "Paused: battery low")
        XCTAssertEqual(notice(.paused(.battery)).body, "Plug in to resume.")
    }

    func testNotCharging() {
        XCTAssertEqual(notice(.paused(.charging)).title, "Paused: not charging")
        XCTAssertEqual(notice(.paused(.charging)).body,
                       "Only while charging is on. Plug in to resume.")
    }

    /// Nothing to add: the flag is up again and the title says it.
    func testResumed() {
        XCTAssertEqual(notice(.resumed).title, "Awake again")
        XCTAssertEqual(notice(.resumed).body, "")
    }

    func testTheTimerEnding() {
        XCTAssertEqual(notice(.ended(.timer)).title, "Time is up")
        XCTAssertEqual(notice(.ended(.timer)).body, "The Mac can sleep now.")
    }

    /// The number comes from the setting, so changing the idle timeout
    /// changes what the banner says it waited for.
    func testTheAgentsFinishing() {
        XCTAssertEqual(notice(.ended(.agentsIdle)).title, "The agents finished")
        XCTAssertEqual(notice(.ended(.agentsIdle)).body,
                       "No transcript has been written for 3 minutes. The Mac can sleep now.")
        var settings = Settings.defaults
        settings.idleTimeout = 600
        XCTAssertEqual(notice(.ended(.agentsIdle), settings).body,
                       "No transcript has been written for 10 minutes. The Mac can sleep now.")
    }

    /// Follow's cap is 8 hours and Indefinite's is 24, and the banner says
    /// which one it was rather than guessing.
    func testTheCap() {
        XCTAssertEqual(notice(.ended(.cap(86400))).title, "Session cap reached")
        XCTAssertEqual(notice(.ended(.cap(86400))).body,
                       "StayUp has been on for 24 hours and stopped itself.")
        XCTAssertEqual(notice(.ended(.cap(28800))).body,
                       "StayUp has been on for 8 hours and stopped itself.")
    }

    /// You did these, so nothing is delivered.
    func testStopAndQuitSayNothing() {
        XCTAssertEqual(notice(.ended(.stopped)).title, "")
        XCTAssertEqual(notice(.ended(.quit)).title, "")
    }

    func testTheWarning() {
        XCTAssertEqual(notice(.warning(300)).title, "5 minutes left")
        XCTAssertEqual(notice(.warning(300)).body,
                       "Start another session from the menu to keep going.")
        XCTAssertEqual(notice(.warning(60)).title, "1 minute left")
    }

    func testGettingHot() {
        XCTAssertEqual(notice(.thermalWarning).title, "Getting hot")
        XCTAssertEqual(notice(.thermalWarning).body,
                       "Still awake. StayUp pauses at critical; change that in Settings.")
    }

    /// A notice with no title is a notice that is never delivered, and the
    /// only two of those are the ones you caused yourself.
    func testEveryOtherNoticeHasATitleAndABody() {
        let delivered: [Notice] = [.paused(.thermal), .paused(.battery), .paused(.charging),
                                   .resumed, .ended(.timer), .ended(.agentsIdle),
                                   .ended(.cap(86400)), .warning(300), .thermalWarning]
        for one in delivered {
            XCTAssertFalse(notice(one).title.isEmpty, String(describing: one))
        }
        for one in delivered where one != .resumed {
            XCTAssertFalse(notice(one).body.isEmpty, String(describing: one))
        }
    }

    /// The three that mean the Mac is about to sleep on you, or already
    /// stopped, get through a Focus. Nothing else does.
    func testOnlyTheUrgentOnesInterrupt() {
        XCTAssertTrue(UserNotifier.isUrgent(.paused(.thermal)))
        XCTAssertTrue(UserNotifier.isUrgent(.paused(.battery)))
        XCTAssertTrue(UserNotifier.isUrgent(.ended(.cap(86400))))
        XCTAssertFalse(UserNotifier.isUrgent(.paused(.charging)))
        XCTAssertFalse(UserNotifier.isUrgent(.resumed))
        XCTAssertFalse(UserNotifier.isUrgent(.ended(.timer)))
        XCTAssertFalse(UserNotifier.isUrgent(.warning(300)))
        XCTAssertFalse(UserNotifier.isUrgent(.thermalWarning))
    }
}
