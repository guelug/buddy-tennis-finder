import { Link, Redirect, Tabs, usePathname } from "expo-router";
import { Platform, Pressable, Text, View } from "react-native";
import { BlurView } from "expo-blur";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { Easing, useAnimatedStyle, useSharedValue, withTiming } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { Icon, type IconName } from "@/components/icon";
import { BrandLockup } from "@/components/brand-lockup";
import { TennisBall } from "@/components/tennis-ball";
import { useAuth } from "@/lib/firebase-auth";
import { useI18n } from "@/lib/i18n";
import { colors, contentWidth, mobileTabBar, radii, shadows, spacing, statusBarTopInset, typography, useBreakpoint, useThemeMode } from "@/theme";

const inactiveColor = "#5E7266";

const NAV_ITEMS: Array<{ href: string; name: string; labelKey: string; icon: IconName }> = [
  { href: "/", name: "index", labelKey: "tabs.rivals", icon: "tennis" },
  { href: "/matches", name: "matches", labelKey: "tabs.matches", icon: "calendar-clock" },
  { href: "/liga", name: "liga", labelKey: "tabs.ranking", icon: "trophy" },
  { href: "/profile", name: "profile", labelKey: "tabs.profile", icon: "user" }
];

function TabBarBlurBackground() {
  const { isLight } = useThemeMode();
  if (Platform.OS === "web") {
    return <View style={[{ flex: 1, backgroundColor: isLight ? "rgba(249,252,247,0.94)" : "rgba(11,16,12,0.94)" }]} />;
  }
  return <BlurView intensity={isLight ? 34 : 28} tint={isLight ? "systemChromeMaterialLight" : "systemChromeMaterialDark"} style={{ flex: 1 }} />;
}

export default function TabsLayout() {
  const { isDesktop } = useBreakpoint();
  const { user, isConfigured } = useAuth();
  const isWeb = Platform.OS === "web";
  const { isLight, toggleMode } = useThemeMode();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (isConfigured && !user) {
    return <Redirect href="/login" />;
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      {isWeb && isDesktop ? <TopNav /> : null}
      <Tabs
        screenOptions={{
          headerShown: !isDesktop,
          headerShadowVisible: false,
          headerTransparent: false,
          headerTitleAlign: "center",
          headerStatusBarHeight: isWeb ? undefined : statusBarTopInset(insets.top),
          headerLeft: () => (
            <View style={{ paddingLeft: spacing.xs, justifyContent: "center" }}>
              <BrandLockup size="sm" stacked={false} light={isLight} />
            </View>
          ),
          headerStyle: {
            backgroundColor: colors.surface,
            minHeight: Platform.OS === "android" ? 52 + statusBarTopInset(insets.top) : undefined
          },
          headerTitleContainerStyle: {
            paddingVertical: 4
          },
          headerTitleStyle: {
            ...typography.headline,
            color: colors.textPrimary
          },
          headerTintColor: colors.textPrimary,
          headerRightContainerStyle: {
            paddingRight: spacing.sm,
            paddingTop: Platform.OS === "android" ? 2 : 0
          },
          headerLeftContainerStyle: {
            paddingLeft: spacing.sm,
            paddingTop: Platform.OS === "android" ? 2 : 0
          },
          headerRight: () => (
            <Pressable
              accessibilityLabel={t(isLight ? "common.darkMode" : "common.lightMode")}
              hitSlop={8}
              onPress={toggleMode}
              style={{
                alignItems: "center",
                backgroundColor: colors.courtLight,
                borderColor: colors.borderStrong,
                borderRadius: radii.pill,
                borderWidth: 1,
                flexDirection: "row",
                marginRight: spacing.xs,
                minHeight: 36,
                paddingHorizontal: spacing.md,
                paddingVertical: 8
              }}
            >
              <Icon name={isLight ? "zap" : "globe"} size={18} color={colors.court as string} weight="bold" />
              <Text style={{ ...typography.footnote, color: colors.textPrimary, fontWeight: "600", marginLeft: 6 }}>{t(isLight ? "common.darkMode" : "common.lightMode")}</Text>
            </Pressable>
          ),
          tabBarActiveTintColor: colors.neon as string,
          tabBarHideOnKeyboard: true,
          tabBarInactiveTintColor: inactiveColor,
          tabBarLabelStyle: {
            ...typography.caption,
            fontSize: 11,
            fontWeight: "600",
            marginTop: -2
          },
          tabBarBackground: TabBarBlurBackground,
          tabBarItemStyle: {
            paddingVertical: 4
          },
          tabBarStyle: isWeb ? { display: "none" } : { display: "none" }
        }}
        tabBar={isDesktop && isWeb ? undefined : (props) => <ConceptMobileTabBar {...props} />}
      >
        {NAV_ITEMS.map((item) => (
          <Tabs.Screen
            key={item.name}
            name={item.name}
            options={{
              title: t(item.labelKey),
              headerTitle: item.name === "profile" ? t("tabs.myProfile") : t(item.labelKey),
              tabBarLabel: t(item.labelKey),
              tabBarIcon: ({ color, focused }) => (
                <Icon name={item.icon} size={24} color={color} weight={focused ? "bold" : "regular"} />
              )
            }}
          />
        ))}
        <Tabs.Screen name="home" options={{ href: null, title: t("tabs.home"), headerShown: false }} />
      </Tabs>
    </View>
  );
}

