import SwiftUI
import WidgetKit

@Observable
@MainActor
final class AppState {
    static let freeClosetItemLimit = 10
    static let premiumTrialDays = 7

    var currentUser: User?
    var isPremium: Bool = false
    var preferredLanguage: Language = .spanish
    var hasCompletedProfileSetup: Bool = false
    var tryOnProvider: TryOnProvider = .google
    var isChatGPTConnected: Bool = false
    var useConnectedChatGPTForChat: Bool = false
    var isCalendarSyncEnabled: Bool = false
    var areDailyWidgetsEnabled: Bool = true
    var isSiriStyleSupportEnabled: Bool = true
    var calendarAuthorizationStatus: CalendarSyncAuthorizationStatus = .notDetermined
    var todayCalendarEvents: [CalendarEventSnapshot] = []
    var latestDailyRecommendation: DailyStyleRecommendationSnapshot?
    var lastStyleRefreshAt: Date?

    private let storeKitManager = StoreKitManager()
    private let calendarSyncService = CalendarSyncService()
    private let dailyRecommendationService = DailyStyleRecommendationService()

    init() {
        AppSecrets.primeDefaultsIfNeeded()
        isPremium = storeKitManager.isPremium
        let sharedConfiguration = SharedStyleCompanionStore.loadConfiguration()
        isCalendarSyncEnabled = sharedConfiguration.calendarSyncEnabled
        areDailyWidgetsEnabled = sharedConfiguration.widgetRecommendationsEnabled
        isSiriStyleSupportEnabled = sharedConfiguration.siriSuggestionsEnabled
        latestDailyRecommendation = SharedStyleCompanionStore.loadRecommendation()
        todayCalendarEvents = SharedStyleCompanionStore.loadEvents()
        calendarAuthorizationStatus = calendarSyncService.currentAuthorizationStatus()

        // Load saved provider
        if let savedProvider = UserDefaults.standard.string(forKey: "tryon_provider"),
           let provider = TryOnProvider(rawValue: savedProvider) {
            tryOnProvider = provider
        }

        // Check ChatGPT connection
        isChatGPTConnected = UserDefaults.standard.string(forKey: "chatgpt_access_token") != nil || AppSecrets.openAIAPIKey != nil
        useConnectedChatGPTForChat = UserDefaults.standard.bool(forKey: "chatgpt_chat_enabled")
    }

    func loadUserState() async {
        // User state is managed via SwiftData model context
    }

    func refreshPremiumStatus() async {
        await storeKitManager.updatePurchasedProducts()
        isPremium = storeKitManager.isPremium
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
        tryOnProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "tryon_provider")
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
        let effectiveValue = enabled && isChatGPTConnected
        useConnectedChatGPTForChat = effectiveValue
        UserDefaults.standard.set(effectiveValue, forKey: "chatgpt_chat_enabled")
    }

    func closetItemLimitDescription(language: Language) -> String {
        if isPremium {
            return language == .spanish
                ? "Ilimitado, según tu espacio local y de iCloud"
                : "Unlimited, depending on your local and iCloud space"
        }

        return language == .spanish
            ? "\(Self.freeClosetItemLimit) prendas"
            : "\(Self.freeClosetItemLimit) garments"
    }

    func hasReachedClosetLimit(currentCount: Int) -> Bool {
        !isPremium && currentCount >= Self.freeClosetItemLimit
    }

    private func persistStyleCompanionConfiguration() {
        SharedStyleCompanionStore.saveConfiguration(
            StyleCompanionConfigurationSnapshot(
                calendarSyncEnabled: isCalendarSyncEnabled,
                widgetRecommendationsEnabled: areDailyWidgetsEnabled,
                siriSuggestionsEnabled: isSiriStyleSupportEnabled
            )
        )
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
