import Foundation

struct WeeklyPlannerGarment: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: ClothingCategory
    let searchableTerms: [String]
    let colorTags: [String]
    let isFavorite: Bool
    let timesWorn: Int
    let lastWornAt: Date?

    init(
        id: UUID,
        category: ClothingCategory,
        searchableTerms: [String] = [],
        colorTags: [String] = [],
        isFavorite: Bool = false,
        timesWorn: Int = 0,
        lastWornAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.searchableTerms = searchableTerms
        self.colorTags = colorTags
        self.isFavorite = isFavorite
        self.timesWorn = timesWorn
        self.lastWornAt = lastWornAt
    }

    init(item: ClothingItem) {
        self.init(
            id: item.id,
            category: item.category,
            searchableTerms: [item.name]
                + item.styleTags
                + item.occasionTags
                + item.detailTags
                + [item.metadataSummary, item.notes].compactMap { $0 },
            colorTags: item.colorTags,
            isFavorite: item.isFavorite,
            timesWorn: item.timesWorn,
            lastWornAt: item.lastWornAt
        )
    }
}

struct WeeklyOutfitDraft: Identifiable, Equatable, Sendable {
    let date: Date
    var itemIDs: [UUID]

    var id: Date { date }
}

enum WeeklyOutfitPlannerService {
    static let planLength = 5

    private static let coreCategories: Set<ClothingCategory> = [.tops, .bottoms, .dresses]
    private static let officeCategories: [ClothingCategory] = [
        .tops, .bottoms, .dresses, .outerwear, .shoes, .accessories, .jewelry
    ]
    private static let officeSignals = [
        "office", "oficina", "work", "trabajo", "business", "formal",
        "professional", "profesional", "meeting", "reunion", "smart casual",
        "business casual", "corporate", "corporativo"
    ]

    static func upcomingWorkdays(
        from startDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        var result: [Date] = []
        var candidate = calendar.startOfDay(for: startDate)

        while result.count < planLength {
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday != 1 && weekday != 7 {
                result.append(candidate)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                break
            }
            candidate = next
        }

        return result
    }

    static func generate(
        garments: [WeeklyPlannerGarment],
        from startDate: Date = Date(),
        paletteColorNames: Set<String> = [],
        seed: UInt64 = UInt64.random(in: 1...UInt64.max),
        calendar: Calendar = .current
    ) -> [WeeklyOutfitDraft] {
        let workdays = upcomingWorkdays(from: startDate, calendar: calendar)
        guard !garments.isEmpty else {
            return workdays.map { WeeklyOutfitDraft(date: $0, itemIDs: []) }
        }

        let normalizedPalette = Set(paletteColorNames.map(normalized))
        var generator = SeededGenerator(seed: seed)
        var weeklyUseCount: [UUID: Int] = [:]

        return workdays.enumerated().map { index, date in
            let selected = makeLook(
                dayIndex: index,
                garments: garments,
                paletteColorNames: normalizedPalette,
                weeklyUseCount: weeklyUseCount,
                generator: &generator
            )
            for garment in selected {
                weeklyUseCount[garment.id, default: 0] += 1
            }
            return WeeklyOutfitDraft(date: date, itemIDs: selected.map(\.id))
        }
    }

    static func isCompleteOfficeLook(itemIDs: [UUID], garments: [WeeklyPlannerGarment]) -> Bool {
        let selectedCategories = Set(
            garments.lazy
                .filter { itemIDs.contains($0.id) }
                .map(\.category)
        )
        return selectedCategories.contains(.dresses)
            || (selectedCategories.contains(.tops) && selectedCategories.contains(.bottoms))
    }

