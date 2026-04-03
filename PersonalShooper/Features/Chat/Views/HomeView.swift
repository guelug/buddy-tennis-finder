import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Binding private var selectedTab: MainTabView.Tab
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    init(selectedTab: Binding<MainTabView.Tab> = .constant(.home)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sectionSpacing) {
                    // Hero greeting
                    heroSection

                    // Quick actions
                    quickActionsSection

                    // Recent conversations
                    recentConversationsSection
                }
                .padding(Theme.Spacing.screenPadding)
            }
            .background(Color.red.opacity(0.15).ignoresSafeArea())
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Settings action
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
                Text("Your palette: \(palette.seasonalType.displayName) \(palette.undertone.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set up your profile for personalized recommendations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.currentUser?.displayName ?? "there"

        if hour < 12 {
            return "Good morning, \(name)"
        } else if hour < 17 {
            return "Good afternoon, \(name)"
        } else {
            return "Good evening, \(name)"
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                NavigationLink {
                    ChatView(conversation: nil)
                } label: {
                    QuickActionCardContent(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Chat with AI",
                        subtitle: "Get style advice",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                QuickActionCard(
                    icon: "camera.fill",
                    title: "Try On",
                    subtitle: "Virtual fitting",
                    color: .purple
                ) {
                    selectedTab = .tryOn
                }

                QuickActionCard(
                    icon: "paintpalette.fill",
                    title: "My Palette",
                    subtitle: "Your colors",
                    color: .orange
                ) {
                    selectedTab = .profile
                }

                QuickActionCard(
                    icon: "arkit",
                    title: "AR View",
                    subtitle: "Preview clothes",
                    color: .green
                ) {
                    selectedTab = .ar
                }
            }
        }
    }

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Recent Conversations")
                    .font(.headline)

                Spacer()

                if !conversations.isEmpty {
                    NavigationLink("See All") {
                        ChatHistoryView()
                    }
                    .font(.subheadline)
                }
            }

            if conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start chatting with your AI stylist for personalized fashion advice")
                )
                .frame(height: 200)
            } else {
                ForEach(conversations.prefix(3)) { conversation in
                    ConversationRow(conversation: conversation)
                }
            }
        }
    }
}

struct QuickActionCardContent: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
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
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        }
        .buttonStyle(.plain)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        NavigationLink {
            ChatView(conversation: conversation)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let lastMessage = conversation.messages.last {
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

