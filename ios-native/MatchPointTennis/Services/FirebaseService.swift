import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: User?
    @Published var players: [Player] = []
    @Published var matches: [TennisMatch] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let database = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var playerListener: ListenerRegistration?
    private var matchListener: ListenerRegistration?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                user == nil ? self?.stopListening() : self?.startListening()
            }
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), password: password) }
    }

    func createAccount(email: String, password: String) async {
        await authenticate { try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), password: password) }
    }

    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "No se ha podido cargar la configuración de Google."
            return
        }
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController else {
            errorMessage = "No se ha podido abrir el acceso con Google."
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingGoogleToken
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        await authenticate {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            return try await Auth.auth().signIn(with: credential)
        }
    }

    func sendPasswordReset(email: String) async {
        do { try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        catch { errorMessage = error.localizedDescription }
    }

    func signOut() {
        do { try Auth.auth().signOut() } catch { errorMessage = error.localizedDescription }
    }

    private func authenticate(_ operation: () async throws -> AuthDataResult) async {
        isLoading = true
        defer { isLoading = false }
        do { _ = try await operation() } catch { errorMessage = error.localizedDescription }
    }

    private func startListening() {
        stopListening()
        playerListener = database.collection("players").limit(to: 100).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription; return }
                self?.players = snapshot?.documents.map { Player(id: $0.documentID, data: $0.data()) }.sorted { $0.rating > $1.rating } ?? []
            }
        }
        matchListener = database.collection("matches").whereField("status", isEqualTo: "proposed").limit(to: 100).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if let error { self?.errorMessage = error.localizedDescription; return }
                self?.matches = snapshot?.documents.map { TennisMatch(id: $0.documentID, data: $0.data()) } ?? []
            }
        }
    }

    private func stopListening() {
        playerListener?.remove(); matchListener?.remove()
        playerListener = nil; matchListener = nil
        players = []; matches = []
    }
}

private enum AuthError: LocalizedError {
    case missingGoogleToken

    var errorDescription: String? {
        "Google no ha devuelto una credencial válida."
    }
}
