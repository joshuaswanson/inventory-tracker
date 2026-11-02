import Foundation
import Testing
@testable import InventoryTracker

@Suite struct DayAndFormatTests {
    @Test func dayDifferenceCrossesDaylightSavingAndLeapDay() {
        #expect(Day.days(from: "2026-03-07", to: "2026-03-09") == 2)
        #expect(Day.days(from: "2024-02-28", to: "2024-03-01") == 2)
        #expect(Day.days(from: "2026-06-01", to: "2026-05-22") == -10)
    }

    @Test func dayRoundTripsThroughThePickerInEveryTimeZone() throws {
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Pacific/Kiritimati", "UTC"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: zone))
            let date = try #require(Day.localDate(from: "2026-11-02", calendar: calendar))
            #expect(Day.string(from: date, calendar: calendar) == "2026-11-02")
        }
    }

    @Test func invalidDaysAreRejected() {
        #expect(Day.isValid("2026-02-28"))
        #expect(!Day.isValid("2026-02-31"))
        #expect(!Day.isValid("soon"))
    }

    @Test func datesFormatWithShortMonths() {
        #expect(Format.longDate("2026-04-20") == "Apr 20, 2026")
        #expect(Format.shortDate("2026-04-20") == "Apr 20")
        #expect(Format.longDate(nil) == "-")
    }

    @Test func currencyFormatsAsUSDollars() {
        #expect(Format.currency(7010.62) == "$7,010.62")
        #expect(Format.currency(nil) == "-")
    }

    @Test func phoneNumbersFormatForNorthAmerica() {
        #expect(Format.phone("8004724346") == "(800) 472-4346")
        #expect(Format.phone("18004724346") == "+1 (800) 472-4346")
        #expect(Format.phone("411") == "411")
        #expect(Format.digits("(800) 472-4346") == "8004724346")
    }
}
