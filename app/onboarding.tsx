import { useEffect, useMemo, useRef, useState } from "react";
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  Switch,
  Text,
  TextInput,
  useWindowDimensions,
  View,
  type TextStyle,
  type ViewStyle
} from "react-native";
import Animated, { FadeIn, FadeInRight, FadeOutLeft } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Icon, type IconName } from "@/components/icon";
import { Chip } from "@/components/chip";
import { PrimaryButton } from "@/components/primary-button";
import { ProfilePhotoUploader } from "@/components/profile-photo-uploader";
import { TimeInput, isValidTime } from "@/components/time-input";
import { WazeLogo } from "@/components/icons/waze-logo";
import { BrandLockup } from "@/components/brand-lockup";
import { LiveBackground } from "@/components/live-visuals";
import { LoadingView } from "@/components/loading-view";
import { skillsFromRating } from "@/components/skill-radar";
import { useAuth } from "@/lib/firebase-auth";
import { getClubs, getPlayer, savePlayerProfile } from "@/lib/firestore";
import { openInWaze } from "@/lib/waze";
import { colors, contentWidth, spacing, statusBarTopInset, typography, radii, shadows, useThemeMode } from "@/theme";
import { Club, Gender, MatchFormat, PlayerProfileInput, PlayerSkills, SkillLevel } from "@/types";
import { CITIES_BY_COUNTRY, countries, Country } from "@/data/seed";
import { useI18n } from "@/lib/i18n";

const LEVELS: Array<{ label: string; labelKey?: string; value: SkillLevel; icon: IconName }> = [
  { label: "Novato", labelKey: "onboarding.level.novato", value: "novato", icon: "tennis" },
  { label: "D", value: "d", icon: "tennis" },
  { label: "C", value: "c", icon: "tennis" },
  { label: "B", value: "b", icon: "tennis" },
  { label: "A", value: "a", icon: "tennis" }
];

const FORMATS: Array<{ labelKey: string; value: MatchFormat; icon: IconName }> = [
  { labelKey: "onboarding.format.singles", value: "singles", icon: "user" },
  { labelKey: "onboarding.format.doubles", value: "doubles", icon: "users" },
  { labelKey: "onboarding.format.mixed", value: "mixed", icon: "users" }
];

// El `label` es el valor canónico que se guarda en Firestore; `labelKey` solo
// traduce lo que se muestra en pantalla.
const LANGUAGES: Array<{ label: string; labelKey: string; icon: IconName }> = [
  { label: "Español", labelKey: "languages.spanish", icon: "globe" },
  { label: "Inglés", labelKey: "languages.english", icon: "globe" },
  { label: "Francés", labelKey: "languages.french", icon: "globe" },
  { label: "Alemán", labelKey: "languages.german", icon: "globe" },
  { label: "Italiano", labelKey: "languages.italian", icon: "globe" },
  { label: "Portugués", labelKey: "languages.portuguese", icon: "globe" }
];

// Nombres canónicos en español: son los valores que se guardan en Firestore.
const DAYS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];

/** Clave i18n de cada día canónico — solo para mostrar, nunca para guardar. */
const DAY_KEYS: Record<string, string> = {
  Lunes: "days.lunes",
  Martes: "days.martes",
  Miércoles: "days.miercoles",
  Jueves: "days.jueves",
  Viernes: "days.viernes",
  Sábado: "days.sabado",
  Domingo: "days.domingo"
};

/** Ejes de la autoevaluación inicial — mismos que el radar del perfil. */
const SKILL_AXES: Array<{ key: keyof PlayerSkills; labelKey: string }> = [
  { key: "consistency", labelKey: "onboarding.skill.consistency" },
  { key: "forehand", labelKey: "onboarding.skill.forehand" },
  { key: "backhand", labelKey: "onboarding.skill.backhand" },
  { key: "serve", labelKey: "onboarding.skill.serve" },
  { key: "volley", labelKey: "onboarding.skill.volley" }
];

type DayAvailability = { active: boolean; start: string; end: string };
type StepIndex = 0 | 1 | 2;

