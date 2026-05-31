import SwiftUI
import WidgetKit
import StoreKit

@Observable
@MainActor
final class AppState {
    static let freeClosetItemLimit = 20
    static let premiumClosetItemLimit = 100
    static let premiumTrialDays = 7

    var currentUser: User?
    var isPremium: Bool = false
    var hasBYOKAccess: Bool = false
    var isBYOKEnabled: Bool = false
    var currentTier: SubscriptionTier = .free
    var preferredLanguage: Language = .spanish
    var hasCompletedProfileSetup: Bool = false
    var tryOnProvider: TryOnProvider = .google
    var isChatGPTConnected: Bool = false
    var useConnectedChatGPTForChat: Bool = false
    var aiProviderMode: AIProviderMode = .premium
    var chatPreparedFeatures = ChatPreparedFeatures()
    var isCalendarSyncEnabled: Bool = false
    var areDailyWidgetsEnabled: Bool = true
    var isSiriStyleSupportEnabled: Bool = true
    var isDailyReminderEnabled: Bool = false
    var dailyReminderTime: Date = AppState.reminderTime(hour: 8, minute: 0)
    var calendarAuthorizationStatus: CalendarSyncAuthorizationStatus = .notDetermined
    var todayCalendarEvents: [CalendarEventSnapshot] = []
    var latestDailyRecommendation: DailyStyleRecommendationSnapshot?
    var lastStyleRefreshAt: Date?

    private let storeKitManager = StoreKitManager.shared
    private let calendarSyncService = CalendarSyncService()
    private let dailyRecommendationService = DailyStyleRecommendationService()

    init() {
        AppSecrets.primeDefaultsIfNeeded()
        syncSubscriptionState()
        let sharedConfiguration = SharedStyleCompanionStore.loadConfiguration()
        isCalendarSyncEnabled = sharedConfiguration.calendarSyncEnabled
        areDailyWidgetsEnabled = sharedConfiguration.widgetRecommendationsEnabled
        isSiriStyleSupportEnabled = sharedConfiguration.siriSuggestionsEnabled
        isDailyReminderEnabled = sharedConfiguration.dailyReminderEnabled
        dailyReminderTime = AppState.reminderTime(
            hour: sharedConfiguration.dailyReminderHour,
            minute: sharedConfiguration.dailyReminderMinute
        )
        latestDailyRecommendation = SharedStyleCompanionStore.loadRecommendation()
        todayCalendarEvents = SharedStyleCompanionStore.loadEvents()
        calendarAuthorizationStatus = calendarSyncService.currentAuthorizationStatus()

        // Load saved provider
        if let savedProvider = UserDefaults.standard.string(forKey: "tryon_provider"),
           let provider = TryOnProvider(rawValue: savedProvider) {
            tryOnProvider = provider
        }

        // Check ChatGPT connection
        let hasServerAI = AppSecrets.vercelAPIBaseURL != nil
        isChatGPTConnected = hasServerAI || UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil || AppSecrets.openAIAPIKey != nil
        useConnectedChatGPTForChat = hasServerAI || UserDefaults.standard.bool(forKey: "chatgpt_chat_enabled")
        aiProviderMode = AIProviderMode(rawValue: UserDefaults.standard.string(forKey: "ai_provider_mode") ?? "") ?? .premium
        chatPreparedFeatures = ChatPreparedFeatures(
            textSelectionEnabled: UserDefaults.standard.bool(forKey: "chat_prepared_text_selection_enabled"),
            richMediaMessagesEnabled: UserDefaults.standard.bool(forKey: "chat_prepared_rich_media_enabled"),
            toolInvocationEnabled: UserDefaults.standard.bool(forKey: "chat_prepared_tool_invocation_enabled"),
            imageGenerationEnabled: UserDefaults.standard.bool(forKey: "chat_prepared_image_generation_enabled")
        )

        if !isTryOnProviderAvailable(tryOnProvider) {
            tryOnProvider = .google
        }
    }

