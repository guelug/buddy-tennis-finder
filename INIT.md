# MatchPoint Tennis — relevo operativo

Actualizado: 17 de julio de 2026 (Europe/Madrid).

Este es el documento principal de relevo del proyecto. El siguiente agente debe leerlo antes de actuar. Distingue entre código implementado, comprobaciones realizadas y cambios todavía no desplegados. No asumir que un cambio local ya está en Firebase o Google Play.

## Resumen ejecutivo

La versión local y publicada actual es **MatchPoint Tennis 1.2.2 (`versionCode 9`)**. Mantiene las correcciones de arranque de v8 y añade una revisión completa de rivales, formulario de partidos informales, márgenes inferiores y onboarding Android.

El AAB y el APK v9 están firmados, construidos y comprobados. La versión 9 está **activa con estado `completed` en el test cerrado `alpha` de Google Play**. Las reglas reforzadas de Firestore y la web 1.2.2 también están desplegadas. La v9 se instaló y recorrió en un emulador Android API 35 autenticado: búsqueda real, filtros, formulario de partido, niveles aceptados, cierre del panel y los tres pasos del onboarding. No hubo ANR, excepción fatal Android ni error fatal React Native. La comprobación pendiente más importante sigue siendo instalar la actualización distribuida por Play en el Samsung físico del usuario.

## Objetivo activo

Completar la validación física de la v1.2.2 en el test cerrado de Google Play:

- comprobar el flujo autenticado completo en un dispositivo real, idealmente Samsung;
- validar onboarding, búsqueda por nombre y solicitudes a partidos informales;
- confirmar en el Samsung que Google Play ofrece/instala la v9 y que muestra el splash con la pelota en vez de una ventana negra;
- completar una prueba real de solicitudes a partidos usando dos cuentas;
- no perder de vista el trabajo de Google Play Billing/Functions que sigue pendiente.

La aplicación Android es una app React Native/Expo nativa, no una web dentro de un WebView. Web y Android comparten Firebase Auth y Firestore, por lo que usuarios y datos se sincronizan. La versión iOS se optimizará más adelante sobre la misma base.

## Identificadores y servicios

- Nombre: **MatchPoint Tennis**.
- Android package / iOS bundle ID: `com.matchpoint.clubs`.
- Expo slug: `matchpoint-clubs`.
- Firebase project: `tenisbuddy-app`.
- Web de producción actual: <https://tenisbuddy-app.web.app>.
- Google Play developer account ID: `6837138431813346298`.
- Google Play app numeric ID: `4972257620336445237`.
- Track de test cerrado usado por los scripts: `alpha`.
- Cuenta de servicio de publicación: `matchpoint-google-play-publish@tenisbuddy-app.iam.gserviceaccount.com`.
- La clave local está en `credentials/google-play-service-account.json`. Es secreta: no mostrarla, copiarla, registrarla ni subirla.
- Existe una cuenta de revisión de Play ya creada. No guardar su contraseña en este documento; obtenerla del canal seguro o de la ficha de Play Console.

## Estado de la versión 1.2.2 / v9

Configuración confirmada en `app.json`:

- versión visible: `1.2.2`;
- Android `versionCode`: `9`;
- `compileSdkVersion` y `targetSdkVersion`: 35;
- `minSdkVersion` del artefacto: 24;
- arquitectura nueva de React Native activada;
- Google Sign-In nativo configurado;
- Google Play Billing incluido mediante `expo-iap`.

Artefactos firmados presentes actualmente:

- AAB publicado: `dist/android/matchpoint-clubs-release.aab`.
- APK validado: `dist/android/matchpoint-clubs-release.apk`.
- Gradle conserva además sus salidas en `android/app/build/outputs/`.

Los hashes siguientes corresponden exactamente a los artefactos finales de `dist/android/`; el hash del AAB coincide con el que devuelve Google Play para el bundle v9.

