import { useEffect } from "react";
import { Stack } from "expo-router/stack";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import { ActivityIndicator, Platform, Text, View } from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { LayoutAnimationConfig } from "react-native-reanimated";
import { AuthProvider } from "@/lib/firebase-auth";
import { I18nProvider } from "@/lib/i18n";
import { AppErrorBoundary } from "@/components/app-error-boundary";
import { AuthGate } from "@/components/auth-gate";
import { PurchaseProvider } from "@/components/purchase-provider";
import { useAppFonts } from "@/lib/use-app-fonts";
import { colors, ThemeModeProvider, useThemeMode } from "@/theme";

void SplashScreen.preventAutoHideAsync().catch((error: unknown) => {
  console.warn("[matchpoint] No se pudo mantener el splash nativo", error);
});

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
          <Text style={{ color: colors.textSecondary, fontSize: 15, fontWeight: "600", letterSpacing: 0.1 }}>Abriendo MatchPoint Tennis…</Text>
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
              <Stack.Screen name="login" options={{ title: "Iniciar sesión", headerShown: false }} />
              <Stack.Screen name="onboarding" options={{ headerShown: false }} />
              <Stack.Screen name="player/[id]" options={{ headerShown: false }} />
              <Stack.Screen name="coaches" options={{ title: "Entrenadores" }} />
              <Stack.Screen name="coach/[id]" options={{ title: "Perfil del entrenador" }} />
              <Stack.Screen name="coach-ad" options={{ title: "Anunciarme", presentation: "modal" }} />
              <Stack.Screen name="coach-interests" options={{ title: "Jugadores interesados" }} />
              <Stack.Screen name="private-leagues" options={{ title: "Ligas privadas" }} />
              <Stack.Screen name="private-league" options={{ title: "Liga privada" }} />
              <Stack.Screen name="invite" options={{ title: "Invitar amigos" }} />
              <Stack.Screen name="privacy" options={{ title: "Privacidad" }} />
              <Stack.Screen name="terms" options={{ title: "Términos de uso" }} />
              <Stack.Screen name="delete-account" options={{ title: "Eliminar cuenta" }} />
              <Stack.Screen name="support" options={{ title: "Soporte" }} />
            </Stack>
          </AuthGate>
        </PurchaseProvider>
      </AuthProvider>
      <StatusBar style={isLight ? "dark" : "light"} />
    </GestureHandlerRootView>
  );
}
