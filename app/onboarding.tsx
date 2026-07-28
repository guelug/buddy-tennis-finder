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
import { MatchBuddyPicker } from "@/components/match-buddy-picker";
import { skillsFromRating } from "@/components/skill-radar";
import { useAuth } from "@/lib/firebase-auth";
import { getClubs, getPlayer, savePlayerProfile } from "@/lib/firestore";
import { openInWaze } from "@/lib/waze";
import { colors, contentWidth, spacing, statusBarTopInset, typography, radii, shadows, useThemeMode } from "@/theme";
import { AccountRole, Club, Gender, MatchFormat, PlayerProfileInput, PlayerSkills, SkillLevel } from "@/types";
import { CITIES_BY_COUNTRY, selectableCountries, Country } from "@/data/seed";
import { SUPPORTED_LANGUAGES, useI18n } from "@/lib/i18n";

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

/**
 * El onboarding avanza pregunta a pregunta: cada pantalla pide una sola cosa,
 * con su propia validación. `section` agrupa las preguntas bajo el mismo
 * antetítulo (Perfil · Juego · Agenda) para que el usuario sepa dónde está.
 */
type QuestionKey =
  | "language"
  | "buddy"
  | "role"
  | "name"
  | "age"
  | "gender"
  | "location"
  | "clubs"
  | "level"
  | "formats"
  | "languages"
  | "skills"
  | "bio"
  | "schedule";

