import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    private var me: Player? { session.players.first { $0.id == session.user?.uid } }
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 58)).foregroundStyle(MPTheme.accent)
                    VStack(alignment: .leading) { Text(me?.name ?? "Jugador").font(.title2.bold()); Text(session.user?.email ?? "").foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
            }
            if let me { Section("Perfil deportivo") { LabeledContent("Nivel", value: me.level); LabeledContent("Ciudad", value: me.city); LabeledContent("Respuesta", value: "\(me.responseRate)%") } }
            Section { Button("Cerrar sesión", role: .destructive) { session.signOut() } }
        }.scrollContentBackground(.hidden).background(MPTheme.background).navigationTitle("Perfil")
    }
}

