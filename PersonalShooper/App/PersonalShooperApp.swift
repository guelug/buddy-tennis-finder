import SwiftUI
import SwiftData
import UserNotifications

@main
struct PersonalShooperApp: App {
    @State private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Conversation.self,
            Message.self,
            ClothingItem.self,
            TryOnResult.self,
            StyleProgressMission.self
        ])
        
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
        }
    }
}

struct ContentView: View {
    @AppStorage("app_theme") private var storedTheme = AppTheme.system.rawValue
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
            if isReady {
                MainTabView(selectedTab: $selectedTab)
            } else {
                SplashView()
            }
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.rawValue))
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isReady = true
                }
            }

            syncUserState()
            applyPendingLaunchDestinationIfNeeded()
            Task {
                await appState.refreshPremiumStatus()
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
                await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                applyPendingLaunchDestinationIfNeeded()
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
