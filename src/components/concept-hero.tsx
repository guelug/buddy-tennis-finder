import * as React from "react";
import { Text, View } from "react-native";
import Animated, { FadeIn, FadeInUp } from "react-native-reanimated";
import { BallBounce } from "@/components/ball-bounce";
import { Icon, type IconName } from "@/components/icon";
import { TennisBall } from "@/components/tennis-ball";
import { broadcast, radii, shadows, spacing, typography, useBreakpoint } from "@/theme";

// Placa "broadcast" siempre oscura: paleta fija, idéntica en claro y oscuro.
const PLATE_BG = "rgba(11,44,26,0.96)";
const NEON = "#C6F135";
const NEON_SOFT = "rgba(198,241,53,0.14)";
const INK_ON_NEON = "#08130A";

type ConceptHeroMetric = {
  label: string;
  value: string | number;
  icon: IconName;
};

type ConceptHeroChip = {
  label: string;
  value: string;
  icon: IconName;
};

type ConceptHeroProps = {
  kicker: string;
  title: string;
  body: string;
  metrics: ConceptHeroMetric[];
  chips: ConceptHeroChip[];
  centerLabel?: string;
};

export function ConceptHero({ kicker, title, body, metrics, chips, centerLabel = "LIVE" }: ConceptHeroProps) {
  const { isCompact } = useBreakpoint();

  return (
    <Animated.View
      entering={FadeInUp.springify().damping(20)}
      style={{
        backgroundColor: PLATE_BG,
        borderColor: "rgba(198,241,53,0.21)",
        borderCurve: "continuous",
        borderRadius: radii.xl,
        borderWidth: 1,
        boxShadow: shadows.courtGlow,
        gap: spacing.lg,
        minHeight: 310,
        overflow: "hidden",
        padding: spacing.lg
      }}
    >
      <View style={{ bottom: -70, left: -50, opacity: 0.22, position: "absolute" }}>
        <Orbit size={260} />
      </View>
      <View style={{ opacity: 0.34, position: "absolute", right: -70, top: -70 }}>
        <Orbit size={280} />
      </View>

      <View
        style={{
          alignItems: "center",
          flexDirection: isCompact ? "column" : "row",
          gap: spacing.lg
        }}
      >
        <View style={{ flex: 1, gap: spacing.sm, minWidth: 0 }}>
          <Text style={{ ...broadcast.jersey, color: NEON, fontSize: 12, letterSpacing: 2 }}>
            {kicker}
          </Text>
          <Text style={{ ...broadcast.hero, color: "#FFFFFF", fontSize: 42, lineHeight: 42 }}>
            {title}
          </Text>
          <Text style={{ ...typography.body, color: "rgba(255,255,255,0.72)", maxWidth: 620 }}>
            {body}
          </Text>
        </View>

        <View
          style={{
            alignItems: "center",
            justifyContent: "center",
            minHeight: isCompact ? 134 : 150,
            minWidth: isCompact ? 134 : 150
          }}
        >
          <View
            style={{
              borderColor: "rgba(198,241,53,0.20)",
              borderRadius: 86,
              borderWidth: 1,
              height: isCompact ? 148 : 172,
              position: "absolute",
              width: isCompact ? 148 : 172
            }}
          />
          <View
            style={{
              borderColor: "rgba(255,255,255,0.08)",
              borderRadius: 66,
              borderWidth: 1,
              height: isCompact ? 112 : 132,
              position: "absolute",
              transform: [{ rotate: "18deg" }],
              width: isCompact ? 112 : 132
            }}
          />
          <BallBounce delay={120} dropDistance={30}>
            <TennisBall animated={false} size={isCompact ? 88 : 104} />
          </BallBounce>
          <View
            style={{
              backgroundColor: NEON,
              borderRadius: radii.pill,
              bottom: 2,
              boxShadow: shadows.spotlightGlow,
              paddingHorizontal: spacing.md,
              paddingVertical: 5,
              position: "absolute"
            }}
          >
            <Text style={{ ...broadcast.jersey, color: INK_ON_NEON, fontSize: 11 }}>{centerLabel}</Text>
          </View>
        </View>
      </View>

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
        {metrics.map((metric, index) => (
          <Animated.View
            entering={FadeIn.delay(120 + index * 60).springify()}
            key={metric.label}
            style={{
              backgroundColor: "rgba(0,0,0,0.28)",
              borderColor: "rgba(255,255,255,0.10)",
              borderRadius: radii.lg,
              borderWidth: 1,
              flex: 1,
              flexDirection: "row",
              gap: spacing.sm,
              minWidth: 132,
              padding: spacing.md
            }}
          >
            <View
              style={{
                alignItems: "center",
                backgroundColor: NEON_SOFT,
                borderRadius: radii.md,
                height: 36,
                justifyContent: "center",
                width: 36
              }}
            >
              <Icon name={metric.icon} size={17} color={NEON} />
            </View>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={{ ...broadcast.stat, color: "#FFFFFF" }}>{metric.value}</Text>
              <Text style={{ ...typography.footnote, color: "rgba(255,255,255,0.55)" }} numberOfLines={1}>
                {metric.label}
              </Text>
            </View>
          </Animated.View>
        ))}
      </View>

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
        {chips.map((chip) => (
          <View
            key={`${chip.label}-${chip.value}`}
            style={{
              alignItems: "center",
              backgroundColor: "rgba(8,19,10,0.52)",
              borderColor: "rgba(255,255,255,0.10)",
              borderRadius: radii.pill,
              borderWidth: 1,
              flexDirection: "row",
              gap: spacing.sm,
              paddingHorizontal: spacing.md,
              paddingVertical: spacing.sm
            }}
          >
            <Icon name={chip.icon} size={14} color={NEON} />
            <Text style={{ ...typography.footnote, color: "rgba(255,255,255,0.52)" }}>{chip.label}</Text>
            <Text style={{ ...typography.footnote, color: "#FFFFFF", fontWeight: "800" }} numberOfLines={1}>
              {chip.value}
            </Text>
          </View>
        ))}
      </View>
    </Animated.View>
  );
}

function Orbit({ size }: { size: number }) {
  return (
    <View
      style={{
        borderColor: NEON,
        borderRadius: size / 2,
        borderWidth: 1,
        height: size,
        width: size
      }}
    >
      <View
        style={{
          borderColor: "rgba(255,255,255,0.30)",
          borderRadius: size / 2,
          borderWidth: 1,
          bottom: size * 0.18,
          left: size * 0.18,
          position: "absolute",
          right: size * 0.18,
          top: size * 0.18,
          transform: [{ rotate: "18deg" }]
        }}
      />
    </View>
  );
}
