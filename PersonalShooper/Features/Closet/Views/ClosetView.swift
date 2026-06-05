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
                    .background(Color.white)
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

private struct ClosetItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var item: ClothingItem
    let lang: Language
    let onDelete: () -> Void

    @State private var errorMessage: String?
    @State private var detailFeedbackCounter = 0
    @State private var isOptimizing = false
    @State private var showOptimizeOverlay = false
    @State private var optimizeSource: UIImage?
    @State private var optimizedResult: UIImage?

    /// Reactively tracks whether THIS garment has a saved AR location. Using `@Query` (instead of
    /// a one-off `modelContext.fetch` inside a computed property) makes the body re-evaluate as
    /// soon as the AR view inserts / removes a row in the shared SwiftData store, so the
    /// "Find in AR" button shows up the moment the user pops back from the AR view.
    @Query private var arPlacementsForItem: [ARClothingPlacement]

    init(item: ClothingItem, lang: Language, onDelete: @escaping () -> Void) {
        self.item = item
        self.lang = lang
        self.onDelete = onDelete
        let itemIDString = item.id.uuidString
        _arPlacementsForItem = Query(
            filter: #Predicate<ARClothingPlacement> { $0.clothingItemIDString == itemIDString }
        )
    }

    private var canOptimize: Bool {
        appState.isPremium || appState.hasBYOKAccess
    }

    private var hasARPlacement: Bool {
        !arPlacementsForItem.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let image = item.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                    }

                    optimizeImageSection

                    // AR Location button
                    NavigationLink {
                        ARWardrobeView()
                            .onAppear {
                                // Pre-select this item when AR opens
                                NotificationCenter.default.post(name: .preselectARItem, object: item.id)
                            }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arkit")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang == .spanish ? "Marcar dónde está" : "Mark where it is")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(lang == .spanish ? "Usa AR para recordar dónde guardaste esta prenda" : "Use AR to remember where you stored this garment")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                    .buttonStyle(.premiumPressable)

                    // Find-in-AR button — only when this garment already has a saved location.
                    if hasARPlacement {
                        NavigationLink {
                            ARWardrobeView()
                                .onAppear {
                                    NotificationCenter.default.post(name: .findARItem, object: item.id)
                                }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "location.magnifyingglass")
                                    .font(.title2)
                                    .foregroundStyle(.green)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang == .spanish ? "¿Dónde está? Encontrar en AR" : "Where is it? Find in AR")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(lang == .spanish ? "Te guío con una flecha hasta la prenda" : "I'll guide you to it with an arrow")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        }
                        .buttonStyle(.premiumPressable)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        TextField(lang == .spanish ? "Nombre" : "Name", text: $item.name)
                            .font(.title2.weight(.semibold))

                        Picker(lang == .spanish ? "Categoría" : "Category", selection: $item.category) {
                            ForEach(ClothingCategory.available(for: appState.currentUser?.personalStylingProfile.genderIdentity), id: \.self) { category in
                                Label(Strings.categoryDisplayName(category, lang), systemImage: category.icon)
                                    .tag(category)
                            }
                        }

                        Toggle(isOn: $item.isFavorite) {
                            Label(lang == .spanish ? "Favorita" : "Favorite", systemImage: "heart")
                        }
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))

                    usageSection
                    tagsSection

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(lang == .spanish ? "Notas" : "Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            lang == .spanish ? "Ej. combinar con denim oscuro" : "Example: pair with dark denim",
                            text: Binding(
                                get: { item.notes ?? "" },
                                set: { item.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                }
                .padding()
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle(lang == .spanish ? "Detalle" : "Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang == .spanish ? "Cerrar" : "Close") {
                        saveAndDismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            markWorn()
                        } label: {
                            Label(lang == .spanish ? "Registrar uso hoy" : "Log worn today", systemImage: "checkmark.circle")
                        }

                        Button {
                            item.registerIgnoredRecommendation()
                            save()
                        } label: {
                            Label(lang == .spanish ? "No me apetece usarla" : "Not feeling it", systemImage: "minus.circle")
                        }

                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label(Strings.closetDelete(lang), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(lang == .spanish ? "No he podido guardar" : "Couldn't save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showOptimizeOverlay) {
                if let optimizeSource {
                    ImageOptimizeOverlay(
                        source: optimizeSource,
                        optimized: optimizedResult,
                        language: lang,
                        onContinue: { showOptimizeOverlay = false }
                    )
                }
            }
            .sensoryFeedback(.success, trigger: detailFeedbackCounter)
        }
    }

    @ViewBuilder
    private var optimizeImageSection: some View {
        if canOptimize {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    startOptimize()
                } label: {
                    HStack(spacing: 8) {
                        if isOptimizing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(optimizeButtonTitle)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .contentShape(Rectangle())
                }
                .disabled(isOptimizing)
                .buttonStyle(.premiumPressable)

                Text(item.hasOptimizedImage
                     ? (lang == .spanish ? "Imagen optimizada. Puedes regenerarla si no te convence." : "Optimized image. You can regenerate it if you're not happy.")
                     : (lang == .spanish ? "Crea una miniatura tipo tienda: fondo blanco, prenda de frente y completa." : "Create a store-style thumbnail: white background, item facing front and fully visible."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optimizeButtonTitle: String {
        if isOptimizing {
            return lang == .spanish ? "Optimizando..." : "Optimizing..."
        }
        if item.hasOptimizedImage {
            return lang == .spanish ? "Regenerar imagen" : "Regenerate image"
        }
        return lang == .spanish ? "Optimizar imagen" : "Optimize image"
    }

    private func startOptimize() {
        guard let source = item.tryOnGarmentImage ?? item.displayImage else { return }

        // Without a configured image provider the generation just echoes the source back, which would
        // otherwise fire a fake "success". Tell the user how to enable it instead.
        guard StyleImageService.hasImageProvider() else {
            errorMessage = lang == .spanish
                ? "Para optimizar imágenes necesitas configurar tu propia clave de API en Ajustes → Clave propia (BYOK)."
                : "To optimize images you need to add your own API key in Settings → Bring your own key (BYOK)."
            return
        }

        optimizeSource = source
        optimizedResult = nil
        isOptimizing = true
        showOptimizeOverlay = true
        Task { await optimizeImage(source: source) }
    }

    private func optimizeImage(source: UIImage) async {
        defer { isOptimizing = false }

        do {
            let optimized = try await StyleImageService.marketingImage(
                for: source,
                categoryHint: item.category.displayName.lowercased()
            )
            item.optimizedImage = optimized
            detailFeedbackCounter += 1
            try? modelContext.save()
            // Drives the overlay's before→after reveal.
            withAnimation { optimizedResult = optimized }
        } catch {
            showOptimizeOverlay = false
            errorMessage = lang == .spanish
                ? "No he podido optimizar la imagen: \(error.localizedDescription)"
                : "I couldn't optimize the image: \(error.localizedDescription)"
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(lang == .spanish ? "Uso de la prenda" : "Garment usage")
                    .font(.headline)
                Spacer()
                Text("\(item.hiddenUsagePercentage)%")
                    .font(.headline)
                    .foregroundStyle(usageTint(for: item.hiddenUsagePercentage))
            }

            ProgressView(value: Double(item.hiddenUsagePercentage), total: 100)
                .tint(usageTint(for: item.hiddenUsagePercentage))

            HStack(spacing: Theme.Spacing.sm) {
                metric(title: lang == .spanish ? "Usos" : "Wears", value: "\(item.timesWorn)")
                metric(title: lang == .spanish ? "Sugerida" : "Suggested", value: "\(item.recommendationAppearanceCount)")
                metric(title: lang == .spanish ? "Aceptada" : "Accepted", value: "\(item.recommendationSuccessfulWearCount)")
            }

            if let lastWornAt = item.lastWornAt {
                Label(lastWornAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(lang == .spanish ? "Aún no registrada como usada" : "Not logged as worn yet", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                markWorn()
            } label: {
                Label(lang == .spanish ? "Registrar uso hoy" : "Log worn today", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .sensoryFeedback(.success, trigger: item.timesWorn)
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    @ViewBuilder
    private var tagsSection: some View {
        let tagGroups: [(String, [String])] = [
            (lang == .spanish ? "Colores" : "Colors", item.colorTags),
            (lang == .spanish ? "Estilo" : "Style", item.styleTags),
            (lang == .spanish ? "Materiales" : "Materials", item.materialTags),
            (lang == .spanish ? "Ocasiones" : "Occasions", item.occasionTags),
            (lang == .spanish ? "Detalles" : "Details", item.detailTags)
        ].filter { !$0.1.isEmpty }

        if !tagGroups.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(tagGroups, id: \.0) { title, tags in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        FlexibleTagRow(tags: tags)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }

    private func markWorn() {
        withAnimation(.snappy(duration: 0.22)) {
            item.registerConfirmedWear()
        }
        detailFeedbackCounter += 1
        save()
    }

    private func saveAndDismiss() {
        save()
        dismiss()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func usageTint(for percentage: Int) -> Color {
        if percentage < 25 { return .orange }
        if percentage < 60 { return Theme.Colors.primary }
        return .green
    }
}

private struct FlexibleTagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
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
