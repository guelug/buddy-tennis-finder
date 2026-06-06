import SwiftUI
import SwiftData
import UIKit

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var selectedCategory: ClothingCategory?
    @State private var showingAddItem = false
    @State private var showingOutfits = false
    @State private var showingSubscription = false
    @State private var searchText = ""
    @State private var pendingDeletionItem: ClothingItem?
    @State private var deletionErrorMessage: String?
    @State private var selectedItem: ClothingItem?
    @State private var sortMode: ClosetSortMode = .recent
    @State private var closetFeedbackCounter = 0

    private var lang: Language {
        appState.preferredLanguage
    }

    var filteredItems: [ClothingItem] {
        var result = items
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }
        return result.sorted(using: sortMode)
    }

    private var closetStats: ClosetStats {
        ClosetStats(items: items)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        CategoryChip(title: Strings.closetAll(lang), icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                            withAnimation(.snappy(duration: 0.22)) {
                                selectedCategory = nil
                            }
                        }

                        ForEach(ClothingCategory.available(for: appState.currentUser?.personalStylingProfile.genderIdentity), id: \.self) { category in
                            CategoryChip(
                                title: Strings.categoryDisplayName(category, lang),
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.snappy(duration: 0.22)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .background(Theme.Colors.cardBackground)

                if filteredItems.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "cabinet.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        Text(Strings.closetNoItems(lang))
                            .font(.headline)
                        Text(Strings.closetAddItems(lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            startAddingItem()
                        } label: {
                            Label(Strings.closetAddArticle(lang), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.groupedBackground)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            ClosetStatsStrip(stats: closetStats, lang: lang)

                            Picker("", selection: $sortMode) {
                                ForEach(ClosetSortMode.allCases) { mode in
                                    Text(mode.title(lang)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .animation(.snappy(duration: 0.22), value: sortMode)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: Theme.Spacing.sm) {
                                ForEach(filteredItems) { item in
                                    ClosetItemCard(item: item, lang: lang)
                                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                                        .onTapGesture {
                                            selectedItem = item
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            if item.isFavorite {
                                                Image(systemName: "heart.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white)
                                                    .padding(7)
                                                    .background(.red)
                                                    .clipShape(Circle())
                                                    .padding(6)
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                markWorn(item)
                                            } label: {
                                                Label(lang == .spanish ? "Usada hoy" : "Worn today", systemImage: "checkmark.circle")
                                            }

                                            Button {
                                                toggleFavorite(item)
                                            } label: {
                                                Label(
                                                    item.isFavorite
                                                        ? (lang == .spanish ? "Quitar favorito" : "Remove favorite")
                                                        : (lang == .spanish ? "Marcar favorito" : "Mark favorite"),
                                                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                                                )
                                            }

                                            Button(role: .destructive) {
                                                pendingDeletionItem = item
                                            } label: {
                                                Label(Strings.closetDelete(lang), systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                    .animation(.snappy(duration: 0.25), value: filteredItems.map(\.id))
                    .background(Theme.Colors.groupedBackground)
                }
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(Strings.closetTitle(lang))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Strings.closetSearch(lang))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingOutfits = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startAddingItem()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                ClothingCaptureView()
            }
            .sheet(isPresented: $showingOutfits) {
                OutfitsView()
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .sheet(item: $selectedItem) { item in
                ClosetItemDetailView(
                    item: item,
                    lang: lang,
                    onDelete: {
                        selectedItem = nil
                        pendingDeletionItem = item
                    }
                )
            }
            .confirmationDialog(
                lang == .spanish ? "Eliminar prenda" : "Delete garment",
                isPresented: Binding(
                    get: { pendingDeletionItem != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeletionItem = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(lang == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    if let pendingDeletionItem {
                        deleteItem(pendingDeletionItem)
                    }
                    pendingDeletionItem = nil
                }

                Button(lang == .spanish ? "Cancelar" : "Cancel", role: .cancel) {
                    pendingDeletionItem = nil
                }
            } message: {
                Text(lang == .spanish ? "También eliminaré los resultados de try-on guardados para esta prenda." : "I will also remove saved try-on results for this garment.")
            }
            .alert(
                lang == .spanish ? "No he podido eliminar la prenda" : "I couldn't delete the garment",
                isPresented: Binding(
                    get: { deletionErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            deletionErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    deletionErrorMessage = nil
                }
            } message: {
                Text(deletionErrorMessage ?? "")
            }
            .sensoryFeedback(.success, trigger: closetFeedbackCounter)
        }
    }

    private func deleteItem(_ item: ClothingItem) {
        let itemIDString = item.id.uuidString
        let descriptor = FetchDescriptor<TryOnResult>(
            predicate: #Predicate { result in
                result.closetItemIDString == itemIDString
            }
        )
        let relatedResults = (try? modelContext.fetch(descriptor)) ?? []

        relatedResults.forEach { modelContext.delete($0) }
        modelContext.delete(item)

        do {
            try modelContext.save()
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }

    private func startAddingItem() {
        if appState.hasReachedClosetLimit(currentCount: items.count) {
            showingSubscription = true
        } else {
            showingAddItem = true
        }
    }

    private func markWorn(_ item: ClothingItem) {
        withAnimation(.snappy(duration: 0.22)) {
            item.registerConfirmedWear()
        }
        closetFeedbackCounter += 1
        saveClosetChange()
    }

    private func toggleFavorite(_ item: ClothingItem) {
        withAnimation(.snappy(duration: 0.22)) {
            item.isFavorite.toggle()
        }
        closetFeedbackCounter += 1
        saveClosetChange()
    }

    private func saveClosetChange() {
        do {
            try modelContext.save()
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
}

private enum ClosetSortMode: String, CaseIterable, Identifiable {
    case recent
    case leastWorn
    case mostWorn
    case favorites

    var id: String { rawValue }

    func title(_ lang: Language) -> String {
        switch self {
        case .recent:
            return lang == .spanish ? "Recientes" : "Recent"
        case .leastWorn:
            return lang == .spanish ? "Menos uso" : "Least worn"
        case .mostWorn:
            return lang == .spanish ? "Más uso" : "Most worn"
        case .favorites:
            return lang == .spanish ? "Favoritas" : "Favorites"
        }
    }
}

private struct ClosetStats {
    let total: Int
    let worn: Int
    let averageUsage: Int
    let underused: Int

    init(items: [ClothingItem]) {
        total = items.count
        worn = items.filter { $0.timesWorn > 0 }.count
        averageUsage = items.isEmpty ? 0 : Int((items.map(\.hiddenUsageScore).reduce(0, +) / Double(items.count)).rounded())
        underused = items.filter { $0.timesWorn == 0 || $0.hiddenUsagePercentage < 25 }.count
    }
}

private struct ClosetStatsStrip: View {
    let stats: ClosetStats
    let lang: Language

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            stat(title: lang == .spanish ? "Prendas" : "Items", value: "\(stats.total)")
            stat(title: lang == .spanish ? "Usadas" : "Worn", value: "\(stats.worn)")
            stat(title: lang == .spanish ? "Uso medio" : "Avg use", value: "\(stats.averageUsage)%")
            stat(title: lang == .spanish ? "Por rotar" : "Rotate", value: "\(stats.underused)")
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.Colors.primary : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.premiumPressable)
    }
}

struct ClosetItemCard: View {
    let item: ClothingItem
    let lang: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let image = item.displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(item.hasCutout ? Color(.systemBackground) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .overlay(alignment: .topLeading) {
                        if item.hasOptimizedImage {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Theme.Colors.primary, in: Circle())
                                .padding(6)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: item.category.icon)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(Strings.categoryDisplayName(item.category, lang))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !item.searchHighlightLine.isEmpty {
                Text(item.searchHighlightLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("\(item.timesWorn)", systemImage: "checkmark.circle")
                        .contentTransition(.numericText())
                    Spacer(minLength: 4)
                    Text("\(item.hiddenUsagePercentage)%")
                        .contentTransition(.numericText())
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                ProgressView(value: Double(item.hiddenUsagePercentage), total: 100)
                    .tint(usageTint(for: item.hiddenUsagePercentage))
            }
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: .black.opacity(0.05), radius: 2)
    }

    private func usageTint(for percentage: Int) -> Color {
        if percentage < 25 { return .orange }
        if percentage < 60 { return Theme.Colors.primary }
        return .green
    }
}


#Preview {
    ClosetView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}

private extension ClothingItem {
    func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchableValues =
            [name, category.displayName]
            + colorTags
            + styleTags
            + materialTags
            + occasionTags
            + detailTags
            + [metadataSummary, notes].compactMap { $0 }

        return searchableValues.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var searchHighlightLine: String {
        let highlights = Array((colorTags + styleTags + materialTags + occasionTags + detailTags).prefix(3))
        return highlights.joined(separator: " · ")
    }
}

private extension Array where Element == ClothingItem {
    func sorted(using mode: ClosetSortMode) -> [ClothingItem] {
        switch mode {
        case .recent:
            return sorted { $0.createdAt > $1.createdAt }
        case .leastWorn:
            return sorted {
                ($0.timesWorn, $0.lastWornAt ?? .distantPast, $0.createdAt)
                    < ($1.timesWorn, $1.lastWornAt ?? .distantPast, $1.createdAt)
            }
        case .mostWorn:
            return sorted {
                ($0.timesWorn, $0.lastWornAt ?? .distantPast, $0.createdAt)
                    > ($1.timesWorn, $1.lastWornAt ?? .distantPast, $1.createdAt)
            }
        case .favorites:
            return sorted {
                ($0.isFavorite ? 1 : 0, $0.timesWorn, $0.createdAt)
                    > ($1.isFavorite ? 1 : 0, $1.timesWorn, $1.createdAt)
            }
        }
    }
}
