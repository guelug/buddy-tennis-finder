# MatchPoint Tennis

Aplicación nativa para iOS y Android que permite encontrar rivales compatibles, organizar partidos y competir en ligas regionales. La web pública es una landing estática con información de producto y páginas legales; no contiene la aplicación ni el SDK de Firebase.

## Funciones activas

- Inicio de sesión nativo por correo, Google y Apple.
- Perfil deportivo persistente: club, nivel, formatos y disponibilidad.
- Búsqueda de rivales por nivel, edad, formato, clubes y horarios compartidos.
- Publicación de reservas individuales con fecha, horario y cancha reales.
- Aceptación, liberación y cancelación de plazas protegidas con transacciones Firestore.
- Resultados validados por el rival y ranking regional derivado de registros inmutables.
- Firebase App Check mediante App Attest en iOS y Play Integrity en Android.
- Tema oscuro y claro, diseño adaptable y controles nativos en Android.

Firebase nativo lee `GoogleService-Info.plist` y `google-services.json`. El paquete web de Firebase solo se conserva como dependencia de desarrollo para probar las reglas en el emulador.

## Comandos

```bash
npm install
npm run start
npm test
npm run typecheck
npm run build:android-bundle
```

La landing vive en `landing/` y se publica gratuitamente con:

```bash
firebase deploy --only hosting
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

Variables públicas de enlaces y acceso social (consulta `.env.example`):

```bash
EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID=...
EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID=... # opcional hasta configurar OAuth nativo
EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID=...     # opcional hasta configurar OAuth nativo
EXPO_PUBLIC_APP_URL=...
EXPO_PUBLIC_APP_STORE_URL=...
```

Despliega las reglas antes de publicar una compilación que dependa de cambios del modelo:

```bash
firebase deploy --only firestore:rules
```

## Estado de producto

Android se distribuye mediante prueba cerrada y iOS mediante TestFlight. Ambos usan los mismos UID, perfiles, partidos y resultados de Firebase. Equipos y torneos continúan marcados como funciones en desarrollo.

La actualización del SDK de Expo debe hacerse incrementalmente, un SDK por vez, con `npx expo install --fix` y `npx expo-doctor` en cada paso; no debe mezclarse con un hotfix de Play Store.
