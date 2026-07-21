# MatchPoint Tennis

Aplicación React Native para encontrar rivales compatibles y publicar o aceptar reservas de tenis. Android, iOS y web comparten Firebase Auth y Firestore, pero cada plataforma usa navegación y componentes nativos.

## Funciones activas

- Inicio de sesión por correo y contraseña. Google se muestra en web y solo se habilita en Android/iOS cuando existe el client ID nativo correspondiente; Apple se muestra en iOS.
- Perfil deportivo persistente: club, nivel, formatos y disponibilidad.
- Búsqueda de rivales por nivel, edad, formato, clubes y horarios compartidos.
- Publicación de reservas individuales con fecha, horario y cancha reales.
- Aceptación, liberación y cancelación de plazas protegidas con transacciones Firestore.
- Ranking provisional basado únicamente en señales reales del perfil. Resultados, equipos y torneos permanecen claramente marcados como beta o próximos.
- Tema oscuro y claro, diseño adaptable y controles nativos en Android.

Sin configuración Firebase se activa el modo demo local. Una compilación de producción siempre debe incluir las variables de `.env`.

## Comandos

```bash
npm install
npm run start
npm test
npm run typecheck
npm run build:web
npm run build:android-bundle
```

El paquete Android firmado y el APK de verificación se generan localmente con:

```bash
npm run build:android-aab
```

El script lee la contraseña de la clave de subida desde el Llavero de macOS y crea:

- `dist/android/matchpoint-clubs-release.aab`
- `dist/android/matchpoint-clubs-release.apk`

Para publicar en la prueba cerrada existente (`alpha`):

```bash
npm run publish:android:closed -- --confirm --track alpha
npm run check:android:closed
```

Cada envío debe aumentar `expo.android.versionCode` en `app.json`.

## Firebase

Variables públicas necesarias (consulta `.env.example`):

```bash
EXPO_PUBLIC_FIREBASE_API_KEY=...
EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN=...
EXPO_PUBLIC_FIREBASE_PROJECT_ID=...
EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET=...
EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
EXPO_PUBLIC_FIREBASE_APP_ID=...
EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID=...
EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID=... # opcional hasta configurar OAuth nativo
EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID=...     # opcional hasta configurar OAuth nativo
EXPO_PUBLIC_APP_URL=...
```

Despliega las reglas antes de publicar una compilación que dependa de cambios del modelo:

```bash
firebase deploy --only firestore:rules
```

## Estado de producto

La versión Android está en prueba cerrada. Las salas de resultados, reseñas, equipos y torneos todavía no escriben datos reales en producción; la interfaz no presenta datos semilla como si fueran actividad real. La futura app iOS utilizará los mismos UID, perfiles y reservas de Firebase.

La actualización del SDK de Expo debe hacerse incrementalmente, un SDK por vez, con `npx expo install --fix` y `npx expo-doctor` en cada paso; no debe mezclarse con un hotfix de Play Store.
