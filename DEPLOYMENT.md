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
- La landing queda disponible en el dominio canónico `https://tennisleagueapp.win` una vez propagado el DNS. Las URLs técnicas de Firebase (`https://tenisbuddy-app.web.app` y `https://tenisbuddy-app.firebaseapp.com`) siguen funcionando como respaldo.
- Las reglas de Firestore (`firestore.rules`) se actualizan en el mismo paso.

Para desplegar solo la landing: `firebase deploy --only hosting`.
Para desplegar solo reglas: `firebase deploy --only firestore:rules`.

### Dominio personalizado en Cloudflare

El dominio `tennisleagueapp.win` ya está asociado al sitio `tenisbuddy-app` de Firebase Hosting y el certificado HTTPS está activo. Estos son los registros configurados en Cloudflare; el A permanece como **DNS only** para que Firebase gestione directamente el certificado:

| Tipo | Nombre | Valor | Proxy |
| --- | --- | --- | --- |
| A | `@` | `199.36.158.100` | DNS only |
| TXT | `@` | `hosting-site=tenisbuddy-app` | — |
| TXT | `_acme-challenge` | `LgCv1Bw4aFyFQmNNs2XzlNPEu0Gpv4yUDc74pI-Cbnw` | — |

El TXT de ACME es el desafío emitido por Firebase el 2 de agosto de 2026; si Firebase genera otro valor, hay que usar el que aparezca en la operación actual. No se deben borrar otros TXT de `_acme-challenge` sin revisar antes si pertenecen a otro certificado. Si se desea añadir una capa proxy de Cloudflare, primero hay que probarla en una ventana controlada y mantener el modo SSL en **Full (strict)**. Si también se quiere cubrir `www`, se debe registrar `www.tennisleagueapp.win` como dominio adicional en Firebase y redirigirlo al dominio canónico.

Cloudflare DNSSEC está activado y la cadena DS ya es visible públicamente. No se ha creado una política SPF/DMARC restrictiva porque el dominio podría enviar facturas o correos transaccionales en el futuro; esos registros deben configurarse cuando se elija el proveedor de correo, usando exactamente sus valores SPF y DKIM.

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


## 4. iOS TestFlight

**Estado real:** MatchPoint se ha subido con archive local + `xcrun altool` (builds 22 y 23). El Mac de desarrollo puede estar en macOS beta; por eso el camino preferido a medio plazo es **Xcode Cloud** (macOS estable de Apple).

### Subida local (respaldo probado)

```bash
# 1) Bump CURRENT_PROJECT_VERSION / app.json buildNumber
# 2) Archive + export + upload
./scripts/upload-testflight.sh --archive
```

Credenciales ASC: `~/.appstoreconnect/private_keys/AuthKey_Q2FTX4KKUY.p8`  
Export options de referencia: `ios/ExportOptions-TestFlight.plist` (upload) y el script genera un plist local `export` para altool.

### Xcode Cloud (preferido cuando esté activo)

- Script de clone ya existe: `ios/ci_scripts/ci_post_clone.sh` (`npm ci` + `pod install`).
- En App Store Connect (ago 2026) **aún no hay ciProduct** para MatchPoint Tennis (sí para LunaCycle / LoLEsports).
- Para activarlo: Xcode → MatchPointTennis workspace → Product → Xcode Cloud → Create Workflow → Archive → TestFlight internal.
- Cuando el workflow exista, un push a `main` (o el branch configurado) compila en infraestructura estable de Apple y publica el build sin depender del macOS beta local.
