import { useEffect, useMemo, useRef, useState } from "react";
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { router } from "expo-router";
import Animated, { FadeInUp } from "react-native-reanimated";
import { Icon } from "@/components/icon";
import { LiveBackground } from "@/components/live-visuals";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { MatchBuddyAvatar, useMatchBuddy } from "@/components/match-buddy-picker";
import { useAuth } from "@/lib/firebase-auth";
import { SUPPORTED_LANGUAGES, useI18n } from "@/lib/i18n";
import {
  askMatchPointAssistant,
  getAssistantContext,
  getLocalAIAvailability,
  type AssistantAction,
  type AssistantContext
} from "@/lib/matchpoint-assistant";
import { colors, radii, spacing, typography } from "@/theme";

type Message = { id: string; role: "assistant" | "user"; text: string; actions?: AssistantAction[] };

const SUGGESTION_KEYS = [
  "assistant.suggestion.results",
  "assistant.suggestion.ranking",
  "assistant.suggestion.upcoming",
  "assistant.suggestion.search",
  "assistant.suggestion.league",
  "assistant.suggestion.improve"
];

export default function AssistantScreen() {
  const { user } = useAuth();
  const { buddy } = useMatchBuddy();
  const { t, lang } = useI18n();
  const insets = useSafeAreaInsets();
  const scrollRef = useRef<ScrollView>(null);
  const [context, setContext] = useState<AssistantContext | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [retryToken, setRetryToken] = useState(0);
  const [provider, setProvider] = useState(() => t("assistant.provider.basic"));
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const requestGeneration = useRef(0);
  const inFlight = useRef(false);

  // El modelo local debe responder en el idioma de la app; `Intl.DisplayNames`
  // no está garantizado en Hermes, así que usamos el propio catálogo.
  const languageName = useMemo(
    () => SUPPORTED_LANGUAGES.find((item) => item.code === lang)?.label ?? lang,
    [lang]
  );

  useEffect(() => {
    requestGeneration.current += 1;
    inFlight.current = false;
    setSending(false);
    setInput("");
    setMessages([{ id: "welcome", role: "assistant", text: t("assistant.welcome", { name: buddy.name }) }]);
    return () => { requestGeneration.current += 1; };
  }, [t, buddy.name, user?.uid]);

  useEffect(() => {
    let active = true;
    setContext(null);
    setLoadError(null);
    void Promise.all([getAssistantContext(user?.uid), getLocalAIAvailability()])
      .then(([value, availability]) => {
        if (!active) return;
        setContext(value);
        setProvider(describeProvider(availability.available ? availability.provider : "fallback", t));
      })
      .catch((error: unknown) => {
        // Sin contexto la pantalla no llega a renderizarse, así que el mensaje
        // dentro del chat no se veía nunca y quedaba un spinner eterno (por
        // ejemplo con el correo sin confirmar). Lo mostramos como estado.
        if (!active) return;
        setLoadError(error instanceof Error ? error.message : t("assistant.error"));
      });
    return () => { active = false; };
  }, [user?.uid, t, retryToken]);

  const send = async (preset?: string) => {
    const question = (preset ?? input).trim();
    if (!question || !context || inFlight.current) return;
    inFlight.current = true;
    const generation = requestGeneration.current;
    setInput("");
    setMessages((current) => [...current, { id: `u-${Date.now()}`, role: "user", text: question }]);
    setSending(true);
    try {
      const answer = await askMatchPointAssistant(question, context, t, languageName, buddy.name);
      if (generation !== requestGeneration.current) return;
      setProvider(describeProvider(answer.provider, t));
      setMessages((current) => [...current, { id: `a-${Date.now()}`, role: "assistant", text: answer.text, actions: answer.actions }]);
    } catch {
      if (generation !== requestGeneration.current) return;
      setMessages((current) => [...current, { id: `a-${Date.now()}`, role: "assistant", text: t("assistant.error") }]);
    } finally {
      if (generation === requestGeneration.current) {
        inFlight.current = false;
        setSending(false);
        requestAnimationFrame(() => scrollRef.current?.scrollToEnd({ animated: true }));
      }
    }
  };

  if (loadError) {
    return (
      <LiveBackground overlay={0.58}>
        <View style={{ alignItems: "center", flex: 1, gap: spacing.md, justifyContent: "center", padding: spacing.xl }}>
          <Icon name="close" size={28} color={colors.warning as string} />
          <Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{loadError}</Text>
          <PrimaryButton
            label={t("common.retry")}
            variant="outline"
            fullWidth={false}
            onPress={() => setRetryToken((value) => value + 1)}
          />
        </View>
      </LiveBackground>
    );
  }
  if (!context) return <LoadingView />;
  return (
    <LiveBackground overlay={0.58}>
      {/*
        En Android el sistema ya encoge la ventana (windowSoftInputMode
        adjustResize), así que KeyboardAvoidingView sobra y solo estorba. En
        iOS sí hace falta, y hay que descontarle la cabecera nativa del Stack:
        el componente mide su marco respecto al padre, que empieza bajo la
        cabecera, y sin este offset levanta de menos.
      */}
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        keyboardVerticalOffset={Platform.OS === "ios" ? insets.top + 44 : 0}
        style={{ flex: 1 }}
      >
        <ScrollView
          ref={scrollRef}
          style={{ flex: 1 }}
          contentInsetAdjustmentBehavior="automatic"
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="interactive"
          onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: false })}
          contentContainerStyle={{ gap: spacing.md, padding: spacing.base, paddingBottom: spacing.lg }}
        >
          <Animated.View entering={FadeInUp} style={{ backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.xl, borderWidth: 1, gap: spacing.sm, padding: spacing.lg }}>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.sm }}>
              <MatchBuddyAvatar size={48} />
              <View style={{ flex: 1 }}>
                <Text style={{ ...typography.headline, color: colors.textPrimary }}>{buddy.name} · Match Buddy</Text>
                <Text style={{ ...typography.footnote, color: colors.neon }}>{provider}</Text>
              </View>
            </View>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("assistant.disclaimer")}</Text>
          </Animated.View>

          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
            {SUGGESTION_KEYS.map((key) => (
              <Pressable
                key={key}
                accessibilityRole="button"
                disabled={sending}
                accessibilityState={{ disabled: sending }}
                onPress={() => void send(t(key))}
                style={{ backgroundColor: colors.surface, borderColor: colors.border, borderRadius: radii.pill, borderWidth: 1, minHeight: 44, justifyContent: "center", paddingHorizontal: spacing.md }}
              >
                <Text style={{ ...typography.footnote, color: colors.textPrimary }}>{t(key)}</Text>
              </Pressable>
            ))}
          </View>

          {messages.map((message) => (
            <View key={message.id} style={{ alignSelf: message.role === "user" ? "flex-end" : "flex-start", gap: spacing.xs, maxWidth: "92%" }}>
              <View style={{ alignSelf: message.role === "user" ? "flex-end" : "flex-start", backgroundColor: message.role === "user" ? colors.accentFill : colors.surface, borderColor: message.role === "user" ? colors.accentFill : colors.border, borderRadius: radii.lg, borderWidth: 1, padding: spacing.md }}>
                <Text selectable style={{ ...typography.body, color: message.role === "user" ? colors.onAccentFill : colors.textPrimary }}>{message.text}</Text>
              </View>
              {message.actions?.length ? (
                <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
                  {message.actions.map((action) => (
                    <Pressable
                      key={action.id}
                      accessibilityRole="button"
                      onPress={() => router.push(action.route as never)}
                      style={{ alignItems: "center", backgroundColor: colors.courtLight, borderColor: `${colors.neon}55`, borderRadius: radii.pill, borderWidth: 1, flexDirection: "row", gap: spacing.xs, minHeight: 40, paddingHorizontal: spacing.md }}
                    >
                      <Icon name="chevron-right" size={13} color={colors.neon as string} />
                      <Text style={{ ...typography.footnote, color: colors.neon, fontWeight: "800" }}>{t(action.labelKey)}</Text>
                    </Pressable>
                  ))}
                </View>
              ) : null}
            </View>
          ))}
          {sending ? <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("assistant.thinking")}</Text> : null}
        </ScrollView>

        {/*
          Antes iba en position:absolute, fuera del flujo: el teclado la tapaba
          y no se veía lo que se escribía. Como hermana en la columna, sube con
          el resto del contenido en ambas plataformas.
        */}
        <View style={{
          alignItems: "center",
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          flexDirection: "row",
          gap: spacing.sm,
          paddingHorizontal: spacing.md,
          paddingTop: spacing.md,
          paddingBottom: spacing.md + insets.bottom
        }}>
          <TextInput
            accessibilityLabel={t("assistant.inputLabel")}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={() => void send()}
            placeholder={t("assistant.placeholder")}
            placeholderTextColor={colors.textTertiary}
            returnKeyType="send"
            maxLength={2000}
            style={{ ...typography.body, backgroundColor: colors.background, borderColor: colors.border, borderRadius: radii.pill, borderWidth: 1, color: colors.textPrimary, flex: 1, minHeight: 48, paddingHorizontal: spacing.md }}
          />
          <Pressable
            accessibilityLabel={t("assistant.send")}
            disabled={!input.trim() || sending}
            onPress={() => void send()}
            style={{ alignItems: "center", backgroundColor: input.trim() ? colors.accentFill : colors.border, borderRadius: 24, height: 48, justifyContent: "center", width: 48 }}
          >
            <Icon name="send" size={20} color={input.trim() ? (colors.onAccentFill as string) : (colors.textTertiary as string)} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </LiveBackground>
  );
}

function describeProvider(provider: string, t: (key: string) => string) {
  if (provider === "apple-intelligence") return t("assistant.provider.apple");
  if (provider === "gemini-nano") return t("assistant.provider.gemini");
  return t("assistant.provider.basic");
}
