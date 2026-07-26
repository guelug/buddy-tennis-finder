import { useEffect } from "react";
import { Stack } from "expo-router/stack";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import { ActivityIndicator, Platform, Text, View } from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { LayoutAnimationConfig } from "react-native-reanimated";
import { AuthProvider } from "@/lib/firebase-auth";
import { I18nProvider, useI18n } from "@/lib/i18n";
import { detectDeviceLanguage, DICTIONARIES, FALLBACK_LANGUAGE, translate } from "@/lib/i18n-catalog";
import { AppErrorBoundary } from "@/components/app-error-boundary";
import { AuthGate } from "@/components/auth-gate";
import { PurchaseProvider } from "@/components/purchase-provider";
import { initCrashReporting } from "@/lib/crash-reporting";
import { useAppFonts } from "@/lib/use-app-fonts";
import { colors, ThemeModeProvider, useThemeMode } from "@/theme";

void SplashScreen.preventAutoHideAsync().catch((error: unknown) => {
  console.warn("[matchpoint] No se pudo mantener el splash nativo", error);
});

initCrashReporting();

export default function RootLayout() {
  const fontsLoaded = useAppFonts();

  useEffect(() => {
    if (!fontsLoaded) return;
    void SplashScreen.hideAsync().catch((error: unknown) => {
      console.warn("[matchpoint] No se pudo cerrar el splash nativo", error);
    });
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return (
      <GestureHandlerRootView style={{ flex: 1 }}>
        <View style={{ alignItems: "center", backgroundColor: colors.background, flex: 1, gap: 16, justifyContent: "center" }}>
          <ActivityIndicator color={colors.neon as string} size="large" />
          <Text style={{ color: colors.textSecondary, fontSize: 15, fontWeight: "600", letterSpacing: 0.1 }}>
            {translate(DICTIONARIES[detectDeviceLanguage()], DICTIONARIES[FALLBACK_LANGUAGE], "common.openingApp")}
          </Text>
        </View>
      </GestureHandlerRootView>
    );
  }

  return (
    <LayoutAnimationConfig skipEntering={Platform.OS === "android"} skipExiting={Platform.OS === "android"}>
      <ThemeModeProvider>
        <I18nProvider>
          <AppErrorBoundary>
            <RootLayoutContent />
          </AppErrorBoundary>
        </I18nProvider>
      </ThemeModeProvider>
    </LayoutAnimationConfig>
  );
}

function RootLayoutContent() {
  const { isLight } = useThemeMode();
  const { t } = useI18n();

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: isLight ? "#F6F9F3" : colors.background }}>
      <AuthProvider>
        <PurchaseProvider>
          <AuthGate>
            <Stack
              screenOptions={{
                headerLargeTitle: false,
                headerShadowVisible: false,
                headerStyle: { backgroundColor: colors.surface },
                headerTintColor: colors.textPrimary,
                headerTitleStyle: { color: colors.textPrimary, fontWeight: "700" },
                contentStyle: { backgroundColor: colors.background },
                statusBarTranslucent: false
              }}
            >
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
              <Stack.Screen name="login" options={{ title: t("nav.login"), headerShown: false }} />
              <Stack.Screen name="onboarding" options={{ headerShown: false }} />
              <Stack.Screen name="player/[id]" options={{ headerShown: false }} />
              <Stack.Screen name="coaches" options={{ title: t("nav.coaches") }} />
              <Stack.Screen name="coach/[id]" options={{ title: t("nav.coachProfile") }} />
              <Stack.Screen name="coach-ad" options={{ title: t("nav.coachAd"), presentation: "modal" }} />
              <Stack.Screen name="coach-interests" options={{ title: t("profile.coachInterests") }} />
              <Stack.Screen name="league/[id]" options={{ title: t("nav.myLeague") }} />
              <Stack.Screen name="private-leagues" options={{ title: t("profile.privateLeagues") }} />
              <Stack.Screen name="private-league" options={{ title: t("nav.privateLeague") }} />
              <Stack.Screen name="invite" options={{ title: t("nav.inviteFriends") }} />
              <Stack.Screen name="assistant" options={{ title: "MatchPoint Assistant" }} />
              <Stack.Screen name="privacy" options={{ title: t("profile.privacy") }} />
              <Stack.Screen name="terms" options={{ title: t("profile.terms") }} />
              <Stack.Screen name="delete-account" options={{ title: t("nav.deleteAccount") }} />
              <Stack.Screen name="support" options={{ title: t("support.title") }} />
            </Stack>
          </AuthGate>
        </PurchaseProvider>
      </AuthProvider>
      <StatusBar style={isLight ? "dark" : "light"} />
    </GestureHandlerRootView>
  );
}