    func loadUserState() async {
        // User state is managed via SwiftData model context
    }

    func refreshPremiumStatus() async {
        await storeKitManager.refreshSubscriptionStatus()
        syncSubscriptionState()
    }

    func updateUser(_ user: User) {
        currentUser = user
        preferredLanguage = user.preferredLanguage
        hasCompletedProfileSetup = user.profilePhotos.allPhotosUploaded
    }

    func setLanguage(_ language: Language) {
        preferredLanguage = language
        currentUser?.preferredLanguage = language
        currentUser?.updatedAt = Date()
    }

    func setTryOnProvider(_ provider: TryOnProvider) {
        let normalizedProvider = isTryOnProviderAvailable(provider) ? provider : .google
        tryOnProvider = normalizedProvider
        UserDefaults.standard.set(normalizedProvider.rawValue, forKey: "tryon_provider")
    }

    func setCalendarSyncEnabled(_ enabled: Bool, closetItems: [ClothingItem]) async {
        isCalendarSyncEnabled = enabled

        if enabled {
            let granted = await calendarSyncService.requestAccessIfNeeded()
            calendarAuthorizationStatus = calendarSyncService.currentAuthorizationStatus()

            if !granted {
                isCalendarSyncEnabled = false
                persistStyleCompanionConfiguration()
                return
            }
        } else {
            todayCalendarEvents = []
            SharedStyleCompanionStore.saveEvents([])
        }

        persistStyleCompanionConfiguration()
        await refreshStyleCompanionState(closetItems: closetItems)
    }

    func setDailyWidgetsEnabled(_ enabled: Bool) {
        areDailyWidgetsEnabled = enabled
        persistStyleCompanionConfiguration()
        reloadWidgets()
    }

    func setSiriStyleSupportEnabled(_ enabled: Bool) {
        isSiriStyleSupportEnabled = enabled
        persistStyleCompanionConfiguration()
    }

    func setDailyReminderEnabled(_ enabled: Bool, closetItems: [ClothingItem]) async {
        isDailyReminderEnabled = enabled
        persistStyleCompanionConfiguration()
        await syncDailyReminder(closetItems: closetItems)
    }

    func setDailyReminderTime(_ time: Date, closetItems: [ClothingItem]) async {
        dailyReminderTime = time
        persistStyleCompanionConfiguration()
        await syncDailyReminder(closetItems: closetItems)
    }

    static func reminderTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func syncDailyReminder(closetItems: [ClothingItem]) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        let scheduled = await DailyOutfitReminderScheduler.shared.sync(
            enabled: isDailyReminderEnabled,
            hour: components.hour ?? 8,
            minute: components.minute ?? 0,
            hasClosetItems: !closetItems.isEmpty,
            language: preferredLanguage
        )

