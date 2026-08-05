/**
 * Feedback sensorial centralizado: vibración + sonido de pelota.
 *
 * Uso:
 *   import { tapBall, switchTab, notifySound } from "@/lib/feedback";
 *
 * El sonido respeta el ajuste "sound" de Notificaciones y nunca rompe la
 * acción que lo dispara (todo va en fire-and-forget con catch propio).
 */
import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from "expo-audio";
import * as Haptics from "expo-haptics";
import { Platform } from "react-native";
import { DEFAULT_NOTIFICATION_PREFS, loadNotificationPrefs } from "@/lib/notification-settings";

const ballSound = require("@/../assets/sounds/tennis-ball-hit.wav");

let soundLoaded: AudioPlayer | null = null;
let soundPrefs = DEFAULT_NOTIFICATION_PREFS;

// Preferencias en memoria: las leemos una vez al arrancar y se refrescan con
// cada guardado para no leer AsyncStorage en cada impacto.
void loadNotificationPrefs().then((prefs) => { soundPrefs = prefs; });

export function refreshFeedbackPrefs(prefs: typeof DEFAULT_NOTIFICATION_PREFS) {
  soundPrefs = prefs;
}

/** Vibración ligera para taps de la bola y elementos del tab bar. */
export function tapBall() {
  if (Platform.OS === "web") return;
  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
  void playBallSound();
}

/** Vibración de selección al cambiar entre pestañas. */
export function switchTab() {
  if (Platform.OS === "web") return;
  void Haptics.selectionAsync().catch(() => {});
}

/** Impacto medio para acciones con resultado (enviar, confirmar). */
export function actionImpact() {
  if (Platform.OS === "web") return;
  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
}

/** Notificación: vibración + sonido de pelota si el usuario no lo ha apagado. */
export function notifySound() {
  if (Platform.OS === "web") return;
  void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
  if (soundPrefs.sound) void playBallSound();
}

/** Celebración de victoria: impacto fuerte (el confeti corre aparte). */
export function winCelebration() {
  if (Platform.OS === "web") return;
  void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy).catch(() => {});
  void playBallSound();
}

async function playBallSound() {
  if (!soundPrefs.sound) return;
  try {
    if (!soundLoaded) {
      await setAudioModeAsync({ playsInSilentMode: true, shouldPlayInBackground: false });
      soundLoaded = createAudioPlayer(ballSound, { keepAudioSessionActive: false });
      soundLoaded.volume = 0.55;
    }
    soundLoaded.pause();
    await soundLoaded.seekTo(0);
    soundLoaded.play();
  } catch {
    // El sonido es decorativo: jamás debe tumbar la interacción.
  }
}
