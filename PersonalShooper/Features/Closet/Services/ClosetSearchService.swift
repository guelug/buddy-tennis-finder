import Foundation
import SwiftData

extension String {
    func normalizedForSearch() -> String {
        self
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ClosetSearch {
    static func matches(for query: String, limit: Int = 12) -> [StyleCompanionClosetItemSnapshot] {
        let snapshots = SharedStyleCompanionStore.loadClosetIndex()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return Array(snapshots.prefix(limit))
        }

        return snapshots
            .filter { $0.matches(trimmed) }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    static func visualMatches(labels: [String], limit: Int = 8) -> [StyleCompanionClosetItemSnapshot] {
        SharedStyleCompanionStore.loadClosetIndex()
            .map { snapshot in
                (snapshot: snapshot, score: snapshot.visualMatchScore(labels: labels))
            }
            .filter { $0.score > 0.2 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.snapshot.createdAt > rhs.snapshot.createdAt
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map(\.snapshot)
    }

    static func routeToCloset(matching query: String?) {
        SharedStyleCompanionStore.savePendingClosetSearch(query)
        SharedStyleCompanionStore.savePendingLaunchDestination(.closet)
    }
}

final class ClosetSearchService {
    func searchItems(
        category: String? = nil,
        occasion: String? = nil,
        colorPreference: String? = nil,
        stylePreference: String? = nil,
        query: String? = nil,
        limit: Int = 10
    ) -> [ClothingItemSummary] {
        let snapshots = SharedStyleCompanionStore.loadClosetIndex()

        let filtered = snapshots.filter { item in
            if let category, !category.isEmpty {
                let normalizedCategory = category.normalizedForSearch()
                guard item.categoryRaw.normalizedForSearch().contains(normalizedCategory)
                        || item.categoryDisplayName.normalizedForSearch().contains(normalizedCategory) else {
                    return false
                }
            }

            if let occasion, !occasion.isEmpty {
                let normalizedOccasion = occasion.normalizedForSearch()
                guard item.occasionTags.contains(where: { $0.normalizedForSearch().contains(normalizedOccasion) }) else {
                    return false
                }
            }

            if let colorPreference, !colorPreference.isEmpty {
                let normalizedColor = colorPreference.normalizedForSearch()
                guard item.colorTags.contains(where: { $0.normalizedForSearch().contains(normalizedColor) }) else {
                    return false
                }
            }

            if let stylePreference, !stylePreference.isEmpty {
                let normalizedStyle = stylePreference.normalizedForSearch()
                guard item.styleTags.contains(where: { $0.normalizedForSearch().contains(normalizedStyle) }) else {
                    return false
                }
            }

            if let query, !query.isEmpty {
                guard item.matches(query) else { return false }
            }

            return true
        }
        .sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }
            return lhs.createdAt > rhs.createdAt
        }
        .prefix(limit)

        return filtered.map { item in
            ClothingItemSummary(
                id: UUID(uuidString: item.id) ?? UUID(),
                name: item.name,
                category: ClothingCategory(rawValue: item.categoryRaw) ?? .tops,
                colorTags: item.colorTags,
                styleTags: item.styleTags
            )
        }
    }

    func wardrobeStats() -> String {
        let snapshots = SharedStyleCompanionStore.loadClosetIndex()

        guard !snapshots.isEmpty else {
            return "The closet is empty."
        }

        let total = snapshots.count
        let favorites = snapshots.filter(\.isFavorite).count
        let mostWorn = snapshots.max { $0.timesWorn < $1.timesWorn }
        let neverWorn = snapshots.filter { $0.timesWorn == 0 }
        let categoryCounts = Dictionary(grouping: snapshots, by: \.categoryDisplayName)
            .map { "\($0.key): \($0.value.count)" }
            .sorted()

        var lines: [String] = []
        lines.append("Total garments: \(total)")
        lines.append("Favorites: \(favorites)")
        if let mostWorn, mostWorn.timesWorn > 0 {
            lines.append("Most worn: \(mostWorn.name) (\(mostWorn.timesWorn) times)")
        }
        if !neverWorn.isEmpty {
            lines.append("Never worn: \(neverWorn.count) item(s)")
        }
        lines.append("By category: \(categoryCounts.joined(separator: ", "))")

        return lines.joined(separator: "\n")
    }
}
