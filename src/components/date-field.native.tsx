import { useMemo, useState } from "react";
import { Platform, Pressable, Text } from "react-native";
import DateTimePicker, { type DateTimePickerEvent } from "@react-native-community/datetimepicker";
import { Icon } from "@/components/icon";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import type { DateFieldProps } from "./date-field";

function parseDate(value: string) {
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(year, month - 1, day, 12);
  return Number.isFinite(parsed.getTime()) ? parsed : new Date();
}

function serializeDate(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function DateField({ value, onChange, minimumDate }: DateFieldProps) {
  const { t, locale } = useI18n();
  const [open, setOpen] = useState(false);
  const selectedDate = useMemo(() => parseDate(value), [value]);

  const handleChange = (event: DateTimePickerEvent, nextDate?: Date) => {
    if (Platform.OS === "android") setOpen(false);
    if (event.type === "set" && nextDate) onChange(serializeDate(nextDate));
  };

  const formattedDate = (() => {
    try {
      return selectedDate.toLocaleDateString(locale, {
        weekday: "short",
        day: "numeric",
        month: "long",
        year: "numeric"
      });
    } catch {
      return selectedDate.toDateString();
    }
  })();

  return (
    <>
      <Pressable
        accessibilityLabel={t("date.picker.a11y")}
        accessibilityRole="button"
        onPress={() => setOpen(true)}
        style={({ pressed }) => ({
          alignItems: "center",
          backgroundColor: pressed ? colors.courtLight : colors.surface,
          borderColor: open ? colors.court : colors.borderStrong,
          borderRadius: radii.md,
          borderWidth: 1,
          flexDirection: "row",
          gap: spacing.sm,
          minHeight: 48,
          paddingHorizontal: spacing.md
        })}
      >
        <Icon name="calendar-clock" size={18} color={colors.court as string} />
        <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary, flex: 1 }}>
          {formattedDate}
        </Text>
        <Icon name="chevron-right" size={15} color={colors.textTertiary as string} />
      </Pressable>
      {open ? (
        <DateTimePicker
          display={Platform.OS === "ios" ? "inline" : "calendar"}
          minimumDate={minimumDate}
          mode="date"
          onChange={handleChange}
          value={selectedDate}
        />
      ) : null}
    </>
  );
}
