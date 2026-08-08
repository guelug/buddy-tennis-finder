import { useEffect, useState } from "react";
import { Alert } from "react-native";
import { router } from "expo-router";
import { GroupedRow } from "@/components/grouped-list";
import { adsPrivacyOptionsRequired, showAdsPrivacyOptions, startAds } from "@/lib/ads";
import { useI18n } from "@/lib/i18n";

/** Required UMP entry point for users who can revisit their consent choices. */
export function AdPrivacyRow({ age }: { age?: number }) {
  const { t } = useI18n();
  const [required, setRequired] = useState(false);

  useEffect(() => {
    let active = true;
    void startAds(age)
      .then(() => adsPrivacyOptionsRequired())
      .then((nextRequired) => { if (active) setRequired(nextRequired); })
      .catch(() => {});
    return () => { active = false; };
  }, [age]);

  return (
    <GroupedRow
      label={t("ads.privacy.title")}
      value={t("ads.privacy.hint")}
      icon="globe"
      onPress={async () => {
        try {
          if (!required) {
            router.push("/privacy");
            return;
          }
          await showAdsPrivacyOptions();
          setRequired(await adsPrivacyOptionsRequired());
        } catch {
          Alert.alert(t("ads.privacy.title"), t("ads.privacy.error"));
        }
      }}
    />
  );
}
