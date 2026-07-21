# Despliegue (gratuito, solo Firebase)

El proyecto usa **Firebase** para todo: Auth, Firestore (datos) y Hosting (web). Con el plan **Spark (free)** es suficiente para arrancar con usuarios reales.

## Límites del plan free (Spark)

- **Hosting:** 10 GB transferidos/mes, 360 MB almacenamiento. Suficiente para un MVP.
- **Firestore:** 50.000 lecturas/día, 20.000 escrituras/día, 1 GB almacenamiento.
- **Authentication:** proveedores Google/Apple/Email sin costo.
- **Sin cold starts** (no hay Cloud Functions en este proyecto).

Si lo superas, escala a Blaze (pago por uso) solo cuando lo necesites.

## 1. Configurar variables

Crea `.env` (copia de `.env.example`) con los valores de Firebase Console → Project Settings → Your apps → Web app:

```bash
cp .env.example .env
# edita .env con tus claves EXPO_PUBLIC_FIREBASE_* y EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID
```

## 2. Build web

```bash
npm install
npm run build:web   # genera ./dist (estático)
```

## 3. Desplegar a Firebase Hosting + reglas Firestore

Requiere Firebase CLI (`npm i -g firebase-tools`) y login (`firebase login`).

```bash
npm run build:web
firebase deploy --only hosting,firestore:rules
```

- La web queda en `https://<tu-proyecto>.web.app` y `https://<tu-proyecto>.firebaseapp.com`.
- Las reglas de Firestore (`firestore.rules`) se actualizan en el mismo paso.

Para desplegar solo la web: `firebase deploy --only hosting`.
Para desplegar solo reglas: `firebase deploy --only firestore:rules`.

## 4. Android (pruebas / distribución interna)

- **Expo Go (gratis):** `npm run android` → escanea QR.
- **APK instalable:** `npx eas-cli build -p android --profile preview`.
- **Google Play:** requiere cuenta de desarrollador de Google (pago).

## Notas

- `.firebaserc` apunta al proyecto (`tennisbuddy-app`). Si usas otro proyecto, edita ese archivo o ejecuta `firebase use <projectId>`.
- La app funciona en **modo demo** con datos semilla si no hay `.env` configurado (útil para previews sin backend).
- El dominio autorizado para Google Sign In debe añadirse en Google Cloud Console → Credentials → OAuth client (origen JS autorizado).