function ConceptMobileTabBar({ state, navigation }: { state: any; navigation: any }) {
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const inactive = isLight ? colors.textTertiary : inactiveColor;
  const bottomPadding = Math.max(mobileTabBar.minBottomPad, insets.bottom);

  return (
    <View
      pointerEvents="box-none"
      style={{
        bottom: 0,
        left: 0,
        paddingBottom: bottomPadding,
        paddingHorizontal: spacing.base,
        position: "absolute",
        right: 0,
        zIndex: 50
      }}
    >
      <BlurView
        intensity={isLight ? 38 : 32}
        tint={isLight ? "systemChromeMaterialLight" : "systemChromeMaterialDark"}
        experimentalBlurMethod={Platform.OS === "android" ? "dimezisBlurView" : undefined}
        style={{
          backgroundColor: isLight ? "rgba(249,252,247,0.72)" : "rgba(11,16,12,0.72)",
          borderColor: colors.borderStrong,
          borderCurve: "continuous",
          borderRadius: 30,
          borderWidth: 1,
          boxShadow: shadows.floating,
          height: mobileTabBar.pillHeight,
          // `hidden` recorta el blur al radio: con `visible` iOS pintaba el
          // efecto como un rectángulo opaco (las esquinas no se recortaban).
          // La pelota central es un hermano fuera de este BlurView, así que
          // no se ve afectada por el recorte.
          overflow: "hidden"
        }}
      >
        <View
          style={{
            alignItems: "center",
            flexDirection: "row",
            height: "100%",
            justifyContent: "space-around",
            paddingHorizontal: spacing.sm
          }}
        >
          {state.routes.map((route: any, index: number) => {
            const item = NAV_ITEMS.find((nav) => nav.name === route.name);
            if (!item) return null;
            const focused = state.index === index;
            const isLeftOfCenter = index === 1;
            const isRightOfCenter = index === 2;

            return (
              <Pressable
                key={route.key}
                accessibilityRole="button"
                onPress={() => {
                  const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
                  if (!focused && !event.defaultPrevented) {
                    if (Platform.OS !== "web") void Haptics.selectionAsync();
                    navigation.navigate(route.name);
                  }
                }}
                style={{
                  alignItems: "center",
                  flex: 1,
                  gap: 3,
                  justifyContent: "center",
                  marginRight: isLeftOfCenter ? 30 : 0,
                  marginLeft: isRightOfCenter ? 30 : 0,
                  minHeight: 58
                }}
              >
                <Icon
                  name={item.icon}
                  size={22}
                  color={(focused ? colors.neon : inactive) as string}
                  weight={focused ? "bold" : "regular"}
                />
                <Text
                  style={{
                    ...typography.footnote,
                    color: (focused ? colors.neon : inactive) as string,
                    fontSize: 10,
                    fontWeight: focused ? "700" : "600"
                  }}
                >
                  {t(item.labelKey)}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </BlurView>

      <CenterBallButton
        bottomOffset={bottomPadding + Math.max(0, (mobileTabBar.pillHeight - mobileTabBar.ballSize) / 2 + 6)}
        focused={state.routes[state.index]?.name === "home"}
        onPress={() => navigation.navigate("home")}
      />
    </View>
  );
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

function CenterBallButton({ focused, onPress, bottomOffset }: { focused: boolean; onPress: () => void; bottomOffset: number }) {
  const pressed = useSharedValue(0);
  const spin = useSharedValue(0);
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 1 - pressed.value * 0.1 }, { rotate: `${spin.value}deg` }]
  }));

  return (
    <AnimatedPressable
      accessibilityLabel="Abrir inicio"
      accessibilityRole="button"
      onPress={() => {
        if (Platform.OS !== "web") void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        spin.value = withTiming(spin.value + 540, { duration: 680, easing: Easing.out(Easing.cubic) });
        onPress();
      }}
      onPressIn={() => { pressed.value = withTiming(1, { duration: 90 }); }}
      onPressOut={() => { pressed.value = withTiming(0, { duration: 130 }); }}
      style={[animatedStyle, {
        alignItems: "center",
        alignSelf: "center",
        backgroundColor: colors.background,
        borderColor: focused ? colors.neon : `${colors.neon}66`,
        borderRadius: 999,
        borderWidth: focused ? 2 : 1,
        bottom: bottomOffset,
        boxShadow: shadows.spotlightGlow,
        height: mobileTabBar.ballSize,
        justifyContent: "center",
        position: "absolute",
        width: mobileTabBar.ballSize,
        zIndex: 51
      }]}
    >
      <View style={{ alignItems: "center", borderColor: `${colors.neon}44`, borderRadius: 999, borderWidth: 1, height: mobileTabBar.ballSize - 8, justifyContent: "center", overflow: "visible", width: mobileTabBar.ballSize - 8 }}>
        <TennisBall size={mobileTabBar.ballSize + 2} animated={false} />
      </View>
    </AnimatedPressable>
  );
}

