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
    @State private var showingDailyLook = false
    @State private var showingSubscription = false
    @State private var searchText = ""
    @State private var pendingDeletionItem: ClothingItem?
    @State private var deletionErrorMessage: String?
    @State private var selectedItem: ClothingItem?
    @State private var sortMode: ClosetSortMode = .recent
    @State private var onPaletteOnly = false
    @State private var closetFeedbackCounter = 0
    @State private var confirmBatchOptimize = false
    @State private var isBatchOptimizing = false
    @State private var batchDone = 0
    @State private var batchTotal = 0

    private var lang: Language {
        appState.preferredLanguage
    }

    private var paletteColorNames: Set<String> {
        PaletteMatching.colorNames(for: appState.currentUser?.personalPalette)
    }

    var filteredItems: [ClothingItem] {
        var result = items
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }
        if onPaletteOnly {
            let names = paletteColorNames
            result = result.filter { PaletteMatching.isOnPalette($0, names: names) }
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

                if filteredItems.isEmpty && !items.isEmpty {
                    // Items exist but a filter is hiding them — don't make it look like the closet is
                    // empty; explain and offer to clear the filter.
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        Text(onPaletteOnly
                             ? (lang == .spanish ? "Ninguna prenda coincide con tu paleta" : "No garments match your palette")
                             : (lang == .spanish ? "Sin resultados para este filtro" : "No results for this filter"))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(lang == .spanish ? "Ajusta los filtros para ver tus prendas." : "Adjust the filters to see your garments.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                onPaletteOnly = false
                                selectedCategory = nil
                                searchText = ""
                            }
                        } label: {
                            Label(lang == .spanish ? "Quitar filtros" : "Clear filters", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Theme.Colors.groupedBackground)
                } else if filteredItems.isEmpty {
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

                            if rotationCandidateCount > 0 && searchText.isEmpty && sortMode != .leastWorn {
                                rotationBanner
                            }

                            Picker("", selection: $sortMode) {
                                ForEach(ClosetSortMode.allCases) { mode in
                                    Text(mode.title(lang)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .animation(.snappy(duration: 0.22), value: sortMode)

                            if !paletteColorNames.isEmpty {
                                Button {
                                    withAnimation(.snappy(duration: 0.22)) { onPaletteOnly.toggle() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: onPaletteOnly ? "checkmark.seal.fill" : "checkmark.seal")
                                        Text(lang == .spanish ? "Solo en mi paleta" : "Only in my palette")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity)
                                    .background(onPaletteOnly ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.1))
                                    .foregroundStyle(onPaletteOnly ? .white : Theme.Colors.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.premiumPressable)
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: Theme.Spacing.sm) {
                                ForEach(filteredItems) { item in
                                    ClosetItemCard(item: item, lang: lang, isOnPalette: PaletteMatching.isOnPalette(item, names: paletteColorNames))
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
                    Menu {
                        Button {
                            showingDailyLook = true
                        } label: {
                            Label(lang == .spanish ? "Look del día" : "Look of the day", systemImage: "sparkles")
                        }
                        Button {
                            showingOutfits = true
                        } label: {
                            Label(lang == .spanish ? "Mis looks" : "My looks", systemImage: "square.stack.3d.up")
                        }
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                }
                if canBatchOptimize {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                confirmBatchOptimize = true
                            } label: {
                                Label(lang == .spanish ? "Optimizar todas (\(unoptimizedCount))" : "Optimize all (\(unoptimizedCount))", systemImage: "wand.and.stars")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
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
            .overlay {
                if isBatchOptimizing {
                    batchOptimizeOverlay
                }
            }
            .confirmationDialog(
                lang == .spanish ? "Optimizar \(unoptimizedCount) imágenes" : "Optimize \(unoptimizedCount) images",
                isPresented: $confirmBatchOptimize,
                titleVisibility: .visible
            ) {
                Button(lang == .spanish ? "Optimizar todas" : "Optimize all") { startBatchOptimize() }
                Button(lang == .spanish ? "Cancelar" : "Cancel", role: .cancel) {}
            } message: {
                Text(lang == .spanish ? "Generaré una miniatura tipo tienda para cada prenda usando tu API. Puede tardar y consumir créditos." : "I'll generate a store-style thumbnail for each garment using your API. It may take a while and use credits.")
            }
            .sheet(isPresented: $showingAddItem) {
                ClothingCaptureView()
            }
            .sheet(isPresented: $showingOutfits) {
                OutfitsView()
            }
            .sheet(isPresented: $showingDailyLook) {
                DailyLookView()
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

    // MARK: - Rotation nudge

    /// Garments that exist for at least 2 weeks but are barely (or never) worn — candidates to rotate.
    private var rotationCandidateCount: Int {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return items.filter { $0.createdAt < twoWeeksAgo && ($0.timesWorn == 0 || $0.hiddenUsagePercentage < 25) }.count
    }

    private var rotationBanner: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { sortMode = .leastWorn }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang == .spanish ? "Hora de rotar tu armario" : "Time to rotate your closet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(lang == .spanish
                         ? "\(rotationCandidateCount) prendas apenas las usas. Toca para verlas y darles uso."
                         : "\(rotationCandidateCount) garments are barely worn. Tap to see them and give them a wear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.premiumPressable)
    }

    // MARK: - Batch optimize

    private var unoptimizedItems: [ClothingItem] {
        items.filter { !$0.hasOptimizedImage && ($0.tryOnGarmentImage ?? $0.displayImage) != nil }
    }

    private var unoptimizedCount: Int { unoptimizedItems.count }

    private var canBatchOptimize: Bool {
        (appState.isPremium || appState.hasBYOKAccess) && StyleImageService.hasImageProvider() && unoptimizedCount > 0
    }

    @ViewBuilder
    private var batchOptimizeOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                ProgressView(value: Double(batchDone), total: Double(max(batchTotal, 1)))
                    .progressViewStyle(.linear)
                    .tint(Theme.Colors.primary)
                    .frame(width: 200)
                Text(lang == .spanish ? "Optimizando \(batchDone)/\(batchTotal)…" : "Optimizing \(batchDone)/\(batchTotal)…")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(Theme.Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        }
    }

    private func startBatchOptimize() {
        let targets = unoptimizedItems
        guard !targets.isEmpty else { return }
        batchTotal = targets.count
        batchDone = 0
        isBatchOptimizing = true

        Task {
            for item in targets {
                guard let source = item.tryOnGarmentImage ?? item.displayImage else { batchDone += 1; continue }
                do {
                    let optimized = try await StyleImageService.marketingImage(
                        for: source,
                        categoryHint: item.category.displayName.lowercased()
                    )
                    item.optimizedImage = optimized
                    item.cutoutImage = BackgroundRemover.removeBackground(from: optimized)
                    try? modelContext.save()
                } catch {
                    // Skip failures (e.g. moderation) and keep going through the rest.
                }
                batchDone += 1
            }
            isBatchOptimizing = false
            closetFeedbackCounter += 1
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
    var isOnPalette: Bool = false

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

            HStack(spacing: 4) {
                Text(Strings.categoryDisplayName(item.category, lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isOnPalette {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text(lang == .spanish ? "En paleta" : "On palette")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

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