Hashes SHA-256:

```text
AAB dbe1403e5f800702ca7948c9b3cd18550864d77ceccc282d56bd2c341e204ec0
APK bb24158f0516a0cead2f0281aaf97c76aa7aadb4e28e2df46563b2312a962b26
```

La inspección del APK confirmó package `com.matchpoint.clubs`, v9, nombre 1.2.2, SDK objetivo 35 y permiso `com.android.vending.BILLING`.

## Cambios implementados en v7, v8 y v9

### Estabilidad y experiencia Android

- v9 elimina el `Modal` nativo problemático de los paneles de publicación/sala y usa una capa integrada en la pantalla. En la combinación actual de React Native/Android, la segunda ventana podía quedar transparente capturando todos los toques. El formulario final se abre, desplaza y cierra correctamente.
- El panel de publicación usa selector horizontal compacto de clubes y reserva el doble del espacio de la barra flotante: **Publicar partido** y **Cancelar** quedan completamente por encima de la pelota central incluso al final del scroll.
- La barra inferior deja 96 dp de despeje para que las últimas tarjetas y acciones no queden cortadas.
- El script de build recrea `dist/android` después de Gradle, porque Metro/Expo puede limpiar `dist` durante la compilación. `firebase.json` excluye `dist/android` de Hosting para no intentar desplegar APK/AAB.
- v8 integra `expo-splash-screen` y registra `SplashScreenManager` antes de `super.onCreate`: el splash nativo permanece visible hasta que React Native y las fuentes están preparados.
- La prueba sin red de v7 capturó una pantalla totalmente negra en el primer instante; la misma prueba con v8 captura inmediatamente la pelota de tenis y después el login completo.
- La configuración futura de Expo conserva este comportamiento mediante el plugin de splash de `app.json`.
- Se añadió un límite de 12 segundos a la carga inicial de datos para evitar esperas indefinidas en redes móviles problemáticas.
- La pantalla inicial ofrece error y reintento en vez de quedar aparentemente bloqueada.
- El onboarding ofrece error recuperable y botón de reintento si no carga el catálogo de clubes.
- El onboarding v9 está organizado como tres preguntas claras: **¿Quién eres?**, **¿Cómo juegas?** y **¿Cuándo juegas?**. Incluye progreso 1/3–3/3, campos formulados como preguntas, transiciones de paso con resorte y aparición suave de horarios. Los tres pasos se validaron en la APK final.
- `AuthGate` espera a que el perfil corresponda explícitamente al UID restaurado antes de decidir si envía al onboarding; evita una carrera intermitente de sesión/perfil en recargas y arranques móviles.
- Se eliminaron estilos exclusivos de navegador (`touchAction`, `overscrollBehaviorY`) de la ruta nativa Android.
- Se eliminó una espera artificial de 600 ms en la búsqueda de rivales.
- Login con Google continúa destacado como acceso principal; correo es alternativa secundaria.
- Se conservan safe areas, navegación y componentes React Native, sin contenedor WebView.

Archivos principales: `src/lib/app-api.ts`, `app/onboarding.tsx`, `src/components/screen-shell.tsx`, `app/(tabs)/index.tsx`.

### Búsqueda de rivales

- En v9 `rankCandidates` excluye siempre `isDemo`; las muestras ya no aparecen en resultados por defecto ni por nombre, y tampoco pueden figurar como participantes. Una prueba unitaria protege esta regla.
- Se añadió búsqueda por nombre en móvil y escritorio.
- La búsqueda ignora mayúsculas, minúsculas y acentos.
- Cuando hay texto, busca entre todos los jugadores cargados aunque no compartan disponibilidad, para que una persona concreta siempre pueda encontrarse.
- Los filtros normales de compatibilidad siguen aplicándose cuando no se busca por nombre.
- La vista incorpora estados de carga, error y reintento.

