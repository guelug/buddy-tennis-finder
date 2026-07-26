import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct PersonalShooperApp: App {
    @State private var appState = AppState()
    @State private var persistence = PersistenceController()

    init() {
        Self.applyPremiumNavigationAppearance()
    }

    /// Gives every navigation title a premium look: SF Rounded, bold, with a touch of tracking — so
    /// section headers like "Mi Armario" / "Probador Virtual" read as designed, not default system.
    private static func applyPremiumNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        let largeSize: CGFloat = 34
        let inlineSize: CGFloat = 17
        let largeBase = UIFont.systemFont(ofSize: largeSize, weight: .bold)
        let inlineBase = UIFont.systemFont(ofSize: inlineSize, weight: .semibold)
        let largeFont = UIFont(descriptor: largeBase.fontDescriptor.withDesign(.rounded) ?? largeBase.fontDescriptor, size: largeSize)
        let inlineFont = UIFont(descriptor: inlineBase.fontDescriptor.withDesign(.rounded) ?? inlineBase.fontDescriptor, size: inlineSize)

        appearance.largeTitleTextAttributes = [
            .font: largeFont,
            .kern: 0.4
        ]
        appearance.titleTextAttributes = [
            .font: inlineFont,
            .kern: 0.2
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = persistence.container {
                    ContentView()
                        .modelContainer(container)
                } else {
                    PersistenceFailureView(
                        details: persistence.errorMessage,
                        onRetry: persistence.load
                    )
                }
            }
            .environment(appState)
        }
    }
}

private struct PersistenceFailureView: View {
    let details: String?
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No se puede abrir el armario", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Tus datos no se han sustituido por una sesión temporal. Cierra otras versiones de la app y vuelve a intentarlo.")
            if let details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        } actions: {
            Button("Reintentar", systemImage: "arrow.clockwise", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("persistence.retry")
        }
        .padding()
    }
}

