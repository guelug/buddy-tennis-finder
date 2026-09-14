# Validación local y checklist de release

## Alcance

MatchPoint Tennis es una aplicación nativa de Expo para iOS y Android. La carpeta
`landing/` contiene únicamente la landing pública y las páginas legales; no es una
versión web de la aplicación ni existe un backend local en `api/`.

## Comprobaciones automáticas

Desde la raíz del proyecto:

```bash
npm install
npm run typecheck
npm test
npm run i18n:validate
npm run build:android-bundle
npm --prefix workers/iap-verifier run types:check
npm --prefix workers/iap-verifier run typecheck
npm --prefix workers/iap-verifier test
```

`npm run verify` ejecuta typecheck, tests, exportación Android y `expo-doctor` en
una sola orden. `expo-doctor` necesita acceso a npm; si la máquina está sin red,
ejecútalo cuando vuelva a estar disponible.

### Reglas de Firestore

La prueba de integración necesita JDK 21 o posterior, Firebase CLI y el emulador local:

```bash
firebase emulators:start --only firestore --project tenisbuddy-app-rules-test
# En otra terminal:
npm run test:firestore:run
```

## Ejecutar la app nativa

```bash
npm run start
```

Con Expo abierto:

- Android: presiona `a` o usa un dispositivo físico.
- iOS: presiona `i` en macOS con Xcode y un runtime de simulador instalado.

También se pueden generar builds de prueba con `npx eas-cli build -p android
--profile preview`. No uses `w` ni `npm run web`: la aplicación funcional no se
distribuye como web.

## Validación manual mínima

- Completar login/onboarding y comprobar que el teclado no tapa los campos.
- Conceder ubicación y cambiar distancia, nivel, formato y disponibilidad.
- Abrir un candidato y enviar una propuesta; aceptarla o rechazarla desde
  `Partidos`.
- Abrir el asistente, escribir con el teclado abierto y comprobar que el texto
  permanece visible; enviar el mensaje y verificar que aparece en el chat.
- Abrir una conversación, enviar/recibir mensajes y comprobar estados de carga y
  error.
- Probar Google/Apple/email según las credenciales configuradas.
- Con una cuenta de prueba desechable y una sesión recién iniciada, eliminar la
  cuenta desde Ajustes y confirmar que se cierra la sesión, no permite volver a
  entrar y no deja el perfil visible en búsquedas ni rankings.
- Validar compra/restauración en los entornos sandbox de App Store y Play antes de
  publicar.

## Landing y páginas legales

Para revisar la landing estática localmente:

```bash
npm run landing:serve
```

Comprueba `/`, `/privacy/`, `/terms/`, `/support/` y `/delete-account/`. El
despliegue de esta carpeta se documenta en `DEPLOYMENT.md` y se realiza mediante
Firebase Hosting.
