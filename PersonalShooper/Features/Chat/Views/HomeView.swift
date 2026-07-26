import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: Int
    @State private var showingAR = false
    @State private var showingCalendar = false
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query private var clothingItems: [ClothingItem]

    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }

    private enum Tab: Int {
        case home = 0, chat = 1, closet = 2, tryOn = 3, ar = 4, profile = 5
    }

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    heroSection
                    closetNudgeSection
                    dailyRecommendationSection
                    statsRow
                    paletteStripSection
                    outfitCalendarCard
                    quickActionsSection
                    recentConversationsSection
                }
                .padding(Theme.Spacing.screenPadding)
                .padding(.top, Theme.Spacing.xs)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingAR) {
                ARWardrobeView()
            }
            .sheet(isPresented: $showingCalendar) {
                OutfitCalendarView()
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(dateEyebrow)
                    .font(.fashionEyebrow)
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.primary)

                Text(greeting)
                    .font(.fashionDisplay(34))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if let user = appState.currentUser, let palette = user.personalPalette {
                    Text("\(Strings.profilePaletteTitle(lang)): \(palette.seasonalType.displayName) \(palette.undertone.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Strings.homeSetupProfile(lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .fashionGlassCircle()
            }
            .buttonStyle(.premiumPressable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateEyebrow: String {
        let locale = Locale(identifier: lang.rawValue)
        return Date.now.formatted(
            .dateTime.weekday(.wide).day(.defaultDigits).month(.wide).locale(locale)
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.currentUser?.displayName ?? Strings.guestUser(lang)

        if hour < 12 { return Strings.greetingMorning(lang, name: name) }
        else if hour < 17 { return Strings.greetingAfternoon(lang, name: name) }
        else { return Strings.greetingEvening(lang, name: name) }
    }

    // MARK: - Stats at a glance

    private var statsRow: some View {
        let paletteCount = appState.currentUser?.personalPalette?.recommendedColors.count ?? 0

        return HStack(spacing: Theme.Spacing.sm) {
            HomeStatTile(
                value: "\(clothingItems.count)",
                label: lang == .spanish ? "Prendas" : "Garments",
                icon: "hanger"
            ) {
                selectedTab = Tab.closet.rawValue
            }
            HomeStatTile(
                value: "\(conversations.count)",
                label: lang == .spanish ? "Charlas" : "Chats",
                icon: "bubble.left.and.bubble.right.fill"
            ) {
                selectedTab = Tab.chat.rawValue
            }
            HomeStatTile(
                value: paletteCount > 0 ? "\(paletteCount)" : "—",
                label: lang == .spanish ? "Colores" : "Colors",
                icon: "paintpalette.fill"
            ) {
                selectedTab = Tab.profile.rawValue
            }
        }
    }

    // MARK: - Palette strip

    @ViewBuilder
    private var paletteStripSection: some View {
        if let palette = appState.currentUser?.personalPalette,
           !palette.recommendedColors.isEmpty {
            Button {
                selectedTab = Tab.profile.rawValue
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    PaletteSwatchStrip(colors: palette.recommendedColors, size: 26)

                    Spacer(minLength: Theme.Spacing.xs)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(palette.seasonalType.displayName)
                            .font(.fashionHeadline)
                            .foregroundStyle(.primary)
                        Text(lang == .spanish ? "Tu temporada" : "Your season")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.md)
                .fashionGlassCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.premiumPressable)
        }
    }

    // MARK: - Weekly planner

    private var outfitCalendarCard: some View {
        Button {
            showingCalendar = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.Colors.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang == .spanish ? "Tus 5 looks de oficina" : "Your 5 office looks")
                        .font(.fashionHeadline)
                        .foregroundStyle(.primary)
                    Text(lang == .spanish
                         ? "Plan semanal automático o manual, gratis"
                         : "Free automatic or manual weekly plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.md)
            .fashionGlassCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.premiumPressable)
        .accessibilityIdentifier("home.weeklyPlanner")
    }

    // MARK: - Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(Strings.homeQuickActions(lang))
                .font(.fashionTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                QuickActionCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: Strings.homeStartChat(lang),
                    subtitle: Strings.tabChat(lang),
                    color: Theme.Colors.primary
                ) {
                    selectedTab = Tab.chat.rawValue
                }
                QuickActionCard(
                    icon: "camera.fill",
                    title: Strings.homeTryOn(lang),
                    subtitle: Strings.tabTryOn(lang),
                    color: .purple
                ) {
                    selectedTab = Tab.tryOn.rawValue
                }
                QuickActionCard(
                    icon: "paintpalette.fill",
                    title: Strings.homeViewPalette(lang),
                    subtitle: Strings.profilePaletteTitle(lang),
                    color: .orange
                ) {
                    selectedTab = Tab.profile.rawValue
                }
                QuickActionCard(
                    icon: "cabinet.fill",
                    title: Strings.tabCloset(lang),
                    subtitle: Strings.tabCloset(lang),
                    color: .green
                ) {
                    selectedTab = Tab.closet.rawValue
                }
                QuickActionCard(
                    icon: "arkit",
                    title: Strings.tabAR(lang),
                    subtitle: Strings.tabAR(lang),
                    color: .teal
                ) {
                    showingAR = true
                }
            }
        }
    }

    // MARK: - Closet nudge

    @ViewBuilder
    private var closetNudgeSection: some View {
        if clothingItems.isEmpty {
            Button {
                selectedTab = Tab.closet.rawValue
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "hanger")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.primary)
                        .frame(width: 46, height: 46)
                        .background(Theme.Colors.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang == .spanish ? "Empieza por tu armario" : "Start with your closet")
                            .font(.fashionHeadline)
                            .foregroundStyle(.primary)
                        Text(lang == .spanish
                             ? "Añade tus prendas para recibir recomendaciones, probártelas y activar el recordatorio diario."
                             : "Add your garments to get recommendations, try them on, and unlock the daily reminder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.primary)
                }
                .padding(Theme.Spacing.md)
                .fashionGlassCard()
            }
            .buttonStyle(.premiumPressable)
        }
    }

    // MARK: - Daily recommendation (editorial feature card)

    @ViewBuilder
    private var dailyRecommendationSection: some View {
        if let recommendation = appState.latestDailyRecommendation {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(lang == .spanish ? "Recomendación del día" : "Daily recommendation")
                        .font(.fashionTitle)

                    Spacer()

                    Button(lang == .spanish ? "Chat" : "Chat") {
                        selectedTab = Tab.chat.rawValue
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .buttonStyle(.premiumPressable)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(recommendation.contextLine)
                        .font(.fashionEyebrow)
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(ThemeManager.shared.accent.highlightColor)

                    Text(recommendation.headline)
                        .font(.fashionDisplay(24, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recommendation.outfitFormula)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recommendation.colorDirection)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    if !recommendation.closetHighlightNames.isEmpty {
                        Text(
                            (lang == .spanish ? "Closet sugerido: " : "Suggested closet: ")
                            + recommendation.closetHighlightNames.joined(separator: ", ")
                        )
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if !recommendation.moodTags.isEmpty {
                        FlexWrapTags(tags: recommendation.moodTags)
                    }
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.09, blue: 0.12),
                            Color(red: 0.20, green: 0.16, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.08))
                        .padding(Theme.Spacing.md)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl))
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
            }
        }
    }

    // MARK: - Recent conversations

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(Strings.homeRecentConversations(lang))
                    .font(.fashionTitle)
                Spacer()
                Button(Strings.homeViewAll(lang)) {
                    selectedTab = Tab.chat.rawValue
                }
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.primary)
            }

            if conversations.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(Strings.homeNoConversations(lang))
                        .font(.fashionHeadline)
                    Text(Strings.homeStartChatting(lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(conversations.prefix(3)) { conversation in
                        RecentConversationCard(conversation: conversation, language: lang) {
                            selectedTab = Tab.chat.rawValue
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Home stat tile

private struct HomeStatTile: View {
    let value: String
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.premiumPressable)
    }
}

// MARK: - Wrapping mood tags

private struct FlexWrapTags: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Recent conversation row

private struct RecentConversationCard: View {
    let conversation: Conversation
    let language: Language
    let action: () -> Void

    private var previewMessage: Message? {
        conversation.messages.max { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.fashionHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(conversation.updatedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Theme.Spacing.md)
            .fashionGlassCard()
        }
        .buttonStyle(.premiumPressable)
    }

    private var previewText: String {
        guard let previewMessage else {
            return language == .spanish ? "Conversación sin mensajes todavía" : "Conversation has no messages yet"
        }

        return previewMessage.content
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.fashionHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .fashionGlassCard()
        }
        .buttonStyle(.premiumPressable)
    }
}
