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
                    outfitCalendarCard
                    dailyRecommendationSection
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

    /// Premium-only entry to the 2-week outfit planner.
    @ViewBuilder
    private var outfitCalendarCard: some View {
        if appState.isPremium || appState.hasBYOKAccess {
            Button {
                showingCalendar = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Theme.Colors.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang == .spanish ? "Calendario de outfits" : "Outfit calendar")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(lang == .spanish ? "Planea 15 días con el tiempo de tu zona" : "Plan 15 days with your local weather")
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                .contentShape(Rectangle())
            }
            .buttonStyle(.premiumPressable)
        }
    }

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)

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
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.premiumPressable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.currentUser?.displayName ?? Strings.guestUser(lang)

        if hour < 12 { return Strings.greetingMorning(lang, name: name) }
        else if hour < 17 { return Strings.greetingAfternoon(lang, name: name) }
        else { return Strings.greetingEvening(lang, name: name) }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(Strings.homeQuickActions(lang)).font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                QuickActionCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: Strings.homeStartChat(lang),
                    subtitle: Strings.tabChat(lang),
                    color: .blue
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
                            .font(.headline)
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
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            }
            .buttonStyle(.premiumPressable)
        }
    }

    @ViewBuilder
    private var dailyRecommendationSection: some View {
        if let recommendation = appState.latestDailyRecommendation {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang == .spanish ? "Recomendación del día" : "Daily recommendation")
                            .font(.headline)
                        Text(recommendation.contextLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(lang == .spanish ? "Chat" : "Chat") {
                        selectedTab = Tab.chat.rawValue
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.premiumPressable)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(recommendation.headline)
                        .font(.title3.weight(.semibold))

                    Text(recommendation.outfitFormula)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text(recommendation.colorDirection)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !recommendation.closetHighlightNames.isEmpty {
                        Text(
                            (lang == .spanish ? "Closet sugerido: " : "Suggested closet: ")
                            + recommendation.closetHighlightNames.joined(separator: ", ")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !recommendation.moodTags.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                            ForEach(recommendation.moodTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            }
        }
    }

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(Strings.homeRecentConversations(lang)).font(.headline)
                Spacer()
                Button(Strings.homeViewAll(lang)) {
                    selectedTab = Tab.chat.rawValue
                }
                .font(.subheadline)
            }

            if conversations.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(Strings.homeNoConversations(lang))
                        .font(.headline)
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
                        .font(.headline)
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
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
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
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        }
        .buttonStyle(.premiumPressable)
    }
}