Archivos principales: `app/(tabs)/index.tsx`, `src/lib/firestore.ts`.

### Perfiles de muestra pasivos

- Los perfiles semilla ya no se guardan en Firestore ni se presentan como personas interactivas.
- El modo local/sin Firebase aplica la misma regla: todos los ejemplos salvo el jugador local son `MUESTRA`, sin perfil, Waze ni acciones.
- Se eliminaron también las propuestas semilla; el modo local empieza sin partidos ficticios abiertos.
- Solo rellenan localmente la app cuando hay menos de ocho perfiles reales.
- Se identifican internamente con `isDemo` y visualmente con la etiqueta **MUESTRA**.
- No se puede abrir su perfil, invitarles ni usar acciones de Waze/contacto sobre ellos.
- Solo pueden aparecer como relleno editorial pasivo en rankings y vistas sin interacción; nunca en rivales encontrados, búsqueda ni participantes.
- Se añadieron ejemplos pasivos en niveles D y A para completar la representación de niveles.

Archivos principales: `src/lib/firestore.ts`, `src/data/seed.ts`, `src/data/rankings.ts`, `src/components/player-card.tsx`, `src/types.ts`.

### Partidos informales y solicitudes

- El organizador publica club, fecha, hora, pista, mensaje y uno o varios niveles aceptados.
- Un jugador compatible pulsa **Solicitar plaza**; ya no entra directamente al partido.
- El organizador ve solicitudes pendientes y puede aceptar o rechazar.
- Al aceptar, el partido queda asignado al solicitante mediante transacción.
- Las propuestas antiguas sin `acceptedLevels` siguen funcionando usando su división original.
- Las solicitudes usan ID determinista `{matchId}_{uid}` para impedir duplicados.
- La lectura inicial tolera temporalmente que la colección nueva aún no exista o no tenga reglas desplegadas, evitando romper clientes durante el rollout.

Archivos principales: `app/(tabs)/index.tsx`, `app/(tabs)/matches.tsx`, `src/lib/app-api.ts`, `src/lib/matching.ts`, `src/types.ts`, `firestore.rules`.

Una solicitud rechazada puede volver a enviarse mientras el partido siga abierto y el nivel continúe aceptado. La transición permitida es únicamente `declined` → `pending`; el solicitante no puede aceptar su propia solicitud ni modificar sus campos de identidad.

### Reglas Firestore nuevas

- Los partidos nuevos validan una lista `acceptedLevels` de 1 a 5 niveles.
- Nueva colección `matchJoinRequests` con validación de propietario, solicitante, estado del partido y nivel aceptado.
- Solo organizador y solicitante pueden leer la solicitud.
- Solo el organizador puede aceptarla o rechazarla.
- El organizador solo puede asignar un partido a una solicitud pendiente válida.
- Se conserva compatibilidad con partidos antiguos sin `acceptedLevels`.

Estas reglas pasaron la compilación del emulador oficial de Firestore y están desplegadas en producción.

En v8 se cerraron además dos huecos de servidor: ya no se puede aceptar directamente una plaza sin solicitud pendiente y el nombre/nivel declarado debe coincidir con el perfil real. Los perfiles `isDemo` no pueden solicitar plaza. Una prueba oficial con contextos de propietario, solicitante, tercero y muestra valida publicación, solicitud, rechazo, reenvío y aceptación, además de todos esos rechazos de seguridad. Archivo: `tests/firestore-rules.integration.ts`.

### Waze

- Se auditaron los botones **Cómo llegar**.
- Todos usan el componente `WazeLogo` con la variante oficial de marca.
- Los enlaces usan la URL universal oficial `https://waze.com/ul?...&navigate=yes`, evitando depender de `canOpenURL` en Android 11+.
- Los perfiles de muestra no ofrecen navegación.

Archivos principales: `src/components/waze-logo.tsx`, `src/lib/waze.ts` y pantallas que invocan `openInWaze`.

