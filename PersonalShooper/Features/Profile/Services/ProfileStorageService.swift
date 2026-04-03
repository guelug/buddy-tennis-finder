import Foundation

protocol ProfileStorageServiceProtocol {
    func saveUserData(_ data: UserData) async throws
    func loadUserData() async throws -> UserData?
    func deleteUserData() async throws
}

struct UserData: Codable {
    var displayName: String
    var preferredLanguage: String
    var hasCompletedSetup: Bool
}

final class ProfileStorageService: ProfileStorageServiceProtocol {

    private let userDefaults = UserDefaults.standard
    private let userKey = "com.personalshooper.user"

    func saveUserData(_ data: UserData) async throws {
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(data)
        userDefaults.set(encoded, forKey: userKey)
    }

    func loadUserData() async throws -> UserData? {
        guard let data = userDefaults.data(forKey: userKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(UserData.self, from: data)
    }

    func deleteUserData() async throws {
        userDefaults.removeObject(forKey: userKey)
    }
}

protocol ConversationStorageServiceProtocol {
    func saveConversationData(_ data: [ConversationData]) async throws
    func loadConversationData() async throws -> [ConversationData]
}

struct ConversationData: Codable {
    let id: UUID
    var title: String
    var messages: [MessageData]
    var updatedAt: Date
}

struct MessageData: Codable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
}

final class ConversationStorageService: ConversationStorageServiceProtocol {

    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "com.personalshooper.conversations"

    func saveConversationData(_ data: [ConversationData]) async throws {
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(data)
        userDefaults.set(encoded, forKey: conversationsKey)
    }

    func loadConversationData() async throws -> [ConversationData] {
        guard let data = userDefaults.data(forKey: conversationsKey) else {
            return []
        }
        let decoder = JSONDecoder()
        return try decoder.decode([ConversationData].self, from: data)
    }
}
