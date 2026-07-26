import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TU CLUB, TU PARTIDO").font(.caption.bold()).tracking(1.5).foregroundStyle(MPTheme.accent)
                Text("Juega más.\nConecta mejor.").font(.largeTitle.bold())
                MPCard {
                    HStack {
                    Label("\(session.players.count) jugadores", systemImage: "person.2.fill")
                    Spacer(); Label("\(session.matches.count) abiertos", systemImage: "calendar")
                    }.font(.headline)
                }
                Text("Próximos partidos").font(.title2.bold()).padding(.top, 8)
                ForEach(session.matches.prefix(3)) { item in MatchRow(match: item) }
                if session.matches.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "figure.tennis").font(.largeTitle).foregroundStyle(MPTheme.accent)
                        Text("Sin partidos abiertos").font(.headline)
                        Text("Vuelve pronto para encontrar rival.").foregroundStyle(MPTheme.muted)
                    }.frame(maxWidth: .infinity).padding(32)
                }
            }.padding(20)
        }.background(MPTheme.background).navigationTitle("MatchPoint")
    }
}
