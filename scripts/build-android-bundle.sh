#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYCHAIN_SERVICE="MatchPoint Clubs Android Upload Key"
KEYSTORE_PATH="$ROOT_DIR/credentials/matchpoint-upload-key.jks"
OUTPUT_PATH="$ROOT_DIR/dist/android/matchpoint-clubs-release.aab"
APK_OUTPUT_PATH="$ROOT_DIR/dist/android/matchpoint-clubs-release.apk"

export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
export NODE_ENV="production"

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "No se encontró la clave de firma: $KEYSTORE_PATH" >&2
  exit 1
fi

MATCHPOINT_UPLOAD_STORE_PASSWORD="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w)"
export MATCHPOINT_UPLOAD_STORE_PASSWORD
export MATCHPOINT_UPLOAD_KEY_PASSWORD="$MATCHPOINT_UPLOAD_STORE_PASSWORD"
export MATCHPOINT_UPLOAD_KEY_ALIAS="matchpoint-upload"
export MATCHPOINT_UPLOAD_KEYSTORE="$KEYSTORE_PATH"
export MATCHPOINT_VERSION_CODE="$(node -p "require('$ROOT_DIR/app.json').expo.android.versionCode")"
export MATCHPOINT_VERSION_NAME="$(node -p "require('$ROOT_DIR/app.json').expo.version")"

mkdir -p "$(dirname "$OUTPUT_PATH")"

(
  cd "$ROOT_DIR/android"
  # Un prebuild puede cambiar la lista de módulos autolinked. CMake intenta
  # entonces limpiar su grafo anterior antes de que codegen regenere las
  # carpetas JNI y falla apuntando a rutas que ya no existen.
  if [[ -d "$ROOT_DIR/android/app/.cxx" ]]; then
    find "$ROOT_DIR/android/app/.cxx" -mindepth 1 -delete
  fi
  # Metro conserva recursos empaquetados en android/app/build. Al cambiar la
  # extensión de un asset (por ejemplo PNG -> WebP), una build incremental
  # puede intentar fusionar ambas versiones bajo el mismo nombre Android.
  # Una release limpia evita duplicados y garantiza que el paquete contiene
  # exactamente los assets referenciados por el código actual.
  # Separar `clean` de la compilación evita una carrera de Prefab/CMake con
  # Reanimated bajo la New Architecture. Sin paralelismo, los paquetes C++
  # quedan listos antes de que la app configure cada ABI.
  ./gradlew clean --no-parallel --console=plain --quiet
  echo "Android clean completado; compilando release firmada..."
  ./gradlew bundleRelease assembleRelease --no-parallel --console=plain --quiet
  echo "Release Android compilada; copiando artefactos..."
)

# Metro/Expo puede limpiar `dist` durante el bundle; recreamos el destino al
# final para que la copia no dependa del orden interno de sus tareas.
mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$ROOT_DIR/android/app/build/outputs/bundle/release/app-release.aab" "$OUTPUT_PATH"
cp "$ROOT_DIR/android/app/build/outputs/apk/release/app-release.apk" "$APK_OUTPUT_PATH"
echo "$OUTPUT_PATH"
echo "$APK_OUTPUT_PATH"
