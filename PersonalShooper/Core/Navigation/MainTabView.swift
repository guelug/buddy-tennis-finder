import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case chat = "Chat"
        case closet = "Closet"
        case tryOn = "Try On"
        case ar = "AR"
        case profile = "Profile"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            // Chat Tab
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(Tab.chat)
            
            // Closet Tab
            NavigationStack {
                ClosetView()
            }
            .tabItem {
                Label("Closet", systemImage: "hanger")
            }
            .tag(Tab.closet)
            
            // Try On Tab
            NavigationStack {
                TryOnView()
            }
            .tabItem {
                Label("Try On", systemImage: "camera.fill")
            }
            .tag(Tab.tryOn)
            
            // AR Tab
            NavigationStack {
                ARWardrobeView()
            }
            .tabItem {
                Label("AR", systemImage: "arkit")
            }
            .tag(Tab.ar)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(Tab.profile)
        }
        .accentColor(Theme.Colors.primary)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environment(AppState())
}
