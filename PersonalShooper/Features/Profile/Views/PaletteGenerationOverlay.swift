import SwiftUI

/// Premium, animated reveal shown while the personal color palette is being generated.
///
/// Flow:
/// 1. The user's close-up selfie sits center-stage with a soft scanning line sweeping over it.
/// 2. A color bar underneath fills as the analysis runs, turning into the actual palette gradient
///    once it's ready.
/// 3. The palette swatches cascade in one by one, finishing with a celebratory
///    "Tu paleta de colores fue generada" message and a continue button.
///
/// `palette` is `nil` while analysis is in flight; setting it (the parent does this when the work
/// completes) triggers the completion choreography.
struct PaletteGenerationOverlay: View {
    let selfie: UIImage
    let palette: PersonalPalette?
    let language: Language
    let onContinue: () -> Void

    @State private var scanOffset: CGFloat = -1
    @State private var barProgress: CGFloat = 0
    @State private var revealedCount: Int = 0
    @State private var showDoneMessage = false
    @State private var glow = false
    @State private var doneFeedback = 0

    private let selfieSize: CGFloat = 230

    private var isComplete: Bool { palette != nil }
    private var isSpanish: Bool { language == .spanish }

    private var revealColors: [CodableColor] {
        guard let palette else { return [] }
        var colors = palette.recommendedColors
        colors += palette.neutralColors ?? []
        colors += palette.statementColors ?? []
        return Array(colors.prefix(10))
    }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                header
                selfieCard
                colorBar
                swatches

                if showDoneMessage {
                    doneSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(Theme.Spacing.xl)
        }
        .onAppear(perform: startLoadingAnimation)
        .onChange(of: isComplete) { _, complete in
            if complete { runCompletionChoreography() }
        }
        .sensoryFeedback(.success, trigger: doneFeedback)
    }

    // MARK: - Sections

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            // Soft palette-tinted glow behind the card once colors are known.
            if let first = revealColors.first?.color {
                RadialGradient(
                    colors: [first.opacity(glow ? 0.45 : 0.2), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 320
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: isComplete ? "sparkles" : "wand.and.stars")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
                .symbolEffect(.variableColor.iterative, isActive: !isComplete)

            Text(isComplete
                 ? (isSpanish ? "Analizando tu color…" : "Reading your color…")
                 : (isSpanish ? "Creando tu paleta" : "Creating your palette"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
        }
    }

    private var selfieCard: some View {
        Image(uiImage: selfie)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: selfieSize, height: selfieSize)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                if !showDoneMessage {
                    // Scanning sweep.
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Theme.Colors.primary.opacity(0.55), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 60)
                        .blur(radius: 6)
                        .offset(y: scanOffset * selfieSize)
                        .mask(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: (revealColors.first?.color ?? Theme.Colors.primary).opacity(0.5), radius: 24, y: 8)
            .scaleEffect(showDoneMessage ? 1.02 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showDoneMessage)
    }

    private var colorBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))

                Capsule()
                    .fill(barFill)
                    .frame(width: max(0, proxy.size.width * barProgress))
            }
        }
        .frame(height: 12)
        .frame(maxWidth: 280)
    }

    private var barFill: LinearGradient {
        if revealColors.count >= 2 {
            return LinearGradient(colors: revealColors.map(\.color), startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(
            colors: [Theme.Colors.primary.opacity(0.6), Theme.Colors.primary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var swatches: some View {
        HStack(spacing: 8) {
            ForEach(Array(revealColors.enumerated()), id: \.element.id) { index, color in
                Circle()
                    .fill(color.color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .scaleEffect(index < revealedCount ? 1 : 0.1)
                    .opacity(index < revealedCount ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: revealedCount)
            }
        }
        .frame(height: 34)
    }

    private var doneSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(isSpanish ? "Tu paleta de colores fue generada" : "Your color palette is ready")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let summary = palette?.summary, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: onContinue) {
                Text(isSpanish ? "Ver mi paleta" : "See my palette")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .buttonStyle(.premiumPressable)
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - Choreography

    private func startLoadingAnimation() {
        glow = true
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            scanOffset = 1
        }
        // Creep the bar toward ~80% while we wait for the analysis to land.
        withAnimation(.easeOut(duration: 2.6)) {
            barProgress = 0.8
        }
    }

    private func runCompletionChoreography() {
        // Fill the bar the rest of the way, now tinted with the real palette.
        withAnimation(.easeInOut(duration: 0.5)) {
            barProgress = 1.0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            // Cascade the swatches in.
            for index in 0..<revealColors.count {
                revealedCount = index + 1
                try? await Task.sleep(for: .milliseconds(90))
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDoneMessage = true
            }
            doneFeedback += 1
        }
    }
}
