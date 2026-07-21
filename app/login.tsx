import { useEffect, useState } from "react";
import { Alert, Platform, Pressable, ScrollView, Text, TextInput, useWindowDimensions, View } from "react-native";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { SafeAreaView } from "react-native-safe-area-context";
import { router, useLocalSearchParams, useRootNavigationState } from "expo-router";
import Constants from "expo-constants";
import { Card } from "@/components/card";
import { PrimaryButton } from "@/components/primary-button";
import { Icon } from "@/components/icon";
import { GoogleLogo } from "@/components/icons/google-logo";
import { AppleLogo } from "@/components/icons/apple-logo";
import { BrandLockup } from "@/components/brand-lockup";
import { TennisBall } from "@/components/tennis-ball";
import { bgLoginLive, bgLoginLiveLight, LandingFeatureCards, LiveBackground, LiveBallStage } from "@/components/live-visuals";
import {
  describeAuthError,
  isNativeGoogleAuthConfigured,
  resetPassword,
  signInWithApple,
  signInWithEmail,
  signInWithGoogleNative,
  signInWithGooglePopup,
  signUpWithEmail,
  useAuth
} from "@/lib/firebase-auth";
import { broadcast, colors, radii, shadows, spacing, typography, useBreakpoint, useThemeMode } from "@/theme";

type EmailMode = "signin" | "signup";

