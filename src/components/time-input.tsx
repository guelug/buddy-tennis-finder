import { useMemo, useRef } from "react";
import { Platform, TextInput, type TextInputProps, type NativeSyntheticEvent, type TextInputKeyPressEventData } from "react-native";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";

type TimeInputProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  compact?: boolean;
  invalid?: boolean;
};

const TIME_RE = /^([01]?\d|2[0-3]):([0-5]\d)$/;

export function isValidTime(value: string) {
  return TIME_RE.test(value);
}

/**
 * Input de hora con máscara suave HH:MM.
 *
 * - Android/iOS: solo teclado numérico, separador automático tras dos dígitos.
 * - Backspace limpia el separador cuando corresponde.
 * - Valida rango real 00-23 / 00-59.
 */
export function TimeInput({ value, onChange, placeholder, compact, invalid }: TimeInputProps) {
  const { t } = useI18n();
  const inputRef = useRef<TextInput>(null);
  const displayValue = useMemo(() => formatTimeDisplay(value), [value]);
  const fallbackPlaceholder = "18:00";

  function handleChange(text: string) {
    const raw = text.replace(/[^0-9]/g, "").slice(0, 4);
    let formatted = raw;
    if (raw.length >= 3) {
      formatted = `${raw.slice(0, 2)}:${raw.slice(2)}`;
    }
    onChange(formatted);
  }

  function handleKeyPress(e: NativeSyntheticEvent<TextInputKeyPressEventData>) {
    if (e.nativeEvent.key === "Backspace" && value.length === 3) {
      // Al borrar "18:" dejamos "18" para que la experiencia sea fluida.
      onChange(value.slice(0, 2));
    }
  }

  return (
    <TextInput
      ref={inputRef}
      value={displayValue}
      onChangeText={handleChange}
      onKeyPress={handleKeyPress}
      placeholder={placeholder ?? fallbackPlaceholder}
      placeholderTextColor={colors.textTertiary}
      keyboardType={Platform.OS === "ios" ? "numbers-and-punctuation" : "numeric"}
      maxLength={5}
      selectTextOnFocus
      accessibilityLabel={t("time.hour")}
      style={[
        timeInputBase,
        {
          // Color de fondo en render: `colors` se muta según el tema, así que
          // no puede hornearse en `timeInputBase` (quedaría oscuro en claro).
          backgroundColor: colors.surface,
          borderColor: invalid ? colors.danger : colors.border,
          color: invalid ? colors.danger : colors.textPrimary,
          paddingHorizontal: compact ? 10 : spacing.md,
          paddingVertical: compact ? 8 : spacing.sm
        }
      ]}
    />
  );
}

function formatTimeDisplay(value: string) {
  if (!value) return "";
  const digits = value.replace(/\D/g, "").slice(0, 4);
  if (digits.length <= 2) return digits;
  return `${digits.slice(0, 2)}:${digits.slice(2)}`;
}

const timeInputBase = {
  ...typography.body,
  borderRadius: radii.md,
  borderWidth: 1,
  flex: 1,
  minWidth: 0,
  textAlign: "center"
} as const;

export type { TextInputProps };
