import { useEffect, useState, type ReactNode } from "react";
import { Link, Redirect, Tabs, usePathname } from "expo-router";
import { Platform, Pressable, Text, View } from "react-native";
import { BlurView } from "expo-blur";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { Easing, useAnimatedStyle, useSharedValue, withTiming } from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { Icon, type IconName } from "@/components/icon";
import { BrandLockup } from "@/components/brand-lockup";
import { TennisBall } from "@/components/tennis-ball";
import { MatchBuddyAvatar } from "@/components/match-buddy-picker";
import { useAuth } from "@/lib/firebase-auth";
import { getPlayer } from "@/lib/firestore";
import { useI18n } from "@/lib/i18n";
import { colors, contentWidth, mobileTabBar, radii, shadows, spacing, statusBarTopInset, typography, useBreakpoint, useThemeMode } from "@/theme";

const inactiveColor = "#5E7266";

// Home no va aquí: la pelota central del tab bar (CenterBallButton) es su
// acceso, y la barra reparte estos elementos a izquierda y derecha de ella.
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
  const { isLight } = useThemeMode();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [coachOnly, setCoachOnly] = useState(false);

  useEffect(() => {
    let active = true;
    if (!user?.uid) {
      setCoachOnly(false);
      return;
    }
    void getPlayer(user.uid).then((player) => {
      if (active) setCoachOnly(player?.accountRole === "coach");
    }).catch(() => {});
    return () => { active = false; };
  }, [user?.uid]);

  const itemLabel = (item: (typeof NAV_ITEMS)[number]) =>
    item.name === "index" && coachOnly ? t("nav.coachAd") : t(item.labelKey);

  if (isConfigured && !user) {
    return <Redirect href="/login" />;
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      {isWeb && isDesktop ? <TopNav coachOnly={coachOnly} /> : null}
      <Tabs
        // La app arranca en Home (la pelota), no en Rivales.
        initialRouteName="home"
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
            <Link href={"/assistant" as never} asChild>
              <Pressable accessibilityLabel="Abrir Match Buddy" hitSlop={8} style={{ marginRight: spacing.xs }}>
                <MatchBuddyAvatar size={40} />
              </Pressable>
            </Link>
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
        tabBar={isDesktop && isWeb ? undefined : (props) => <ConceptMobileTabBar {...props} coachOnly={coachOnly} />}
      >
        {NAV_ITEMS.map((item) => (
          <Tabs.Screen
            key={item.name}
            name={item.name}
            options={{
              title: itemLabel(item),
              headerTitle: item.name === "profile" ? t("tabs.myProfile") : itemLabel(item),
              tabBarLabel: itemLabel(item),
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

function ConceptMobileTabBar({ state, navigation, coachOnly }: { state: any; navigation: any; coachOnly: boolean }) {
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
      <TabBarGlassSurface isLight={isLight}>
        <View style={{ alignItems: "center", flexDirection: "row", height: "100%", paddingHorizontal: spacing.xs }}>
          {NAV_ITEMS.slice(0, 2).map((item) => <MobileTabItem key={item.name} item={item} state={state} navigation={navigation} inactive={inactive} label={item.name === "index" && coachOnly ? t("nav.coachAd") : t(item.labelKey)} />)}
          <View pointerEvents="none" style={{ width: mobileTabBar.ballSize + 12 }} />
          {NAV_ITEMS.slice(2).map((item) => <MobileTabItem key={item.name} item={item} state={state} navigation={navigation} inactive={inactive} label={t(item.labelKey)} />)}
        </View>
      </TabBarGlassSurface>

      <CenterBallButton
        bottomOffset={bottomPadding + Math.max(0, (mobileTabBar.pillHeight - mobileTabBar.ballSize) / 2 + 6)}
        focused={state.routes[state.index]?.name === "home"}
        onPress={() => navigation.navigate("home")}
      />
    </View>
  );
}

function TabBarGlassSurface({ children, isLight }: { children: ReactNode; isLight: boolean }) {
  const style = {
    backgroundColor: isLight ? "rgba(249,252,247,0.54)" : "rgba(11,16,12,0.52)",
    borderColor: colors.borderStrong,
    borderCurve: "continuous" as const,
    borderRadius: 30,
    borderWidth: 1,
    boxShadow: shadows.floating,
    height: mobileTabBar.pillHeight,
    overflow: "hidden" as const
  };
  return (
    <BlurView intensity={isLight ? 38 : 32} tint={isLight ? "systemChromeMaterialLight" : "systemChromeMaterialDark"} experimentalBlurMethod={Platform.OS === "android" ? "dimezisBlurView" : undefined} style={style}>
      {children}
    </BlurView>
  );
}

function MobileTabItem({ item, state, navigation, inactive, label }: { item: (typeof NAV_ITEMS)[number]; state: any; navigation: any; inactive: string; label: string }) {
  const routeIndex = state.routes.findIndex((route: any) => route.name === item.name);
  const route = state.routes[routeIndex];
  const focused = state.index === routeIndex;
  if (!route) return null;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: focused }}
      onPress={() => {
        const event = navigation.emit({ type: "tabPress", target: route.key, canPreventDefault: true });
        if (!focused && !event.defaultPrevented) {
          if (Platform.OS !== "web") void Haptics.selectionAsync();
          navigation.navigate(route.name);
        }
      }}
      style={({ pressed }) => ({
        alignItems: "center",
        flex: 1,
        gap: 3,
        justifyContent: "center",
        minHeight: 58,
        opacity: pressed ? 0.72 : 1,
        transform: [{ scale: pressed ? 0.94 : 1 }]
      })}
    >
      <Icon name={item.icon} size={22} color={(focused ? colors.neon : inactive) as string} weight={focused ? "bold" : "regular"} />
      <Text numberOfLines={1} style={{ ...typography.footnote, color: (focused ? colors.neon : inactive) as string, fontSize: 10, fontWeight: focused ? "700" : "600" }}>{label}</Text>
    </Pressable>
  );
}

function CenterBallButton({ focused, onPress, bottomOffset }: { focused: boolean; onPress: () => void; bottomOffset: number }) {
  const pressed = useSharedValue(0);
  const spin = useSharedValue(0);
  const ballMotionStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 1 - pressed.value * 0.1 }, { rotate: `${spin.value}deg` }]
  }));

  return (
    <Pressable
      accessibilityLabel="Abrir inicio"
      accessibilityRole="button"
      onPress={() => {
        if (Platform.OS !== "web") void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
        spin.value = withTiming(spin.value + 540, { duration: 680, easing: Easing.out(Easing.cubic) });
        onPress();
      }}
      onPressIn={() => { pressed.value = withTiming(1, { duration: 90 }); }}
      onPressOut={() => { pressed.value = withTiming(0, { duration: 130 }); }}
      style={{
        alignItems: "center",
        alignSelf: "center",
        backgroundColor: colors.surface,
        borderColor: focused ? `${colors.neon}AA` : `${colors.neon}44`,
        borderRadius: 999,
        borderWidth: 1,
        bottom: bottomOffset,
        boxShadow: focused ? "0 6px 18px rgba(198,241,53,0.22)" : shadows.floating,
        height: mobileTabBar.ballSize,
        justifyContent: "center",
        position: "absolute",
        width: mobileTabBar.ballSize,
        zIndex: 51
      }}
    >
      <Animated.View
        style={[
          ballMotionStyle,
          {
            alignItems: "center",
            borderRadius: (mobileTabBar.ballSize - 6) / 2,
            height: mobileTabBar.ballSize - 6,
            justifyContent: "center",
            overflow: "hidden",
            width: mobileTabBar.ballSize - 6
          }
        ]}
      >
        <TennisBall size={mobileTabBar.ballSize + 2} animated={false} />
      </Animated.View>
    </Pressable>
  );
}

function TopNav({ compact = false, coachOnly = false }: { compact?: boolean; coachOnly?: boolean }) {
  const pathname = usePathname();
  const inactive = inactiveColor;
  const textSecondary = colors.textSecondary;
  const { isLight } = useThemeMode();
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
                      {item.name === "index" && coachOnly ? t("nav.coachAd") : t(item.labelKey)}
                    </Text>
                  ) : null}
                </Pressable>
              </Link>
            );
          })}
          <Link href={"/assistant" as never} asChild>
            <Pressable accessibilityLabel="Abrir Match Buddy" style={{ marginLeft: spacing.sm }}>
              <MatchBuddyAvatar size={42} />
            </Pressable>
          </Link>
        </View>
      </View>
    </View>
  );
}
