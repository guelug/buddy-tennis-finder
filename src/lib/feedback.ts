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

/**
 * Piscina de reproductores. Con uno solo, dos golpes seguidos se cortaban
 * entre ellos (había que parar, rebobinar y volver a lanzar el mismo). Con
 * tres alternándose, los toques rápidos suenan superpuestos como en la vida
 * real y ninguno se trunca.
 */
const POOL_SIZE = 3;
const pool: AudioPlayer[] = [];
let poolIndex = 0;
let priming: Promise<void> | null = null;
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
  playBallSound();
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
  playBallSound();
}

/** Celebración de victoria: impacto fuerte (el confeti corre aparte). */
export function winCelebration() {
  if (Platform.OS === "web") return;
  void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
  void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy).catch(() => {});
  playBallSound();
}

/**
 * Prepara el audio por adelantado. Antes el primer golpe cargaba el sonido y
 * configuraba la sesión de audio en ese momento, así que llegaba tarde o
 * directamente no se oía. Llamar a esto al arrancar deja el primer toque tan
 * inmediato como el resto. Es idempotente y nunca lanza.
 */
export function primeFeedback(): Promise<void> {
  if (Platform.OS === "web") return Promise.resolve();
  if (priming) return priming;
  priming = (async () => {
    try {
      await setAudioModeAsync({ playsInSilentMode: true, shouldPlayInBackground: false });
      for (let i = 0; i < POOL_SIZE; i += 1) {
        const player = createAudioPlayer(ballSound, { keepAudioSessionActive: false });
        // El archivo ya está grabado bajo (-20,8 dBFS RMS); a 0.55 apenas se
        // oía sobre el ruido ambiente de una pista.
        player.volume = 1;
        pool.push(player);
      }
    } catch {
      // Sin audio la app sigue igual de usable.
    }
  })();
  return priming;
}

function playBallSound() {
  if (!soundPrefs.sound || Platform.OS === "web") return;
  if (pool.length === 0) {
    // Aún no se ha precargado: lo preparamos y dejamos pasar este toque.
    void primeFeedback();
    return;
  }
  try {
    const player = pool[poolIndex];
    poolIndex = (poolIndex + 1) % pool.length;
    // `seekTo` es asíncrono: esperarlo metía un salto perceptible entre el
    // toque y el sonido. Lo lanzamos y reproducimos sin bloquear.
    void player.seekTo(0).catch(() => {});
    player.play();
  } catch {
    // El sonido es decorativo: jamás debe tumbar la interacción.
  }
}
