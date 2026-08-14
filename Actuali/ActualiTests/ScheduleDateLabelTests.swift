import Testing
@testable import Actuali

struct ScheduleDateLabelTests {
    private let today = DayDate(year: 2026, month: 8, day: 14)

    @Test func labelsNearbyDatesRelatively() {
        #expect(ScheduleDateLabel.text(for: today, today: today) == "Today")
        #expect(ScheduleDateLabel.text(for: today.adding(days: 1), today: today) == "Tomorrow")
        #expect(ScheduleDateLabel.text(for: today.adding(days: 4), today: today) == "In 4 days")
    }

    @Test func labelsOverdueDates() {
        #expect(ScheduleDateLabel.text(for: today.adding(days: -1), today: today) == "1 day overdue")
        #expect(ScheduleDateLabel.text(for: today.adding(days: -3), today: today) == "3 days overdue")
    }
}