const QUESTIONS: Array<{ key: QuestionKey; eyebrowKey: string; titleKey: string; subtitleKey: string }> = [
  { key: "language", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.language.title", subtitleKey: "onboarding.q.language.subtitle" },
  { key: "buddy", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.buddy.title", subtitleKey: "onboarding.q.buddy.subtitle" },
  { key: "role", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.role.title", subtitleKey: "onboarding.q.role.subtitle" },
  { key: "name", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.name.title", subtitleKey: "onboarding.q.name.subtitle" },
  { key: "age", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.age.title", subtitleKey: "onboarding.q.age.subtitle" },
  { key: "gender", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.gender.title", subtitleKey: "onboarding.q.gender.subtitle" },
  { key: "location", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.location.title", subtitleKey: "onboarding.q.location.subtitle" },
  { key: "clubs", eyebrowKey: "onboarding.step1.eyebrow", titleKey: "onboarding.q.clubs.title", subtitleKey: "onboarding.q.clubs.subtitle" },
  { key: "level", eyebrowKey: "onboarding.step2.eyebrow", titleKey: "onboarding.q.level.title", subtitleKey: "onboarding.q.level.subtitle" },
  { key: "formats", eyebrowKey: "onboarding.step2.eyebrow", titleKey: "onboarding.q.formats.title", subtitleKey: "onboarding.q.formats.subtitle" },
  { key: "languages", eyebrowKey: "onboarding.step2.eyebrow", titleKey: "onboarding.q.languages.title", subtitleKey: "onboarding.q.languages.subtitle" },
  { key: "skills", eyebrowKey: "onboarding.step2.eyebrow", titleKey: "onboarding.q.skills.title", subtitleKey: "onboarding.q.skills.subtitle" },
  { key: "bio", eyebrowKey: "onboarding.step2.eyebrow", titleKey: "onboarding.q.bio.title", subtitleKey: "onboarding.q.bio.subtitle" },
  { key: "schedule", eyebrowKey: "onboarding.step3.eyebrow", titleKey: "onboarding.q.schedule.title", subtitleKey: "onboarding.q.schedule.subtitle" }
];

const LAST_STEP = QUESTIONS.length - 1;

/**
 * `selectableCountries` es una tupla literal, así que comparar su `length`
 * contra 1 lo resolvía TypeScript en tiempo de compilación. Con la lista
 * ensanchada, la preselección vuelve a depender de cuántos mercados haya
 * abiertos en cada momento.
 */
const OPEN_COUNTRIES: readonly Country[] = selectableCountries;

function onlyOption<T>(options: readonly T[]): T | null {
  return options.length === 1 ? options[0] : null;
}

export default function OnboardingScreen() {
  const { width } = useWindowDimensions();
  const compact = width < 560;
  const insets = useSafeAreaInsets();
  const { isLight } = useThemeMode();
  const { user } = useAuth();
  const { t } = useI18n();
  const [step, setStep] = useState(0);
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
  const [accountRole, setAccountRole] = useState<AccountRole>("player");
  // Si solo hay un país seleccionable (lanzamiento en Guatemala) lo
  // preseleccionamos, y si ese país tiene una sola ciudad, también. Cuando se
  // abran más mercados vuelve a exigir selección manual automáticamente.
  const [country, setCountry] = useState<Country | null>(() => onlyOption(OPEN_COUNTRIES));
  const [city, setCity] = useState<string | null>(() => {
    const initialCountry = onlyOption(OPEN_COUNTRIES);
    return initialCountry ? onlyOption(CITIES_BY_COUNTRY[initialCountry]) : null;
  });
  const [clubIds, setClubIds] = useState<string[]>([]);
  const [level, setLevel] = useState<SkillLevel>("c");
  const [formats, setFormats] = useState<MatchFormat[]>(["singles"]);
  const [bio, setBio] = useState("");
  const [languages, setLanguages] = useState<string[]>(["Español"]);
  const [skills, setSkills] = useState<PlayerSkills>(() => skillsFromRating(3));
  const [availability, setAvailability] = useState<Record<string, DayAvailability>>({});
  const [isFirstProfile, setIsFirstProfile] = useState(true);
  const [touched, setTouched] = useState(false);

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
      setAccountRole(player.accountRole ?? "player");
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

  /** Validez de cada pregunta: solo bloquea el avance de su propia pantalla. */
  const answered: Record<QuestionKey, boolean> = {
    language: true,
    buddy: true,
    role: true,
    name: name.trim().length > 1,
    age: ageValid,
    gender: gender !== null,
    location: country !== null && city !== null,
    clubs: clubIds.length > 0,
    level: true,
    formats: formats.length > 0,
    languages: languages.length > 0,
    skills: true,
    bio: true,
    schedule: true
  };

  const question = QUESTIONS[step];
  const currentValid = answered[question.key];
  const canSave = QUESTIONS.every((item) => answered[item.key]);

  /** Primera pregunta sin responder — para el atajo "Guardar" al editar. */
  const firstUnanswered = useMemo(
    () => QUESTIONS.findIndex((item) => !answered[item.key]),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [name, age, gender, country, city, clubIds, formats, languages]
  );

  const stepHint = useMemo(() => {
    if (currentValid) return null;
    if (question.key === "clubs" && (!country || !city)) return t("onboarding.q.clubs.pickCity");
    return t("onboarding.hint.answer");
  }, [currentValid, question.key, country, city, t]);

  function goToStep(next: number) {
    setStep(Math.max(0, Math.min(LAST_STEP, next)));
    setTouched(false);
    setSaveMessage(null);
    scrollRef.current?.scrollTo({ y: 0, animated: false });
  }

  function goNext() {
    setTouched(true);
    setSaveMessage(null);
    if (!currentValid) return;
    if (Platform.OS !== "web") void Haptics.selectionAsync();
    if (step < LAST_STEP) goToStep(step + 1);
  }

  function goBack() {
    if (step > 0) goToStep(step - 1);
  }

  async function handleSave() {
    if (!user) {
      Alert.alert(t("onboarding.save.sessionTitle"), t("onboarding.save.sessionExpired"));
      router.replace("/login");
      return;
    }
    if (!canSave || gender === null) {
      setSaveMessage(t("onboarding.save.reviewRequired"));
      if (firstUnanswered >= 0) goToStep(firstUnanswered);
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
      accountRole,
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
        <View style={glassErrorStyle()}>
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
        <StepProgress current={step} total={QUESTIONS.length} />

        <Animated.View key={`header-${step}`} entering={FadeIn.duration(240)}>
          <View style={{ gap: spacing.sm, paddingHorizontal: spacing.base, marginTop: spacing.sm }}>
            <Text style={{ ...typography.caption, color: colors.court, textTransform: "uppercase", letterSpacing: 1.4, fontWeight: "800" }}>
              {isFirstProfile ? t(question.eyebrowKey) : `${t("onboarding.editing")} · ${t(question.eyebrowKey)}`}
            </Text>
            <Text style={{ ...typography.largeTitle, color: colors.textPrimary, letterSpacing: -0.2 }}>{t(question.titleKey)}</Text>
            <Text style={{ ...typography.body, color: colors.textSecondary }}>{t(question.subtitleKey)}</Text>
          </View>
        </Animated.View>

        <Animated.View key={`body-${step}`} entering={FadeInRight.springify().damping(22).stiffness(180)} exiting={FadeOutLeft.duration(150)}>
          <QuestionCard
            question={question.key}
            compact={compact}
            userId={user?.uid}
            name={name}
            setName={setName}
            age={age}
            setAge={setAge}
            ageValid={ageValid}
            gender={gender}
            setGender={setGender}
            accountRole={accountRole}
            setAccountRole={setAccountRole}
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
            availability={availability}
            setAvailability={setAvailability}
            toggleDay={toggleDay}
            touched={touched}
          />
        </Animated.View>

        {saveMessage ? (
          <Text style={{ ...typography.footnote, color: saving ? colors.court : colors.textSecondary, textAlign: "center" }}>
            {saveMessage}
          </Text>
        ) : null}
        {touched && stepHint ? (
          <Text style={{ ...typography.footnote, color: colors.danger, textAlign: "center" }}>
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
          <View style={{ alignSelf: "center", gap: spacing.sm, maxWidth: contentWidth.narrow + 80, width: "100%" }}>
            <View style={{ flexDirection: "row", gap: spacing.sm }}>
              {step > 0 ? (
                <View style={{ flex: 1 }}>
                  <PrimaryButton label={t("onboarding.back")} variant="outline" onPress={goBack} disabled={saving} />
                </View>
              ) : null}
              <View style={{ flex: step > 0 ? 1.4 : 1 }}>
                {/* El botón nunca se deshabilita por falta de respuesta: al
                    pulsarlo se marca la pregunta como tocada y aparece la pista
                    que explica qué falta. Deshabilitarlo dejaba al usuario
                    bloqueado sin ningún mensaje. */}
                {step < LAST_STEP ? (
                  <PrimaryButton
                    label={t("onboarding.next")}
                    onPress={goNext}
                    disabled={saving}
                    size="lg"
                  />
                ) : (
                  <PrimaryButton
                    label={saving ? t("onboarding.saving") : isFirstProfile ? t("onboarding.saveAndStart") : t("onboarding.saveChanges")}
                    onPress={handleSave}
                    disabled={saving}
                    size="lg"
                  />
                )}
              </View>
            </View>
            {/* Al editar un perfil ya creado nadie debería recorrer las 13
                pantallas para cambiar un dato: se guarda desde cualquier paso. */}
            {!isFirstProfile && step < LAST_STEP ? (
              <PrimaryButton
                label={saving ? t("onboarding.saving") : t("onboarding.saveChanges")}
                variant="ghost"
                onPress={handleSave}
                disabled={saving}
              />
            ) : null}
          </View>
        </View>
      </View>
    </LiveBackground>
  );
}

// ---------------------------------------------------------------------------
// Pregunta actual
// ---------------------------------------------------------------------------

type QuestionCardProps = {
  question: QuestionKey;
  compact: boolean;
  userId?: string;
  name: string;
  setName: (v: string) => void;
  age: string;
  setAge: (v: string) => void;
  ageValid: boolean;
  gender: Gender | null;
  setGender: (v: Gender) => void;
  accountRole: AccountRole;
  setAccountRole: (v: AccountRole) => void;
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
  availability: Record<string, DayAvailability>;
  setAvailability: React.Dispatch<React.SetStateAction<Record<string, DayAvailability>>>;
  toggleDay: (day: string) => void;
  touched: boolean;
};

function QuestionCard(props: QuestionCardProps) {
  const { t, lang, setLang } = useI18n();
  const { question } = props;

  const cityOptions = useMemo(() => (props.country ? CITIES_BY_COUNTRY[props.country] : []), [props.country]);
  const filteredClubs = useMemo(() => {
    if (!props.country || !props.city) return [];
    return props.clubs.filter((c) => c.country === props.country && c.city === props.city);
  }, [props.clubs, props.country, props.city]);

  if (question === "language") {
    return (
      <View style={cardWrapper()}>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
          {SUPPORTED_LANGUAGES.map((language) => (
            <Chip
              key={language.code}
              active={lang === language.code}
              label={language.label}
              onPress={() => setLang(language.code)}
            />
          ))}
        </View>
      </View>
    );
  }

  if (question === "buddy") {
    return (
      <View style={{ gap: spacing.lg }}>
        <View style={{ backgroundColor: colors.surface, borderColor: colors.borderStrong, borderCurve: "continuous", borderRadius: radii.xl, borderWidth: 1, padding: spacing.base }}>
          <MatchBuddyPicker compact={props.compact} />
        </View>
        {props.userId ? (
          <View style={cardWrapper()}>
            <ProfilePhotoUploader uid={props.userId} name={props.name} value={props.photoURL} onChange={props.setPhotoURL} />
          </View>
        ) : null}
      </View>
    );
  }

  if (question === "name") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.name")} required>
          <TextInput
            value={props.name}
            onChangeText={props.setName}
            placeholder={t("onboarding.field.namePlaceholder")}
            placeholderTextColor={colors.textTertiary}
            style={inputStyle()}
            autoComplete="name"
            autoFocus
            accessibilityLabel={t("onboarding.a11y.name")}
          />
        </Field>
      </View>
    );
  }

  if (question === "role") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.role")} required>
          <View style={{ gap: spacing.sm }}>
            {ROLE_OPTIONS.map((option) => {
              const selected = props.accountRole === option.value;
              return (
                <Pressable
                  key={option.value}
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
                  onPress={() => props.setAccountRole(option.value)}
                  style={{
                    alignItems: "center",
                    backgroundColor: selected ? colors.courtLight : colors.surface,
                    borderColor: selected ? colors.neon : colors.border,
                    borderCurve: "continuous",
                    borderRadius: radii.lg,
                    borderWidth: 1,
                    flexDirection: "row",
                    gap: spacing.md,
                    minHeight: 68,
                    padding: spacing.md
                  }}
                >
                  <Icon name={option.icon} size={24} color={(selected ? colors.neon : colors.textSecondary) as string} />
                  <View style={{ flex: 1, gap: 2 }}>
                    <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>{t(option.labelKey)}</Text>
                    <Text style={{ ...typography.footnote, color: colors.textSecondary }}>{t(option.bodyKey)}</Text>
                  </View>
                  {selected ? <Icon name="check-badge" size={20} color={colors.neon as string} /> : null}
                </Pressable>
              );
            })}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "age") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.age")} required>
          <TextInput
            value={props.age}
            onChangeText={(text) => props.setAge(text.replace(/[^0-9]/g, "").slice(0, 3))}
            placeholder={t("onboarding.field.agePlaceholder")}
            keyboardType="numeric"
            placeholderTextColor={colors.textTertiary}
            style={[inputStyle(), props.touched && !props.ageValid ? { borderColor: colors.danger, color: colors.danger } : null]}
            accessibilityLabel={t("onboarding.a11y.age")}
          />
          {props.touched && !props.ageValid ? (
            <Text style={{ ...typography.footnote, color: colors.danger, marginTop: spacing.xs }}>{t("onboarding.field.ageError")}</Text>
          ) : null}
        </Field>
      </View>
    );
  }

  if (question === "gender") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.gender")} required>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {GENDER_OPTIONS.map((g) => (
              <Chip key={g.value} active={props.gender === g.value} label={t(g.labelKey)} onPress={() => props.setGender(g.value)} />
            ))}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "location") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.country")} required>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {selectableCountries.map((c) => (
              <Chip
                key={c}
                active={props.country === c}
                label={c}
                onPress={() => {
                  props.setCountry(c);
                  // Si el país tiene una sola ciudad la fijamos directamente para
                  // ahorrar un toque; si tiene varias, obligamos a re-elegir.
                  const nextCities = CITIES_BY_COUNTRY[c] ?? [];
                  props.setCity(nextCities.length === 1 ? nextCities[0] : null);
                  props.setClubIds([]);
                }}
              />
            ))}
          </View>
        </Field>
        {props.country ? (
          <Field label={t("onboarding.field.city")} required>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
              {cityOptions.map((c) => (
                <Chip
                  key={c}
                  active={props.city === c}
                  label={c}
                  onPress={() => {
                    props.setCity(c);
                    props.setClubIds([]);
                  }}
                />
              ))}
            </View>
          </Field>
        ) : null}
      </View>
    );
  }

  if (question === "clubs") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.clubs")} required>
          <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
            {t("onboarding.field.clubsHint")}
          </Text>
          {!props.country || !props.city ? (
            <Text style={{ ...typography.footnote, color: colors.textTertiary }}>{t("onboarding.q.clubs.pickCity")}</Text>
          ) : filteredClubs.length === 0 ? (
            <Text style={{ ...typography.footnote, color: colors.textTertiary }}>
              {t("onboarding.clubs.empty").replace("{city}", props.city).replace("{country}", props.country)}
            </Text>
          ) : (
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
              {filteredClubs.map((club) => {
                const selected = props.clubIds.includes(club.id);
                const isPrimary = props.clubIds[0] === club.id;
                return (
                  <Chip
                    key={club.id}
                    active={selected}
                    label={isPrimary ? `${club.name} ★` : club.name}
                    onPress={() => props.toggleClub(club.id)}
                    onLongPress={() => props.moveClubToFirst(club.id)}
                  />
                );
              })}
            </View>
          )}
          {props.primaryClub ? (
            <Pressable
              onPress={() => openInWaze(props.primaryClub!.latitude, props.primaryClub!.longitude, props.primaryClub!.name)}
              style={wazeRowStyle}
            >
              <WazeLogo size={15} color={colors.court} />
              <Text style={{ ...typography.caption, color: colors.court }}>
                {t("onboarding.clubs.waze").replace("{club}", props.primaryClub.name)}
              </Text>
            </Pressable>
          ) : null}
        </Field>
      </View>
    );
  }

  if (question === "level") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.level")}>
          <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
            {t("onboarding.field.levelHint")}
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {LEVELS.map((l) => (
              <Chip
                key={l.value}
                active={props.level === l.value}
                label={l.labelKey ? t(l.labelKey) : l.label}
                icon={<Icon name={l.icon} size={14} color={props.level === l.value ? colors.textOnBrand : colors.textPrimary} />}
                onPress={() => props.setLevel(l.value)}
              />
            ))}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "formats") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.formats")} required>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {FORMATS.map((f) => (
              <Chip
                key={f.value}
                active={props.formats.includes(f.value)}
                label={t(f.labelKey)}
                icon={<Icon name={f.icon} size={14} color={props.formats.includes(f.value) ? colors.textOnBrand : colors.textPrimary} />}
                onPress={() => props.toggleFormat(f.value)}
              />
            ))}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "languages") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.languages")} required>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.xs }}>
            {LANGUAGES.map((language) => (
              <Chip
                key={language.label}
                label={t(language.labelKey)}
                active={props.languages.includes(language.label)}
                icon={<Icon name={language.icon} size={13} color={props.languages.includes(language.label) ? colors.textOnBrand : colors.textPrimary} />}
                onPress={() => props.toggleLanguage(language.label)}
              />
            ))}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "skills") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.skills")}>
          <Text style={{ ...typography.footnote, color: colors.textSecondary, marginBottom: spacing.xs }}>
            {t("onboarding.field.skillsHint")}
          </Text>
          <View style={{ gap: spacing.md }}>
            {SKILL_AXES.map((axis) => (
              <SkillAxisInput
                key={axis.key}
                label={t(axis.labelKey)}
                value={props.skills[axis.key]}
                onChange={(value) => props.setSkill(axis.key, value)}
              />
            ))}
          </View>
        </Field>
      </View>
    );
  }

  if (question === "bio") {
    return (
      <View style={cardWrapper()}>
        <Field label={t("onboarding.field.bio")}>
          <TextInput
            value={props.bio}
            onChangeText={props.setBio}
            placeholder={t("onboarding.field.bioPlaceholder")}
            multiline
            numberOfLines={3}
            placeholderTextColor={colors.textTertiary}
            style={[inputStyle(), { minHeight: 84, textAlignVertical: "top" }]}
            accessibilityLabel={t("onboarding.a11y.bio")}
          />
        </Field>
      </View>
    );
  }

  return (
    <ScheduleStep
      compact={props.compact}
      availability={props.availability}
      setAvailability={props.setAvailability}
      toggleDay={props.toggleDay}
    />
  );
}

