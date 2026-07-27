import { useEffect, useMemo, useState } from "react";
import { Alert, Pressable, ScrollView, Text, TextInput, View } from "react-native";
import { router } from "expo-router";
import Animated, { FadeInUp } from "react-native-reanimated";
import { Avatar } from "@/components/avatar";
import { Card } from "@/components/card";
import { DateField } from "@/components/date-field";
import { Icon } from "@/components/icon";
import { LiveBackground } from "@/components/live-visuals";
import { LoadingView } from "@/components/loading-view";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { recordDoublesMatch } from "@/lib/app-api";
import { getClubs, getPlayersForArea, getPlayer, getDoublesRankingResults } from "@/lib/firestore";
import { suggestedPartnerId } from "@/data/rankings";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { colors, radii, spacing, typography } from "@/theme";
import type { Club, Player } from "@/types";

/** Devuelve YYYY-MM-DD en horario local (no UTC, que desplaza el día). */
function toLocalDateInput(date: Date) {
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 10);
}

/**
 * Parte de dobles: quien lo registra elige compañero y los dos rivales, y el
 * partido nace cerrado. A partir de ahí funciona igual que un individual —
 * marcador, validación del equipo contrario y valoraciones — con la diferencia
 * de que se puede puntuar también al compañero.
 */
export default function RecordDoublesScreen() {
  const { user } = useAuth();
  const { t } = useI18n();
  const [loading, setLoading] = useState(true);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [people, setPeople] = useState<Player[]>([]);
  const [me, setMe] = useState<Player | null>(null);
  const [suggestedPartner, setSuggestedPartner] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [clubId, setClubId] = useState("");
  const [partnerId, setPartnerId] = useState("");
  const [rivalIds, setRivalIds] = useState<string[]>([]);
  const [date, setDate] = useState(() => toLocalDateInput(new Date()));
  const [startTime, setStartTime] = useState("10:00");
  const [endTime, setEndTime] = useState("12:00");
  const [court, setCourt] = useState(1);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    const uid = user?.uid;
    if (!uid) return;
    (async () => {
      try {
        const profile = await getPlayer(uid);
        if (!profile) throw new Error(t("doubles.error.noProfile"));
        const [clubList, directory, history] = await Promise.all([
          getClubs(),
          getPlayersForArea(profile.city),
          getDoublesRankingResults(profile.city)
        ]);
        if (!active) return;
        setMe(profile);
        setClubs(clubList);
        setPeople(directory.filter((item) => item.id !== uid && !item.isDemo));
        setClubId(profile.clubIds[0] ?? clubList[0]?.id ?? "");
        setSuggestedPartner(suggestedPartnerId(uid, history));
      } catch (error) {
        if (active) setLoadError(error instanceof Error ? error.message : String(error));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, [user?.uid, t]);

  // Proponemos el compañero habitual: la clasificación de dobles va por
  // pareja, así que repetir compañero es lo que hace subir.
  useEffect(() => {
    if (suggestedPartner && !partnerId && people.some((item) => item.id === suggestedPartner)) {
      setPartnerId(suggestedPartner);
    }
  }, [suggestedPartner, partnerId, people]);

  const selectedClub = clubs.find((club) => club.id === clubId);
  const courtOptions = useMemo(
    () => Array.from({ length: Math.max(1, selectedClub?.courts ?? 1) }, (_, index) => index + 1),
    [selectedClub]
  );

  useEffect(() => {
    if (selectedClub && court > selectedClub.courts) setCourt(1);
  }, [court, selectedClub]);

  const toggleRival = (id: string) => {
    setRivalIds((current) => {
      if (current.includes(id)) return current.filter((item) => item !== id);
      if (current.length >= 2) return current;
      return [...current, id];
    });
  };

  const canSubmit = Boolean(clubId) && Boolean(partnerId) && rivalIds.length === 2 && !busy;

  const submit = async () => {
    if (!canSubmit) return;
    setBusy(true);
    try {
      const startsAt = new Date(`${date}T${startTime}:00`).toISOString();
      await recordDoublesMatch({
        clubId,
        court,
        startsAt,
        reservationTime: `${startTime}-${endTime}`,
        partnerId,
        rivalIds,
        message
      });
      Alert.alert(t("doubles.saved.title"), t("doubles.saved.body"));
      router.replace("/matches");
    } catch (error) {
      Alert.alert(t("doubles.error.title"), error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <LoadingView />;

  if (loadError) {
    return (
      <LiveBackground overlay={0.58}>
        <View style={{ alignItems: "center", flex: 1, gap: spacing.md, justifyContent: "center", padding: spacing.xl }}>
          <Text style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{loadError}</Text>
          <PrimaryButton label={t("common.retry")} variant="outline" fullWidth={false} onPress={() => router.back()} />
        </View>
      </LiveBackground>
    );
  }

  return (
    <LiveBackground overlay={0.58}>
      <ScreenShell>
        <Animated.View entering={FadeInUp} style={{ gap: spacing.md }}>
          <Text style={{ ...typography.headline, color: colors.textPrimary }}>{t("doubles.title")}</Text>
          <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("doubles.subtitle")}</Text>

          <Card style={{ gap: spacing.sm }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("doubles.partner")}</Text>
            {suggestedPartner && suggestedPartner === partnerId ? (
              <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
                <Icon name="star" size={13} color={colors.neon as string} />
                <Text style={{ ...typography.footnote, color: colors.neon }}>{t("doubles.usualPartner")}</Text>
              </View>
            ) : null}
            <PersonPicker people={people} selected={partnerId ? [partnerId] : []} onToggle={(id) => setPartnerId((current) => (current === id ? "" : id))} />
          </Card>

          <Card style={{ gap: spacing.sm }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("doubles.rivals")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("doubles.rivalsHint")}</Text>
            <PersonPicker
              people={people.filter((item) => item.id !== partnerId)}
              selected={rivalIds}
              onToggle={toggleRival}
            />
          </Card>

          <Card style={{ gap: spacing.sm }}>
            <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("doubles.when")}</Text>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("doubles.date")}</Text>
            <DateField value={date} onChange={setDate} />
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              <TimeBox label={t("doubles.start")} value={startTime} onChange={setStartTime} />
              <TimeBox label={t("doubles.end")} value={endTime} onChange={setEndTime} />
            </View>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("doubles.club")}</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
              {clubs.map((club) => (
                <Pressable
                  key={club.id}
                  accessibilityRole="button"
                  accessibilityState={{ selected: club.id === clubId }}
                  onPress={() => setClubId(club.id)}
                  style={{
                    backgroundColor: club.id === clubId ? colors.courtLight : colors.surface,
                    borderColor: club.id === clubId ? colors.neon : colors.border,
                    borderRadius: radii.pill,
                    borderWidth: 1,
                    paddingHorizontal: spacing.md,
                    paddingVertical: 6
                  }}
                >
                  <Text style={{ ...typography.footnote, color: club.id === clubId ? colors.neon : colors.textPrimary }}>{club.name}</Text>
                </Pressable>
              ))}
            </View>
            <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t("doubles.court")}</Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
              {courtOptions.map((option) => (
                <Pressable
                  key={option}
                  accessibilityRole="button"
                  accessibilityState={{ selected: option === court }}
                  onPress={() => setCourt(option)}
                  style={{
                    alignItems: "center",
                    backgroundColor: option === court ? colors.courtLight : colors.surface,
                    borderColor: option === court ? colors.neon : colors.border,
                    borderRadius: radii.sm,
                    borderWidth: 1,
                    minWidth: 38,
                    paddingVertical: 6
                  }}
                >
                  <Text style={{ ...typography.footnote, color: option === court ? colors.neon : colors.textPrimary }}>{option}</Text>
                </Pressable>
              ))}
            </View>
          </Card>

          <TextInput
            value={message}
            onChangeText={setMessage}
            placeholder={t("doubles.notePlaceholder")}
            placeholderTextColor={colors.textTertiary as string}
            multiline
            maxLength={280}
            style={{
              ...typography.body,
              backgroundColor: colors.surface,
              borderColor: colors.border,
              borderRadius: radii.sm,
              borderWidth: 1,
              color: colors.textPrimary as string,
              minHeight: 64,
              padding: spacing.md,
              textAlignVertical: "top"
            }}
          />

          <PrimaryButton label={busy ? t("doubles.saving") : t("doubles.save")} disabled={!canSubmit} onPress={() => void submit()} />
          <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
            {t("doubles.disclaimer")}
          </Text>
        </Animated.View>
      </ScreenShell>
    </LiveBackground>
  );
}

