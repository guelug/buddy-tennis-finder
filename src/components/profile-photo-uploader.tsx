import { useEffect, useState } from "react";
import { Image, Pressable, Text, View } from "react-native";
import * as ImagePicker from "expo-image-picker";
import Animated, {
  Easing,
  FadeIn,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming
} from "react-native-reanimated";
import { Icon } from "@/components/icon";
import { uploadProfilePhoto } from "@/lib/profile-photo";
import { useI18n } from "@/lib/i18n";
import { colors, radii, shadows, spacing, typography } from "@/theme";

type UploadState = "idle" | "scanning" | "complete" | "error";

export function ProfilePhotoUploader({
  uid,
  name,
  value,
  onChange
}: {
  uid: string;
  name: string;
  value?: string | null;
  onChange: (url: string) => void;
}) {
  const { t } = useI18n();
  const [preview, setPreview] = useState<string | null>(value ?? null);
  const [state, setState] = useState<UploadState>("idle");
  const [progress, setProgress] = useState(0);
  const scan = useSharedValue(0);

  useEffect(() => {
    scan.value = state === "scanning"
      ? withRepeat(withTiming(1, { duration: 1250, easing: Easing.inOut(Easing.quad) }), -1, true)
      : 0;
  }, [scan, state]);

  const scanStyle = useAnimatedStyle(() => ({ transform: [{ translateY: scan.value * 164 }] }));

  async function choosePhoto() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.88
    });
    if (result.canceled) return;

    const uri = result.assets[0].uri;
    setPreview(uri);
    setProgress(0);
    setState("scanning");
    try {
      const url = await uploadProfilePhoto(uid, uri, setProgress);
      onChange(url);
      setProgress(1);
      setState("complete");
      setTimeout(() => setState("idle"), 1800);
    } catch {
      setState("error");
    }
  }

  return (
    <View style={{ alignItems: "center", gap: spacing.md }}>
      <Pressable
        accessibilityLabel={t("onboarding.photo.a11y")}
        disabled={state === "scanning"}
        onPress={choosePhoto}
        style={{
          borderColor: state === "complete" ? colors.success : `${colors.neon}88`,
          borderRadius: 999,
          borderWidth: 2,
          boxShadow: shadows.courtGlow,
          height: 184,
          overflow: "hidden",
          width: 184
        }}
      >
        {preview ? (
          <Image source={{ uri: preview }} resizeMode="cover" style={{ height: "100%", width: "100%" }} />
        ) : (
          <View style={{ alignItems: "center", backgroundColor: colors.surfaceCourt, flex: 1, gap: spacing.sm, justifyContent: "center" }}>
            <Icon name="user" size={42} color={colors.neon as string} />
            <Text style={{ ...typography.caption, color: colors.textSecondary }}>{t("onboarding.photo.add")}</Text>
          </View>
        )}

        {state === "scanning" ? (
          <>
            <View style={{ backgroundColor: "rgba(4,12,7,0.38)", bottom: 0, left: 0, position: "absolute", right: 0, top: 0 }} />
            <Animated.View
              style={[
                scanStyle,
                {
                  backgroundColor: colors.neon,
                  boxShadow: `0 0 22px ${colors.neon}`,
                  height: 2,
                  left: 10,
                  position: "absolute",
                  right: 10,
                  top: 8
                }
              ]}
            />
            <View style={{ alignItems: "center", bottom: 0, justifyContent: "center", left: 0, position: "absolute", right: 0, top: 0 }}>
              <View style={{ backgroundColor: "rgba(4,12,7,0.82)", borderRadius: radii.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm }}>
                <Text style={{ ...typography.caption, color: colors.neon }}>{t("onboarding.photo.scanning", { percent: Math.round(progress * 100) })}</Text>
              </View>
            </View>
          </>
        ) : null}

        {state === "complete" ? (
          <Animated.View entering={FadeIn} style={{ alignItems: "center", backgroundColor: "rgba(4,12,7,0.58)", bottom: 0, justifyContent: "center", left: 0, position: "absolute", right: 0, top: 0 }}>
            <Icon name="check-badge" size={44} color={colors.neon as string} />
          </Animated.View>
        ) : null}
      </Pressable>

      <View style={{ alignItems: "center", gap: 3 }}>
        <Text style={{ ...typography.subheadline, color: colors.textPrimary }}>
          {state === "scanning"
            ? t("onboarding.photo.optimizing")
            : state === "complete"
              ? t("onboarding.photo.ready")
              : t("onboarding.photo.label", { name: name || t("onboarding.photo.playerFallback") })}
        </Text>
        <Text style={{ ...typography.footnote, color: state === "error" ? colors.danger : colors.textSecondary, textAlign: "center" }}>
          {state === "error" ? t("onboarding.photo.error") : t("onboarding.photo.hint")}
        </Text>
      </View>
    </View>
  );
}
