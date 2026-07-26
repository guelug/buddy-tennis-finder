import SwiftUI
import SwiftData

/// Premium wardrobe lobby: closet stats + a vintage armoire. Tapping the armoire plays a
/// door-opening animation (with sound + haptics) and then pushes the real wardrobe grid
/// (ClosetContentView).
struct ClosetLobbyView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]

    @State private var doorsOpen = false
    @State private var showWardrobe = false
    @State private var showingDailyLook = false
    @State private var showingOutfits = false
    @State private var showingOutfitCalendar = false
    @AppStorage(ArmoireSoundPlayer.mutedKey) private var armoireSoundMuted = false

    private var lang: Language {
        appState.preferredLanguage
    }

    private var paletteColorNames: Set<String> {
        PaletteMatching.colorNames(for: appState.currentUser?.personalPalette)
    }

    // MARK: - Stats

    private var totalCount: Int { items.count }

    private var averageUsage: Int {
        items.isEmpty ? 0 : Int((items.map(\.hiddenUsageScore).reduce(0, +) / Double(items.count)).rounded())
    }

    private var rotationCount: Int {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return items.filter { $0.createdAt < twoWeeksAgo && ($0.timesWorn == 0 || $0.hiddenUsagePercentage < 25) }.count
    }

    private var onPaletteCount: Int {
        let names = paletteColorNames
        guard !names.isEmpty else { return 0 }
        return items.filter { PaletteMatching.isOnPalette($0, names: names) }.count
    }

    private var starItem: ClothingItem? {
        items.filter { $0.timesWorn > 0 }.max(by: { $0.timesWorn < $1.timesWorn })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    header
                    armoireCard
                    statsGrid
                    starItemRow
                    paletteRow
                    shortcutsRow
                }
                .padding(Theme.Spacing.screenPadding)
                .padding(.top, Theme.Spacing.xs)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showWardrobe) {
                ClosetContentView()
            }
            .sheet(isPresented: $showingDailyLook) { DailyLookView() }
            .sheet(isPresented: $showingOutfits) { OutfitsView() }
            .sheet(isPresented: $showingOutfitCalendar) { OutfitCalendarView() }
            .onChange(of: showWardrobe) { _, isShowing in
                // Close the doors behind the user when they come back to the lobby.
                if !isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.smooth(duration: 0.5)) { doorsOpen = false }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(lang == .spanish ? "El atelier" : "The atelier")
                    .font(.fashionEyebrow)
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.primary)

                Text(lang == .spanish ? "Tu Armario" : "Your Wardrobe")
                    .font(.fashionDisplay(34))

                Text(lang == .spanish
                     ? "Todo lo que tienes, cuánto lo usas y qué le sienta mejor a tu paleta."
                     : "Everything you own, how much you wear it, and what suits your palette best.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Armoire

    private var armoireCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: Theme.Spacing.xs) {
                ArmoireHeroView(open: doorsOpen, accent: Theme.Colors.primary)
                    .frame(width: 232, height: 310)
                    .padding(.top, Theme.Spacing.xs)

                HStack(spacing: 6) {
                    Image(systemName: doorsOpen ? "door.left.hand.open" : "hand.tap")
                        .font(.caption.weight(.semibold))
                    Text(doorsOpen
                         ? (lang == .spanish ? "Abriendo…" : "Opening…")
                         : (lang == .spanish ? "Toca el armario para abrirlo" : "Tap the wardrobe to open it"))
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: openWardrobe)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(lang == .spanish ? "Abrir mi armario" : "Open my wardrobe")
            .accessibilityValue(doorsOpen ? "open" : "closed")
            .accessibilityIdentifier("closet.lobby.armoire")

            Button {
                let newValue = !armoireSoundMuted
                armoireSoundMuted = newValue
                ArmoireSoundPlayer.setMuted(newValue, previewsWhenEnabled: true)
            } label: {
                Image(systemName: armoireSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .fashionGlassCircle()
                    .contentShape(Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(Theme.Spacing.xs)
            .zIndex(2)
            .accessibilityLabel(armoireSoundMuted
                                ? (lang == .spanish ? "Activar sonido del armario" : "Unmute wardrobe sound")
                                : (lang == .spanish ? "Silenciar sonido del armario" : "Mute wardrobe sound"))
            .accessibilityIdentifier("closet.lobby.soundToggle")
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: doorsOpen)
        .sensoryFeedback(trigger: showWardrobe) { _, new in new ? .success : nil }
        .sensoryFeedback(.selection, trigger: armoireSoundMuted)
    }

    private func openWardrobe() {
        guard !doorsOpen else { return }
        ArmoireSoundPlayer.playOpen()
        // Slow, ceremonial opening: glow fades in first, doors follow, then we enter.
        withAnimation(.easeInOut(duration: 1.4)) { doorsOpen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showWardrobe = true
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        HStack(spacing: Theme.Spacing.sm) {
            LobbyStatTile(
                value: "\(totalCount)",
                label: lang == .spanish ? "Prendas" : "Garments",
                icon: "hanger"
            )
            LobbyStatTile(
                value: "\(averageUsage)%",
                label: lang == .spanish ? "Uso medio" : "Avg use",
                icon: "chart.pie.fill"
            )
            LobbyStatTile(
                value: "\(rotationCount)",
                label: lang == .spanish ? "Por rotar" : "To rotate",
                icon: "arrow.triangle.2.circlepath"
            )
        }
    }

    @ViewBuilder
    private var starItemRow: some View {
        if let star = starItem {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang == .spanish ? "Tu prenda estrella" : "Your star garment")
                        .font(.fashionHeadline)
                        .foregroundStyle(.primary)
                    Text(lang == .spanish
                         ? "\(star.name) · \(star.timesWorn) usos"
                         : "\(star.name) · worn \(star.timesWorn) times")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .fashionGlassCard()
        }
    }

    @ViewBuilder
    private var paletteRow: some View {
        if let palette = appState.currentUser?.personalPalette, !paletteColorNames.isEmpty {
            HStack(spacing: Theme.Spacing.md) {
                PaletteSwatchStrip(colors: palette.recommendedColors, size: 24)

                Spacer(minLength: Theme.Spacing.xs)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(onPaletteCount)/\(totalCount)")
                        .font(.fashionStat(18))
                        .foregroundStyle(.primary)
                    Text(lang == .spanish ? "prendas en tu paleta" : "garments on palette")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.md)
            .fashionGlassCard()
        }
    }

    // MARK: - Shortcuts

    private var shortcutsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            LobbyShortcutChip(
                icon: "sparkles",
                title: lang == .spanish ? "Look del día" : "Daily look"
            ) { showingDailyLook = true }

            LobbyShortcutChip(
                icon: "square.stack.3d.up",
                title: lang == .spanish ? "Mis looks" : "My looks"
            ) { showingOutfits = true }

            LobbyShortcutChip(
                icon: "calendar",
                title: lang == .spanish ? "Plan semanal" : "Weekly plan"
            ) { showingOutfitCalendar = true }
        }
    }
}

