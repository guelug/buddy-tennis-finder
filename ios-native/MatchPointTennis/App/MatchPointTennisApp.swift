import SwiftUI
import FirebaseCore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct MatchPointTennisApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session).preferredColorScheme(.dark)
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
    }
}
