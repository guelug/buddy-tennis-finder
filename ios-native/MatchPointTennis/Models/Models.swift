import Foundation
import FirebaseFirestore

struct Player: Identifiable, Hashable {
    let id: String
    let name: String
    let level: String
    let city: String
    let bio: String
    let rating: Double
    let responseRate: Int
    let photoURL: URL?

    init(id: String, data: [String: Any]) {
        self.id = id
        name = data["name"] as? String ?? "Jugador"
        level = (data["level"] as? String ?? "novato").uppercased()
        city = data["city"] as? String ?? ""
        bio = data["bio"] as? String ?? ""
        rating = data["rating"] as? Double ?? Double(data["rating"] as? Int ?? 3)
        responseRate = data["responseRate"] as? Int ?? 100
        photoURL = (data["photoURL"] as? String).flatMap(URL.init(string:))
    }
}

struct TennisMatch: Identifiable, Hashable {
    let id: String
    let ownerID: String
    let clubID: String
    let startsAt: String
    let level: String
    let message: String
    let status: String

    init(id: String, data: [String: Any]) {
        self.id = id
        ownerID = data["fromPlayerId"] as? String ?? ""
        clubID = data["clubId"] as? String ?? "Club"
        startsAt = data["startsAt"] as? String ?? data["proposedAt"] as? String ?? "Por confirmar"
        level = (data["division"] as? String ?? "novato").uppercased()
        message = data["message"] as? String ?? "Partido abierto"
        status = data["status"] as? String ?? "proposed"
    }
}

