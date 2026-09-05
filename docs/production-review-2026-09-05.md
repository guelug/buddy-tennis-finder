# Revisión de preparación para producción — 2026-09-05

## Correcciones y evidencia

- Objetivos semanales: una lectura tardía ya no sustituye la elección reciente. Una sola restauración, escrituras serializadas y snapshots compartidos; los errores de almacenamiento no bloquean cambios posteriores. Archivos: `src/lib/weekly-goals.ts`, `src/lib/weekly-goals-store.ts`; cinco pruebas en `tests/weekly-goals-store.test.ts`.
- Metadatos iOS: `Info.plist` todavía fijaba 1.2.4 mientras Expo y Xcode indicaban 1.2.5. Ahora usa `$(MARKETING_VERSION)`. `tests/release-metadata.test.ts` comprueba ambas configuraciones y el número de build. `plutil -lint` correcto.
- XML de herramientas: actualizados únicamente los parches compatibles de xmldom a 0.8.15 y 0.9.12. Roundtrip de valores plist correcto en ambos consumidores. No se identificó la operación vulnerable de EntityReference en el flujo actual.

## Remediación del parser (procedimiento fix-finding)

Hallazgo: [GHSA-vcc3-ghjq-m6fr](https://github.com/advisories/GHSA-vcc3-ghjq-m6fr). Cadena instalada: Expo Router 57 → query-string 7 → decode-uri-component 0.2.2. La invariante es procesar parámetros de URL no confiables sin un bloqueo desproporcionado, conservando Unicode, espacios, parámetros vacíos, repetidos y codificados.

Alcance: la ruta normal del fork de Expo Router usa URLSearchParams; no se demostró explotación por el flujo habitual de esta app. El core de compatibilidad React Navigation sí llama query-string.parse. El arreglo protege esa dependencia y futuros consumidores, sin atribuirle falsamente un fallo general de deep links.

Estrategia: fork temporal MIT del scanner oficial 0.5.0, con export CommonJS y normalización `+` heredada. Un override directo a 0.5.0 ESM rompe la función que query-string espera. La revisión independiente encontró además coste cuadrático en el mapa de sustituciones del upstream: eliminado con escaneo directo y tratamiento de BOM/%C2 sobre bytes originales, sin doble interpretación de `%25`. `vendor/decode-uri-component/README.md` documenta fuente, cambios y criterio de retirada. `package.json` y lockfile resuelven la copia local también en una instalación limpia.

Verificación ordenada:

1. `npm ci --ignore-scripts`, `npm run typecheck` y `git diff --check`: correctos.
2. Reproducción original: queries `%FF` × 1500 y `%41%FF` × 1000 agotaron 2000 ms en procesos aislados. Con el parche final, ambas, la variante `%E0%A4` × 1000 y 30.000 fragmentos codificados distintos completan el test conjunto en aproximadamente 149 ms. Prueba con timeout aislado para no colgar CI. La revisión independiente motivó esta última prueba y el endurecimiento adicional.
3. Controles legítimos: función CJS, Unicode, signos `+`, `%25`, BOM, parámetros repetidos y roundtrip de invitaciones a través del core de navegación, correctos en `tests/query-parser.test.ts`.
4. Suite completa: 100/100 pruebas, TypeScript limpio, traducciones 1011 claves por catálogo, `EXPO_OFFLINE=1 npx expo install --check` correcto. Exportaciones Hermes iOS/Android tras el último endurecimiento finalizadas correctamente en `/tmp/tennis-verification.b3tN4L/final-bundles`.
5. `npm audit --omit=dev`: cero avisos. La auditoría completa conserva seis avisos moderados en herramientas de desarrollo; no equivale a una garantía de ausencia de vulnerabilidades.

## Distribución y pruebas que siguen pendientes

- Android 1.2.5 (31) compiló y produjo AAB/APK firmados; firma APK y manifiesto comprobados. Ese paquete precede a las últimas correcciones de esta revisión: hay que regenerarlo antes de distribuirlo.
- Xcode Cloud 32 compiló/archivó, pero terminó FAILED al preparar App Store Connect. El log señala error de autenticación de la sesión de Cloud; los exports también identificaban la versión antigua 1.2.4. No se afirma que la corrección de versión por sí sola resuelva la autenticación.
- No se han certificado compras reales ni todos los flujos autenticados en dispositivo. El emulador Android disponible no tiene Play Store y no puede validar facturación real. No se realizaron cobros ni escrituras de datos de producción.
- Smoke Android del APK previo: instalación correcta, arranque en frío `Status: ok` (1342 ms), pantalla Rivales renderizada; captura `/tmp/tennis-android-review.png`. Hubo ANR de System UI del emulador, no crash de la app en los logs consultados. Esto no certifica todos los flujos ni el paquete final pendiente.
- La última comprobación de Google Play mostraba alpha en build 30 y production sin releases. No confundir una build local o prueba cerrada con disponibilidad pública.