        // If the user enabled it and we have garments but couldn't schedule, notifications are
        // denied — reflect that so the toggle doesn't look misleadingly on.
        if isDailyReminderEnabled && !scheduled && !closetItems.isEmpty {
            isDailyReminderEnabled = false
            persistStyleCompanionConfiguration()
        }
    }

    func refreshStyleCompanionState(closetItems: [ClothingItem]) async {
        calendarAuthorizationStatus = calendarSyncService.currentAuthorizationStatus()

        if isCalendarSyncEnabled && calendarAuthorizationStatus == .notDetermined {
            let granted = await calendarSyncService.requestAccessIfNeeded()
            calendarAuthorizationStatus = calendarSyncService.currentAuthorizationStatus()
            if !granted {
                isCalendarSyncEnabled = false
            }
        }

        if isCalendarSyncEnabled && calendarAuthorizationStatus == .fullAccess {
            todayCalendarEvents = calendarSyncService.fetchTodayEvents()
        } else {
            todayCalendarEvents = []
        }

        latestDailyRecommendation = dailyRecommendationService.buildRecommendation(
            for: currentUser,
            closetItems: closetItems,
            events: todayCalendarEvents,
            language: preferredLanguage
        )
        lastStyleRefreshAt = Date()

        SharedStyleCompanionStore.saveEvents(todayCalendarEvents)
        SharedStyleCompanionStore.saveRecommendation(latestDailyRecommendation)
        persistStyleCompanionConfiguration()
        reloadWidgets()

        // Keep the daily reminder in sync with closet contents (only fires when there are garments).
        await syncDailyReminder(closetItems: closetItems)
    }

    func connectChatGPT(token: String) {
        isChatGPTConnected = true
        UserDefaults.standard.set(token, forKey: "chatgpt_access_token")
    }

    func disconnectChatGPT() {
        isChatGPTConnected = false
        useConnectedChatGPTForChat = false
        UserDefaults.standard.removeObject(forKey: "chatgpt_access_token")
        UserDefaults.standard.set(false, forKey: "chatgpt_chat_enabled")
    }

    func setConnectedChatGPTForChatEnabled(_ enabled: Bool) {
        let effectiveValue = enabled && (hasBYOKAccess || currentTier.hasBYOK) && isBYOKEnabled
        useConnectedChatGPTForChat = effectiveValue
        UserDefaults.standard.set(effectiveValue, forKey: "chatgpt_chat_enabled")
    }

    func setAIProviderMode(_ mode: AIProviderMode) {
        aiProviderMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "ai_provider_mode")

        switch mode {
        case .premium:
            useConnectedChatGPTForChat = isChatGPTConnected
            UserDefaults.standard.set(useConnectedChatGPTForChat, forKey: "chatgpt_chat_enabled")
        case .byok:
            isBYOKEnabled = storeKitManager.isBYOKConfigured
            useConnectedChatGPTForChat = false
            UserDefaults.standard.set(false, forKey: "chatgpt_chat_enabled")
        }
    }

    func isTryOnProviderAvailable(_ provider: TryOnProvider) -> Bool {
        provider != .chatgpt || hasBYOKAccess || currentTier.hasBYOK
    }

    func closetItemLimitDescription(language: Language) -> String {
        if isPremium {
            return language == .spanish
                ? "Hasta \(Self.premiumClosetItemLimit) prendas"
                : "Up to \(Self.premiumClosetItemLimit) garments"
        }

        return language == .spanish
            ? "\(Self.freeClosetItemLimit) prendas"
            : "\(Self.freeClosetItemLimit) garments"
    }

    func hasReachedClosetLimit(currentCount: Int) -> Bool {
        !isPremium && currentCount >= Self.freeClosetItemLimit
    }

    private func syncSubscriptionState() {
        currentTier = storeKitManager.currentTier
        isPremium = storeKitManager.isPremium
        hasBYOKAccess = storeKitManager.hasBYOKPurchase
        isBYOKEnabled = storeKitManager.isBYOKActive

        if !hasBYOKAccess {
            useConnectedChatGPTForChat = false
            UserDefaults.standard.set(false, forKey: "chatgpt_chat_enabled")
        }
    }

    private func persistStyleCompanionConfiguration() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        SharedStyleCompanionStore.saveConfiguration(
            StyleCompanionConfigurationSnapshot(
                calendarSyncEnabled: isCalendarSyncEnabled,
                widgetRecommendationsEnabled: areDailyWidgetsEnabled,
                siriSuggestionsEnabled: isSiriStyleSupportEnabled,
                dailyReminderEnabled: isDailyReminderEnabled,
                dailyReminderHour: components.hour ?? 8,
                dailyReminderMinute: components.minute ?? 0
            )
        )
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum AIProviderMode: String, CaseIterable, Identifiable {
    case premium
    case byok

    var id: String { rawValue }

    func displayName(language: Language) -> String {
        switch self {
        case .premium:
            return language == .spanish ? "Premium" : "Premium"
        case .byok:
            return "BYOK"
        }
    }
}
