# MatchPoint Tennis para iOS

Aplicación nativa SwiftUI conectada al proyecto Firebase `tenisbuddy-app`.

## Generar y abrir

```sh
cd ios-native
xcodegen generate
open MatchPointTennis.xcodeproj
```

El target usa `com.matchpoint.clubs`, versión `1.2.3` y build `10`. Firebase se integra mediante Swift Package Manager con `FirebaseAuth`, `FirebaseFirestore` y `FirebaseCore`.

Para distribuir en App Store Connect hay que iniciar sesión con la cuenta Apple en Xcode, seleccionar el equipo correcto y crear la ficha de la app si aún no existe. La primera versión usa acceso por correo; Sign in with Apple se añadirá cuando la capacidad esté habilitada en el identificador.