struct ContentView: View {
    @AppStorage("app_theme") private var storedTheme = AppTheme.system.rawValue
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @State private var isReady = false
    @State private var selectedTab = 0
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \User.createdAt) private var users: [User]
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \StyleProgressMission.createdAt, order: .reverse) private var progressMissions: [StyleProgressMission]

    /// Change-detector for the shared closet index (the snapshot the AI's `search_closet` tool,
    /// Siri and the widgets read from). Keying the refresh on `clothingItems.count` alone meant an
    /// *edit* — rename, retag, favorite, "worn today" — never propagated, so the assistant kept
    /// answering from a stale inventory until an item was added or removed.
    private var closetFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(clothingItems.count)
        for item in clothingItems {
            hasher.combine(item.id)
            hasher.combine(item.name)
            hasher.combine(item.timesWorn)
            hasher.combine(item.isFavorite)
            hasher.combine(item.categoryRaw)
            hasher.combine(item.colorTags)
            hasher.combine(item.styleTags)
            hasher.combine(item.occasionTags)
            hasher.combine(item.lastWornAt)
        }
        return hasher.finalize()
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppTheme(rawValue: storedTheme) ?? .system {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }

    var body: some View {
        Group {
            if !isReady {
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingView { name, gender in
                    completeOnboarding(with: name, gender: gender)
                }
            } else {
                MainTabView(selectedTab: $selectedTab)
            }
        }
        .environment(\.locale, Locale(identifier: appState.preferredLanguage.rawValue))
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-ui-reset-onboarding") {
                hasCompletedOnboarding = false
            } else if arguments.contains("-ui-skip-onboarding") {
                hasCompletedOnboarding = true
            }

            if arguments.contains("-ui-testing") {
                isReady = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isReady = true
                    }
                }
            }

            // Debug/UI-test hook: `-ui-start-tab N` opens a specific tab on launch.
            if let tabArgIndex = arguments.firstIndex(of: "-ui-start-tab"),
               arguments.indices.contains(tabArgIndex + 1),
               let tab = Int(arguments[tabArgIndex + 1]) {
                selectedTab = tab
            }

            syncUserState()
            #if DEBUG
            if arguments.contains("-ui-screenshot-content") {
                seedScreenshotContentIfNeeded()
            }
            #endif
            applyPendingLaunchDestinationIfNeeded()
            Task {
                await appState.refreshAccessStatus()
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
                await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
                refreshLiveActivity()
                learnStyleUsageIfDue()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                applyPendingLaunchDestinationIfNeeded()
                refreshLiveActivity()
                Task {
                    await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
                }
            }
        }
        .onChange(of: isReady) { _, ready in
            if ready {
                applyPendingLaunchDestinationIfNeeded()
            }
        }
        .onChange(of: users.count) { _, _ in
            syncUserState()
            Task {
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
            }
        }
        .onChange(of: closetFingerprint) { _, _ in
            Task {
                await appState.refreshStyleCompanionState(closetItems: clothingItems)
            }
        }
        .onChange(of: progressMissions.count) { _, _ in
            Task {
                await StyleProgressReminderCoordinator.shared.sync(missions: progressMissions)
            }
        }
    }

    private func refreshLiveActivity() {
        DailyOutfitLiveActivityController.shared.refresh(
            enabled: appState.isDailyReminderEnabled,
            hasClosetItems: !clothingItems.isEmpty,
            reminderTime: appState.dailyReminderTime,
            recommendation: appState.latestDailyRecommendation,
            language: appState.preferredLanguage
        )
    }

    private func completeOnboarding(with name: String, gender: StyleGender) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let user = appState.currentUser ?? users.first {
            if !trimmed.isEmpty {
                user.displayName = trimmed
            }
            if gender != .unspecified {
                var profile = user.personalStylingProfile
                profile.genderIdentity = gender
                user.updateStylingProfile(profile)
            }
            user.updatedAt = Date()
            try? modelContext.save()
            appState.updateUser(user)
        }

        withAnimation(.smooth) {
            hasCompletedOnboarding = true
        }
    }

    /// Counts today as a usage-day and, once the user has enough real days of use, refreshes the
    /// auto-learned style summary from their most-worn garments.
    private func learnStyleUsageIfDue() {
        StyleUsageLearning.registerUsageDay()
        guard let user = users.first else { return }
        StyleUsageLearning.runIfDue(
            user: user,
            closetItems: clothingItems,
            language: appState.preferredLanguage,
            modelContext: modelContext
        )
    }

    private func syncUserState() {
        if let user = users.first {
            if appState.currentUser?.id != user.id || appState.preferredLanguage != user.preferredLanguage {
                appState.updateUser(user)
            }
            return
        }

        let newUser = User(
            displayName: Strings.guestUser(appState.preferredLanguage),
            preferredLanguage: appState.preferredLanguage
        )
        modelContext.insert(newUser)
        do {
            try modelContext.save()
            appState.updateUser(newUser)
        } catch {
            modelContext.delete(newUser)
        }
    }

    #if DEBUG
    private func seedScreenshotContentIfNeeded() {
        if let user = appState.currentUser {
            user.displayName = "Alex"
            user.updateStylingProfile(
                PersonalStylingProfile(
                    age: 32,
                    genderIdentity: .unspecified,
                    occupation: "Producto digital",
                    lifestyleSummary: "Semana urbana entre oficina, reuniones y planes informales.",
                    usualSocialPlans: ["office_days", "dinners"],
                    preferredStyles: ["minimal", "classic"],
                    desiredImpression: ["professional", "approachable"],
                    fitPriorities: ["versatility", "comfort"],
                    favoriteColors: ["Azul marino", "Verde bosque", "Camel"],
                    avoidColors: ["Neón"],
                    styleGoals: "Crear looks de oficina variados con menos prendas.",
                    shoppingChallenges: "Evitar compras duplicadas y aprovechar mejor el armario."
                )
            )
            user.personalPalette = PersonalPalette(
                seasonalType: .softAutumn,
                undertone: .warm,
                recommendedColors: [
                    CodableColor(red: 0.12, green: 0.24, blue: 0.42, name: "Azul marino"),
                    CodableColor(red: 0.22, green: 0.42, blue: 0.28, name: "Verde bosque"),
                    CodableColor(red: 0.67, green: 0.38, blue: 0.20, name: "Terracota"),
                    CodableColor(red: 0.78, green: 0.65, blue: 0.42, name: "Camel"),
                    CodableColor(red: 0.93, green: 0.88, blue: 0.76, name: "Crema")
                ],
                summary: "Tonos cálidos, suaves y fáciles de combinar."
            )
            user.updatedAt = Date()
            appState.updateUser(user)
        }

        guard clothingItems.isEmpty else { return }

        let samples: [(String, ClothingCategory, UIColor, String, [String], Int)] = [
            ("Blazer azul", .outerwear, .systemBlue, "Azul marino", ["Oficina", "Elegante"], 7),
            ("Camisa blanca", .tops, .white, "Blanco", ["Clásico", "Oficina"], 12),
            ("Pantalón sastre", .bottoms, .darkGray, "Gris", ["Minimalista", "Oficina"], 9),
            ("Vestido verde", .dresses, .systemGreen, "Verde", ["Cena", "Elegante"], 4),
            ("Mocasines", .shoes, .brown, "Marrón", ["Clásico", "Oficina"], 15),
            ("Bolso diario", .accessories, .systemOrange, "Camel", ["Diario", "Minimalista"], 6)
        ]

        for (index, sample) in samples.enumerated() {
            let image = screenshotGarmentImage(category: sample.1, color: sample.2)
            let item = ClothingItem(
                name: sample.0,
                category: sample.1,
                image: image,
                colorTags: [sample.3],
                styleTags: sample.4,
                occasionTags: sample.4
            )
            item.cutoutImage = image
            item.isFavorite = index < 2
            item.timesWorn = sample.5
            item.hiddenUsageScore = min(100, Double(28 + sample.5 * 4))
            item.createdAt = Calendar.current.date(byAdding: .day, value: -(index * 12), to: Date()) ?? Date()
            item.lastWornAt = Calendar.current.date(byAdding: .day, value: -(index + 1), to: Date())
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    private func screenshotGarmentImage(category: ClothingCategory, color: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let path: UIBezierPath
            switch category {
            case .bottoms:
                path = UIBezierPath()
                path.move(to: CGPoint(x: 155, y: 80))
                path.addLine(to: CGPoint(x: 357, y: 80))
                path.addLine(to: CGPoint(x: 348, y: 425))
                path.addLine(to: CGPoint(x: 270, y: 425))
                path.addLine(to: CGPoint(x: 256, y: 245))
                path.addLine(to: CGPoint(x: 242, y: 425))
                path.addLine(to: CGPoint(x: 164, y: 425))
                path.close()
            case .dresses:
                path = UIBezierPath()
                path.move(to: CGPoint(x: 210, y: 75))
                path.addCurve(
                    to: CGPoint(x: 302, y: 75),
                    controlPoint1: CGPoint(x: 225, y: 115),
                    controlPoint2: CGPoint(x: 287, y: 115)
                )
                path.addLine(to: CGPoint(x: 325, y: 210))
                path.addLine(to: CGPoint(x: 410, y: 430))
                path.addLine(to: CGPoint(x: 102, y: 430))
                path.addLine(to: CGPoint(x: 187, y: 210))
                path.close()
            case .shoes:
                path = UIBezierPath()
                path.move(to: CGPoint(x: 92, y: 325))
                path.addCurve(
                    to: CGPoint(x: 420, y: 330),
                    controlPoint1: CGPoint(x: 180, y: 300),
                    controlPoint2: CGPoint(x: 330, y: 370)
                )
                path.addCurve(
                    to: CGPoint(x: 92, y: 325),
                    controlPoint1: CGPoint(x: 390, y: 420),
                    controlPoint2: CGPoint(x: 140, y: 425)
                )
            case .accessories:
                path = UIBezierPath(roundedRect: CGRect(x: 115, y: 180, width: 282, height: 245), cornerRadius: 42)
                let handle = UIBezierPath(arcCenter: CGPoint(x: 256, y: 195), radius: 82, startAngle: .pi, endAngle: 0, clockwise: true)
                handle.lineWidth = 34
                color.setStroke()
                handle.stroke()
            default:
                path = UIBezierPath()
                path.move(to: CGPoint(x: 185, y: 105))
                path.addLine(to: CGPoint(x: 80, y: 170))
                path.addLine(to: CGPoint(x: 125, y: 270))
                path.addLine(to: CGPoint(x: 168, y: 245))
                path.addLine(to: CGPoint(x: 168, y: 425))
                path.addLine(to: CGPoint(x: 344, y: 425))
                path.addLine(to: CGPoint(x: 344, y: 245))
                path.addLine(to: CGPoint(x: 387, y: 270))
                path.addLine(to: CGPoint(x: 432, y: 170))
                path.addLine(to: CGPoint(x: 327, y: 105))
                path.addCurve(
                    to: CGPoint(x: 185, y: 105),
                    controlPoint1: CGPoint(x: 302, y: 155),
                    controlPoint2: CGPoint(x: 210, y: 155)
                )
                path.close()
            }

            color.setFill()
            path.fill()
            UIColor.black.withAlphaComponent(color == .white ? 0.35 : 0.12).setStroke()
            path.lineWidth = 8
            path.lineJoinStyle = .round
            path.stroke()

            if category == .outerwear {
                let seam = UIBezierPath()
                seam.move(to: CGPoint(x: 256, y: 150))
                seam.addLine(to: CGPoint(x: 256, y: 420))
                seam.lineWidth = 6
                UIColor.white.withAlphaComponent(0.45).setStroke()
                seam.stroke()
            }

            context.cgContext.setBlendMode(.normal)
        }
    }
    #endif

    private func applyPendingLaunchDestinationIfNeeded() {
        guard let destination = SharedStyleCompanionStore.consumePendingLaunchDestination() else {
            return
        }

        switch destination {
        case .chat:
            selectedTab = 1
        case .closet:
            selectedTab = 2
        case .tryOn:
            selectedTab = 3
        case .profile:
            selectedTab = 5
        }
    }
}