### Escritorio y ranking

- Las filas horizontales gigantes del ranking se sustituyeron por tarjetas compactas y responsivas.
- Cada tarjeta muestra posición, nombre, club, puntos, partidos, racha y etiqueta MUESTRA cuando corresponde.
- El contenedor usa ajuste automático con ancho mínimo/máximo para evitar rectángulos de lado a lado.
- El ranking se validó visualmente a 1440 × 900: no hay desbordamiento horizontal y las tarjetas mantienen una composición compacta.

Archivo principal: `app/(tabs)/liga.tsx`.

## Verificaciones realizadas

Resultados positivos:

- TypeScript: correcto.
- Tests: **7/7 correctos**, incluidos el control de visibilidad por niveles aceptados y la ausencia de perfiles/propuestas ficticias interactivas en modo local.
- Export web: correcto.
- Export Android/Metro: correcto.
- Compilación firmada AAB/APK: `BUILD SUCCESSFUL`.
- Sintaxis de reglas: validada con el emulador oficial de Firestore.
- APK v9 final instalada sobre v8 en emulador Android API 35 conservando la sesión.
- Primer arranque en frío: correcto, pantalla de login renderizada, sin pantalla negra.
- Veinte arranques en frío consecutivos de v7 y diez de v8 terminaron correctamente; v8 quedó entre 919 y 1672 ms en la última serie.
- Diez ciclos de fondo/primer plano con cambios de orientación terminaron correctamente.
- Arranque inmediato sin red: v7 mostró fondo negro; v8 mostró el splash oficial con la pelota y llegó al login completo.
- Proceso estable y actividad reanudada.
- Logcat sin `FATAL EXCEPTION`, ANR ni error fatal de React Native.
- Búsqueda `Cristian` validada en la APK autenticada: devuelve únicamente el perfil real; ninguna muestra aparece como rival o participante.
- Formulario informal v9 validado visual y funcionalmente: abre sin ventana invisible, permite añadir el nivel B junto a C, desplaza hasta el final, deja **Publicar partido** y **Cancelar** libres sobre la navegación y vuelve a la pantalla al cancelar.
- Onboarding v9 validado directamente mediante `matchpoint://onboarding`: los pasos 1/3, 2/3 y 3/3 renderizan preguntas, selecciones, horarios y CTA fijos sin cortes. No se guardaron cambios durante esta inspección.
- Evidencias v9 principales: `output/playwright/android-v9-final-compact-modal.png`, `android-v9-final-clear-cta2.png`, `android-v9-final-level-toggle.png`, `android-v9-final-cancelled.png` y `android-v9-final-onboarding-step{1,2,3}.png`.
- Evidencias finales: `output/playwright/android-v8-offline-immediate.png` (primer instante) y `output/playwright/android-v8-offline-ready.png` (interfaz lista).
- La aparente aparición de rectángulos negros sobre los textos en dos capturas offline quedó descartada como fallo de la app: ImageMagick confirma que los PNG originales no contienen píxeles negros en esa interfaz (luminancia mínima aproximada de 10,8 %, igual que la captura con red) y que la comparación offline/online solo cambia alrededor del 0,64 % de los píxeles. Era una superposición del visor visual.
- Se repitió después un arranque completamente offline de v8: `MainActivity` quedó reanudada, el proceso siguió activo, el login se renderizó correctamente y logcat no mostró excepción fatal ni ANR. Evidencia: `output/playwright/android-v8-offline-recheck-ready.png`. La captura `android-v8-offline-recheck-immediate.png` se tomó antes de que la ventana de la app sustituyera al launcher y no debe usarse como evidencia del splash.
- Onboarding completo validado tanto en navegador local como en la APK final, incluidos sus tres pasos y bloqueos de campos obligatorios.
- Búsqueda por nombre validada localmente con un perfil fuera de los filtros habituales y en producción con un usuario real.
- Acceso directo autenticado a `/liga` validado en producción después de corregir la carrera sesión/perfil de `AuthGate`.
- Web de escritorio validada y desplegada; reglas de Firestore compiladas y desplegadas.
- Prueba multiusuario de reglas: **1/1 correcta** con solicitud, rechazo, reenvío y aceptación, más controles negativos de identidad, nivel, muestra y privacidad.

