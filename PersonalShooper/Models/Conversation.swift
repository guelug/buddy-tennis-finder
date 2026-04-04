import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade) var messages: [Message]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Conversation") {
        self.id = id
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }
}

@Model
final class Message {
    var id: UUID
    var roleRaw: String
    var content: String
    var imageURLString: String?
    var timestamp: Date

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), role: MessageRole, content: String, imageURL: String? = nil) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.imageURLString = imageURL
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct ChatContext {
    var userPalette: PersonalPalette?
    var userStylePreferences: [String]
    var personalStylingProfile: PersonalStylingProfile?
    var preferredName: String?
    var todayEvents: [CalendarEventSnapshot]
    var dailyRecommendation: DailyStyleRecommendationSnapshot?
    var recentConversations: [ConversationSummary]
    var language: Language

    init(
        userPalette: PersonalPalette? = nil,
        userStylePreferences: [String] = [],
        personalStylingProfile: PersonalStylingProfile? = nil,
        preferredName: String? = nil,
        todayEvents: [CalendarEventSnapshot] = [],
        dailyRecommendation: DailyStyleRecommendationSnapshot? = nil,
        recentConversations: [ConversationSummary] = [],
        language: Language = .english
    ) {
        self.userPalette = userPalette
        self.userStylePreferences = userStylePreferences
        self.personalStylingProfile = personalStylingProfile
        self.preferredName = preferredName
        self.todayEvents = todayEvents
        self.dailyRecommendation = dailyRecommendation
        self.recentConversations = recentConversations
        self.language = language
    }
}

struct ConversationSummary: Identifiable {
    let id: UUID
    let title: String
    let messages: [MessageSummary]
    let updatedAt: Date
}

struct MessageSummary {
    let id: UUID
    let role: MessageRole
    let content: String
}
