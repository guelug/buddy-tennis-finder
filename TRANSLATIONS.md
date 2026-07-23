# Traducciones (i18n) — MatchPoint Tennis

La app está internacionalizada con un diccionario plano de claves. El español
(`es`) es la **fuente de verdad** y el inglés (`en`) ya está traducido. El resto
de idiomas (francés, alemán, italiano, portugués…) se generan a partir del
español.

## Archivos

- `src/lib/i18n.tsx` — runtime. Contiene los diccionarios `es` y `en`, el
  `I18nProvider`, `useI18n()` y `t(key)`. `t` cae al español clave por clave, así
  que una traducción incompleta nunca rompe la UI.
- `i18n/es.json`, `i18n/en.json` — export plano generado por el script (ver abajo).
  **Este es el material que se le pasa a MiniMax.**
- `scripts/export-i18n.mjs` — regenera los JSON desde `i18n.tsx`.

## Regenerar los JSON fuente

```bash
node scripts/export-i18n.mjs
```

Verifica que `es` y `en` tengan exactamente las mismas claves (lo reporta al
final). Ejecútalo siempre que añadas o cambies claves en `i18n.tsx` antes de
mandar a traducir.

## Encargo a MiniMax

> Traduce el archivo `i18n/es.json` a **&lt;idioma&gt;**. Devuelve un JSON con las
> **mismas claves** y solo los valores traducidos. Reglas:
> 1. **No traduzcas las claves** (lo de la izquierda), solo los valores.
> 2. **Conserva intactos los placeholders** entre llaves: `{count}`, `{name}`,
>    `{city}`, `{country}`, `{club}`, `{courts}`, `{level}`, `{n}`, `{gap}`,
>    `{rank}`, `{division}`, etc. Deben aparecer igual en la traducción.
> 3. Conserva emojis y símbolos (`🎾`, `·`, `★`, `↑`, `–`).
> 4. Respeta mayúsculas/estilo: las claves en MAYÚSCULAS (eyebrows/kickers) van
>    en mayúsculas en el idioma destino.
> 5. Usa `i18n/en.json` como referencia de tono cuando ayude.
>
> El resultado debe ser un JSON válido con las 424 claves.

## Integrar una traducción nueva (p. ej. francés `fr`)

1. Guarda el JSON devuelto como `i18n/fr.json`.
2. En `src/lib/i18n.tsx`:
   - Añade el diccionario `const fr: Dictionary = { …valores… };` (o impórtalo).
   - Regístralo: `const DICTIONARIES: Partial<Record<LanguageCode, Dictionary>> = { es, en, fr };`
   - Añádelo al selector: `SUPPORTED_LANGUAGES` → `{ code: "fr", label: "Français" }`.
3. `LanguageCode` ya contempla `fr | de | it | pt`; si necesitas otro código,
   amplíalo en el `type`.
4. `npm run typecheck` para confirmar que no falta ninguna clave.

## Notas importantes

- Los valores **canónicos que se guardan en Firestore** (días de la semana como
  `"Lunes"`, idiomas como `"Español"`, géneros) **no se traducen en la base de
  datos**. Las claves `days.*` y `languages.*` solo traducen lo que se *muestra*
  en pantalla; lo persistido sigue en español para que sea comparable entre
  usuarios de distintos idiomas.
- El país de lanzamiento es **solo Guatemala** (`selectableCountries` en
  `src/data/seed.ts`). Al abrir nuevos mercados se amplía esa lista.