El comando agregado `npm run verify` completó typecheck, tests y ambos exports. Solo falló el último `expo-doctor` porque `npx` intentó acceder a `registry.npmjs.org` y el entorno no tenía red; no fue un fallo del proyecto. Se puede repetir con red:

```bash
npm run doctor
```

Pruebas todavía necesarias:

- Samsung físico y, si es posible, un segundo Android real.
- Login Google real en Samsung; el login de revisión por correo sí se validó en producción web.
- Onboarding desde una cuenta nueva.
- Búsqueda de un usuario real por nombre.
- Publicación, solicitud, rechazo y aceptación desde dos móviles/cuentas reales; el mismo flujo ya está probado con dos contextos autenticados en el emulador oficial.
- Recepción e instalación de v9 desde Google Play en la cuenta tester.

## Estado de despliegues

### Google Play

- La versión activa del test cerrado es **v9 / 1.2.2**.
- La v6 se subió previamente como **upload-only** a App Bundle Explorer, pero no se activó.
- La release se llama `MatchPoint Tennis (9)`, está en `alpha` con estado `completed` y sustituye a v8 en ese track.
- Google Play confirmó el bundle v9 con SHA-256 `dbe1403e5f800702ca7948c9b3cd18550864d77ceccc282d56bd2c341e204ec0`.
- La publicación se confirmó el 17 de julio de 2026 a las 01:58 (Europe/Madrid). La propagación a cada tester puede tardar.
- El próximo bundle deberá usar `versionCode` 10 o superior; no volver a subir v9.

### Firebase / web

- La web 1.2.2 se desplegó el 17 de julio de 2026.
- Hosting sirve el bundle final `entry-8424ad79251d4a9b3d8e23e94f612ef0.js`.
- Las reglas nuevas de `matchJoinRequests` están desplegadas y Firestore confirmó su compilación.
- Se añadió `cleanUrls` a Hosting para que los accesos directos a `/liga`, `/matches` y las demás rutas estáticas no caigan en la página raíz.
- Hosting ignora `dist/android/**`; el primer intento v9 se rechazó de forma segura por la restricción de ejecutables del plan Spark y el segundo despliegue, ya con 71 archivos web únicamente, terminó correctamente.
- `AuthGate` recupera además la ruta real del navegador después de resolver la sesión si el shell estático se hidrata momentáneamente como `/`.

## Compras y monetización pendientes

Productos previstos:

| Product ID | Uso | Precio EUR |
|---|---|---:|
| `coach_ad_7_days` | Promoción de entrenador durante 7 días | 4,99 € |
| `coach_ad_30_days` | Promoción de entrenador durante 30 días | 12,99 € |
| `private_league_create` | Creación de liga privada | 6,99 € |

El script `scripts/setup-google-play-products.mjs` usa la API moderna de monetización, pero el último intento devolvió que Play no reconocía el permiso de facturación. La causa probable era que el bundle con Billing solo estaba subido, no asociado a una release.

Firebase seguía en plan Spark en la última comprobación. El alta de Blaze llegó hasta el botón final **Confirm purchase**, que no se pulsó. Aunque el usuario autorizó avanzar con lógica, comprobar el estado real antes de actuar y no exponer información de pago.

`functions/index.js` contiene:

- `verifyCoachPurchase`;
- `verifyLeaguePurchase`;
- `acceptLeagueInvite`.

