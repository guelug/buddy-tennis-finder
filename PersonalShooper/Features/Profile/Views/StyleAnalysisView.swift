import SwiftUI

/// "My Image Analysis" — surfaces everything the app inferred about the user's coloring and shape in
/// a clear, professional-consultant layout: color season, depth (ITA°), undertone, personal
/// contrast, body silhouette and face shape, each with the *why* and a styling takeaway.
struct StyleAnalysisView: View {
    @Environment(AppState.self) private var appState
    let user: User
    @State private var showingAdjust = false

    private var lang: Language { appState.preferredLanguage }
    private var isSpanish: Bool { lang == .spanish }

    private var analysis: SkinAnalysisResult? { user.skinAnalysis }
    private var palette: PersonalPalette? { user.personalPalette }
    private var profile: PersonalStylingProfile { user.personalStylingProfile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header

                if let palette {
                    card(
                        icon: "leaf.fill",
                        tint: .green,
                        title: isSpanish ? "Estación de color" : "Color season",
                        value: palette.seasonalType.displayName,
                        detail: palette.summary ?? seasonExplanation
                    )
                }

                if let analysis {
                    card(
                        icon: "circle.lefthalf.filled",
                        tint: .orange,
                        title: isSpanish ? "Profundidad de piel" : "Skin depth",
                        value: depthValue(analysis),
                        detail: isSpanish
                            ? "Calculada con el Ángulo Tipológico Individual (ITA°), el estándar dermatológico de profundidad de piel."
                            : "Computed with the Individual Typology Angle (ITA°), the dermatological standard for skin depth."
                    )

                    card(
                        icon: "thermometer.medium",
                        tint: .pink,
                        title: isSpanish ? "Subtono" : "Undertone",
                        value: undertoneValue(analysis),
                        detail: isSpanish
                            ? "Derivado del balance amarillo–rojo (b*/a*) en el espacio de color CIELAB."
                            : "Derived from the yellow–red balance (b*/a*) in the CIELAB color space."
                    )
                }

                if let contrast = profile.contrastLevel {
                    card(
                        icon: "circle.righthalf.filled",
                        tint: .blue,
                        title: isSpanish ? "Contraste personal" : "Personal contrast",
                        value: contrast.displayName(lang),
                        detail: contrast.stylingGoal(lang)
                    )
                }

                if let shape = profile.bodyShape {
                    card(
                        icon: "figure.stand",
                        tint: .teal,
                        title: isSpanish ? "Silueta" : "Silhouette",
                        value: shape.displayName(lang),
                        detail: shape.stylingGoal(lang)
                    )
                }

                if let face = profile.faceShape {
                    card(
                        icon: "face.smiling",
                        tint: .indigo,
                        title: isSpanish ? "Forma de rostro" : "Face shape",
                        value: face.displayName(lang),
                        detail: face.stylingGoal(lang)
                    )
                }

                disclaimer
            }
            .padding()
        }
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle(isSpanish ? "Mi análisis" : "My Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSpanish ? "Ajustar" : "Adjust") { showingAdjust = true }
            }
        }
        .sheet(isPresented: $showingAdjust) {
            AnalysisAdjustView(user: user)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isSpanish ? "Tu análisis de imagen" : "Your image analysis")
                .font(.largeTitle.weight(.bold))
            Text(isSpanish
                 ? "Lo que he deducido de tus fotos para asesorarte como un profesional de la imagen."
                 : "What I inferred from your photos to advise you like a professional image consultant.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(icon: String, tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var disclaimer: some View {
        Text(isSpanish
             ? "Estos resultados son una estimación a partir de tus fotos y medidas; afínalos con tu propia experiencia."
             : "These results are an estimate from your photos and measurements; refine them with your own experience.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Value formatting

    private var seasonExplanation: String {
        isSpanish
            ? "Combinación de profundidad, subtono y claridad de tu piel."
            : "A blend of your skin's depth, undertone and clarity."
    }

    private func depthValue(_ analysis: SkinAnalysisResult) -> String {
        let category = analysis.skinToneCategory.displayName
        if let ita = analysis.ita {
            return "\(category) · ITA \(Int(ita.rounded()))°"
        }
        return category
    }

    private func undertoneValue(_ analysis: SkinAnalysisResult) -> String {
        let name = analysis.undertone.displayName
        let confidence = Int((analysis.undertoneConfidence * 100).rounded())
        return isSpanish ? "\(name) · \(confidence)% confianza" : "\(name) · \(confidence)% confidence"
    }
}