// MARK: - Lobby stat tile

private struct LobbyStatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.Colors.primary)
            Text(value)
                .font(.fashionStat())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .fashionGlassCard(cornerRadius: Theme.CornerRadius.medium)
    }
}

// MARK: - Lobby shortcut chip

private struct LobbyShortcutChip: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primary)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .fashionGlassCard(cornerRadius: Theme.CornerRadius.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.premiumPressable)
    }
}

// MARK: - Armoire designs
// Each design is a closed/open image pair in the asset catalog. As the app grows we can
// add more designs (boutique, noir, minimal...) and even let the user pick one.

enum ArmoireDesign: String, CaseIterable, Identifiable {
    case atelier

    var id: String { rawValue }
    var closedImageName: String { "armoire_closed" }
    var openImageName: String { "armoire_open" }
}

/// The hero armoire: photoreal closed/open pair with a crossfade, warm halo, scale
/// breathing and drifting sparkles when the doors open.
struct ArmoireHeroView: View {
    let open: Bool
    let accent: Color
    var design: ArmoireDesign = .atelier

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Soft floor shadow grounding the piece
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.6 : 0.18))
                .frame(width: 185, height: 26)
                .blur(radius: 10)
                .offset(y: 138)

            Image(design.closedImageName)
                .resizable()
                .scaledToFit()
                .opacity(open ? 0 : 1)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.2), radius: 14, y: 8)

            Image(design.openImageName)
                .resizable()
                .scaledToFit()
                .opacity(open ? 1 : 0)
                .scaleEffect(open ? 1 : 1.03)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.2), radius: 14, y: 8)

            if open {
                sparkles
                    .transition(.opacity.animation(.easeIn(duration: 0.6).delay(0.5)))
            }
        }
        .scaleEffect(open ? 1.02 : 1)
        .animation(.easeInOut(duration: 1.4), value: open)
    }

    private var sparkles: some View {
        ZStack {
            sparkle(at: CGPoint(x: -64, y: -96), size: 14, delay: 0.0)
            sparkle(at: CGPoint(x: 58, y: -120), size: 11, delay: 0.35)
            sparkle(at: CGPoint(x: 70, y: -50), size: 9, delay: 0.7)
        }
    }

    private func sparkle(at position: CGPoint, size: CGFloat, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: accent.opacity(0.8), radius: 6)
            .offset(x: position.x, y: position.y)
            .phaseAnimator([false, true]) { content, phase in
                content
                    .opacity(phase ? 1 : 0.15)
                    .offset(x: position.x, y: position.y + (phase ? -14 : 0))
                    .scaleEffect(phase ? 1 : 0.7)
            } animation: { _ in
                    .easeInOut(duration: 1.1).delay(delay)
            }
    }
}

#Preview {
    ClosetLobbyView()
        .environment(AppState())
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
