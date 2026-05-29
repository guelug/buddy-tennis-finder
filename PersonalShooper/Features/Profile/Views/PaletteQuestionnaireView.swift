import SwiftUI

/// Quick questionnaire shown before generating the color palette. Lets the user tell us which
/// colors they already know flatter them (and which don't), so the palette respects real experience
/// instead of relying only on an automatic skin read.
struct PaletteQuestionnaireView: View {
    @Environment(\.dismiss) private var dismiss
    let language: Language
    let onContinue: (PalettePreferences) -> Void

    @State private var lovedIDs: Set<String> = []
    @State private var dislikedIDs: Set<String> = []
    @State private var notes: String = ""

    init(language: Language, initial: PalettePreferences = PalettePreferences(), onContinue: @escaping (PalettePreferences) -> Void) {
        self.language = language
        self.onContinue = onContinue
        _lovedIDs = State(initialValue: Set(initial.lovedColorIDs))
        _dislikedIDs = State(initialValue: Set(initial.dislikedColorIDs))
        _notes = State(initialValue: initial.notes)
    }

    private var isSpanish: Bool { language == .spanish }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header

                    colorSection(
                        title: isSpanish ? "Colores con los que luces bien" : "Colors you look great in",
                        subtitle: isSpanish
                            ? "Los que te dicen que te favorecen o con los que te sientes radiante."
                            : "Ones people compliment, or that make you feel radiant.",
                        selection: $lovedIDs,
                        other: $dislikedIDs
                    )

                    colorSection(
                        title: isSpanish ? "Colores que no te convencen" : "Colors that don't work for you",
                        subtitle: isSpanish
                            ? "Los que sientes que te apagan o no te gustan."
                            : "Ones that wash you out or you simply dislike.",
                        selection: $dislikedIDs,
                        other: $lovedIDs
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(isSpanish ? "Algo más (opcional)" : "Anything else (optional)")
                            .font(.headline)
                        TextField(
                            isSpanish ? "Ej. me encanta el verde botella para eventos" : "e.g. I love bottle green for events",
                            text: $notes,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        .padding(Theme.Spacing.md)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(isSpanish ? "Afina tu paleta" : "Refine your palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Omitir" : "Skip") {
                        onContinue(PalettePreferences())
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSpanish ? "Generar" : "Generate") {
                        onContinue(currentPreferences)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var currentPreferences: PalettePreferences {
        PalettePreferences(
            lovedColorIDs: Array(lovedIDs),
            dislikedColorIDs: Array(dislikedIDs),
            notes: notes
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(isSpanish ? "Cuéntame qué te sienta bien" : "Tell me what suits you")
                .font(.title2.weight(.bold))
            Text(isSpanish
                 ? "Combinaré tu experiencia con el análisis de tus fotos para una paleta más precisa."
                 : "I'll blend your experience with the photo analysis for a more accurate palette.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorSection(
        title: String,
        subtitle: String,
        selection: Binding<Set<String>>,
        other: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                ForEach(PaletteColorCatalog.all) { choice in
                    let isSelected = selection.wrappedValue.contains(choice.id)
                    Button {
                        toggle(choice.id, in: selection, removingFrom: other)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(choice.codableColor?.color ?? .gray)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                            Text(choice.name(in: language))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Theme.Colors.primary.opacity(0.12) : Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(isSelected ? Theme.Colors.primary : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private func toggle(_ id: String, in selection: Binding<Set<String>>, removingFrom other: Binding<Set<String>>) {
        if selection.wrappedValue.contains(id) {
            selection.wrappedValue.remove(id)
        } else {
            selection.wrappedValue.insert(id)
            other.wrappedValue.remove(id) // a color can't be both loved and disliked
        }
    }
}