Las Functions no estaban desplegadas en la última comprobación. Antes de desplegarlas hay que resolver qué cuenta de servicio las ejecuta y asegurar que esa identidad tiene permisos de consulta/consumo de compras en Google Play. No incrustar claves JSON en código o variables públicas.

El 16 de julio de 2026 `firebase functions:list` confirmó que el proyecto sigue sin Functions. Por seguridad, los accesos a anuncios y ligas de pago están ocultos detrás de `EXPO_PUBLIC_PURCHASES_ENABLED=true`; sin esa variable, la v9 no ofrece checkouts que no puedan validarse. Activarlos solo después de productos + Functions + prueba con license tester.

## Scripts útiles

- `npm run typecheck`: comprobación TypeScript.
- `npm test`: tests del dominio.
- `npm run test:firestore:run`: ejecuta la integración de reglas cuando el emulador ya está levantado; en este Mac se lanzó con `JAVA_HOME=/opt/homebrew/opt/openjdk firebase emulators:exec --only firestore --project tenisbuddy-app-rules-test 'npm run test:firestore:run'`.
- `npm run build:web`: export web.
- `npm run build:android-bundle`: export Android de Metro.
- `npm run build:android-aab`: AAB/APK firmado.
- `npm run verify`: typecheck, tests, exports y doctor.
- `npm run check:android:closed -- --track alpha`: consulta del track cerrado.
- `npm run publish:android:closed -- ...`: subida/asignación en Play.
- `npm run setup:android:products -- --confirm`: creación de productos.
- `scripts/publish-google-play.mjs`: admite `--upload-only`, `--version-code` y `--preserve-existing`.
- `firebase deploy --only firestore:rules`: despliegue de reglas.
- `firebase deploy --only hosting`: despliegue web.
- `firebase deploy --only functions`: despliegue Functions.

Atención al orden de builds: `npm run build:web` recrea `dist/` y elimina temporalmente `dist/android/`. Si se compila web después del AAB, volver a copiar las salidas de Gradle desde `android/app/build/outputs/{bundle,apk}/release/` antes de publicar. No recompilar es necesario si esas salidas siguen intactas; comprobar siempre el hash y `versionCode` del archivo final.

Este directorio **no es actualmente un repositorio Git** (`git status` devuelve “not a git repository”). No prometer commit o push hasta confirmar dónde está el repositorio correcto o inicializar uno con autorización expresa.

## Orden recomendado para continuar

1. Abrir el enlace de participación del test cerrado con la misma cuenta invitada y comprobar en Play Store que se ofrece MatchPoint Tennis v1.2.2.
2. Instalar/actualizar en el Samsung, forzar un arranque limpio y confirmar que aparece el login con Google destacado, sin pantalla negra.
3. Probar onboarding y búsqueda por nombre en Android autenticado.
4. Verificar `matchJoinRequests` de extremo a extremo con dos cuentas: solicitar, rechazar, reenviar y aceptar.
5. Si se cambia código, incrementar `versionCode` a 10, repetir typecheck/tests/build/instalación y publicar un nuevo bundle; v9 ya no puede reutilizarse.
6. Mantener `EXPO_PUBLIC_PURCHASES_ENABLED` desactivado hasta desplegar productos, Functions y completar una compra con license tester.
7. Ejecutar `npm run doctor` con red cuando convenga cerrar la advertencia de herramientas.

## Criterio para dar la tarea por terminada

No marcarla como completada únicamente porque el AAB exista. Deben estar comprobados:

- reglas y web desplegadas;
- v9 disponible en el test cerrado;
- actualización recibida por una cuenta tester;
- arranque estable en Samsung real;
- onboarding funcional;
- búsqueda por nombre funcional con usuarios reales;
- solicitud y aceptación de partido entre dos cuentas;
- ejemplos completamente pasivos;
- ranking de escritorio revisado visualmente;
- botones de Waze correctos;
- cualquier función de pago visible respaldada por productos y Functions operativos, o claramente deshabilitada hasta entonces.