@MainActor
private final class StyleProgressReminderCoordinator {
    static let shared = StyleProgressReminderCoordinator()

    private let center = UNUserNotificationCenter.current()

    func sync(missions: [StyleProgressMission]) async {
        let activeMissions = missions.filter(\.isActive)
        let activeIdentifiers = Set(activeMissions.compactMap(\.reminderIdentifier))

        let pending = await center.pendingNotificationRequests()
        let staleIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("style-progress-") && !activeIdentifiers.contains($0) }

        for identifier in staleIdentifiers {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }

        guard !activeMissions.isEmpty else { return }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return
        case .notDetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else { return }
        @unknown default:
            return
        }

        for mission in activeMissions where mission.reminderIdentifier == nil {
            let identifier = "style-progress-\(mission.id.uuidString)"
            let content = UNMutableNotificationContent()
            content.title = "Comparativa lista"
            content.body = "Ya puedes subir la nueva foto para comparar tu evolución con \(mission.title)."
            content.sound = .default

            let interval = max(mission.dueAt.timeIntervalSinceNow, 60)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                mission.reminderIdentifier = identifier
            } catch {
                #if DEBUG
                print("StyleProgressReminderCoordinator failed to schedule reminder: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

struct SplashView: View {
    @Environment(AppState.self) private var appState

    private var title: String {
        Strings.appName(appState.preferredLanguage)
    }

    private var subtitle: String {
        appState.preferredLanguage == .spanish ? "Tu asistente de estilo con IA" : "Your AI Style Assistant"
    }

    var body: some View {
        ZStack {
            Theme.Colors.primaryGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "hanger")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.fashionDisplay(36))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.top, 30)
            }
        }
    }
}
