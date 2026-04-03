import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .home

    enum Tab: Int, CaseIterable {
        case home
        case tryOn
        case ar
        case closet
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .tryOn: return "Try On"
            case .ar: return "AR"
            case .closet: return "Closet"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .tryOn: return "tshirt.fill"
            case .ar: return "arkit"
            case .closet: return "cabinet.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            TryOnView()
                .tabItem {
                    Label(Tab.tryOn.title, systemImage: Tab.tryOn.icon)
                }
                .tag(Tab.tryOn)

            ARWardrobeView()
                .tabItem {
                    Label(Tab.ar.title, systemImage: Tab.ar.icon)
                }
                .tag(Tab.ar)

            ClosetView()
                .tabItem {
                    Label(Tab.closet.title, systemImage: Tab.closet.icon)
                }
                .tag(Tab.closet)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(Theme.Colors.primary)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
