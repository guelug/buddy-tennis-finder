import SwiftUI
import SwiftData
import UIKit

struct ClosetItemDetailView: View {
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
    @State private var confirmManagedImageProcessing = false

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
        StyleImageService.hasImageProvider() || StyleImageService.shouldRequestManagedProcessingConsent
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
                            .background(Color.clear)
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

                        HStack {
                            Label(lang == .spanish ? "Precio" : "Price", systemImage: "tag")
                                .font(.subheadline)
                            Spacer()
                            TextField(
                                lang == .spanish ? "Opcional" : "Optional",
                                value: $item.price,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
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
            .alert(
                lang == .spanish ? "Procesado externo opcional" : "Optional Cloud Processing",
                isPresented: $confirmManagedImageProcessing
            ) {
                Button(lang == .spanish ? "Usar nube" : "Use Cloud") {
                    StyleImageService.hasManagedProcessingConsent = true
                    startOptimizeAfterConsentCheck()
                }
                Button(lang == .spanish ? "Solo en dispositivo" : "On Device Only") {
                    startOptimizeAfterConsentCheck()
                }
                Button(lang == .spanish ? "Cancelar" : "Cancel", role: .cancel) {}
            } message: {
                Text(lang == .spanish
                     ? "Si Image Playground no está disponible, la app puede enviar esta foto al servicio de IA de Personal Shooper. Puedes revocar este permiso en Privacidad."
                     : "If Image Playground is unavailable, the app can send this photo to Personal Shooper's AI service. You can revoke this permission in Privacy.")
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

        guard StyleImageService.hasImageProvider() || StyleImageService.shouldRequestManagedProcessingConsent else {
            errorMessage = lang == .spanish
                ? "No hay ningún procesador de imagen compatible disponible en este dispositivo."
                : "No compatible image processor is available on this device."
            return
        }

        optimizeSource = source
        if StyleImageService.shouldRequestManagedProcessingConsent {
            confirmManagedImageProcessing = true
            return
        }

        startOptimizeAfterConsentCheck()
    }

    private func startOptimizeAfterConsentCheck() {
        guard let source = optimizeSource ?? item.tryOnGarmentImage ?? item.displayImage else { return }
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
            // Remove the white background so the garment floats on any backdrop (light/dark).
            item.cutoutImage = await GarmentBackgroundRemovalService.cutout(from: optimized)
            detailFeedbackCounter += 1
            try? modelContext.save()
            // The overlay reveal uses the white-background version so it stays visible on the dark
            // overlay backdrop; the closet then displays the transparent cutout.
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

            if let costPerWear = item.costPerWear {
                HStack {
                    Label(lang == .spanish ? "Coste por puesta" : "Cost per wear", systemImage: "eurosign.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costPerWear, format: .number.precision(.fractionLength(0...2)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.timesWorn >= 5 ? .green : .primary)
                }
                if item.timesWorn == 0 {
                    Text(lang == .spanish ? "Aún sin usar — el coste por puesta baja cada vez que la llevas." : "Not worn yet — cost per wear drops every time you wear it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
