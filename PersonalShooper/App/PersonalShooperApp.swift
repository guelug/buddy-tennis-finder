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
    @State private var isReady = false
    @State private var selectedTab = 0
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if isReady {
                MainTabView(selectedTab: $selectedTab)
            } else {
                SplashView()
            }
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.rawValue))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isReady = true
                }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.orange.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "hanger")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Text("Personal Shooper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Your AI Style Assistant")
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
