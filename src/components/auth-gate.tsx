import { ReactNode, useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import Animated, { FadeIn, FadeInUp, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from "react-native-reanimated";
import { useGlobalSearchParams, usePathname, useRouter, useRootNavigationState } from "expo-router";
import { useAuth } from "@/lib/firebase-auth";
import { subscribeToPlayer } from "@/lib/firestore";
import { useI18n } from "@/lib/i18n";
import { PrimaryButton } from "@/components/primary-button";
import { colors, radii, spacing, typography } from "@/theme";
import { useThemeMode } from "@/theme/theme-mode";
import { Player } from "@/types";

/**
 * Puerta de autenticación:
 *  - Muestra un loader hasta resolver el primer estado de auth.
 *  - Con sesión pero perfil incompleto → /onboarding (efecto, con navigator ya montado).
 *  - El redirect "sin sesión → /login" NO vive aquí: lo declara app/(tabs)/_layout
 *    con <Redirect>, porque navegar imperativamente antes de montar el Stack lanza
 *    ("Attempted to navigate before mounting the Root Layout").
 *
 * Importante: cuando auth ya resolvió SIEMPRE renderizamos children (el Stack);
 * si no, el navigator nunca monta y ninguna redirección puede ocurrir.
 */
export function AuthGate({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const { user, loading, isConfigured } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useGlobalSearchParams<Record<string, string | string[]>>();
  const rootNavigationState = useRootNavigationState();
  const navReady = Boolean(rootNavigationState?.key);
  const [player, setPlayer] = useState<Player | null>(null);
  const [playerLoading, setPlayerLoading] = useState(true);
  const [resolvedPlayerUid, setResolvedPlayerUid] = useState<string | null>(null);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);
  const [loadingStep, setLoadingStep] = useState(0);

  // Suscripción al perfil del usuario autenticado.
  useEffect(() => {
    if (!user) {
      setPlayer(null);
      setPlayerLoading(false);
      setResolvedPlayerUid(null);
      setProfileError(null);
      return;
    }
    setPlayerLoading(true);
    setResolvedPlayerUid(null);
    setProfileError(null);
    const timeout = setTimeout(() => {
      setProfileError(t("authGate.timeout"));
      setPlayerLoading(false);
      setResolvedPlayerUid(user.uid);
    }, 12000);
    const unsubscribe = subscribeToPlayer(user.uid, (next) => {
      clearTimeout(timeout);
      setPlayer(next);
      setResolvedPlayerUid(user.uid);
      setProfileError(null);
      setPlayerLoading(false);
    }, (error) => {
      clearTimeout(timeout);
      setPlayer(null);
      setResolvedPlayerUid(user.uid);
      setProfileError(error.message || t("authGate.profileFallback"));
      setPlayerLoading(false);
    });
    return () => { clearTimeout(timeout); unsubscribe(); };
  }, [user, retryKey]);

  useEffect(() => {
    if (!loading && !(user && playerLoading)) return;
    const timer = setInterval(() => setLoadingStep((step) => Math.min(step + 1, 2)), 1050);
    return () => clearInterval(timer);
  }, [loading, user, playerLoading]);

  // Sesión con perfil incompleto → onboarding. Aquí el Stack ya está montado
  // (renderizamos children cuando hay usuario), así que navegar es seguro.
  // Si el usuario está en onboarding y el perfil ya está completo, lo devolvemos
  // a la app para evitar quedarse atrapado en la bienvenida.
  useEffect(() => {
    if (!navReady || loading || !isConfigured || !user || profileError || resolvedPlayerUid !== user.uid) return;
    if (!playerLoading && player?.profileComplete) {
      if (pathname === "/onboarding") {
        router.replace("/(tabs)");
      }
      return;
    }
    if (!playerLoading && (!player || !player.profileComplete) && pathname !== "/onboarding") {
      router.replace("/onboarding");
    }
  }, [navReady, user, loading, player, playerLoading, resolvedPlayerUid, profileError, isConfigured, router, pathname]);

  // Las rutas fuera de las tabs también son privadas. Si una invitación se
  // abre sin sesión, enviamos al login conservando liga y código para volver
  // exactamente al mismo punto después de autenticarse.
  useEffect(() => {
    if (!navReady || loading || !isConfigured || user || pathname === "/login") return;
    const activePathname = webPathname(pathname);
    const publicPaths = new Set(["/", "/privacy", "/terms", "/support"]);
    if (publicPaths.has(activePathname)) return;
    const query = Object.entries(searchParams).flatMap(([key, value]) => {
      if (key === "returnTo") return [];
      const values = Array.isArray(value) ? value : [value];
      return values.filter((item): item is string => typeof item === "string").map((item) => `${encodeURIComponent(key)}=${encodeURIComponent(item)}`);
    }).join("&");
    const returnTo = `${activePathname}${query ? `?${query}` : ""}`;
    router.replace({ pathname: "/login", params: { returnTo } });
  }, [navReady, loading, isConfigured, user, pathname, searchParams, router]);

  // En una carga directa de Hosting, el shell estático puede hidratar un
  // instante como `/` aunque la barra del navegador conserve `/liga` u otra
  // ruta. Tras resolver Auth recuperamos esa ruta real. Solo actúa en web y
  // nunca modifica la navegación nativa de Android/iOS.
  useEffect(() => {
    if (!navReady || loading || !isConfigured || !user || pathname !== "/") return;
    const activePathname = webPathname(pathname);
    if (activePathname !== "/") router.replace(activePathname as never);
  }, [navReady, loading, isConfigured, user, pathname, router]);

  if (loading || (user && (playerLoading || resolvedPlayerUid !== user.uid))) {
    return (
      <WelcomeLoader step={loadingStep} firstProfile={Boolean(user)} />
    );
  }

  if (user && profileError) {
    return <ProfileLoadError message={profileError} onRetry={() => setRetryKey((value) => value + 1)} />;
  }

  return <>{children}</>;
}

function webPathname(fallback: string) {
  if (process.env.EXPO_OS !== "web" || typeof window === "undefined") return fallback;
  const pathname = window.location.pathname.replace(/\.html$/, "");
  return pathname.startsWith("/") && pathname.length > 0 ? pathname : fallback;
}

function ProfileLoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  return (
    <View style={{ alignItems: "center", backgroundColor: colors.background, flex: 1, justifyContent: "center", padding: spacing.xxl }}>
      <View style={{ alignItems: "center", backgroundColor: colors.surface, borderColor: colors.borderStrong, borderRadius: radii.xl, borderWidth: 1, boxShadow: isLight ? "0 14px 36px rgba(27,55,36,.12)" : "0 18px 44px rgba(0,0,0,.42)", gap: spacing.md, maxWidth: 420, padding: spacing.xl, width: "100%" }}>
        <View style={{ alignItems: "center", backgroundColor: colors.warningBg, borderRadius: radii.xl, height: 64, justifyContent: "center", width: 64 }}>
          <Text style={{ color: colors.warning, fontSize: 30 }}>!</Text>
        </View>
        <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>{t("authGate.errorTitle")}</Text>
        <Text selectable style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{message}</Text>
        <PrimaryButton label={t("authGate.retry")} onPress={onRetry} />
      </View>
    </View>
  );
}

function WelcomeLoader({ step, firstProfile }: { step: number; firstProfile: boolean }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const rotation = useSharedValue(0);
  useEffect(() => { rotation.value = withRepeat(withTiming(360, { duration: 2400 }), -1, false); }, [rotation]);
  const spin = useAnimatedStyle(() => ({ transform: [{ rotate: `${rotation.value}deg` }] }));
  const messages = firstProfile
    ? [t("authGate.first.0"), t("authGate.first.1"), t("authGate.first.2")]
    : [t("authGate.returning.0"), t("authGate.returning.1"), t("authGate.returning.2")];
  const progress = firstProfile ? [32, 68, 92][step] : [38, 72, 94][step];
  return (
    <View style={[styles.center, { backgroundColor: colors.background }]}>
      <View style={styles.radar}>
        <View style={[styles.radarRing, { borderColor: isLight ? "rgba(82,122,0,.25)" : "rgba(198,241,53,.28)" }]} />
        <Animated.View style={[styles.scanLine, { backgroundColor: colors.court, boxShadow: isLight ? "0 0 10px rgba(82,122,0,.24)" : "0 0 14px #C6F135" }, spin]} />
        <Text style={[styles.ball, { color: colors.court, textShadowColor: colors.court }]}>●</Text>
      </View>
      <Animated.Text entering={FadeInUp.duration(400)} key={messages[step]} style={[styles.title, { color: colors.textPrimary }]}>{messages[step]}</Animated.Text>
      <Text style={[styles.loadingText, { color: colors.textSecondary }]}>{firstProfile ? t("authGate.firstBody") : t("authGate.returningBody")}</Text>
      <View style={[styles.progressTrack, { backgroundColor: colors.surfaceElevated }]}><Animated.View entering={FadeIn.duration(300)} style={[styles.progressFill, { backgroundColor: colors.court, boxShadow: isLight ? undefined : "0 0 12px rgba(198,241,53,.65)", width: `${progress}%` }]} /></View>
      <Text style={[styles.progressLabel, { color: colors.court }]}>{progress}%</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { alignItems: "center", flex: 1, justifyContent: "center", paddingHorizontal: 32 },
  radar: { alignItems: "center", height: 126, justifyContent: "center", marginBottom: 26, width: 126 },
  radarRing: { borderRadius: 63, borderWidth: 1, height: 126, position: "absolute", width: 126 },
  scanLine: { borderRadius: 2, height: 2, left: 63, position: "absolute", transformOrigin: "left center", width: 58 },
  ball: { fontSize: 64, lineHeight: 68, textShadowRadius: 22 },
  title: { fontSize: 24, fontWeight: "800", marginBottom: 8 },
  loadingText: { fontSize: 14, textAlign: "center" },
  progressTrack: { borderRadius: 20, height: 7, marginTop: 28, maxWidth: 330, overflow: "hidden", width: "100%" },
  progressFill: { borderRadius: 20, height: "100%" },
  progressLabel: { fontSize: 12, fontWeight: "800", marginTop: 8 }
});
