import SwiftUI
import SwiftData

/// A 2-week (15-day) outfit planner. Each day shows the local weather forecast and the garments the
/// user has planned. Tapping a day lets the user pick several garments from the closet for that date.
struct OutfitCalendarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var closetItems: [ClothingItem]
    @Query private var entries: [OutfitCalendarEntry]

    @State private var forecasts: [String: DayForecast] = [:]
    @State private var placeName: String?
    @State private var editingDay: Date?
    @State private var isLoadingWeather = false
    @State private var showingWeeklyPlanner = false

    private let weatherService = OutfitWeatherService()
    private let dayCount = 15

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    weeklyPlannerCallout
                    header

                    ForEach(days, id: \.self) { day in
                        dayRow(for: day)
                    }
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(isSpanish ? "Calendario de outfits" : "Outfit calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cerrar" : "Close") { dismiss() }
                }
            }
            .sheet(item: editingDayItem) { item in
                DayOutfitPickerSheet(
                    day: item.date,
                    closetItems: closetItems,
                    entry: entry(for: item.date),
                    language: appState.preferredLanguage,
                    onSave: { ids in saveSelection(ids, for: item.date) }
                )
            }
            .sheet(isPresented: $showingWeeklyPlanner) {
                WeeklyOutfitPlannerView(
                    closetItems: closetItems,
                    existingSelections: Dictionary(
                        entries.map { ($0.dayKey, $0.clothingItemIDs) },
                        uniquingKeysWith: { first, _ in first }
                    ),
                    language: appState.preferredLanguage,
                    paletteColorNames: PaletteMatching.colorNames(for: appState.currentUser?.personalPalette),
                    onSave: saveWeeklyPlan
                )
            }
            .task { await loadWeather() }
        }
    }

    private var weeklyPlannerCallout: some View {
        Button {
            showingWeeklyPlanner = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isSpanish ? "Preparar 5 looks de oficina" : "Prepare 5 office looks")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isSpanish
                         ? "Automáticos o manuales, con tu armario y gratis"
                         : "Automatic or manual, from your closet and free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.weeklyPlanner")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Theme.Colors.primary)
            Text(isSpanish ? "Próximos 15 días" : "Next 15 days")
                .font(.subheadline.weight(.medium))
            Spacer()
            if isLoadingWeather {
                ProgressView().controlSize(.small)
            } else if let placeName {
                Label(placeName, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, Theme.Spacing.xs)
    }

    private func dayRow(for day: Date) -> some View {
        let key = OutfitCalendarEntry.dayKey(for: day)
        let forecast = forecasts[key]
        let plannedItems = items(for: day)

        return Button {
            editingDay = day
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayText(day))
                            .font(.headline)
                        Text(dateText(day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let forecast {
                        HStack(spacing: 6) {
                            Image(systemName: forecast.symbolName)
                                .foregroundStyle(Theme.Colors.primary)
                            Text("\(Int(forecast.tempMax.rounded()))° / \(Int(forecast.tempMin.rounded()))°")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                    }
                }

                if plannedItems.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text(isSpanish ? "Planear outfit" : "Plan outfit")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.primary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(plannedItems) { item in
                                if let image = item.displayImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 56, height: 56)
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isToday(day) ? Theme.Colors.primary.opacity(0.08) : Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .overlay {
                if isToday(day) {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                        .stroke(Theme.Colors.primary.opacity(0.4), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func entry(for day: Date) -> OutfitCalendarEntry? {
        let key = OutfitCalendarEntry.dayKey(for: day)
        return entries.first { $0.dayKey == key }
    }

    private func items(for day: Date) -> [ClothingItem] {
        let ids = entry(for: day)?.clothingItemIDs ?? []
        return ids.compactMap { id in closetItems.first { $0.id == id } }
    }

    private func saveSelection(_ ids: [UUID], for day: Date) {
        let key = OutfitCalendarEntry.dayKey(for: day)
        if let existing = entries.first(where: { $0.dayKey == key }) {
            if ids.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.clothingItemIDs = ids
            }
        } else if !ids.isEmpty {
            modelContext.insert(OutfitCalendarEntry(dayKey: key, clothingItemIDs: ids))
        }
        try? modelContext.save()
    }

    private func saveWeeklyPlan(_ drafts: [WeeklyOutfitDraft]) {
        for draft in drafts {
            let key = OutfitCalendarEntry.dayKey(for: draft.date)
            if let existing = entries.first(where: { $0.dayKey == key }) {
                if draft.itemIDs.isEmpty {
                    modelContext.delete(existing)
                } else {
                    existing.clothingItemIDs = draft.itemIDs
                }
            } else if !draft.itemIDs.isEmpty {
                modelContext.insert(
                    OutfitCalendarEntry(dayKey: key, clothingItemIDs: draft.itemIDs)
                )
            }
        }
        try? modelContext.save()
    }

    private func loadWeather() async {
        isLoadingWeather = true
        let result = await weatherService.forecast(days: dayCount)
        for forecast in result {
            forecasts[OutfitCalendarEntry.dayKey(for: forecast.date)] = forecast
        }
        placeName = weatherService.placeName
        isLoadingWeather = false
    }

    // MARK: - Formatting

    private var editingDayItem: Binding<DayItem?> {
        Binding(
            get: { editingDay.map(DayItem.init) },
            set: { editingDay = $0?.date }
        )
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    private func weekdayText(_ day: Date) -> String {
        if isToday(day) { return isSpanish ? "Hoy" : "Today" }
        if Calendar.current.isDateInTomorrow(day) { return isSpanish ? "Mañana" : "Tomorrow" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appState.preferredLanguage == .spanish ? "es_ES" : "en_US")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day).capitalized
    }

    private func dateText(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appState.preferredLanguage == .spanish ? "es_ES" : "en_US")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: day)
    }
}

private struct DayItem: Identifiable {
    let date: Date
    var id: Date { date }
}

// MARK: - Garment multi-select sheet

private struct DayOutfitPickerSheet: View {
    let day: Date
    let closetItems: [ClothingItem]
    let entry: OutfitCalendarEntry?
    let language: Language
    let onSave: ([UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    private var isSpanish: Bool { language == .spanish }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if closetItems.isEmpty {
                    ContentUnavailableView(
                        isSpanish ? "Armario vacío" : "Empty closet",
                        systemImage: "cabinet",
                        description: Text(isSpanish ? "Añade prendas a tu armario para planear outfits." : "Add garments to your closet to plan outfits.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(closetItems) { item in
                                garmentCell(item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(isSpanish ? "Elegir prendas" : "Choose garments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cancelar" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Guardar" : "Save") {
                        onSave(Array(selected))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { selected = Set(entry?.clothingItemIDs ?? []) }
        }
    }

    private func garmentCell(_ item: ClothingItem) -> some View {
        let isOn = selected.contains(item.id)
        return Button {
            if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    if let image = item.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 96)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 96)
                            .overlay { Image(systemName: item.category.icon).foregroundStyle(.secondary) }
                    }
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.primary)
                            .background(Circle().fill(.white))
                            .padding(6)
                    }
                }
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(6)
            .background(isOn ? Theme.Colors.primary.opacity(0.1) : Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isOn ? Theme.Colors.primary : Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
