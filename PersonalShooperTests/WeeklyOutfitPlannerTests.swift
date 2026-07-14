import XCTest
@testable import PersonalShooper

final class WeeklyOutfitPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testUpcomingWorkdaysSkipsWeekend() throws {
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 17))
        )

        let days = WeeklyOutfitPlannerService.upcomingWorkdays(
            from: friday,
            calendar: calendar
        )

        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.map { calendar.component(.weekday, from: $0) }, [6, 2, 3, 4, 5])
    }

    func testGeneratorCreatesFiveCompleteOfficeLooks() throws {
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )
        let garments = makeGarments(category: .tops, count: 5)
            + makeGarments(category: .bottoms, count: 5, offset: 10)
            + makeGarments(category: .shoes, count: 3, offset: 20)

        let drafts = WeeklyOutfitPlannerService.generate(
            garments: garments,
            from: start,
            seed: 42,
            calendar: calendar
        )

        XCTAssertEqual(drafts.count, 5)
        XCTAssertTrue(drafts.allSatisfy { draft in
            WeeklyOutfitPlannerService.isCompleteOfficeLook(
                itemIDs: draft.itemIDs,
                garments: garments
            )
        })
    }

    func testGeneratorRotatesCoreGarmentsWhenClosetHasEnough() throws {
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )
        let tops = makeGarments(category: .tops, count: 5)
        let bottoms = makeGarments(category: .bottoms, count: 5, offset: 10)
        let garments = tops + bottoms

        let drafts = WeeklyOutfitPlannerService.generate(
            garments: garments,
            from: start,
            seed: 7,
            calendar: calendar
        )

        let topIDs = Set(drafts.flatMap(\.itemIDs).filter { id in tops.contains { $0.id == id } })
        let bottomIDs = Set(drafts.flatMap(\.itemIDs).filter { id in bottoms.contains { $0.id == id } })
        XCTAssertEqual(topIDs.count, 5)
        XCTAssertEqual(bottomIDs.count, 5)
    }

    func testOfficeTaggedGarmentWinsFirstSuggestion() throws {
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )
        let officeTop = WeeklyPlannerGarment(
            id: id(1),
            category: .tops,
            searchableTerms: ["camisa formal de oficina"],
            timesWorn: 8
        )
        let sportTop = WeeklyPlannerGarment(
            id: id(2),
            category: .tops,
            searchableTerms: ["camiseta deportiva"],
            timesWorn: 0
        )
        let bottom = WeeklyPlannerGarment(id: id(3), category: .bottoms)

        let firstDraft = try XCTUnwrap(
            WeeklyOutfitPlannerService.generate(
                garments: [officeTop, sportTop, bottom],
                from: start,
                seed: 99,
                calendar: calendar
            ).first
        )

        XCTAssertTrue(firstDraft.itemIDs.contains(officeTop.id))
        XCTAssertFalse(firstDraft.itemIDs.contains(sportTop.id))
    }

    func testEmptyClosetStillReturnsFiveEditableDays() throws {
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13))
        )

        let drafts = WeeklyOutfitPlannerService.generate(
            garments: [],
            from: start,
            seed: 1,
            calendar: calendar
        )

        XCTAssertEqual(drafts.count, 5)
        XCTAssertTrue(drafts.allSatisfy(\.itemIDs.isEmpty))
    }

    private func makeGarments(
        category: ClothingCategory,
        count: Int,
        offset: Int = 0
    ) -> [WeeklyPlannerGarment] {
        (0..<count).map { index in
            WeeklyPlannerGarment(
                id: id(offset + index + 1),
                category: category,
                searchableTerms: ["office"],
                colorTags: index.isMultiple(of: 2) ? ["navy"] : ["white"],
                timesWorn: index
            )
        }
    }

    private func id(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
