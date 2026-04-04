import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Environment(AppState.self) private var appState

    private var lang: Language {
        appState.preferredLanguage
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(Strings.tabHome(lang), systemImage: "house.fill")
                }
                .tag(0)

            ChatView()
                .tabItem {
                    Label(Strings.tabChat(lang), systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)

            ClosetView()
                .tabItem {
                    Label(Strings.tabCloset(lang), systemImage: "hanger")
                }
                .tag(2)

            TryOnView()
                .tabItem {
                    Label(Strings.tabTryOn(lang), systemImage: "camera.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label(Strings.tabProfile(lang), systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.orange)
    }
}
