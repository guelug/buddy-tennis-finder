import SwiftUI

struct MatchesView: View {
    @EnvironmentObject private var session: SessionStore
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(session.matches) { MatchRow(match: $0) }
                if session.matches.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus").font(.largeTitle).foregroundStyle(MPTheme.accent)
                        Text("No hay partidos abiertos").font(.headline)
                        Text("Las propuestas publicadas aparecerán aquí.").foregroundStyle(MPTheme.muted)
                    }.frame(maxWidth: .infinity).padding(32)
                }
            }.padding(20)
        }.background(MPTheme.background).navigationTitle("Partidos")
    }
}

struct MatchRow: View {
    let match: TennisMatch
    var body: some View {
        MPCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("NIVEL \(match.level)").font(.caption.bold()).foregroundStyle(MPTheme.accent); Spacer(); Image(systemName: "figure.tennis") }
                Text(match.message).font(.headline)
                Label(match.startsAt, systemImage: "clock").font(.subheadline).foregroundStyle(MPTheme.muted)
                Label(match.clubID, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(MPTheme.muted)
            }
        }
    }
}