const STEPS = [
  {
    key: "identity",
    eyebrowKey: "onboarding.step1.eyebrow",
    titleKey: "onboarding.step1.title",
    subtitleKey: "onboarding.step1.subtitle"
  },
  {
    key: "game",
    eyebrowKey: "onboarding.step2.eyebrow",
    titleKey: "onboarding.step2.title",
    subtitleKey: "onboarding.step2.subtitle"
  },
  {
    key: "schedule",
    eyebrowKey: "onboarding.step3.eyebrow",
    titleKey: "onboarding.step3.title",
    subtitleKey: "onboarding.step3.subtitle"
  }
] as const;

export default function OnboardingScreen() {
  const { width } = useWindowDimensions();
  const compact = width < 560;
  const insets = useSafeAreaInsets();
  const { isLight } = useThemeMode();
  const { user } = useAuth();
  const { t } = useI18n();
  const [step, setStep] = useState<StepIndex>(0);
  const scrollRef = useRef<ScrollView>(null);
  const [clubs, setClubs] = useState<Club[]>([]);
  const [loadingClubs, setLoadingClubs] = useState(true);
  const [clubsError, setClubsError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [photoURL, setPhotoURL] = useState<string | null>(user?.photoURL ?? null);

  const [name, setName] = useState(user?.displayName ?? "");
  const [age, setAge] = useState("");
  const [gender, setGender] = useState<Gender | null>(null);
  const [country, setCountry] = useState<Country | null>(null);
  const [city, setCity] = useState<string | null>(null);
  const [clubIds, setClubIds] = useState<string[]>([]);
  const [level, setLevel] = useState<SkillLevel>("c");
  const [formats, setFormats] = useState<MatchFormat[]>(["singles"]);
  const [bio, setBio] = useState("");
  const [languages, setLanguages] = useState<string[]>(["Español"]);
  const [skills, setSkills] = useState<PlayerSkills>(() => skillsFromRating(3));
  const [availability, setAvailability] = useState<Record<string, DayAvailability>>({});
  const [isFirstProfile, setIsFirstProfile] = useState(true);
  const [touched, setTouched] = useState<Record<string, boolean>>({});

  const loadClubs = () => {
    setLoadingClubs(true);
    setClubsError(null);
    getClubs()
      .then(setClubs)
      .catch(() => setClubsError(t("onboarding.clubsError")))
      .finally(() => setLoadingClubs(false));
  };

  useEffect(() => { loadClubs(); }, []);

  useEffect(() => {
    if (!user) return;
    getPlayer(user.uid).then((player) => {
      if (!player) return;
      setIsFirstProfile(false);
      setName(player.name);
      setAge(String(player.age));
      setGender(player.gender);
      setCountry((player.country || "Guatemala") as Country);
      setCity(player.city || null);
      setClubIds(player.clubIds.length ? player.clubIds : []);
      setLevel(player.level);
      setFormats(player.preferredFormats);
      setBio(player.bio);
      setLanguages(player.languages.length ? player.languages : ["Español"]);
      if (player.skills) setSkills(player.skills);
      setPhotoURL(player.photoURL ?? user.photoURL ?? null);
      setAvailability(Object.fromEntries(player.availability.map((slot) => {
        const [start = "18:00", end = "21:00"] = (slot.ranges[0] ?? "18:00-21:00").split("-");
        return [slot.day, { active: true, start, end } satisfies DayAvailability];
      })));
    }).catch(() => {});
  }, [user]);

  const toggleFormat = (format: MatchFormat) => {
    setFormats((prev) =>
      prev.includes(format) ? prev.filter((f) => f !== format) : [...prev, format]
    );
  };

  const toggleClub = (clubId: string) => {
    setClubIds((prev) => {
      if (prev.includes(clubId)) return prev.filter((id) => id !== clubId);
      return [...prev, clubId];
    });
  };

  const moveClubToFirst = (clubId: string) => {
    setClubIds((prev) => {
      if (!prev.includes(clubId)) return [clubId, ...prev];
      return [clubId, ...prev.filter((id) => id !== clubId)];
    });
  };

  const toggleDay = (day: string) => {
    setAvailability((prev) => ({
      ...prev,
      [day]: prev[day]
        ? { ...prev[day], active: !prev[day].active }
        : { active: true, start: "18:00", end: "21:00" }
    }));
  };

  const toggleLanguage = (language: string) => {
    setLanguages((current) =>
      current.includes(language) ? current.filter((item) => item !== language) : [...current, language]
    );
  };

  const primaryClub = clubs.find((c) => c.id === clubIds[0]);

  const ageNum = Number(age);
  const ageValid = age.trim() !== "" && Number.isFinite(ageNum) && ageNum >= 13 && ageNum <= 100;

  const step0Valid = name.trim().length > 1 && ageValid && gender !== null && country !== null && city !== null && clubIds.length > 0;
  const step1Valid = formats.length > 0 && languages.length > 0;
  const canSave = step0Valid && step1Valid;

  const stepMeta = STEPS[step];

  const stepHint = useMemo(() => {
    if (step === 0 && !step0Valid) {
      return t("onboarding.hint.step0");
    }
    if (step === 1 && !step1Valid) {
      return t("onboarding.hint.step1");
    }
    return null;
  }, [step, step0Valid, step1Valid, t]);

  function goToStep(next: StepIndex) {
    setStep(next);
    scrollRef.current?.scrollTo({ y: 0, animated: false });
  }

  function goNext() {
    setSaveMessage(null);
    setTouched((prev) => ({ ...prev, [step]: true }));
    if (step === 0 && !step0Valid) {
      setSaveMessage(t("onboarding.save.reviewStep"));
      return;
    }
    if (step === 1 && !step1Valid) {
      setSaveMessage(t("onboarding.save.reviewGame"));
      return;
    }
    if (step < 2) {
      if (Platform.OS !== "web") void Haptics.selectionAsync();
      goToStep((step + 1) as StepIndex);
    }
  }

  function goBack() {
    setSaveMessage(null);
    if (step > 0) goToStep((step - 1) as StepIndex);
  }

  async function handleSave() {
    if (!user) {
      Alert.alert(t("onboarding.save.sessionTitle"), t("onboarding.save.sessionExpired"));
      router.replace("/login");
      return;
    }
    if (!canSave || gender === null) {
      setSaveMessage(t("onboarding.save.reviewRequired"));
      return;
    }

    const resolvedGender: Gender = gender;
    const slots = Object.entries(availability)
      .filter(([, value]) => value.active && value.start < value.end && isValidTime(value.start) && isValidTime(value.end))
      .map(([day, value]) => ({ day, ranges: [`${value.start}-${value.end}`] }));

    const profile: PlayerProfileInput = {
      name: name.trim(),
      age: ageNum,
      gender: resolvedGender,
      clubIds,
      city: city ?? primaryClub?.city ?? "",
      country: country ?? primaryClub?.country ?? "Guatemala",
      latitude: primaryClub?.latitude ?? 0,
      longitude: primaryClub?.longitude ?? 0,
      level,
      preferredFormats: formats,
      availability: slots.length > 0 ? slots : [{ day: "Sábado", ranges: ["09:00-12:00"] }],
      bio: bio.trim() || "Jugador de MatchPoint Tennis.",
      languages,
      skills,
      photoURL,
      verified: user.providerId === "google.com" || user.providerId === "apple.com" || user.emailVerified
    };

    setSaving(true);
    setSaveMessage(t("onboarding.save.saving"));
    try {
      await withTimeout(savePlayerProfile(user.uid, profile), 15000, t("onboarding.error.timeout"));
      setSaveMessage(t("onboarding.save.success"));
      router.replace("/(tabs)");
    } catch (error) {
      const msg = describeError(error, t("onboarding.error.retryFallback"));
      setSaveMessage(msg);
      Alert.alert(t("onboarding.save.failedTitle"), msg);
    } finally {
      setSaving(false);
    }
  }

  if (loadingClubs) return <LoadingView />;
  if (clubsError) {
    return (
      <View style={{ alignItems: "center", backgroundColor: colors.background, flex: 1, justifyContent: "center", padding: spacing.xl }}>
        <View style={glassErrorStyle}>
          <View style={{ alignItems: "center", gap: spacing.md }}>
            <Icon name="building" size={36} color={colors.warning as string} />
            <Text style={{ ...typography.headline, color: colors.textPrimary, textAlign: "center" }}>{t("onboarding.errorTitle")}</Text>
            <Text selectable style={{ ...typography.body, color: colors.textSecondary, textAlign: "center" }}>{clubsError}</Text>
            <PrimaryButton label={t("common.retry")} onPress={loadClubs} />
          </View>
        </View>
      </View>
    );
  }

  const topPad = Math.max(statusBarTopInset(insets.top), spacing.sm) + spacing.sm;
  const bottomPad = Math.max(insets.bottom, spacing.md) + spacing.xl;

  const content = (
    <ScrollView
      ref={scrollRef}
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
      nestedScrollEnabled
      showsVerticalScrollIndicator={false}
      style={[{ flex: 1 }, Platform.OS === "web" ? ({ overscrollBehaviorY: "contain", touchAction: "pan-y" } as object) : null]}
      contentContainerStyle={{
        paddingTop: topPad,
        paddingHorizontal: spacing.base,
        paddingBottom: bottomPad + 96,
        alignItems: "center"
      }}
    >
      <View style={{ width: "100%", maxWidth: contentWidth.narrow + 80, gap: spacing.lg }}>
        <BrandBadge />
        <StepProgress current={step} total={STEPS.length} />

        <Animated.View key={`header-${step}`} entering={FadeIn.duration(280)}>
          <View style={{ gap: spacing.sm, paddingHorizontal: spacing.base, marginTop: spacing.sm }}>
            <Text style={{ ...typography.caption, color: colors.court, textTransform: "uppercase", letterSpacing: 1.4, fontWeight: "800" }}>
              {isFirstProfile ? t(stepMeta.eyebrowKey) : `${t("onboarding.editing")} · ${t(stepMeta.eyebrowKey)}`}
            </Text>
            <Text style={{ ...typography.largeTitle, color: colors.textPrimary, letterSpacing: -0.2 }}>{t(stepMeta.titleKey)}</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary }}>{t(stepMeta.subtitleKey)}</Text>
          </View>
        </Animated.View>

        <Animated.View key={`body-${step}`} entering={FadeInRight.springify().damping(22).stiffness(180)} exiting={FadeOutLeft.duration(150)}>
          {step === 0 ? (
            <IdentityStep
              userId={user?.uid}
              name={name}
              setName={setName}
              age={age}
              setAge={setAge}
              gender={gender}
              setGender={setGender}
              country={country}
              setCountry={setCountry}
              city={city}
              setCity={setCity}
              photoURL={photoURL}
              setPhotoURL={setPhotoURL}
              clubs={clubs}
              clubIds={clubIds}
              toggleClub={toggleClub}
              moveClubToFirst={moveClubToFirst}
              setClubIds={setClubIds}
              primaryClub={primaryClub}
              ageValid={ageValid}
              touched={touched[0]}
            />
          ) : null}
          {step === 1 ? (
            <GameStep
              level={level}
              setLevel={setLevel}
              formats={formats}
              toggleFormat={toggleFormat}
              languages={languages}
              toggleLanguage={toggleLanguage}
              bio={bio}
              setBio={setBio}
              skills={skills}
              setSkill={(key, value) => setSkills((current) => ({ ...current, [key]: value }))}
            />
          ) : null}
          {step === 2 ? (
            <ScheduleStep
              compact={compact}
              availability={availability}
              setAvailability={setAvailability}
              toggleDay={toggleDay}
            />
          ) : null}
        </Animated.View>

        {saveMessage ? (
          <Text style={{ ...typography.footnote, color: saving ? colors.court : colors.textSecondary, textAlign: "center" }}>
            {saveMessage}
          </Text>
        ) : null}
        {stepHint ? (
          <Text style={{ ...typography.footnote, color: colors.textTertiary, textAlign: "center" }}>
            {stepHint}
          </Text>
        ) : null}
      </View>
    </ScrollView>
  );

  return (
    <LiveBackground overlay={isLight ? 0.5 : 0.55}>
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : "height"}
        keyboardVerticalOffset={Platform.OS === "ios" ? 0 : 24}
        style={{ flex: 1 }}
      >
        {content}
      </KeyboardAvoidingView>

      {/* Footer flotante */}
      <View pointerEvents="box-none" style={{ position: "absolute", bottom: 0, left: 0, right: 0 }}>
        <View
          pointerEvents="auto"
          style={{
            backgroundColor: isLight ? "rgba(244,247,241,0.92)" : "rgba(7,12,8,0.92)",
            borderTopColor: isLight ? "rgba(27,55,36,0.12)" : colors.borderStrong,
            borderTopWidth: 1,
            paddingBottom: Math.max(insets.bottom, spacing.md),
            paddingHorizontal: spacing.base,
            paddingTop: spacing.md,
            boxShadow: isLight ? "0 -10px 30px rgba(27,55,36,0.08)" : "0 -10px 32px rgba(0,0,0,0.45)",
            backdropFilter: Platform.OS === "web" ? "blur(14px)" : undefined
          }}
        >
          <View style={{ alignSelf: "center", flexDirection: "row", gap: spacing.sm, maxWidth: contentWidth.narrow + 80, width: "100%" }}>
            {step > 0 ? (
              <View style={{ flex: 1 }}>
                <PrimaryButton label={t("onboarding.back")} variant="outline" onPress={goBack} disabled={saving} />
              </View>
            ) : null}
            <View style={{ flex: step > 0 ? 1.4 : 1 }}>
              {step < 2 ? (
                <PrimaryButton
                  label={t("onboarding.next")}
                  onPress={goNext}
                  disabled={(step === 0 && !step0Valid) || (step === 1 && !step1Valid)}
                  size="lg"
                />
              ) : (
                <PrimaryButton
                  label={saving ? t("onboarding.saving") : isFirstProfile ? t("onboarding.saveAndStart") : t("onboarding.saveChanges")}
                  onPress={handleSave}
                  disabled={!canSave || saving}
                  size="lg"
                />
              )}
            </View>
          </View>
        </View>
      </View>
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// Pasos
// ---------------------------------------------------------------------------

