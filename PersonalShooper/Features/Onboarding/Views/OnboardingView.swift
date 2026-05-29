import SwiftUI

/// First-launch onboarding inspired by DIA browser: an animated aurora reveal that asks for the
/// user's name to personalize the app, then introduces the assistant, Rebe.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    /// Called with the entered name and gender when onboarding finishes.
    let onComplete: (String, StyleGender) -> Void

    @State private var step: Step = .intro
    @State private var name: String = ""
    @State private var gender: StyleGender?
    @FocusState private var nameFieldFocused: Bool

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum Step: Int { case intro, name, gender, meet }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .intro: introStep
                    case .name: nameStep
                    case .gender: genderStep
                    case .meet: meetStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)

                progressDots
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: 520)
        }
        .animation(.smooth(duration: 0.5), value: step)
        .preferredColorScheme(.dark)
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            badge(systemImage: "sparkles")

            VStack(spacing: Theme.Spacing.sm) {
                Text(isSpanish ? "Te damos la bienvenida a\nPersonal Shopper" : "Welcome to\nPersonal Shopper")
                    .font(.system(size: 38, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(isSpanish
                     ? "Tu asistente personal de estilo, con IA en tu dispositivo."
                     : "Your personal style assistant, with on-device AI.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            primaryButton(isSpanish ? "Empezar" : "Get started") {
                step = .name
            }
        }
        .foregroundStyle(.white)
    }

    private var nameStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            badge(systemImage: "person.fill")

            VStack(spacing: Theme.Spacing.sm) {
                Text(isSpanish ? "¿Cómo te llamas?" : "What's your name?")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(isSpanish
                     ? "Así personalizo tus recomendaciones."
                     : "So I can personalize your recommendations.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            TextField("", text: $name, prompt: Text(isSpanish ? "Tu nombre" : "Your name").foregroundStyle(.white.opacity(0.4)))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($nameFieldFocused)
                .foregroundStyle(.white)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                .onSubmit(advanceFromName)

            primaryButton(isSpanish ? "Continuar" : "Continue", enabled: !trimmedName.isEmpty, action: advanceFromName)
        }
        .foregroundStyle(.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                nameFieldFocused = true
            }
        }
    }

    private var meetStep: some View {
        let assistantName = AssistantPersona.name(forUserNamed: trimmedName)
        // The greeting is the assistant introducing herself/himself, so it follows the assistant's
        // gender (Rebe is female, the "Peter" fallback is male), not the user's.
        let greeting = isSpanish
            ? (assistantName == AssistantPersona.alternateName ? "Encantado" : "Encantada")
            : "Lovely to meet you"

        return VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryGradient)
                    .frame(width: 96, height: 96)
                Text(String(assistantName.prefix(1)))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: Theme.Spacing.sm) {
                Text("\(greeting)\(trimmedName.isEmpty ? "" : ", \(trimmedName)").")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(isSpanish
                     ? "Soy \(assistantName), tu asistente personal de estilo. Vamos a vestir tu mejor versión."
                     : "I'm \(assistantName), your personal style assistant. Let's dress your best self.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }

            primaryButton(isSpanish ? "Entrar" : "Enter") {
                onComplete(trimmedName, gender ?? .unspecified)
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Components

    private var genderStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            badge(systemImage: "tshirt.fill")

            VStack(spacing: Theme.Spacing.sm) {
                Text(isSpanish ? "¿Para quién vamos a\nvestir?" : "Who are we\ndressing?")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(isSpanish
                     ? "Así adapto las prendas y los consejos a tu estilo."
                     : "So I tailor garments and advice to your style.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(StyleGender.allCases) { option in
                    Button {
                        gender = option
                        step = .meet
                    } label: {
                        HStack {
                            Text(option.title(in: appState.preferredLanguage))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .opacity(0.5)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, Theme.Spacing.md)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
                        .overlay(RoundedRectangle(cornerRadius: Theme.CornerRadius.large).stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.premiumPressable)
                }
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .foregroundStyle(.white)
    }

    private func advanceFromName() {
        guard !trimmedName.isEmpty else { return }
        nameFieldFocused = false
        step = .gender
    }

    private func badge(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 96, height: 96)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
    }

    private func primaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(.white.opacity(enabled ? 1 : 0.4), in: Capsule())
        }
        .buttonStyle(.premiumPressable)
        .disabled(!enabled)
        .padding(.top, Theme.Spacing.sm)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach([Step.intro, .name, .gender, .meet], id: \.rawValue) { dot in
                Capsule()
                    .fill(.white.opacity(dot == step ? 0.95 : 0.3))
                    .frame(width: dot == step ? 22 : 8, height: 8)
            }
        }
    }
}

// MARK: - Animated background

private struct AuroraBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.05, blue: 0.11), Color(red: 0.11, green: 0.08, blue: 0.17)],
                startPoint: .top,
                endPoint: .bottom
            )

            blob(.orange, size: 340, x: animate ? -90 : -50, y: animate ? -220 : -170)
            blob(.purple, size: 320, x: animate ? 130 : 80, y: animate ? -70 : -30)
            blob(.pink, size: 300, x: animate ? -70 : -20, y: animate ? 240 : 280)
            blob(Color(red: 1, green: 0.84, blue: 0), size: 280, x: animate ? 150 : 100, y: animate ? 280 : 320)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 90)
            .opacity(0.5)
            .offset(x: x, y: y)
    }
}