export default function LoginScreen() {
  const appVersion = Constants.expoConfig?.version ?? "1.0.4";
  const { isConfigured, user } = useAuth();
  // El root layout puede no estar montado aún cuando `user` cambia (p. ej. justo
  // tras registrarse); esperamos a que el navigator tenga key antes de navegar,
  // o expo-router lanza "Attempted to navigate before mounting the Root Layout".
  const rootNavigationState = useRootNavigationState();
  const { returnTo } = useLocalSearchParams<{ returnTo?: string }>();
  const navReady = Boolean(rootNavigationState?.key);
  const { height: viewportHeight } = useWindowDimensions();
  const { isDesktop } = useBreakpoint();
  const { isLight, toggleMode } = useThemeMode();
  const [busy, setBusy] = useState<"google" | "apple" | "email" | null>(null);

  // --- Email + contraseña ---
  const [emailMode, setEmailMode] = useState<EmailMode>("signin");
  const [emailFormOpen, setEmailFormOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [emailError, setEmailError] = useState<string | null>(null);

  // --- Anti-spam (sin dependencias externas; ver también App Check en firebase.config.ts) ---
  // Honeypot: campo invisible para personas, que los bots de registro masivo
  // rellenan igual porque no "ven" el formulario, solo el DOM/HTML.
  const [honeypot, setHoneypot] = useState("");
  // Time-trap: un registro completado en <900ms desde que se abrió el
  // formulario es casi seguro un script, no una persona escribiendo.
  const [formOpenedAt, setFormOpenedAt] = useState<number | null>(null);
  // Cooldown progresivo tras varios intentos fallidos seguidos (fuerza bruta
  // de contraseñas / credential stuffing contra una cuenta).
  const [failedAttempts, setFailedAttempts] = useState(0);
  const [cooldownUntil, setCooldownUntil] = useState<number | null>(null);

  // Única fuente de navegación post-login: en cuanto hay sesión, salimos de
  // /login hacia /(tabs). Si el perfil está incompleto, AuthGate (que envuelve
  // todo el Stack) redirige a /onboarding — no duplicamos esa consulta aquí,
  // porque hacerlo en paralelo genera una carrera: AuthGate vuelve a mostrar su
  // loader (desmontando este Stack/pantalla) justo cuando `user` cambia, así
  // que un router.replace() propio puede disparar sobre un Stack ya desmontado
  // ("Attempted to navigate before mounting the Root Layout").
  useEffect(() => {
    if (!navReady || !user) return;
    const safeReturnTo = typeof returnTo === "string"
      && returnTo.startsWith("/")
      && !returnTo.startsWith("//")
      && returnTo.length <= 500
      ? returnTo
      : "/(tabs)";
    router.replace(safeReturnTo as never);
  }, [navReady, user, returnTo]);

  async function handleGoogle() {
    if (Platform.OS === "web") {
      try {
        setBusy("google");
        await signInWithGooglePopup();
        // La navegación la realiza el efecto que observa `user`, cuando
        // AuthProvider ya confirmó y persistió la sesión.
      } catch (error) {
        Alert.alert("No pudimos iniciar sesión con Google", describeError(error));
      } finally {
        setBusy(null);
      }
      return;
    }

    if (!isNativeGoogleAuthConfigured()) {
      Alert.alert(
        "Google todavía no está configurado en este dispositivo",
        Platform.OS === "android"
          ? "Falta registrar el OAuth Client ID de Android. Mientras tanto puedes entrar con correo y contraseña."
          : "Falta registrar el OAuth Client ID de iOS. Mientras tanto puedes entrar con correo y contraseña."
      );
      return;
    }
    try {
      setBusy("google");
      await signInWithGoogleNative();
    } catch (error) {
      Alert.alert("No pudimos iniciar sesión con Google", describeError(error));
    } finally {
      setBusy(null);
    }
  }

  async function handleApple() {
    try {
      setBusy("apple");
      await signInWithApple();
    } catch (error) {
      if ((error as { code?: string })?.code === "ERR_CANCELED") return;
      Alert.alert("No pudimos iniciar sesión con Apple", describeError(error));
    } finally {
      setBusy(null);
    }
  }

  async function handleEmailSubmit() {
    setEmailError(null);

    // Cooldown activo: bloqueamos antes de tocar red o Firebase.
    if (cooldownUntil && Date.now() < cooldownUntil) {
      const secondsLeft = Math.ceil((cooldownUntil - Date.now()) / 1000);
      setEmailError(`Demasiados intentos. Espera ${secondsLeft}s y vuelve a intentar.`);
      return;
    }

    // Honeypot relleno → tráfico automatizado. No llamamos a Firebase (evita
    // gastar cuota) ni damos pistas de qué falló.
    if (honeypot.trim().length > 0) {
      setEmailError("No pudimos procesar la solicitud. Intenta de nuevo.");
      return;
    }

    // Formulario completado sospechosamente rápido (solo al crear cuenta).
    if (emailMode === "signup" && formOpenedAt && Date.now() - formOpenedAt < 900) {
      setEmailError("Tómate un segundo e inténtalo de nuevo.");
      return;
    }

    const trimmedEmail = email.trim();
    if (!trimmedEmail || !password) {
      setEmailError("Escribe tu correo y contraseña.");
      return;
    }
    if (emailMode === "signup" && password.length < 6) {
      setEmailError("La contraseña debe tener al menos 6 caracteres.");
      return;
    }
    try {
      setBusy("email");
      if (emailMode === "signup") {
        await signUpWithEmail(trimmedEmail, password, name);
      } else {
        await signInWithEmail(trimmedEmail, password);
      }
      // La navegación la realiza el efecto que observa `user`.
      setFailedAttempts(0);
    } catch (error) {
      setEmailError(describeAuthError(error));
      setFailedAttempts((count) => {
        const next = count + 1;
        if (next >= 5) {
          setCooldownUntil(Date.now() + 30_000);
          return 0;
        }
        return next;
      });
    } finally {
      setBusy(null);
    }
  }

  async function handleForgotPassword() {
    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setEmailError("Escribe tu correo arriba para poder enviarte el enlace.");
      return;
    }
    try {
      setBusy("email");
      await resetPassword(trimmedEmail);
      Alert.alert("Correo enviado", `Te enviamos un enlace para restablecer tu contraseña a ${trimmedEmail}.`);
    } catch (error) {
      setEmailError(describeAuthError(error));
    } finally {
      setBusy(null);
    }
  }

  // Apple web necesita Service ID + redirect OAuth propio. Hasta configurarlo,
  // mostramos el botón únicamente donde el flujo nativo está implementado.
  const showApple = Platform.OS === "ios";
  const showGoogle = true;
  const pageBackground = isLight ? "#EEF5E9" : colors.background;
  const cardBackground = isLight ? "rgba(255,255,255,0.92)" : "rgba(15,23,17,0.88)";
  const cardBorder = isLight ? "rgba(77,143,25,0.20)" : `${colors.neon}28`;
  const textPrimary = isLight ? "#102016" : colors.textPrimary;
  const textSecondary = isLight ? "#53635A" : colors.textSecondary;
  const textTertiary = isLight ? "#748176" : colors.textTertiary;

  const loginCard = (
    <Animated.View entering={FadeInUp.delay(120).duration(520)} style={{ width: "100%", maxWidth: 440 }}>
      <Card
        variant="glass"
        pad={isDesktop ? "xl" : "lg"}
        style={{
          backgroundColor: cardBackground,
          borderColor: cardBorder,
          boxShadow: shadows.floating
        }}
      >
        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.md, marginBottom: spacing.md }}>
          <View
            style={{
              alignItems: "center",
              backgroundColor: colors.courtLight,
              borderRadius: radii.lg,
              height: 48,
              justifyContent: "center",
              width: 48
            }}
          >
            <TennisBall size={30} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ ...broadcast.jersey, color: colors.neon, fontSize: 12, letterSpacing: 2 }}>
              MATCHPOINT TENNIS
            </Text>
            <Text style={{ ...typography.footnote, color: textSecondary }}>
              Rivales, reservas y comunidad de club
            </Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={isLight ? "Activar modo oscuro" : "Activar modo claro"}
            onPress={toggleMode}
            style={{
              alignItems: "center",
              backgroundColor: isLight ? "rgba(15,32,22,0.07)" : "rgba(255,255,255,0.08)",
              borderColor: isLight ? "rgba(77,143,25,0.16)" : "rgba(255,255,255,0.12)",
              borderRadius: radii.pill,
              borderWidth: 1,
              height: 48,
              justifyContent: "center",
              width: 48
            }}
          >
            <Icon name={isLight ? "globe" : "zap"} size={17} color={isLight ? colors.court : colors.neon} weight="bold" />
          </Pressable>
        </View>

        <View style={{ gap: spacing.xs, marginBottom: spacing.lg }}>
          <Text style={{ ...typography.title, color: textPrimary, fontSize: 26 }}>
            Inicia sesión
          </Text>
          <Text style={{ ...typography.body, color: textSecondary }}>
            Entra para guardar tu perfil, encontrar rivales y gestionar tus reservas.
          </Text>
        </View>

        <View style={{ gap: spacing.sm }}>
          <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
            <View
              style={{
                backgroundColor: isLight ? "rgba(77,143,25,0.12)" : "rgba(198,241,53,0.14)",
                borderRadius: radii.pill,
                paddingHorizontal: spacing.sm,
                paddingVertical: 4
              }}
            >
              <Text
                style={{
                  ...broadcast.jersey,
                  color: isLight ? colors.court : colors.neon,
                  fontSize: 10,
                  letterSpacing: 1.4
                }}
              >
                RECOMENDADO
              </Text>
            </View>
            <Text style={{ ...typography.footnote, color: textTertiary }}>
              La forma más rápida de entrar
            </Text>
          </View>

          {showGoogle ? (
            <PrimaryButton
              label={busy === "google" ? "Conectando..." : "Continuar con Google"}
              onPress={handleGoogle}
              disabled={busy !== null}
              variant="solid"
              size="lg"
              textColor="#1F1F1F"
              style={{
                backgroundColor: "#FFFFFF",
                borderColor: "rgba(31,31,31,0.18)",
                borderWidth: 1,
                boxShadow: isLight
                  ? "0 10px 26px -8px rgba(35,73,30,0.34)"
                  : "0 10px 30px -8px rgba(198,241,53,0.32)",
                height: 58
              }}
              icon={<GoogleLogo size={21} />}
            />
          ) : null}

          {showApple ? (
            <PrimaryButton
              label={busy === "apple" ? "Conectando..." : "Continuar con Apple"}
              onPress={handleApple}
              disabled={busy !== null}
              variant="solid"
              size="lg"
              textColor="#FFFFFF"
              style={{ backgroundColor: "#000000" }}
              icon={<AppleLogo size={20} color="#FFFFFF" />}
            />
          ) : null}

          {!emailFormOpen ? (
            <>
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm, paddingVertical: 2 }}>
                <View style={{ backgroundColor: cardBorder, flex: 1, height: 1 }} />
                <Text style={{ ...typography.footnote, color: textTertiary }}>o usa otra opción</Text>
                <View style={{ backgroundColor: cardBorder, flex: 1, height: 1 }} />
              </View>
              <PrimaryButton
                label="Entrar con correo"
                onPress={() => {
                  setEmailFormOpen(true);
                  setFormOpenedAt(Date.now());
                }}
                disabled={busy !== null}
                variant="ghost"
                size="md"
                style={{ backgroundColor: isLight ? "rgba(15,32,22,0.04)" : "rgba(255,255,255,0.04)" }}
                icon={<Icon name="user" size={17} color={textSecondary} />}
              />
            </>
          ) : null}
        </View>

        {emailFormOpen ? (
          <Animated.View entering={FadeIn.duration(200)} style={{ gap: spacing.sm, marginTop: spacing.md }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <View style={{ backgroundColor: cardBorder, flex: 1, height: 1 }} />
              <Text style={{ ...typography.footnote, color: textTertiary }}>
                {emailMode === "signup" ? "Crear cuenta" : "Iniciar sesión"}
              </Text>
              <View style={{ backgroundColor: cardBorder, flex: 1, height: 1 }} />
            </View>

            {/* Honeypot: invisible y no navegable para personas (aria-hidden +
                fuera de pantalla), pero presente en el DOM para que los bots
                de registro masivo lo rellenen igual. Si llega con contenido,
                tratamos el envío como spam. */}
            <TextInput
              value={honeypot}
              onChangeText={setHoneypot}
              placeholder="Sitio web"
              autoComplete="off"
              importantForAccessibility="no-hide-descendants"
              accessibilityElementsHidden
              tabIndex={-1}
              {...({ "aria-hidden": true } as object)}
              style={{ height: 0, opacity: 0, position: "absolute", width: 0 }}
            />

            {emailMode === "signup" ? (
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder="Tu nombre"
                placeholderTextColor={textTertiary}
                autoCapitalize="words"
                style={[emailInputStyle, { borderColor: cardBorder, color: textPrimary }]}
              />
            ) : null}
            <TextInput
              value={email}
              onChangeText={setEmail}
              placeholder="Correo electrónico"
              placeholderTextColor={textTertiary}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
              textContentType="emailAddress"
              style={[emailInputStyle, { borderColor: cardBorder, color: textPrimary }]}
            />
            <TextInput
              value={password}
              onChangeText={setPassword}
              placeholder="Contraseña"
              placeholderTextColor={textTertiary}
              secureTextEntry
              textContentType={emailMode === "signup" ? "newPassword" : "password"}
              style={[emailInputStyle, { borderColor: cardBorder, color: textPrimary }]}
            />

            {emailError ? (
              <Text style={{ ...typography.footnote, color: colors.danger }}>{emailError}</Text>
            ) : null}

            <PrimaryButton
              label={
                busy === "email"
                  ? "Un momento..."
                  : emailMode === "signup"
                    ? "Crear cuenta"
                    : "Iniciar sesión"
              }
              onPress={handleEmailSubmit}
              disabled={busy !== null}
              size="lg"
            />

            <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
              <Pressable
                onPress={() => {
                  setEmailError(null);
                  setFormOpenedAt(Date.now());
                  setEmailMode((mode) => (mode === "signup" ? "signin" : "signup"));
                }}
                disabled={busy !== null}
              >
                <Text style={{ ...typography.footnote, color: isLight ? colors.court : colors.neon, fontWeight: "700" }}>
                  {emailMode === "signup" ? "Ya tengo cuenta" : "Crear cuenta nueva"}
                </Text>
              </Pressable>
              {emailMode === "signin" ? (
                <Pressable onPress={handleForgotPassword} disabled={busy !== null}>
                  <Text style={{ ...typography.footnote, color: textSecondary }}>
                    Olvidé mi contraseña
                  </Text>
                </Pressable>
              ) : null}
            </View>
          </Animated.View>
        ) : null}

        {!isConfigured ? (
          <Pressable
            onPress={() => router.replace("/")}
            style={({ pressed }) => ({
              alignItems: "center",
              backgroundColor: pressed ? "rgba(198,241,53,0.20)" : colors.courtLight,
              borderColor: `${colors.neon}36`,
              borderRadius: radii.pill,
              borderWidth: 1,
              marginTop: spacing.lg,
              paddingHorizontal: spacing.md,
              paddingVertical: spacing.sm
            })}
          >
            <Text style={{ ...typography.caption, color: colors.neon }}>
              Entrar en modo demo
            </Text>
          </Pressable>
        ) : null}

        <Text
          style={{
            ...typography.footnote,
            color: textTertiary,
            marginTop: spacing.lg,
            textAlign: "center"
          }}
        >
          Al continuar aceptas la Política de Privacidad.{"\n"}No vendemos tus datos a terceros.
        </Text>
      </Card>
    </Animated.View>
  );

  // -------------------------------------------------------------------------
  // Desktop (≥1024): split-screen — panel de marca a la izquierda, login a la derecha.
  // -------------------------------------------------------------------------
  if (isDesktop) {
    return (
      <View style={{ flex: 1, flexDirection: "row", backgroundColor: pageBackground, minHeight: viewportHeight, overflow: "hidden" }}>
        <LiveBackground
          source={bgLoginLive}
          lightSource={bgLoginLiveLight}
          overlay={isLight ? 0.32 : 0.46}
          style={{
            flex: 1.15,
            minWidth: 0,
            width: "auto",
            justifyContent: "center",
            overflow: "hidden",
            padding: spacing.xxxl
          }}
        >
          <Animated.View entering={FadeIn.duration(600)} style={{ gap: spacing.xl, maxWidth: 720, alignSelf: "center", width: "100%" }}>
            <BrandLockup size="lg" light={isLight} />

            <View style={{ flexDirection: "row", alignItems: "center", gap: spacing.xl, flexWrap: "wrap" }}>
              <View style={{ flex: 1, gap: spacing.lg, minWidth: 280 }}>
                <Text
                  style={{
                    ...broadcast.hero,
                    color: isLight ? "#102016" : "#FFFFFF",
                    fontSize: 50,
                    lineHeight: 52,
                    textShadowColor: isLight ? "rgba(255,255,255,0.6)" : "rgba(2,5,3,0.85)",
                    textShadowOffset: { width: 0, height: 2 },
                    textShadowRadius: 14
                  }}
                >
                  Tu club.{"\n"}Tus rivales.{"\n"}
                  <Text style={{ color: colors.neon }}>Tu momento.</Text>
                </Text>
                <Text style={{ ...typography.body, color: isLight ? "rgba(16,32,22,0.72)" : "rgba(255,255,255,0.78)", fontSize: 16, lineHeight: 24 }}>
                  Una app para encontrar rivales, publicar reservas y construir tu comunidad de tenis. Equipos y resultados llegarán por fases.
                </Text>
              </View>
              <LiveBallStage label="APP" size={120} />
            </View>

            <LandingFeatureCards />
          </Animated.View>
        </LiveBackground>

        <View
          style={{
            flex: 0.85,
            minWidth: 420,
            alignItems: "center",
            justifyContent: "center",
            padding: spacing.xxl,
            position: "relative",
            zIndex: 2
          }}
        >
          {loginCard}
        </View>
      </View>
    );
  }

  // -------------------------------------------------------------------------
  // Móvil / tablet (<1024): fondo de marca a pantalla completa + branding + card.
  // Layout compacto que cabe en una pantalla sin scroll (como el concepto).
  // -------------------------------------------------------------------------
  return (
    <LiveBackground
      source={bgLoginLive}
      lightSource={bgLoginLiveLight}
      overlay={isLight ? 0.5 : 0.55}
      style={{ flex: 1 }}
    >
      <SafeAreaView style={{ flex: 1 }}>
        <ScrollView
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          style={{ flex: 1, overscrollBehaviorY: "contain", touchAction: "pan-y" } as object}
          contentContainerStyle={{
            flexGrow: 1,
            alignItems: "center",
            justifyContent: "space-between",
            paddingHorizontal: spacing.base,
            paddingVertical: spacing.lg
          }}
        >
          {/* Branding compacto arriba (~25% de la pantalla) */}
          <Animated.View
            entering={FadeIn.duration(600)}
            style={{ alignItems: "center", gap: spacing.sm, paddingTop: spacing.md }}
          >
            <View
              style={{
                alignItems: "center",
                backgroundColor: isLight ? "rgba(255,255,255,0.36)" : "rgba(7,12,8,0.42)",
                borderColor: isLight ? "rgba(77,143,25,0.22)" : `${colors.neon}30`,
                borderRadius: 999,
                height: 72,
                justifyContent: "center",
                width: 72
              }}
            >
              <TennisBall size={48} />
            </View>
            <Text style={{ ...typography.title, color: textPrimary, textAlign: "center", fontSize: 20 }}>
              MatchPoint Tennis
            </Text>
            <Text
              style={{
                ...typography.body,
                color: textSecondary,
                textAlign: "center",
                maxWidth: 280,
                fontSize: 13,
                lineHeight: 18
              }}
            >
              Encuentra rivales, arma equipos y organiza partidos.
            </Text>
          </Animated.View>

          {/* Card de login al centro/abajo (~55%) */}
          <View style={{ width: "100%", maxWidth: 420 }}>{loginCard}</View>

          {/* Footer fino (~10%) */}
          <Pressable onPress={toggleMode} style={{ padding: spacing.sm }}>
            <Text style={{ ...typography.footnote, color: textTertiary, fontSize: 12 }}>
              {isLight ? "Modo oscuro" : "Modo claro"} · v{appVersion}
            </Text>
          </Pressable>
        </ScrollView>
      </SafeAreaView>
    </LiveBackground>
  );
}

function describeError(error: unknown) {
  if (error instanceof Error) return error.message;
  return "Intenta de nuevo en unos momentos.";
}

const emailInputStyle = {
  ...typography.body,
  borderRadius: radii.md,
  borderWidth: 1,
  height: 50,
  paddingHorizontal: spacing.md
} as const;
