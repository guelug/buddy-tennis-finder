# Despliegue (gratuito, solo Firebase)

MatchPoint Tennis es **solo app nativa (iOS + Android)**. La web (`landing/`) es una landing estática de promoción + páginas de políticas (privacidad, términos, soporte, borrado de cuenta) — no contiene la app funcional ni lógica de negocio. Firebase se usa para Auth, Firestore (datos) y Hosting (solo la landing).

## Límites del plan free (Spark)

- **Hosting:** 10 GB transferidos/mes, 360 MB almacenamiento. De sobra para una landing estática.
- **Firestore:** 50.000 lecturas/día, 20.000 escrituras/día, 1 GB almacenamiento.
- **Authentication:** proveedores Google/Apple/Email sin costo.
- **Cloud Functions:** el proyecto sí usa Functions (`functions/`) para verificar compras de Google Play; esto requiere plan **Blaze** (pago por uso), aunque el uso esperado es mínimo.

## 1. Configurar variables

Crea `.env` (copia de `.env.example`) con las claves de Google OAuth y URLs de la app:

```bash
cp .env.example .env
```

## 2. Desplegar la landing + reglas de Firestore

Requiere Firebase CLI (`npm i -g firebase-tools`) y login (`firebase login`).

```bash
firebase deploy --only hosting,firestore:rules
```

- `firebase.json` sirve el contenido estático de `landing/` tal cual (sin build), con cabeceras de seguridad (CSP, `X-Content-Type-Options`, etc.).
- La landing queda en `https://<tu-proyecto>.web.app` y `https://<tu-proyecto>.firebaseapp.com`.
- Las reglas de Firestore (`firestore.rules`) se actualizan en el mismo paso.

Para desplegar solo la landing: `firebase deploy --only hosting`.
Para desplegar solo reglas: `firebase deploy --only firestore:rules`.
Para desplegar las Cloud Functions: `firebase deploy --only functions`.

## 3. Apps móviles

- **Android (pruebas):** `npm run android` (Expo run) o `npx eas-cli build -p android --profile preview` para un APK instalable.
- **Android (producción):** `npm run build:android-aab` + `npm run publish:android:closed`.
- **iOS:** build gestionado vía Expo/EAS; ver [ios-native/README.md](ios-native/README.md) para el proyecto SwiftUI experimental (no es el pipeline principal).
- **Google Play / App Store:** requieren cuentas de desarrollador de pago.

## Notas

- `.firebaserc` apunta al proyecto (`tennisbuddy-app`). Si usas otro proyecto, edita ese archivo o ejecuta `firebase use <projectId>`.
- El dominio autorizado para Google Sign In debe añadirse en Google Cloud Console → Credentials → OAuth client (origen JS autorizado).