function TopNav({ compact = false }: { compact?: boolean }) {
  const pathname = usePathname();
  const inactive = inactiveColor;
  const textSecondary = colors.textSecondary;
  const { isLight, toggleMode } = useThemeMode();
  const { t } = useI18n();

  return (
    <View
      style={{
        alignItems: "center",
        backgroundColor: isLight ? "rgba(249,252,247,.90)" : "rgba(10,15,11,.90)",
        backdropFilter: "blur(20px)" as const,
        borderBottomColor: colors.border,
        borderBottomWidth: 1,
        boxShadow: shadows.subtle,
        paddingHorizontal: compact ? spacing.base : spacing.xl,
        position: "sticky" as "relative",
        top: 0,
        zIndex: 20
      }}
    >
      <View
        style={{
          alignItems: "center",
          flexDirection: "row",
          height: compact ? 58 : 72,
          justifyContent: "space-between",
          maxWidth: contentWidth.wide,
          width: "100%"
        }}
      >
        <Link href={"/home" as never} asChild>
          <Pressable style={{ alignItems: "center", flexDirection: "row", minWidth: compact ? undefined : 210 }}>
            <BrandLockup size={compact ? "sm" : "md"} stacked={!compact} light={isLight} />
          </Pressable>
        </Link>

        <View style={{ alignItems: "center", flexDirection: "row", gap: spacing.xs }}>
          {NAV_ITEMS.map((item) => {
            const active =
              item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            return (
              <Link key={item.name} href={item.href as never} asChild>
                <Pressable
                  style={{
                    alignItems: "center",
                    backgroundColor: active ? colors.courtLight : "transparent",
                    borderRadius: radii.pill,
                    flexDirection: "row",
                    gap: compact ? 0 : spacing.sm,
                    height: 40,
                    justifyContent: "center",
                    paddingHorizontal: compact ? spacing.md : spacing.base
                  }}
                >
                  <Icon
                    name={item.icon}
                    size={17}
                    color={(active ? colors.neon : inactive) as string}
                    weight={active ? "bold" : "regular"}
                  />
                  {!compact ? (
                    <Text
                      style={{
                        ...typography.bodyEmphasized,
                        color: (active ? colors.neon : textSecondary) as string,
                        fontSize: 14
                      }}
                    >
                      {t(item.labelKey)}
                    </Text>
                  ) : null}
                </Pressable>
              </Link>
            );
          })}
          <Pressable
            accessibilityLabel={t(isLight ? "common.darkMode" : "common.lightMode")}
            onPress={toggleMode}
            style={{
              alignItems: "center",
              backgroundColor: colors.courtLight,
              borderRadius: radii.pill,
              height: 40,
              justifyContent: "center",
              marginLeft: spacing.xs,
              paddingHorizontal: spacing.md
            }}
          >
            <Icon name={isLight ? "zap" : "globe"} size={17} color={colors.court as string} weight="bold" />
            <Text style={{ ...typography.footnote, color: colors.textPrimary, fontWeight: "600", marginLeft: 6 }}>{t(isLight ? "common.darkMode" : "common.lightMode")}</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}