const GENDER_OPTIONS: Array<{ labelKey: string; value: Gender }> = [
  { labelKey: "onboarding.gender.female", value: "female" },
  { labelKey: "onboarding.gender.male", value: "male" },
  { labelKey: "onboarding.gender.other", value: "other" }
];

const ROLE_OPTIONS: Array<{ labelKey: string; bodyKey: string; value: AccountRole; icon: IconName }> = [
  { labelKey: "onboarding.role.player", bodyKey: "onboarding.role.playerBody", value: "player", icon: "tennis" },
  { labelKey: "onboarding.role.coach", bodyKey: "onboarding.role.coachBody", value: "coach", icon: "users" },
  { labelKey: "onboarding.role.both", bodyKey: "onboarding.role.bothBody", value: "both", icon: "check-badge" }
];

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
  const { t } = useI18n();
  return (
    <View style={cardWrapper()}>
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
      <View style={{ flexDirection: "row", gap: 3 }}>
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

// Factories evaluadas en cada render: `colors`/`shadows` son singletons que el
// proveedor de tema muta según el modo. Definirlas a nivel de módulo horneaba
// los colores oscuros y dejaba tarjetas/inputs oscuros en modo claro.
const inputStyle = (): TextStyle => ({
  ...typography.body,
  backgroundColor: colors.surfaceElevated,
  borderColor: colors.borderStrong,
  borderRadius: radii.md,
  borderWidth: 1,
  color: colors.textPrimary,
  paddingHorizontal: spacing.md,
  paddingVertical: spacing.md,
  minHeight: 48
});

const cardWrapper = (): ViewStyle => ({
  backgroundColor: colors.surface,
  borderRadius: radii.lg,
  borderWidth: 1,
  borderColor: colors.borderStrong,
  boxShadow: shadows.card,
  gap: spacing.lg,
  padding: spacing.lg
});

const glassErrorStyle = (): ViewStyle => ({
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
});

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
