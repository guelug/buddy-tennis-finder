import SwiftUI
import SwiftData
import UIKit

/// Saved looks the user assembled from their closet, plus an entry point to build a new one.
struct OutfitsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedOutfit.createdAt, order: .reverse) private var outfits: [SavedOutfit]
    @Query private var closetItems: [ClothingItem]
    @State private var showingBuilder = false
    @State private var shareImage: UIImage?

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }
    private var itemsByID: [UUID: ClothingItem] { Dictionary(closetItems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty {
                    ContentUnavailableView {
                        Label(isSpanish ? "Sin looks guardados" : "No saved looks", systemImage: "square.stack.3d.up")
                    } description: {
                        Text(isSpanish ? "Combina prendas de tu armario y guárdalas como un look." : "Combine garments from your closet and save them as a look.")
                    } actions: {
                        Button(isSpanish ? "Crear un look" : "Create a look") { showingBuilder = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(outfits) { outfit in
                                outfitCard(outfit)
                            }
                        }
                        .padding()
                    }
                    .background(Theme.Colors.groupedBackground)
                }
            }
            .navigationTitle(isSpanish ? "Mis looks" : "My Looks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                OutfitBuilderView()
            }
            .sheet(isPresented: Binding(get: { shareImage != nil }, set: { if !$0 { shareImage = nil } })) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                }
            }
        }
    }

    /// Renders a shareable collage image of a look (title + garment grid) via ImageRenderer.
    @MainActor
    private func renderCollage(name: String, occasion: String?, items: [ClothingItem]) -> UIImage? {
        let content = VStack(spacing: 18) {
            Text(name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
            if let occasion, !occasion.isEmpty {
                Text(occasion)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(items) { item in
                    GarmentThumbnail(item: item, size: 165, corner: 18)
                }
            }
            Text(isSpanish ? "Creado con Personal Shopper" : "Created with Personal Shopper")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 620)
        .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage
    }

    private func outfitCard(_ outfit: SavedOutfit) -> some View {
        let items = outfit.itemIDs.compactMap { itemsByID[$0] }
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(outfit.name).font(.headline)
                    if let occasion = outfit.occasion, !occasion.isEmpty {
                        Text(occasion).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button {
                        shareImage = renderCollage(name: outfit.name, occasion: outfit.occasion, items: items)
                    } label: {
                        Label(isSpanish ? "Compartir" : "Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { delete(outfit) } label: {
                        Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(items) { item in
                        thumb(item)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private func thumb(_ item: ClothingItem) -> some View {
        VStack(spacing: 4) {
            GarmentThumbnail(item: item, size: 70)
            Text(item.name).font(.caption2).lineLimit(1).frame(width: 70)
        }
    }

    private func delete(_ outfit: SavedOutfit) {
        modelContext.delete(outfit)
        try? modelContext.save()
    }
}

/// Build a look by picking one garment per slot, with a one-tap palette-aware "suggest" helper.
struct OutfitBuilderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var closetItems: [ClothingItem]

    @State private var selection: [ClothingCategory: UUID] = [:]
    @State private var name: String = ""
    @State private var occasion: String = ""

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }

    /// Canonical slot order; only slots with at least one closet item are shown.
    private let slotOrder: [ClothingCategory] = [.tops, .dresses, .bottoms, .outerwear, .shoes, .accessories, .jewelry, .activewear]

    private var availableSlots: [ClothingCategory] {
        slotOrder.filter { category in closetItems.contains { $0.category == category } }
    }

    private func items(in category: ClothingCategory) -> [ClothingItem] {
        closetItems.filter { $0.category == category }
    }

    private var selectedCount: Int { selection.values.count }

    /// Lowercased palette color names, used to highlight on-palette picks.
    private var paletteColorNames: Set<String> {
        guard let palette = appState.currentUser?.personalPalette else { return [] }
        let all = palette.recommendedColors + (palette.neutralColors ?? []) + (palette.statementColors ?? [])
        return Set(all.compactMap { $0.name?.lowercased() })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    TextField(isSpanish ? "Nombre del look" : "Look name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField(isSpanish ? "Ocasión (opcional)" : "Occasion (optional)", text: $occasion)
                        .textFieldStyle(.roundedBorder)

                    ForEach(availableSlots, id: \.self) { category in
                        slotSection(category)
                    }
                }
                .padding()
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle(isSpanish ? "Nuevo look" : "New look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cancelar" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Guardar" : "Save") { save() }
                        .disabled(selectedCount == 0)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        suggest()
                    } label: {
                        Label(isSpanish ? "Sugerir look" : "Suggest a look", systemImage: "wand.and.stars")
                    }
                }
            }
        }
    }

    private func slotSection(_ category: ClothingCategory) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(Strings.categoryDisplayName(category, appState.preferredLanguage))
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(items(in: category)) { item in
                        slotItem(item, category: category)
                    }
                }
            }
        }
    }

    private func slotItem(_ item: ClothingItem, category: ClothingCategory) -> some View {
        let isSelected = selection[category] == item.id
        let onPalette = item.colorTags.contains { paletteColorNames.contains($0.lowercased()) }
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected { selection[category] = nil } else { selection[category] = item.id }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    GarmentThumbnail(item: item, size: 84, corner: 12)
                    if onPalette {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.green, in: Circle())
                            .padding(4)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Theme.Colors.primary : .clear, lineWidth: 3)
                )
                Text(item.name).font(.caption2).lineLimit(1).frame(width: 84)
            }
        }
        .buttonStyle(.plain)
    }

    /// Auto-fill each slot, preferring on-palette garments and then the least-worn (to rotate the
    /// closet). Skips bottoms when a dress is chosen.
    private func suggest() {
        var newSelection: [ClothingCategory: UUID] = [:]
        for category in availableSlots {
            let candidates = items(in: category)
            guard !candidates.isEmpty else { continue }
            let onPalette = candidates.filter { item in item.colorTags.contains { paletteColorNames.contains($0.lowercased()) } }
            let pool = onPalette.isEmpty ? candidates : onPalette
            // Prefer the least-worn to encourage rotation.
            let pick = pool.min { $0.timesWorn < $1.timesWorn } ?? pool.first
            if let pick { newSelection[category] = pick.id }
        }
        // A dress is a full look — drop separate top/bottom if a dress was picked.
        if newSelection[.dresses] != nil {
            newSelection[.tops] = nil
            newSelection[.bottoms] = nil
        }
        withAnimation(.snappy(duration: 0.25)) { selection = newSelection }
    }

    private func save() {
        let ids = availableSlots.compactMap { selection[$0]?.uuidString }
        guard !ids.isEmpty else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty
            ? (isSpanish ? "Look \(Date().formatted(date: .abbreviated, time: .omitted))" : "Look \(Date().formatted(date: .abbreviated, time: .omitted))")
            : trimmedName
        let outfit = SavedOutfit(
            name: finalName,
            itemIDStrings: ids,
            occasion: occasion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : occasion
        )
        modelContext.insert(outfit)
        try? modelContext.save()
        dismiss()
    }
}
