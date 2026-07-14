import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct PersonalShooperApp: App {
    @State private var appState = AppState()
    @State private var persistence = PersistenceController()

    init() {
        Self.applyPremiumNavigationAppearance()
    }

    /// Gives every navigation title a premium look: SF Rounded, bold, with a touch of tracking — so
    /// section headers like "Mi Armario" / "Probador Virtual" read as designed, not default system.
    private static func applyPremiumNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        let largeSize: CGFloat = 34
        let inlineSize: CGFloat = 17
        let largeBase = UIFont.systemFont(ofSize: largeSize, weight: .bold)
        let inlineBase = UIFont.systemFont(ofSize: inlineSize, weight: .semibold)
        let largeFont = UIFont(descriptor: largeBase.fontDescriptor.withDesign(.rounded) ?? largeBase.fontDescriptor, size: largeSize)
        let inlineFont = UIFont(descriptor: inlineBase.fontDescriptor.withDesign(.rounded) ?? inlineBase.fontDescriptor, size: inlineSize)

        appearance.largeTitleTextAttributes = [
            .font: largeFont,
            .kern: 0.4
        ]
        appearance.titleTextAttributes = [
            .font: inlineFont,
            .kern: 0.2
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = persistence.container {
                    ContentView()
                        .modelContainer(container)
                } else {
                    PersistenceFailureView(
                        details: persistence.errorMessage,
                        onRetry: persistence.load
                    )
                }
            }
            .environment(appState)
        }
    }
}

private struct PersistenceFailureView: View {
    let details: String?
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No se puede abrir el armario", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Tus datos no se han sustituido por una sesión temporal. Cierra otras versiones de la app y vuelve a intentarlo.")
            if let details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } actions: {
            Button("Reintentar", systemImage: "arrow.clockwise", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("persistence.retry")
        }
        .padding()
    }
}

struct ContentView: View {
    @AppStorage("app_theme") private var storedTheme = AppTheme.system.rawValue
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @State private var isReady = false
    @State private var selectedTab = 0
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \User.createdAt) private var users: [User]
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \StyleProgressMission.createdAt, order: .reverse) private var progressMissions: [StyleProgressMission]

    private var preferredColorScheme: ColorScheme? {
        switch AppTheme(rawValue: storedTheme) ?? .system {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }

    var body: some View {
        Group {
            if !isReady {
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingView { name, gender in
                    completeOnboarding(with: name, gender: gender)
                }
            } else {
                MainTabView(selectedTab: $selectedTab)
            }
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.rawValue))
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-ui-reset-onboarding") {
                hasCompletedOnboarding = false
            } else if arguments.contains("-ui-skip-onboarding") {
                hasCompletedOnboarding = true
            }

            if arguments.contains("-ui-testing") {
                isReady = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isReady = true
                    }
                }
            }

            syncUserState()
            applyPendingLaunchDestinationIfNeeded()
            Task {
                await appState.refreshAccessStatus()
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
                await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
                refreshLiveActivity()
                learnStyleUsageIfDue()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                applyPendingLaunchDestinationIfNeeded()
                refreshLiveActivity()
                Task {
                    await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
                }
            }
        }
        .onChange(of: isReady) { _, ready in
            if ready {
                applyPendingLaunchDestinationIfNeeded()
            }
        }
        .onChange(of: users.count) { _, _ in
            syncUserState()
            Task {
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
            }
        }
        .onChange(of: clothingItems.count) { _, _ in
            Task {
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
            }
        }
        .onChange(of: progressMissions.count) { _, _ in
            Task {
                await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
            }
        }
    }

    private func refreshLiveActivity() {
        DailyOutfitLiveActivityController.shared.refresh(
            enabled: appState.isDailyReminderEnabled,
            hasClosetItems: !clothingItems.isEmpty,
            reminderTime: appState.dailyReminderTime,
            recommendation: appState.latestDailyRecommendation,
            language: appState.preferredLanguage
        )
    }

    private func completeOnboarding(with name: String, gender: StyleGender) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let user = appState.currentUser ?? users.first {
            if !trimmed.isEmpty {
                user.displayName = trimmed
            }
            if gender != .unspecified {
                var profile = user.personalStylingProfile
                profile.genderIdentity = gender
                user.updateStylingProfile(profile)
            }
            user.updatedAt = Date()
            try? modelContext.save()
            appState.updateUser(user)
        }

        withAnimation(.smooth) {
            hasCompletedOnboarding = true
        }
    }

    /// Counts today as a usage-day and, once the user has enough real days of use, refreshes the
    /// auto-learned style summary from their most-worn garments.
    private func learnStyleUsageIfDue() {
        StyleUsageLearning.registerUsageDay()
        guard let user = users.first else { return }
        StyleUsageLearning.runIfDue(
            user: user,
            closetItems: clothingItems,
            language: appState.preferredLanguage,
            modelContext: modelContext
        )
    }

    private func syncUserState() {
        if let user = users.first {
            if appState.currentUser?.id != user.id || appState.preferredLanguage != user.preferredLanguage {
                appState.updateUser(user)
            }
            return
        }

        let newUser = User(
            displayName: Strings.guestUser(appState.preferredLanguage),
            preferredLanguage: appState.preferredLanguage
        )
        modelContext.insert(newUser)
        do {
            try modelContext.save()
            appState.updateUser(newUser)
        } catch {
            modelContext.delete(newUser)
        }
    }

    private func applyPendingLaunchDestinationIfNeeded() {
        guard let destination = SharedStyleCompanionStore.consumePendingLaunchDestination() else {
            return
        }

        switch destination {
        case .chat:
            selectedTab = 1
        case .closet:
            selectedTab = 2
        case .tryOn:
            selectedTab = 3
        case .profile:
            selectedTab = 5
        }
    }
}

@MainActor
private final class StyleProgressReminderCoordinator {
    static let shared = StyleProgressReminderCoordinator()

    private let center = UNUserNotificationCenter.current()

    func sync(missions: [StyleProgressMission]) async {
        let activeMissions = missions.filter(\.isActive)
        let activeIdentifiers = Set(activeMissions.compactMap(\.reminderIdentifier))

        let pending = await center.pendingNotificationRequests()
        let staleIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("style-progress-") && !activeIdentifiers.contains($0) }

        for identifier in staleIdentifiers {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }

        guard !activeMissions.isEmpty else { return }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return
        case .notDetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else { return }
        @unknown default:
            return
        }

        for mission in activeMissions where mission.reminderIdentifier == nil {
            let identifier = "style-progress-\(mission.id.uuidString)"
            let content = UNMutableNotificationContent()
            content.title = "Comparativa lista"
            content.body = "Ya puedes subir la nueva foto para comparar tu evolución con \(mission.title)."
            content.sound = .default

            let interval = max(mission.dueAt.timeIntervalSinceNow, 60)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                mission.reminderIdentifier = identifier
            } catch {
                #if DEBUG
                print("StyleProgressReminderCoordinator failed to schedule reminder: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

struct SplashView: View {
    @Environment(AppState.self) private var appState

    private var title: String {
        Strings.appName(appState.preferredLanguage)
    }

    private var subtitle: String {
        appState.preferredLanguage == .spanish ? "Tu asistente de estilo con IA" : "Your AI Style Assistant"
    }

    var body: some View {
        ZStack {
            Color.orange.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "hanger")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 30)
            }
        }
    }
}
