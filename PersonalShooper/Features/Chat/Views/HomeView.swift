import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }

    private enum Tab: Int {
        case home = 0, chat = 1, closet = 2, tryOn = 3, profile = 4
    }

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    heroSection
                    dailyRecommendationSection
                    quickActionsSection
                    recentConversationsSection
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var heroSection: some View {
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
            }
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
        }
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
        .buttonStyle(.plain)
    }
}
