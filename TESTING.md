# Test ready

## Prueba local

```bash
npm install
npm --prefix api install
npm run verify
npm run start
```

Con Expo abierto:

- Android: escanea el QR con Expo Go o presiona `a` para emulador Android.
- iOS: escanea el QR con Expo Go o presiona `i` para simulador iOS en Mac.
- Web: presiona `w` o usa `npm run web`.

La app funciona sin backend porque usa datos mock. Para probar API real:

```bash
npm run api
EXPO_PUBLIC_API_URL=http://localhost:4000 npm run start
```

En Android físico, `localhost` no apunta a la computadora. Usa una URL pública o la IP local de la computadora.

## Vercel Free para web

Configura el proyecto en Vercel con:

- Framework preset: Other.
- Build command: `npm run build:web`.
- Output directory: `dist`.
- Environment variable: `EXPO_PUBLIC_APP_URL=https://tu-proyecto.vercel.app`.

Después de desplegar, actualiza `EXPO_PUBLIC_APP_URL` para que el enlace de prueba del home apunte a tu URL final.

## Android para testers

Opción gratis sin Play Store:

```bash
npx eas-cli build -p android --profile preview
```

Ese perfil genera APK para instalar directamente. También puedes usar Expo Go sin generar APK.

Google Play no es gratis: requiere cuenta de desarrollador con pago único. Para pruebas privadas por Play Store, crea una pista de Internal testing cuando ya tengas la cuenta.

## Checklist manual

- Abrir app en Android con Expo Go.
- Tocar `Ubicación` y aceptar permiso.
- Cambiar distancia, nivel, formato y disponibilidad.
- Abrir un candidato y enviar propuesta.
- Ir a `Partidos` y aceptar o declinar una solicitud.
- Abrir la web desplegada en móvil y usar `Agregar a pantalla de inicio`.
- Revisar que el enlace de prueba del home abre la URL final.
