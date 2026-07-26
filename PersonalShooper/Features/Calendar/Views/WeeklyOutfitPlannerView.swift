import SwiftData
import SwiftUI

private enum WeeklyPlanningMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    func title(language: Language) -> String {
        switch (self, language) {
        case (.automatic, .spanish): return "Automático"
        case (.automatic, .english): return "Automatic"
        case (.manual, .spanish): return "Manual"
        case (.manual, .english): return "Manual"
        }
    }
}

struct WeeklyOutfitPlannerView: View {
    let closetItems: [ClothingItem]
    let existingSelections: [String: [UUID]]
    let language: Language
    let paletteColorNames: Set<String>
    let onSave: ([WeeklyOutfitDraft]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: WeeklyPlanningMode = .automatic
    @State private var drafts: [WeeklyOutfitDraft] = []
    @State private var editingDraft: WeeklyOutfitDraft?

    private var isSpanish: Bool { language == .spanish }
    private var garments: [WeeklyPlannerGarment] { closetItems.map(WeeklyPlannerGarment.init) }
    private var itemsByID: [UUID: ClothingItem] {
        Dictionary(closetItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    private var hasAnySelection: Bool { drafts.contains { !$0.itemIDs.isEmpty } }

    var body: some View {
        NavigationStack {
            Group {
                if closetItems.isEmpty {
                    ContentUnavailableView {
                        Label(isSpanish ? "Tu armario está vacío" : "Your closet is empty", systemImage: "hanger")
                    } description: {
                        Text(isSpanish
                             ? "Añade prendas al armario y volveré a preparar tus cinco looks de oficina."
                             : "Add garments to your closet and come back to prepare five office looks.")
                    }
                    .accessibilityIdentifier("weeklyPlanner.empty")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            intro

                            Picker(isSpanish ? "Modo" : "Mode", selection: $mode) {
                                ForEach(WeeklyPlanningMode.allCases) { option in
                                    Text(option.title(language: language)).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("weeklyPlanner.mode")

                            modeControls

                            LazyVStack(spacing: Theme.Spacing.sm) {
                                ForEach(drafts) { draft in
                                    dayCard(draft)
                                }
                            }

                            Label(
                                isSpanish
                                    ? "Se guarda en tu calendario de outfits. No usa créditos ni envía datos."
                                    : "Saved to your outfit calendar. Uses no credits and sends no data.",
                                systemImage: "lock.shield"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Theme.Spacing.screenPadding)
                    }
                    .background(Theme.Colors.groupedBackground.ignoresSafeArea())
                }
            }
            .navigationTitle(isSpanish ? "5 looks de oficina" : "5 office looks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cancelar" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Guardar" : "Save") {
                        onSave(drafts)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasAnySelection)
                    .accessibilityIdentifier("weeklyPlanner.save")
                }
            }
            .sheet(item: $editingDraft) { draft in
                OfficeOutfitPickerSheet(
                    day: draft.date,
                    closetItems: closetItems,
                    initialSelection: draft.itemIDs,
                    language: language,
                    paletteColorNames: paletteColorNames
                ) { ids in
                    updateDraft(for: draft.date, itemIDs: ids)
                }
            }
            .onAppear(perform: loadInitialDrafts)
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Theme.Colors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))

            VStack(alignment: .leading, spacing: 4) {
                Text(isSpanish ? "Tu próxima semana laboral" : "Your next workweek")
                    .font(.headline)
                Text(isSpanish
                     ? "Genero cinco combinaciones con tu propia ropa. Puedes cambiar cualquier día antes de guardar."
                     : "I create five combinations from your own clothes. You can change any day before saving.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var modeControls: some View {
        switch mode {
        case .automatic:
            Button {
                regenerate()
            } label: {
                Label(isSpanish ? "Generar otros 5" : "Generate 5 more", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .manual:
            HStack {
                Text(isSpanish
                     ? "Toca cada día para elegir las prendas."
                     : "Tap each day to choose garments.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isSpanish ? "Vaciar" : "Clear", role: .destructive) {
                    for index in drafts.indices {
                        drafts[index].itemIDs = []
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func dayCard(_ draft: WeeklyOutfitDraft) -> some View {
        let selectedItems = draft.itemIDs.compactMap { itemsByID[$0] }
        let isComplete = WeeklyOutfitPlannerService.isCompleteOfficeLook(
            itemIDs: draft.itemIDs,
            garments: garments
        )

        return Button {
            editingDraft = draft
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayText(draft.date))
                            .font(.headline)
                        Text(dateText(draft.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(isComplete ? Theme.Colors.success : Theme.Colors.warning)
                        .accessibilityLabel(isComplete
                                            ? (isSpanish ? "Look completo" : "Complete look")
                                            : (isSpanish ? "Look por completar" : "Look needs items"))

                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }

                if selectedItems.isEmpty {
                    Label(isSpanish ? "Elegir prendas" : "Choose garments", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(height: 66)
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedItems.prefix(4))) { item in
                            VStack(spacing: 3) {
                                GarmentThumbnail(item: item, size: 64, corner: 10)
                                Text(item.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }

                        if selectedItems.count > 4 {
                            Text("+\(selectedItems.count - 4)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 64)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadInitialDrafts() {
        guard drafts.isEmpty else { return }
        let days = WeeklyOutfitPlannerService.upcomingWorkdays()
        let existing = days.map { day in
            WeeklyOutfitDraft(
                date: day,
                itemIDs: existingSelections[OutfitCalendarEntry.dayKey(for: day)] ?? []
            )
        }

        if existing.contains(where: { !$0.itemIDs.isEmpty }) {
            drafts = existing
        } else {
            regenerate()
        }
    }

    private func regenerate() {
        drafts = WeeklyOutfitPlannerService.generate(
            garments: garments,
            paletteColorNames: paletteColorNames
        )
    }

    private func updateDraft(for date: Date, itemIDs: [UUID]) {
        guard let index = drafts.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }
        drafts[index].itemIDs = itemIDs
    }

    private func weekdayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

private struct OfficeOutfitPickerSheet: View {
    let day: Date
    let closetItems: [ClothingItem]
    let initialSelection: [UUID]
    let language: Language
    let paletteColorNames: Set<String>
    let onSave: ([UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: [ClothingCategory: UUID] = [:]

    private let categoryOrder: [ClothingCategory] = [
        .tops, .bottoms, .dresses, .outerwear, .shoes, .accessories, .jewelry
    ]

    private var isSpanish: Bool { language == .spanish }
    private var availableCategories: [ClothingCategory] {
        categoryOrder.filter { category in closetItems.contains { $0.category == category } }
    }
    private var selectedIDs: [UUID] {
        categoryOrder.compactMap { selection[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(availableCategories, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cancelar" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Guardar" : "Save") {
                        onSave(selectedIDs)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        suggest()
                    } label: {
                        Label(isSpanish ? "Sugerir combinación" : "Suggest combination", systemImage: "wand.and.stars")
                    }
                }
            }
            .onAppear(perform: loadSelection)
        }
    }

    private func categorySection(_ category: ClothingCategory) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(Strings.categoryDisplayName(category, language))
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(closetItems.filter { $0.category == category }) { item in
                        garmentButton(item)
                    }
                }
            }
        }
    }

    private func garmentButton(_ item: ClothingItem) -> some View {
        let isSelected = selection[item.category] == item.id
        let isOnPalette = item.colorTags.contains { color in
            paletteColorNames.contains {
                $0.compare(color, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }

        return Button {
            toggle(item)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    GarmentThumbnail(item: item, size: 92, corner: 12)
                    if isOnPalette {
                        Image(systemName: "paintpalette.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Theme.Colors.success, in: Circle())
                            .padding(4)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.Colors.primary : .clear, lineWidth: 3)
                }

                Text(item.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ item: ClothingItem) {
        if selection[item.category] == item.id {
            selection[item.category] = nil
            return
        }

        selection[item.category] = item.id
        if item.category == .dresses {
            selection[.tops] = nil
            selection[.bottoms] = nil
        } else if item.category == .tops || item.category == .bottoms {
            selection[.dresses] = nil
        }
    }

    private func loadSelection() {
        let selectedItems = initialSelection.compactMap { id in closetItems.first { $0.id == id } }
        selection = Dictionary(
            selectedItems.map { ($0.category, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func suggest() {
        guard let proposal = WeeklyOutfitPlannerService.generate(
            garments: closetItems.map(WeeklyPlannerGarment.init),
            from: day,
            paletteColorNames: paletteColorNames
        ).first else { return }

        let proposedItems = proposal.itemIDs.compactMap { id in closetItems.first { $0.id == id } }
        selection = Dictionary(
            proposedItems.map { ($0.category, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: day).capitalized
    }
}