function IdentityStep({
  userId,
  name,
  setName,
  age,
  setAge,
  gender,
  setGender,
  country,
  setCountry,
  city,
  setCity,
  photoURL,
  setPhotoURL,
  clubs,
  clubIds,
  toggleClub,
  moveClubToFirst,
  setClubIds,
  primaryClub,
  ageValid,
  touched
}: {
  userId?: string;
  name: string;
  setName: (v: string) => void;
  age: string;
  setAge: (v: string) => void;
  gender: Gender | null;
  setGender: (v: Gender) => void;
  country: Country | null;
  setCountry: (v: Country) => void;
  city: string | null;
  setCity: (v: string | null) => void;
  photoURL: string | null;
  setPhotoURL: (v: string | null) => void;
  clubs: Club[];
  clubIds: string[];
  toggleClub: (id: string) => void;
  moveClubToFirst: (id: string) => void;
  setClubIds: (v: string[]) => void;
  primaryClub?: Club;
  ageValid: boolean;
  touched: boolean;
}) {
  const { t } = useI18n();
  const filteredClubs = useMemo(() => {
    if (!country || !city) return [];
    return clubs.filter((c) => c.country === country && c.city === city);
  }, [clubs, country, city]);

  const cityOptions = useMemo(() => (country ? CITIES_BY_COUNTRY[country] : []), [country]);

  return (
    <View style={cardWrapper}>
      {userId ? <ProfilePhotoUploader uid={userId} name={name} value={photoURL} onChange={setPhotoURL} /> : null}

      <Field label={t("onboarding.field.name")} required>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder={t("onboarding.field.namePlaceholder")}
          placeholderTextColor={colors.textTertiary}
          style={inputStyle}
          autoComplete="name"
          accessibilityLabel={t("onboarding.a11y.name")}
        />
      </Field>

      <View style={{ flexDirection: "row", gap: spacing.md }}>
        <Field label={t("onboarding.field.age")} required style={{ flex: 1 }}>
          <TextInput
            value={age}
            onChangeText={(text) => setAge(text.replace(/[^0-9]/g, "").slice(0, 3))}
            placeholder={t("onboarding.field.agePlaceholder")}
            keyboardType="numeric"
            placeholderTextColor={colors.textTertiary}
            style={[inputStyle, touched && !ageValid ? { borderColor: colors.danger, color: colors.danger } : null]}
            accessibilityLabel={t("onboarding.a11y.age")}
          />
          {touched && !ageValid ? <Text style={{ ...typography.footnote, color: colors.danger, marginTop: spacing.xs }}>{t("onboarding.field.ageError")}</Text> : null}
        </Field>
        <Field label={t("onboarding.field.gender")} required style={{ flex: 1 }}>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {GENDER_OPTIONS.map((g) => (
              <Chip key={g.value} active={gender === g.value} label={t(g.labelKey)} onPress={() => setGender(g.value)} />
            ))}
          </View>
        </Field>
      </View>

      <Field label={t("onboarding.field.country")} required>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {countries.map((c) => (
            <Chip
              key={c}
              active={country === c}
              label={c}
              onPress={() => {
                setCountry(c);
                setCity(null);
                setClubIds([]);
              }}
            />
          ))}
        </View>
      </Field>

      {country ? (
        <Field label={t("onboarding.field.city")} required>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {cityOptions.map((c) => (
              <Chip key={c} active={city === c} label={c} onPress={() => {
   setCity(c);
   setClubIds([]);
 }} />
            ))}
          </View>
        </Field>
      ) : null}

      {country && city ? (
        <Field label={t("onboarding.field.clubs")} required>
          <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
            {t("onboarding.field.clubsHint")}
          </Text>
          {filteredClubs.length === 0 ? (
            <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
              {t("onboarding.clubs.empty").replace("{city}", city).replace("{country}", country)}
            </Text>
          ) : (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
              {filteredClubs.map((club) => {
                const selected = clubIds.includes(club.id);
                const isPrimary = clubIds[0] === club.id;
                return (
                  <Chip
                    key={club.id}
                    active={selected}
                    label={isPrimary ? `${club.name} ★` : club.name}
                    onPress={() => toggleClub(club.id)}
                    onLongPress={() => {
                      if (selected) moveClubToFirst(club.id);
                      else moveClubToFirst(club.id);
                    }}
                  />
                );
              })}
            </View>
          )}
          {primaryClub ? (
            <Pressable onPress={() => openInWaze(primaryClub.latitude, primaryClub.longitude, primaryClub.name)} style={wazeRowStyle}>
              <WazeLogo size={15} color={colors.court} />
              <Text style={{ ...typography.caption, color: colors.court }}>
                {t("onboarding.clubs.waze").replace("{club}", primaryClub.name)}
              </Text>
            </Pressable>
          ) : null}
        </Field>
      ) : null}
    </View>
  );
}

