import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        Group { if session.user == nil { LoginView() } else { MainTabView() } }
            .tint(MPTheme.accent)
            .alert("MatchPoint Tennis", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
                Button("Aceptar") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Inicio", systemImage: "house.fill") }
            NavigationStack { PlayersView() }.tabItem { Label("Jugadores", systemImage: "person.2.fill") }
            NavigationStack { MatchesView() }.tabItem { Label("Partidos", systemImage: "calendar") }
            NavigationStack { ProfileView() }.tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }.toolbarBackground(MPTheme.background, for: .tabBar).toolbarBackground(.visible, for: .tabBar)
    }
}

