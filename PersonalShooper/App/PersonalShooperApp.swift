import SwiftUI
import SwiftData

@main
struct PersonalShooperApp: App {
    @State private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Conversation.self,
            Message.self,
            ClothingItem.self,
            TryOnResult.self
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
    @Query(sort: \User.createdAt) private var users: [User]
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]

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
            Task {
                await appState.refreshPremiumStatus()
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
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