const GENDER_OPTIONS: Array<{ labelKey: string; value: Gender }> = [
  { labelKey: "onboarding.gender.female", value: "female" },
  { labelKey: "onboarding.gender.male", value: "male" },
  { labelKey: "onboarding.gender.other", value: "other" }
];

function GameStep({
  level,
  setLevel,
  formats,
  toggleFormat,
  languages,
  toggleLanguage,
  bio,
  setBio,
  skills,
  setSkill
}: {
  level: SkillLevel;
  setLevel: (v: SkillLevel) => void;
  formats: MatchFormat[];
  toggleFormat: (f: MatchFormat) => void;
  languages: string[];
  toggleLanguage: (l: string) => void;
  bio: string;
  setBio: (v: string) => void;
  skills: PlayerSkills;
  setSkill: (key: keyof PlayerSkills, value: number) => void;
}) {
  const { t } = useI18n();
  return (
    <View style={cardWrapper}>
      <Field label={t("onboarding.field.level")}>
        <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
          {t("onboarding.field.levelHint")}
        </Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {LEVELS.map((l) => (
            <Chip
              key={l.value}
              active={level === l.value}
              label={l.labelKey ? t(l.labelKey) : l.label}
              icon={<Icon name={l.icon} size={14} color={level === l.value ? colors.textOnBrand : colors.textPrimary} />}
              onPress={() => setLevel(l.value)}
            />
          ))}
        </View>
      </Field>

      <Field label={t("onboarding.field.formats")}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {FORMATS.map((f) => (
            <Chip
              key={f.value}
              active={formats.includes(f.value)}
              label={t(f.labelKey)}
              icon={<Icon name={f.icon} size={14} color={formats.includes(f.value) ? colors.textOnBrand : colors.textPrimary} />}
              onPress={() => toggleFormat(f.value)}
            />
          ))}
        </View>
      </Field>

      <Field label={t("onboarding.field.languages")}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {LANGUAGES.map((language) => (
            <Chip
              key={language.label}
              label={t(language.labelKey)}
              active={languages.includes(language.label)}
              icon={<Icon name={language.icon} size={13} color={languages.includes(language.label) ? colors.textOnBrand : colors.textPrimary} />}
              onPress={() => toggleLanguage(language.label)}
            />
          ))}
        </View>
      </Field>

      <Field label={t("onboarding.field.skills")}>
        <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
          {t("onboarding.field.skillsHint")}
        </Text>
        <View style={{ gap: spacing.md }}>
          {SKILL_AXES.map((axis) => (
            <SkillAxisInput
              key={axis.key}
              label={t(axis.labelKey)}
              value={skills[axis.key]}
              onChange={(value) => setSkill(axis.key, value)}
            />
          ))}
        </View>
      </Field>

      <Field label={t("onboarding.field.bio")}>
        <TextInput
          value={bio}
          onChangeText={setBio}
          placeholder={t("onboarding.field.bioPlaceholder")}
          multiline
          numberOfLines={3}
          placeholderTextColor={colors.textTertiary}
          style={[inputStyle, { minHeight: 84, textAlignVertical: "top" }]}
          accessibilityLabel={t("onboarding.a11y.bio")}
        />
      </Field>
    </View>
  );
}

