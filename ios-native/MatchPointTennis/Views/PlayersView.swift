import SwiftUI

struct PlayersView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var search = ""
    private var filtered: [Player] { search.isEmpty ? session.players : session.players.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.city.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List(filtered) { player in
            HStack(spacing: 14) {
                AsyncImage(url: player.photoURL) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.fill").foregroundStyle(MPTheme.accent) }
                    .frame(width: 52, height: 52).background(MPTheme.surface).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name).font(.headline)
                    Text([player.city, "Nivel \(player.level)"].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(.secondary)
                }
                Spacer(); Text(String(format: "%.1f", player.rating)).font(.headline).foregroundStyle(MPTheme.accent)
            }.padding(.vertical, 6)
        }.scrollContentBackground(.hidden).background(MPTheme.background).navigationTitle("Jugadores").searchable(text: $search, prompt: "Nombre o ciudad")
    }
}

