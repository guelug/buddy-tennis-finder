import * as React from "react";
import { Pressable, Text, View } from "react-native";
import { recordError } from "@/lib/crash-reporting";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";

type Props = React.PropsWithChildren<{
  /** Si se pasa, al fallar se renderiza esto en vez de la pantalla de reintento. */
  fallback?: React.ReactNode;
}>;

type State = { error: Error | null };

/**
 * Barrera de errores: sin ella, cualquier excepción de render en producción
 * deja la app en pantalla negra congelada (lo reportado en Samsung). Con ella,
 * el usuario ve un mensaje y puede reintentar sin reabrir la app.
 */
export class AppErrorBoundary extends React.Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.warn("[matchpoint] Error de render capturado:", error, info.componentStack);
    recordError(error, `render-error: ${info.componentStack?.slice(0, 200) ?? ""}`);
  }

  render() {
    if (!this.state.error) return this.props.children;
    if (this.props.fallback !== undefined) return this.props.fallback;
    return <ErrorScreen onRetry={() => this.setState({ error: null })} />;
  }
}

function ErrorScreen({ onRetry }: { onRetry: () => void }) {
  const { t } = useI18n();
  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: colors.background,
        flex: 1,
        gap: spacing.md,
        justifyContent: "center",
        padding: spacing.xl
      }}
    >
      <Text style={{ ...typography.title, color: colors.textPrimary, textAlign: "center" }}>
        {t("errors.title")}
      </Text>
      <Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>
        {t("errors.body")}
      </Text>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={t("common.retry")}
        onPress={onRetry}
        style={{
          backgroundColor: colors.accentFill,
          borderRadius: radii.pill,
          paddingHorizontal: spacing.xl,
          paddingVertical: spacing.md
        }}
      >
        <Text style={{ ...typography.headline, color: colors.onAccentFill, fontSize: 15 }}>{t("common.retry")}</Text>
      </Pressable>
    </View>
  );
}
