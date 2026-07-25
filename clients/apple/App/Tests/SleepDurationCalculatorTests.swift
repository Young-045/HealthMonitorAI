import Foundation
import XCTest
@testable import HealthMonitorAI

final class SleepDurationCalculatorTests: XCTestCase {
    func testOverlappingSleepStagesAreNotDoubleCounted() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let intervals = [
            DateInterval(start: start, duration: 3_600),
            DateInterval(start: start.addingTimeInterval(1_800), duration: 3_600),
            DateInterval(start: start.addingTimeInterval(7_200), duration: 1_800)
        ]

        XCTAssertEqual(SleepDurationCalculator.mergedDuration(intervals), 7_200)
    }

    func testEmptySleepIntervalsReturnZero() {
        XCTAssertEqual(SleepDurationCalculator.mergedDuration([]), 0)
    }

    func testSleepDayEndsAtNoonAfterNoon() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 20, hour: 18
        )))

        let window = SleepDayWindowCalculator.window(containing: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: window.start), 12)
        XCTAssertEqual(calendar.component(.day, from: window.start), 19)
        XCTAssertEqual(calendar.component(.hour, from: window.end), 12)
        XCTAssertEqual(calendar.component(.day, from: window.end), 20)
    }

    func testMorningSleepDayEndsAtCurrentTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 20, hour: 8, minute: 30
        )))

        let window = SleepDayWindowCalculator.window(containing: now, calendar: calendar)

        XCTAssertEqual(window.end, now)
        XCTAssertEqual(calendar.component(.hour, from: window.start), 12)
        XCTAssertEqual(calendar.component(.day, from: window.start), 19)
    }
}
