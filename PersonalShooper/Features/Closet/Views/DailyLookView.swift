import SwiftUI
import SwiftData

/// "Look of the day": auto-assembles a complete outfit from the closet for today, favoring on-palette
/// and least-worn garments, and adapting the slots to the season (adds a layer in cold months).
/// The user can reshuffle for another suggestion or save it as a look.
struct DailyLookView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var closetItems: [ClothingItem]

    @State private var picks: [ClothingCategory: ClothingItem] = [:]
    @State private var saved = false

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }

    private var paletteColorNames: Set<String> {
        PaletteMatching.colorNames(for: appState.currentUser?.personalPalette)
    }

    /// Northern-hemisphere season heuristic from the current month — a lightweight stand-in until
    /// real weather (WeatherKit) is wired in.
    private var isColdSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return [11, 12, 1, 2, 3].contains(month)
    }

    private var slotOrder: [ClothingCategory] {
        var slots: [ClothingCategory] = [.tops, .bottoms, .shoes, .accessories]
        if isColdSeason { slots.insert(.outerwear, at: 2) }
        return slots
    }

    private var orderedPicks: [ClothingItem] {
        slotOrder.compactMap { picks[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header

                    if orderedPicks.isEmpty {
                        ContentUnavailableView {
                            Label(isSpanish ? "Armario vacío" : "Empty closet", systemImage: "hanger")
                        } description: {
                            Text(isSpanish ? "Añade prendas para recibir un look diario." : "Add garments to get a daily look.")
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                            ForEach(orderedPicks) { item in
                                VStack(spacing: 6) {
                                    GarmentThumbnail(item: item, size: 150, corner: 16)
                                    Text(item.name).font(.caption).lineLimit(1)
                                }
                            }
                        }

                        actionButtons
                    }
                }
                .padding()
            }
            .background(Theme.Colors.groupedBackground)
            .navigationTitle(isSpanish ? "Look del día" : "Look of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cerrar" : "Close") { dismiss() }
                }
            }
            .onAppear { if picks.isEmpty { suggest() } }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title2.weight(.bold))
            Text(isColdSeason
                 ? (isSpanish ? "Temporada fresca — incluyo una capa de abrigo." : "Cool season — I added a warm layer.")
                 : (isSpanish ? "Temporada cálida — look ligero." : "Warm season — a lighter look."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                withAnimation { suggest() }
            } label: {
                Label(isSpanish ? "Otra sugerencia" : "Another suggestion", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .foregroundStyle(Theme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .buttonStyle(.premiumPressable)

            Button {
                save()
            } label: {
                Label(saved ? (isSpanish ? "Guardado" : "Saved") : (isSpanish ? "Guardar como look" : "Save as look"),
                      systemImage: saved ? "checkmark" : "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(saved ? Color.green : Theme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .buttonStyle(.premiumPressable)
            .disabled(saved)
        }
    }

    private func items(in category: ClothingCategory) -> [ClothingItem] {
        closetItems.filter { $0.category == category }
    }

    private func suggest() {
        saved = false
        var newPicks: [ClothingCategory: ClothingItem] = [:]
        let names = paletteColorNames
        for category in slotOrder {
            let candidates = items(in: category)
            guard !candidates.isEmpty else { continue }
            let onPalette = candidates.filter { PaletteMatching.isOnPalette($0, names: names) }
            let pool = onPalette.isEmpty ? candidates : onPalette
            // Favor least-worn, but shuffle within ties so reshuffle gives variety.
            let minWorn = pool.map(\.timesWorn).min() ?? 0
            let leastWorn = pool.filter { $0.timesWorn == minWorn }
            newPicks[category] = leastWorn.randomElement() ?? pool.randomElement()
        }
        picks = newPicks
    }

    private func save() {
        let ids = orderedPicks.map(\.id.uuidString)
        guard !ids.isEmpty else { return }
        let name = isSpanish
            ? "Look \(Date().formatted(date: .abbreviated, time: .omitted))"
            : "Look \(Date().formatted(date: .abbreviated, time: .omitted))"
        let outfit = SavedOutfit(name: name, itemIDStrings: ids)
        modelContext.insert(outfit)
        try? modelContext.save()
        withAnimation { saved = true }
    }
}
