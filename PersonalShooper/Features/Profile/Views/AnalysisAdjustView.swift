import SwiftUI
import SwiftData

/// Lets the user manually correct the auto-detected analysis (silhouette, face shape, contrast and
/// color season). The 2D-photo estimates are approximations, so giving the user the final say is the
/// honest, robust design. Changing the season rebuilds the wardrobe palette for that season.
struct AnalysisAdjustView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let user: User

    @State private var bodyShape: BodyShape?
    @State private var faceShape: FaceShape?
    @State private var contrast: ContrastLevel?
    @State private var season: SeasonalType?

    private var lang: Language { appState.preferredLanguage }
    private var isSpanish: Bool { lang == .spanish }

    init(user: User) {
        self.user = user
        let profile = user.personalStylingProfile
        _bodyShape = State(initialValue: profile.bodyShape)
        _faceShape = State(initialValue: profile.faceShape)
        _contrast = State(initialValue: profile.contrastLevel)
        _season = State(initialValue: user.personalPalette?.seasonalType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(isSpanish
                         ? "El análisis automático es una estimación a partir de tus fotos. Ajústalo si no encaja contigo."
                         : "The automatic analysis is an estimate from your photos. Adjust it if it doesn't fit you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isSpanish ? "Estación de color" : "Color season") {
                    Picker(isSpanish ? "Estación" : "Season", selection: $season) {
                        Text(isSpanish ? "Sin definir" : "Unset").tag(SeasonalType?.none)
                        ForEach(SeasonalType.allCases, id: \.self) { s in
                            Text(s.displayName).tag(SeasonalType?.some(s))
                        }
                    }
                    if season != user.personalPalette?.seasonalType {
                        Text(isSpanish ? "Se regenerará tu paleta para esta estación." : "Your palette will be rebuilt for this season.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section(isSpanish ? "Silueta" : "Silhouette") {
                    Picker(isSpanish ? "Silueta" : "Silhouette", selection: $bodyShape) {
                        Text(isSpanish ? "Sin definir" : "Unset").tag(BodyShape?.none)
                        ForEach(BodyShape.allCases, id: \.self) { s in
                            Text(s.displayName(lang)).tag(BodyShape?.some(s))
                        }
                    }
                }

                Section(isSpanish ? "Forma de rostro" : "Face shape") {
                    Picker(isSpanish ? "Rostro" : "Face", selection: $faceShape) {
                        Text(isSpanish ? "Sin definir" : "Unset").tag(FaceShape?.none)
                        ForEach(FaceShape.allCases, id: \.self) { s in
                            Text(s.displayName(lang)).tag(FaceShape?.some(s))
                        }
                    }
                }

                Section(isSpanish ? "Contraste personal" : "Personal contrast") {
                    Picker(isSpanish ? "Contraste" : "Contrast", selection: $contrast) {
                        Text(isSpanish ? "Sin definir" : "Unset").tag(ContrastLevel?.none)
                        ForEach(ContrastLevel.allCases, id: \.self) { c in
                            Text(c.displayName(lang)).tag(ContrastLevel?.some(c))
                        }
                    }
                }
            }
            .navigationTitle(isSpanish ? "Ajustar análisis" : "Adjust analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cancelar" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Guardar" : "Save") { save() }
                }
            }
        }
    }

    private func save() {
        var profile = user.personalStylingProfile
        profile.bodyShape = bodyShape
        profile.faceShape = faceShape
        profile.contrastLevel = contrast
        user.updateStylingProfile(profile)

        // Rebuild the palette if the user changed the season.
        if let season, season != user.personalPalette?.seasonalType {
            let undertone = user.personalPalette?.undertone ?? user.skinAnalysis?.undertone ?? .neutral
            user.personalPalette = Self.palette(for: season, undertone: undertone, isSpanish: isSpanish)
        }

        user.updatedAt = Date()
        try? modelContext.save()
        appState.updateUser(user)
        dismiss()
    }

    /// Builds a professional wardrobe palette for a season from the curated 12-tone library.
    private static func palette(for season: SeasonalType, undertone: Undertone, isSpanish: Bool) -> PersonalPalette {
        let recipe = NamedPaletteLibrary.recipe(for: season)
        func swatches(_ entries: [(String, String, String)]) -> [CodableColor] {
            entries.compactMap { CodableColor(hex: $0.0, name: isSpanish ? $0.2 : $0.1) }
        }
        return PersonalPalette(
            seasonalType: season,
            undertone: undertone,
            recommendedColors: swatches(recipe.best),
            summary: isSpanish ? recipe.summaryEs : recipe.summaryEn,
            neutralColors: swatches(recipe.neutrals),
            statementColors: swatches(recipe.statements),
            colorsToAvoid: swatches(recipe.avoid)
        )
    }
}
