# Revisión de seguridad · MatchPoint Tennis

Fecha: 28 de julio de 2026

## Alcance

- Aplicación Expo/React Native para iOS y Android.
- Firebase Authentication, App Check y Firestore.
- Compras iOS con StoreKit y verificación en un Cloudflare Worker.
- Landing estática de Firebase Hosting.

## Controles verificados

- App Check usa App Attest en iOS y Play Integrity en Android; Firestore e
  Identity Toolkit están en modo obligatorio.
- Las compras nunca se conceden desde el cliente. El verificador exige a la
  vez un ID token de Firebase y un token de App Check válidos, consulta la
  transacción en App Store Server API y comprueba producto, bundle,
  `appAccountToken`, propietario, cantidad, revocación y fecha.
- Cada transacción se registra con identificador único antes de entregar el
  beneficio. Una transacción no puede utilizarse para otra cuenta o producto.
- Los clientes no pueden escribir `iapPurchases` ni concederse compras o altas
  en ligas privadas mediante las reglas de Firestore.
- Las claves privadas de Apple y Google se almacenan como secretos del Worker;
  no están en el repositorio ni en el bundle de la aplicación.
- El Worker acepta cuerpos JSON acotados, no habilita CORS, limita valores y
  rutas, y devuelve errores sin datos internos.
- La landing aplica CSP sin `unsafe-inline`, bloquea objetos y limita las
  capacidades del navegador.

## Pruebas realizadas

- TypeScript de app y Worker: correcto.
- Tests de aplicación: 26/26.
- Tests del Worker: 5/5.
- Tests de reglas con Firestore Emulator: 9/9.
- Dependencias de producción del Worker: 0 vulnerabilidades conocidas.
- Build nativa limpia de iOS: correcta; la aplicación se instaló y arrancó en
  el simulador sin excepción nativa ni cierre inesperado.

## Riesgos residuales

`npm audit --omit=dev` informa 23 avisos en el árbol principal (4 altos y 19
moderados, 0 críticos). Los altos llegan por `glob`/`minimatch` a través de
`babel-plugin-module-resolver`; los moderados proceden principalmente de
Expo CLI/configuración y `xcode`. Son herramientas de compilación, no código
del Worker de compras. La corrección automática propuesta por npm degrada
Expo a una versión incompatible, por lo que no debe aplicarse a ciegas.

No se debe afirmar que el proyecto tiene “cero vulnerabilidades”: el estado
correcto es cero críticas conocidas, cero en el runtime del verificador y
avisos residuales de tooling que requieren una actualización compatible de
Expo/dependencias.

## Pendiente antes de producción

- Completar una compra Sandbox real de cada producto en una build firmada.
- Contrato Paid Applications, fiscalidad y cuenta bancaria: activos en App
  Store Connect.
- Adjuntar la compra a la nueva versión y enviarla conjuntamente a App Review.
- Rotar inmediatamente cualquier clave si alguna vez aparece en logs, commits
  o capturas compartidas.