function PersonPicker({
  people,
  selected,
  onToggle
}: {
  people: Player[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  const { t } = useI18n();
  if (people.length === 0) {
    return <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("doubles.noPeople")}</Text>;
  }
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.xs, paddingVertical: 2 }}>
      {people.map((person) => {
        const isSelected = selected.includes(person.id);
        return (
          <Pressable
            key={person.id}
            accessibilityRole="button"
            accessibilityState={{ selected: isSelected }}
            onPress={() => onToggle(person.id)}
            style={{
              alignItems: "center",
              backgroundColor: isSelected ? colors.courtLight : colors.surface,
              borderColor: isSelected ? colors.neon : colors.border,
              borderRadius: radii.md,
              borderWidth: 1,
              gap: 4,
              minWidth: 84,
              paddingHorizontal: spacing.sm,
              paddingVertical: spacing.sm
            }}
          >
            <Avatar name={person.name} size={34} />
            <Text numberOfLines={1} style={{ ...typography.footnote, color: isSelected ? colors.neon : colors.textPrimary, fontWeight: "700", maxWidth: 78 }}>
              {person.name}
            </Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

function TimeBox({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  return (
    <View style={{ flex: 1, gap: 3 }}>
      <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{label}</Text>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder="10:00"
        placeholderTextColor={colors.textTertiary as string}
        keyboardType="numbers-and-punctuation"
        maxLength={5}
        style={{
          ...typography.body,
          backgroundColor: colors.surface,
          borderColor: colors.border,
          borderRadius: radii.sm,
          borderWidth: 1,
          color: colors.textPrimary as string,
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.sm
        }}
      />
    </View>
  );
}
