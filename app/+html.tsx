import { ScrollViewStyleReset } from "expo-router/html";
import type { PropsWithChildren } from "react";

/**
 * Documento HTML custom para web.
 *
 * Sobreescribe el reset por defecto de react-native-web, que pone
 * `body { overflow: hidden }` y `html, body, #root { height: 100% }`.
 * Eso es correcto para apps "fullscreen" con scroll gestionado por RN,
 * pero rompe el scroll nativo del navegador en móvil/web cuando el contenido
 * excede el viewport (login, onboarding, páginas largas). A cambio usamos
 * `min-height: 100%` y dejamos que el body scrollee normalmente.
 *
 * Docs: https://docs.expo.dev/router/reference/web-rendering/
 */
export default function RootHTML({ children }: PropsWithChildren) {
  return (
    <html lang="es">
      <head>
        <meta charSet="utf-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, shrink-to-fit=no, viewport-fit=cover"
        />

        {/* Evita el flash blanco antes de que cargue el JS: fondo de marca. */}
        <style>{`
          html, body, #root {
            height: 100%;
            min-height: 100%;
            width: 100%;
            max-width: none;
            box-sizing: border-box;
            background-color: #070C08 !important;
          }
          /* Una sola superficie de scroll: cada pantalla usa ScrollView. Evita
             el doble scroll que bloquea gestos en Safari móvil. */
          body {
            margin: 0;
            overflow: hidden !important;
            overflow-x: hidden !important;
            overflow-y: hidden !important;
            overscroll-behavior: none;
          }
          /* El #root en flex es necesario para que RN llene la pantalla. */
          #root {
            display: flex;
            flex: 1 1 auto;
            height: 100dvh;
            min-height: 100dvh;
            min-width: 100%;
            background-color: #070C08 !important;
          }
        `}</style>
      </head>
      <body>{children}</body>
    </html>
  );
}
