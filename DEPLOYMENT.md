# Despliegue (servicios con nivel gratuito)

MatchPoint Tennis es **solo app nativa (iOS + Android)**. La web (`landing/`) es una landing estática de promoción + páginas de políticas (privacidad, términos, soporte, borrado de cuenta) — no contiene la app funcional ni lógica de negocio. Firebase se usa para Auth, Firestore (datos) y Hosting (solo la landing).

## Límites del plan free (Spark)

- **Hosting:** 10 GB transferidos/mes, 360 MB almacenamiento. De sobra para una landing estática.
- **Firestore:** 50.000 lecturas/día, 20.000 escrituras/día, 1 GB almacenamiento.
- **Authentication:** proveedores Google/Apple/Email sin costo.
- **Backend seguro:** Cloudflare Worker para compras iOS e invitaciones privadas, dentro del nivel gratuito. No se usan Cloud Functions ni el plan Blaze.

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

El backend seguro vive en `workers/iap-verifier/` y se despliega con:

```bash
cd workers/iap-verifier
npm run typecheck && npm test && npm run deploy
```

Sus credenciales se guardan únicamente como secretos de Cloudflare; nunca en Git ni en el bundle móvil.

## 3. Apps móviles

- **Android (pruebas):** `npm run android` (Expo run) o `npx eas-cli build -p android --profile preview` para un APK instalable.
- **Android (producción):** `npm run build:android-aab` + `npm run publish:android:closed`.
- **iOS:** el único proyecto vigente es `ios/MatchPointTennis.xcworkspace`; se compila y distribuye con Xcode/Xcode Cloud.
- **Google Play / App Store:** requieren cuentas de desarrollador de pago.

## Notas

- `.firebaserc` apunta al proyecto (`tennisbuddy-app`). Si usas otro proyecto, edita ese archivo o ejecuta `firebase use <projectId>`.
- El dominio autorizado para Google Sign In debe añadirse en Google Cloud Console → Credentials → OAuth client (origen JS autorizado).
