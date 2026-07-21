import { TextInput } from "react-native";
import { colors, radii, spacing, typography } from "@/theme";

export type DateFieldProps = {
  value: string;
  onChange: (value: string) => void;
  minimumDate?: Date;
};

/** Fallback multiplataforma; Metro usa la variante `.native` en Android/iOS. */
export function DateField({ value, onChange }: DateFieldProps) {
  return (
    <TextInput
      accessibilityLabel="Fecha de la reserva"
      autoCapitalize="none"
      autoCorrect={false}
      keyboardType="numbers-and-punctuation"
      maxLength={10}
      onChangeText={onChange}
      placeholder="AAAA-MM-DD"
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
