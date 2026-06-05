import SwiftUI

/// Premium animated overlay shown while a garment photo is being turned into a clean store-style
/// thumbnail. The source garment sits center-stage with a sweeping highlight and a filling progress
/// bar; when the optimized result lands it crossfades in with a sparkle pop and a success message.
struct ImageOptimizeOverlay: View {
    let source: UIImage
    let optimized: UIImage?
    let language: Language
    let onContinue: () -> Void

    @State private var sweep: CGFloat = -1
    @State private var progress: CGFloat = 0
    @State private var revealed = false
    @State private var showDone = false
    @State private var glow = false
    @State private var doneFeedback = 0

    private let cardSize: CGFloat = 250

    private var isSpanish: Bool { language == .spanish }
    private var isComplete: Bool { optimized != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Colors.primary.opacity(glow ? 0.4 : 0.18), .clear],
                center: .center, startRadius: 10, endRadius: 320
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                header
                imageCard
                progressBar
                if showDone { doneSection.transition(.move(edge: .bottom).combined(with: .opacity)) }
                Spacer()
            }
            .padding(Theme.Spacing.xl)
        }
        .onAppear(perform: startAnimation)
        .onChange(of: isComplete) { _, done in if done { runReveal() } }
        .sensoryFeedback(.success, trigger: doneFeedback)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: showDone ? "sparkles" : "wand.and.stars")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
                .symbolEffect(.variableColor.iterative, isActive: !showDone)
            Text(showDone
                 ? (isSpanish ? "¡Imagen optimizada!" : "Image optimized!")
                 : (isSpanish ? "Optimizando tu prenda" : "Optimizing your garment"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
        }
    }

    private var imageCard: some View {
        ZStack {
            // Source garment (fades out on reveal).
            garmentImage(source)
                .opacity(revealed ? 0 : 1)

            // Optimized result (fades + pops in).
            if let optimized {
                garmentImage(optimized)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.92)
            }

            // Scanning sweep while processing.
            if !showDone {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 60)
                    .blur(radius: 8)
                    .offset(y: sweep * cardSize)
                    .mask(RoundedRectangle(cornerRadius: 26, style: .continuous).frame(width: cardSize, height: cardSize))
            }
        }
        .frame(width: cardSize, height: cardSize)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Theme.Colors.primary.opacity(0.5), radius: 24, y: 8)
        .scaleEffect(showDone ? 1.02 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showDone)
    }

    private func garmentImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardSize, height: cardSize)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.Colors.primary.opacity(0.7), Theme.Colors.primary], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, proxy.size.width * progress))
            }
        }
        .frame(height: 10)
        .frame(maxWidth: 260)
        .opacity(showDone ? 0 : 1)
    }

    private var doneSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(isSpanish ? "Miniatura tipo tienda lista: fondo blanco y prenda de frente." : "Store-style thumbnail ready: white background, garment facing front.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button(action: onContinue) {
                Text(isSpanish ? "Ver resultado" : "See result")
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

    private func startAnimation() {
        glow = true
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = 1 }
        withAnimation(.easeOut(duration: 2.8)) { progress = 0.82 }
    }

    private func runReveal() {
        withAnimation(.easeInOut(duration: 0.4)) { progress = 1.0 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { revealed = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showDone = true }
            doneFeedback += 1
        }
    }
}
