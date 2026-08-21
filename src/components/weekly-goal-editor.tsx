import { Pressable, Text, View } from "react-native";
import { ringSolidColor } from "@/components/progress-rings";
import { useI18n } from "@/lib/i18n";
import { WEEKLY_GOAL_LIMITS, type RingKey, type WeeklyGoals } from "@/lib/gamification";
import { colors, radii, spacing, typography } from "@/theme";

const RING_ORDER: RingKey[] = ["play", "compete", "connect"];

/**
 * Ajuste de los tres objetivos semanales. Botones de más y menos en vez de un
 * deslizador: los valores son pequeños y discretos, y un slider a esta escala
 * es imposible de acertar con el pulgar.
 */
export function WeeklyGoalEditor({
  goals,
  onChange,
  onReset
}: {
  goals: WeeklyGoals;
  onChange: (key: RingKey, value: number) => void;
  onReset: () => void;
}) {
  const { t } = useI18n();

  return (
    <View style={{ gap: spacing.md }}>
      {RING_ORDER.map((key) => {
        const limits = WEEKLY_GOAL_LIMITS[key];
        const value = goals[key];
        return (
          <View key={key} style={{ alignItems: "center", flexDirection: "row", gap: spacing.md }}>
            <View
              style={{
                backgroundColor: ringSolidColor(key),
                borderRadius: 999,
                height: 10,
                width: 10
              }}
            />
            <View style={{ flex: 1 }}>
              <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary, fontSize: 14 }}>
                {t(`progress.rings.${key}`)}
              </Text>
              <Text style={{ ...typography.footnote, color: colors.textSecondary, fontSize: 11 }}>
                {t(`progress.goals.hint.${key}`)}
              </Text>
            </View>
            <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
              <StepButton
                glyph="−"
                label={t("progress.goals.decrease")}
                disabled={value <= limits.min}
                onPress={() => onChange(key, value - limits.step)}
              />
              <Text
                style={{
                  ...typography.bodyEmphasized,
                  color: colors.textPrimary,
                  fontSize: 17,
                  minWidth: 34,
                  textAlign: "center"
                }}
              >
                {value}
              </Text>
              <StepButton
                glyph="+"
                label={t("progress.goals.increase")}
                disabled={value >= limits.max}
                onPress={() => onChange(key, value + limits.step)}
              />
            </View>
          </View>
        );
      })}

      <Pressable
        accessibilityRole="button"
        onPress={onReset}
        style={{ alignSelf: "flex-start", minHeight: 44, justifyContent: "center" }}
      >
        <Text style={{ ...typography.footnote, color: colors.court, fontWeight: "800" }}>
          {t("progress.goals.reset")}
        </Text>
      </Pressable>
    </View>
  );
}

function StepButton({
  glyph,
  label,
  disabled,
  onPress
}: {
  glyph: "−" | "+";
  label: string;
  disabled: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      // 44 pt es el mínimo táctil de las guías de Apple; el círculo visible es
      // más pequeño, pero el área que responde no.
      hitSlop={8}
      style={{
        alignItems: "center",
        backgroundColor: disabled ? colors.surfaceCourt : colors.courtLight,
        borderColor: disabled ? colors.border : `${colors.court}55`,
        borderRadius: radii.md,
        borderWidth: 1,
        height: 38,
        justifyContent: "center",
        opacity: disabled ? 0.5 : 1,
        width: 38
      }}
    >
      <Text
        style={{
          ...typography.bodyEmphasized,
          color: disabled ? colors.textTertiary : colors.court,
          fontSize: 20,
          lineHeight: 22
        }}
      >
        {glyph}
      </Text>
    </Pressable>
  );
}