function ScheduleStep({
  compact,
  availability,
  setAvailability,
  toggleDay
}: {
  compact: boolean;
  availability: Record<string, DayAvailability>;
  setAvailability: React.Dispatch<React.SetStateAction<Record<string, DayAvailability>>>;
  toggleDay: (day: string) => void;
}) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  return (
    <View style={cardWrapper}>
      <View style={{ gap: spacing.sm, marginBottom: spacing.md }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t("onboarding.schedule.title")}</Text>
        <Text style={{ ...typography.body, color: colors.textSecondary }}>
          {t("onboarding.schedule.subtitle")}
        </Text>
      </View>

      <View style={{ gap: compact ? 7 : spacing.xs }}>
        {DAYS.map((day) => {
          const dayLabel = t(DAY_KEYS[day]);
          const active = Boolean(availability[day]?.active);
          const startInvalid = active && !isValidTime(availability[day].start);
          const endInvalid = active && !isValidTime(availability[day].end);
          return (
            <View
              key={day}
              style={{
                alignItems: "stretch",
                backgroundColor: colors.surface,
                borderColor: active ? colors.court : colors.border,
                borderRadius: radii.md,
                borderWidth: 1,
                gap: spacing.sm,
                paddingHorizontal: compact ? spacing.sm : spacing.md,
                paddingVertical: compact ? 9 : spacing.sm
              }}
            >
              <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
                <Text style={{ ...typography.bodyEmphasized, color: colors.textPrimary }}>{dayLabel}</Text>
                <Switch
                  value={active}
                  onValueChange={() => toggleDay(day)}
                  thumbColor={active ? "#ffffff" : colors.textTertiary}
                  trackColor={{ false: colors.border, true: colors.court }}
                  accessibilityLabel={t("onboarding.day.available").replace("{day}", dayLabel)}
                />
              </View>
              {active ? (
                <Animated.View entering={FadeIn.duration(180)} style={{ alignItems: "center", flexDirection: "row", gap: compact ? 7 : spacing.sm, width: "100%" }}>
                  <TimeInput
                    value={availability[day].start}
                    onChange={(start) => setAvailability((current) => ({ ...current, [day]: { ...current[day], start } }))}
                    placeholder="18:00"
                    compact={compact}
                    invalid={startInvalid}
                  />
                  <Icon name="chevron-right" size={14} color={colors.textTertiary as string} />
                  <TimeInput
                    value={availability[day].end}
                    onChange={(end) => setAvailability((current) => ({ ...current, [day]: { ...current[day], end } }))}
                    placeholder="21:00"
                    compact={compact}
                    invalid={endInvalid}
                  />
                </Animated.View>
              ) : null}
            </View>
          );
        })}
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

/** Selector 1-10 por eje técnico — segmentos táctiles optimizados para móvil. */
function SkillAxisInput({ label, value, onChange }: { label: string; value: number; onChange: (value: number) => void }) {
  const { t } = useI18n();
  const rounded = Math.max(1, Math.min(10, Math.round(value)));
  return (
    <View style={{ gap: 6 }}>
      <View style={{ alignItems: "center", flexDirection: "row", justifyContent: "space-between" }}>
        <Text style={{ ...typography.caption, color: colors.textSecondary }}>{label}</Text>
        <Text style={{ ...typography.caption, color: colors.court, fontWeight: "800" }}>{rounded}/10</Text>
      </View>
      <View style={{ flexDirection: "row", gap: 4 }}>
        {Array.from({ length: 10 }, (_, index) => index + 1).map((n) => {
          const active = n <= rounded;
          return (
            <Pressable
              key={n}
              accessibilityLabel={t("onboarding.skill.a11y").replace("{label}", label).replace("{n}", String(n))}
              accessibilityRole="button"
              hitSlop={4}
              onPress={() => {
                if (Platform.OS !== "web") void Haptics.selectionAsync();
                onChange(n);
              }}
              style={{
                backgroundColor: active ? colors.court : colors.surfaceElevated,
                borderColor: active ? colors.court : colors.borderStrong,
                borderRadius: 6,
                borderWidth: 1,
                flex: 1,
                height: 28
              }}
            />
          );
        })}
      </View>
    </View>
  );
}

function BrandBadge() {
  const { isLight } = useThemeMode();
  return (
    <View style={{ alignItems: "center", alignSelf: "center" }}>
      <BrandLockup size="sm" light={isLight} />
    </View>
  );
}

function StepProgress({ current, total }: { current: number; total: number }) {
  const { t } = useI18n();
  return (
    <View style={{ gap: spacing.sm, paddingHorizontal: spacing.base }}>
      <View style={{ flexDirection: "row", gap: spacing.xs }}>
        {Array.from({ length: total }).map((_, i) => (
          <View
            key={i}
            style={{
              backgroundColor: i <= current ? colors.neon : colors.borderStrong,
              borderRadius: radii.pill,
              flex: 1,
              height: 4,
              opacity: i <= current ? 1 : 0.55
            }}
          />
        ))}
      </View>
      <Text style={{ ...typography.caption, color: colors.textTertiary, letterSpacing: 0.6 }}>
        {t("onboarding.progress")} · {current + 1}/{total}
      </Text>
    </View>
  );
}

const inputStyle: TextStyle = {
  ...typography.body,
  backgroundColor: colors.surfaceElevated,
  borderColor: colors.borderStrong,
  borderRadius: radii.md,
  borderWidth: 1,
  color: colors.textPrimary,
  paddingHorizontal: spacing.md,
  paddingVertical: spacing.md,
  minHeight: 48
};

const cardWrapper: ViewStyle = {
  backgroundColor: colors.surface,
  borderRadius: radii.lg,
  borderWidth: 1,
  borderColor: colors.borderStrong,
  boxShadow: "0 8px 24px rgba(0,0,0,0.35), 0 2px 6px rgba(0,0,0,0.22)",
  gap: spacing.lg,
  padding: spacing.lg
};

const glassErrorStyle: ViewStyle = {
  alignItems: "center",
  backgroundColor: colors.surface,
  borderColor: colors.borderStrong,
  borderRadius: radii.xl,
  borderWidth: 1,
  boxShadow: shadows.floating,
  gap: spacing.md,
  maxWidth: 440,
  padding: spacing.xl,
  width: "100%"
};

const wazeRowStyle: ViewStyle = {
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xs,
  marginTop: spacing.sm,
  alignSelf: "flex-start"
};

function Field({
  label,
  required,
  children,
  style
}: {
  label: string;
  required?: boolean;
  children: React.ReactNode;
  style?: ViewStyle;
}) {
  return (
    <View style={[{ gap: spacing.sm }, style]}>
      <Text style={{ ...typography.subheadline, color: colors.textSecondary, letterSpacing: 0.2 }}>
        {label}
        {required ? <Text style={{ color: colors.danger }}> *</Text> : null}
      </Text>
      {children}
    </View>
  );
}

function describeError(error: unknown, fallback: string) {
  if (error instanceof Error) return error.message;
  return fallback;
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number, timeoutMessage: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(timeoutMessage)), milliseconds)
    )
  ]);
}
