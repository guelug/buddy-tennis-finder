import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var creating = false
    @State private var showingEmailLogin = false
    @StateObject private var appleCoordinator = AppleSignInCoordinator()

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("bg-login-live")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.48))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, MPTheme.background.opacity(0.45), MPTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()

            RadialGradient(
                colors: [MPTheme.accent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    Image("matchpoint-tennis-logo-light")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 270, maxHeight: 82)
                        .accessibilityLabel("MatchPoint Tennis")

                    VStack(spacing: 8) {
                        Text(creating ? "Crea tu cuenta" : "Tu próximo partido empieza aquí")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text("Rivales, reservas y comunidad de club")
                            .font(.subheadline)
                            .foregroundStyle(MPTheme.muted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "tennisball.fill")
                                .foregroundStyle(MPTheme.accent)
                            Text("ENTRA EN MATCHPOINT")
                                .font(.caption.weight(.black))
                                .tracking(1.6)
                                .foregroundStyle(MPTheme.accent)
                        }

                        Button { Task { await session.signInWithGoogle() } } label: {
                            Label("Continuar con Google", systemImage: "g.circle.fill")
                                .fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                        .disabled(session.isLoading)

                        SignInWithAppleButton(.continue) { request in
                            appleCoordinator.prepare(request)
                        } onCompletion: { result in
                            appleCoordinator.complete(result, session: session)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(session.isLoading)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showingEmailLogin.toggle() }
                        } label: {
                            Label("Continuar con correo", systemImage: showingEmailLogin ? "chevron.up" : "envelope")
                                .fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered).tint(.white)

                        if showingEmailLogin {
                            VStack(spacing: 12) {
                                TextField("Correo electrónico", text: $email)
                                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                SecureField("Contraseña", text: $password)
                                    .textContentType(creating ? .newPassword : .password)
                            }
                            .textFieldStyle(.roundedBorder)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            Button {
                                Task { creating ? await session.createAccount(email: email, password: password) : await session.signIn(email: email, password: password) }
                            } label: {
                                Group { if session.isLoading { ProgressView() } else { Text(creating ? "Crear cuenta" : "Entrar").fontWeight(.bold) } }
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.borderedProminent).tint(MPTheme.accent).foregroundStyle(.black)
                            .disabled(email.isEmpty || password.count < 6 || session.isLoading)

                            Button(creating ? "Ya tengo cuenta" : "Crear una cuenta") { creating.toggle() }
                                .frame(maxWidth: .infinity)
                            if !creating {
                                Button("He olvidado mi contraseña") { Task { await session.sendPasswordReset(email: email) } }
                                    .frame(maxWidth: .infinity).foregroundStyle(MPTheme.muted)
                            }
                        }

                        if session.isLoading { ProgressView().frame(maxWidth: .infinity) }
                        if let error = session.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.13)))
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 14)

                    Text("Al continuar aceptas los Términos y la Política de privacidad.")
                        .font(.caption2)
                        .foregroundStyle(MPTheme.muted)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

@MainActor
private final class AppleSignInCoordinator: ObservableObject {
    private var currentNonce: String?

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func complete(_ result: Result<ASAuthorization, Error>, session: SessionStore) {
        guard case let .success(authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            if case let .failure(error) = result { session.errorMessage = error.localizedDescription }
            return
        }
        Task { await session.signInWithApple(idToken: token, rawNonce: nonce, fullName: credential.fullName) }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                fatalError("No se ha podido generar el nonce de Apple.")
            }
            if random < characters.count {
                result.append(characters[Int(random)])
                remaining -= 1
            }
        }
        return result
    }
}
