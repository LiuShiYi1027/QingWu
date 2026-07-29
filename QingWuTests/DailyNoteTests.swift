import XCTest

@testable import QingWu

/// Daily note naming must stay Logseq-compatible: `journals/yyyy_MM_dd.md`.
final class DailyNoteTests: XCTestCase {

    func testDailyNoteNameMatchesLogseqFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 29
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(ViewController.dailyNoteName(for: date), "2026_07_29")
    }

    func testDailyNoteNameZeroPadsMonthAndDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        let date = Calendar.current.date(from: components)!

        XCTAssertEqual(ViewController.dailyNoteName(for: date), "2026_01_05")
    }
}
