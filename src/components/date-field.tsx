import { TextInput } from "react-native";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";

export type DateFieldProps = {
  value: string;
  onChange: (value: string) => void;
  minimumDate?: Date;
};

/** Fallback multiplataforma; Metro usa la variante `.native` en Android/iOS. */
export function DateField({ value, onChange }: DateFieldProps) {
  const { t } = useI18n();
  return (
    <TextInput
      accessibilityLabel={t("rivals.form.date")}
      autoCapitalize="none"
      autoCorrect={false}
      keyboardType="numbers-and-punctuation"
      maxLength={10}
      onChangeText={onChange}
      placeholder={t("date.placeholder")}
      placeholderTextColor={colors.textTertiary as string}
      value={value}
      style={{
        ...typography.body,
        backgroundColor: colors.surface,
        borderColor: colors.borderStrong,
        borderRadius: radii.md,
        borderWidth: 1,
        color: colors.textPrimary as string,
        minHeight: 46,
        paddingHorizontal: spacing.md
      }}
    />
  );
}
