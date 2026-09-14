# Revisión 1.2.6 — 2026-09-15

## Corrección de la línea de publicación

`main` (4046c01) no contenía la rama que produjo la versión pública 1.2.5 (f3b0d92).
Se integran ambas historias, conservando progreso, objetivos, ATT y las correcciones
publicadas; se mantienen los cupones recientes y la versión 1.2.6. Los archivos
sin seguimiento de `app-store-assets/iap-review/` no se incluyen ni modifican.

## Mejoras y pruebas

- IA: respeta nuevamente el nombre/idioma elegidos en iOS y Android.
- Las estadísticas incluyen todos los resultados validados del jugador, no solo cinco.
- Ranking del asistente: mismas fuentes, puntos y ámbito regional que la pantalla de clasificación.
- Las consultas simultáneas de disponibilidad se comparten, pero la siguiente se
  refresca (activar Apple Intelligence o completar una descarga no exige reiniciar).
- Un error al cargar resultados muestra el reintento existente, no estadísticas falsas a cero.
- El prompt limita los próximos partidos a cinco y conserva el total por separado.
- Cupones traducidos y cierre de hoja corregido, pero **no habilitados en esta
  publicación**: la hoja actual no vincula `appAccountToken`; el servidor rechaza
  correctamente compras sin vinculación. Mostrar el canje podría consumir un
  código sin entregar el producto. Se conserva la compra normal y la validación
  estricta; no se relaja la seguridad para hacer funcionar el cupón.
- StoreKit solo presenta sobre una escena activa. La verificación sigue en el backend.
- CI conserva los placeholders de versión del plist y valida dependencias con el mapa local del SDK.

Verificación local: TypeScript correcto, 107 pruebas correctas, 1012 claves de
traducción consistentes, exportación iOS correcta, auditoría de dependencias de
producción sin vulnerabilidades. Las seis advertencias moderadas de desarrollo
no se incluyen en el binario.

## iOS 27 y límites

Xcode Cloud está configurado con Xcode 26.6; el Mac tiene Xcode 27 beta.
Se conserva el SDK estable para distribución. No se afirma que se hayan incorporado
todas las APIs de iOS 27 ni validado la inferencia en un iPhone físico.
Apple actualiza el modelo local con el sistema: deben evaluarse sus respuestas
en hardware con Apple Intelligence, no solo comprobar que compila.

Referencias: [Foundation Models](https://developer.apple.com/documentation/updates/foundationmodels)
y [gestión del contexto](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window).

## Estado remoto antes del envío

- App Store: 1.2.5 disponible (`READY_FOR_DISTRIBUTION`, downloadable=true).
- Build 42 válida, pero sin versión 1.2.6 enviada a App Review.
- Tres compras consumibles `READY_TO_SUBMIT`; aún no aprobadas.
- Un grupo TestFlight interno; no hay grupo público externo.

Este registro no certifica pagos reales ni una publicación nueva hasta verificar
el resultado de Xcode Cloud y App Review.
