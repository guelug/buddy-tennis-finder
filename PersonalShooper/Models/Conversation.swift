import Foundation
import SwiftData
import UIKit

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
    var imageData: Data?
    var linkedClosetItemIDString: String?
    var linkedTryOnResultIDString: String?
    var metadataData: Data?
    var timestamp: Date

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    var image: UIImage? {
        get { imageData.flatMap(UIImage.init(data:)) }
        set { imageData = newValue?.jpegData(compressionQuality: 0.85) }
    }

    var linkedClosetItemID: UUID? {
        get { linkedClosetItemIDString.flatMap(UUID.init(uuidString:)) }
        set { linkedClosetItemIDString = newValue?.uuidString }
    }

    var linkedTryOnResultID: UUID? {
        get { linkedTryOnResultIDString.flatMap(UUID.init(uuidString:)) }
        set { linkedTryOnResultIDString = newValue?.uuidString }
    }

    var metadata: ChatMessageMetadata {
        get {
            guard let metadataData else { return ChatMessageMetadata() }
            return (try? JSONDecoder().decode(ChatMessageMetadata.self, from: metadataData)) ?? ChatMessageMetadata()
        }
        set {
            metadataData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        imageURL: String? = nil,
        image: UIImage? = nil,
        linkedClosetItemID: UUID? = nil,
        linkedTryOnResultID: UUID? = nil,
        metadata: ChatMessageMetadata = ChatMessageMetadata()
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.imageURLString = imageURL
        self.imageData = image?.jpegData(compressionQuality: 0.85)
        self.linkedClosetItemIDString = linkedClosetItemID?.uuidString
        self.linkedTryOnResultIDString = linkedTryOnResultID?.uuidString
        self.metadataData = try? JSONEncoder().encode(metadata)
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

enum ChatMessageAssetSource: String, Codable {
    case none
    case localAttachment
    case generatedTryOn
    case remoteImage
}

struct ChatMessageMetadata: Codable {
    var assetSource: ChatMessageAssetSource
    var toolIdentifier: String?
    var cacheKey: String?

    init(
        assetSource: ChatMessageAssetSource = .none,
        toolIdentifier: String? = nil,
        cacheKey: String? = nil
    ) {
        self.assetSource = assetSource
        self.toolIdentifier = toolIdentifier
        self.cacheKey = cacheKey
    }
}

struct ChatContext {
    var userPalette: PersonalPalette?
    var userStylePreferences: [String]
    var personalStylingProfile: PersonalStylingProfile?
    var preferredName: String?
    var userGender: StyleGender?
    var todayEvents: [CalendarEventSnapshot]
    var dailyRecommendation: DailyStyleRecommendationSnapshot?
    var closetItems: [ClothingItemSummary]
    var recentConversations: [ConversationSummary]
    var language: Language

    init(
        userPalette: PersonalPalette? = nil,
        userStylePreferences: [String] = [],
        personalStylingProfile: PersonalStylingProfile? = nil,
        preferredName: String? = nil,
        userGender: StyleGender? = nil,
        todayEvents: [CalendarEventSnapshot] = [],
        dailyRecommendation: DailyStyleRecommendationSnapshot? = nil,
        closetItems: [ClothingItemSummary] = [],
        recentConversations: [ConversationSummary] = [],
        language: Language = .english
    ) {
        self.userPalette = userPalette
        self.userStylePreferences = userStylePreferences
        self.personalStylingProfile = personalStylingProfile
        self.preferredName = preferredName
        self.userGender = userGender
        self.todayEvents = todayEvents
        self.dailyRecommendation = dailyRecommendation
        self.closetItems = closetItems
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