    private static func makeLook(
        dayIndex: Int,
        garments: [WeeklyPlannerGarment],
        paletteColorNames: Set<String>,
        weeklyUseCount: [UUID: Int],
        generator: inout SeededGenerator
    ) -> [WeeklyPlannerGarment] {
        let candidatesByCategory = Dictionary(grouping: garments, by: \.category)
        let hasDress = !(candidatesByCategory[.dresses] ?? []).isEmpty
        let hasSeparates = !(candidatesByCategory[.tops] ?? []).isEmpty
            && !(candidatesByCategory[.bottoms] ?? []).isEmpty
        let useDress = hasDress && (!hasSeparates || (dayIndex + Int(generator.next() % 3)).isMultiple(of: 3))

        var selected: [WeeklyPlannerGarment] = []

        if useDress {
            appendPick(
                category: .dresses,
                candidatesByCategory: candidatesByCategory,
                selected: &selected,
                weeklyUseCount: weeklyUseCount,
                paletteColorNames: paletteColorNames,
                generator: &generator
            )
        } else {
            appendPick(
                category: .tops,
                candidatesByCategory: candidatesByCategory,
                selected: &selected,
                weeklyUseCount: weeklyUseCount,
                paletteColorNames: paletteColorNames,
                generator: &generator
            )
            appendPick(
                category: .bottoms,
                candidatesByCategory: candidatesByCategory,
                selected: &selected,
                weeklyUseCount: weeklyUseCount,
                paletteColorNames: paletteColorNames,
                generator: &generator
            )
        }

        appendPick(
            category: .outerwear,
            candidatesByCategory: candidatesByCategory,
            selected: &selected,
            weeklyUseCount: weeklyUseCount,
            paletteColorNames: paletteColorNames,
            generator: &generator
        )
        appendPick(
            category: .shoes,
            candidatesByCategory: candidatesByCategory,
            selected: &selected,
            weeklyUseCount: weeklyUseCount,
            paletteColorNames: paletteColorNames,
            generator: &generator
        )

        let finishingCategory: ClothingCategory = dayIndex.isMultiple(of: 2) ? .accessories : .jewelry
        appendPick(
            category: finishingCategory,
            candidatesByCategory: candidatesByCategory,
            selected: &selected,
            weeklyUseCount: weeklyUseCount,
            paletteColorNames: paletteColorNames,
            generator: &generator
        )

        if selected.isEmpty {
            for category in officeCategories where selected.count < 4 {
                appendPick(
                    category: category,
                    candidatesByCategory: candidatesByCategory,
                    selected: &selected,
                    weeklyUseCount: weeklyUseCount,
                    paletteColorNames: paletteColorNames,
                    generator: &generator
                )
            }
        }

        return selected
    }

    private static func appendPick(
        category: ClothingCategory,
        candidatesByCategory: [ClothingCategory: [WeeklyPlannerGarment]],
        selected: inout [WeeklyPlannerGarment],
        weeklyUseCount: [UUID: Int],
        paletteColorNames: Set<String>,
        generator: inout SeededGenerator
    ) {
        guard let candidates = candidatesByCategory[category], !candidates.isEmpty else { return }

        let selectedColors = Set(selected.flatMap(\.colorTags).map(normalized))
        let scored = candidates.map { garment in
            let jitter = Double(generator.next() % 10_000) / 10_000
            return (
                garment,
                score(
                    garment,
                    selectedColors: selectedColors,
                    paletteColorNames: paletteColorNames,
                    weeklyUseCount: weeklyUseCount
                ) + (jitter * 14)
            )
        }

        if let pick = scored.max(by: { $0.1 < $1.1 })?.0,
           !selected.contains(where: { $0.id == pick.id }) {
            selected.append(pick)
        }
    }

    private static func score(
        _ garment: WeeklyPlannerGarment,
        selectedColors: Set<String>,
        paletteColorNames: Set<String>,
        weeklyUseCount: [UUID: Int]
    ) -> Double {
        let normalizedTerms = garment.searchableTerms.map(normalized)
        let normalizedColors = Set(garment.colorTags.map(normalized))
        let officeMatch = normalizedTerms.contains { term in
            officeSignals.contains { term.contains($0) }
        }
        let paletteMatch = !normalizedColors.isDisjoint(with: paletteColorNames)
        let coordinatesWithLook = !selectedColors.isEmpty
            && !normalizedColors.isDisjoint(with: selectedColors)
        let daysSinceLastWear = garment.lastWornAt.map {
            min(30, max(0, Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0))
        } ?? 30

        var value = 0.0
        value += officeMatch ? 42 : 0
        value += paletteMatch ? 18 : 0
        value += coordinatesWithLook ? 8 : 0
        value += garment.isFavorite ? 4 : 0
        value += Double(max(0, 12 - min(garment.timesWorn, 12)))
        value += Double(daysSinceLastWear) / 6
        value -= Double(weeklyUseCount[garment.id, default: 0]) * 65

        if !coreCategories.contains(garment.category) && garment.category != .shoes {
            value -= 2
        }
        return value
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
