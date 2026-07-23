# Auditoría de strings hardcodeados en componentes compartidos y tabs

Alcance: `src/components/**/*.tsx` (compartidos de alto impacto) + `app/(tabs)/**/*.tsx`. Excluidos: nombres de marca (MatchPoint, Waze), símbolos, fechas/horas numéricas, datos generados por el usuario (nombres, scores, ratings), emoji y logs de dev.

## Inventario de claves ya existentes reutilizables

De `src/lib/i18n.tsx` ya hay 425 claves es/en. Las siguientes familias están listas para reutilizar sin inventar nada nuevo:

| Familia | Claves reutilizables |
|---|---|
| `tabs.*` | `tabs.rivals`, `tabs.matches`, `tabs.ranking`, `tabs.profile`, `tabs.home`, `tabs.myProfile` |
| `settings.*` | `settings.title`, `settings.appearance`, `settings.appearanceHint`, `settings.theme.{system,light,dark}`, `settings.language`, `settings.languageHint`, `settings.version` |
| `profile.*` | `profile.edit`, `profile.invite`, `profile.inviteShort`, `profile.privateLeagues`, `profile.signOut`, `profile.privacy`, `profile.terms`, `profile.support`, `profile.deleteAccount`, `profile.coachInterests*`, `profile.badges.{verified,captain}`, `profile.kicker`, `profile.yearsOld`, `profile.stats.{wins,played,streakDetail,noRanking}`, `profile.skills.*`, `profile.reputation.*`, `profile.reviews.*`, `profile.achievements.*`, `profile.availability.*`, `profile.clubs.*`, `profile.languages.title`, `profile.form.*`, `profile.matchStars.title`, `profile.error.title` |
| `home.*` | `home.error`, `home.coachInterests.*`, `home.tennisIn.*`, `home.coaches.*`, `home.promoted`, `home.viewAll`, `home.promoteAsCoach`, `home.quick.*`, `home.selection.*`, `home.sponsored`, `home.community.title`, `home.stats.*`, `home.greeting.*`, `home.playerFallback`, `home.avatarFallback`, `home.pulse.*`, `home.nextMatch.*` |
| `rivals.*` | casi todo: `rivals.hero.*`, `rivals.publish.*`, `rivals.open.*`, `rivals.dashboard.*`, `rivals.featured.*`, `rivals.radar.*`, `rivals.form.*`, `rivals.alert.*`, `rivals.empty.*`, `rivals.search.*`, `rivals.filters.*`, `rivals.validation.*` |
| `matches.*` | `matches.filters.*`, `matches.tabs.*`, `matches.hero.*`, `matches.error.*`, `matches.dashboard.*`, `matches.stats.played`, `matches.score.pending`, `matches.upcoming.title`, `matches.create`, `matches.live.*`, `matches.validation.*`, `matches.captain.*`, `matches.stars.*`, `matches.activity.title`, `matches.validate.title`, `matches.ops.*`, `matches.banner.*`, `matches.row.*`, `matches.join.*`, `matches.cancel.*`, `matches.release.*`, `matches.requests.*`, `matches.alert.*`, `matches.empty.*`, `matches.confirm.*` |
| `ranking.*` | cubre la práctica totalidad del tab Liga (`ranking.mode.*`, `ranking.teams.*`, `ranking.leagues.*`, `ranking.tournaments.*`, `ranking.table.*`, `ranking.empty.*`, `ranking.league.*`, `ranking.status*`, `ranking.hero.*`, `ranking.web.subtitle`, `ranking.metric.*`, `ranking.leader`, `ranking.noData`, `ranking.circuit`, `ranking.livePosition*`, `ranking.podium`, `ranking.fullStandings`, `ranking.findRival`, `ranking.chase.*`, `ranking.rule*`, `ranking.featured.*`, `ranking.pointsBase`, `ranking.competitive.*`, `ranking.youSuffix`, `ranking.clubTbd`, `ranking.provisional.*`, `ranking.demoBadge`, `ranking.demoView`, `ranking.demoProfiles`, `ranking.privateLeagues.*`, `ranking.comingSoon`, `ranking.kicker`) |
| `onboarding.*` | `onboarding.format.{singles,doubles,mixed}` (reusables en filtros y tarjetas), `onboarding.level.novato` |
| `levels.*` | `levels.all` |
| `days.*`, `languages.*` | ya con tabla displayDay / displayLanguage |
| `common.*` | `common.directions`, `common.court`, `common.retry`, `common.cancel`, `common.save` |

---

## Hallazgos por archivo — alto impacto

### `app/(tabs)/_layout.tsx`  (tab bar + top nav)
Hardcoded a traducir:
| Línea | String | Acción |
|---|---|---|
| 74 | `accessibilityLabel="Activar modo oscuro"` | **nuevo** `a11y.theme.activateDark` |
| 74 | `accessibilityLabel="Activar modo claro"` | **nuevo** `a11y.theme.activateLight` |
| 91 | `"Oscuro"` (texto del toggle en tab bar) | reusar `settings.theme.dark` |
| 354 | `accessibilityLabel="Activar modo oscuro"` | reusar `a11y.theme.activateDark` |
| 354 | `accessibilityLabel="Activar modo claro"` | reusar `a11y.theme.activateLight` |
| 367 | `"Claro"` (texto del toggle en top nav) | reusar `settings.theme.light` |
| 244 | `accessibilityLabel="Abrir inicio"` (CenterBallButton) | **nuevo** `a11y.openHome` |

### `app/(tabs)/home.tsx`  (home, ya casi todo traducido)
Hardcoded a traducir:
| Línea | String | Acción |
|---|---|---|
| 90 | `t("common.retry").toUpperCase()` dentro de banner de error | OK, ya usa `common.retry`. Pero aparece `REINTENTAR` en mayúsculas — confirmar que el uppercase se aplica tras la traducción (ya lo hace). |
| 175 | `t("settings.theme.dark")` / `t("settings.theme.light")` | OK, reusa. |
| 348 | `StoryCard` recibe `tag`, `title`, `body` desde data (no hardcoded en este archivo) | contenido editorial dinámico — fuera de alcance. |

### `app/(tabs)/index.tsx`  (Rivales / Discover — el más grande)
Casi todo ya está traducido. Hardcoded residual:
| Línea | String | Acción |
|---|---|---|
| 252 | `kicker="RIVAL RADAR"` | **nuevo** `rivals.dashboard.kicker` |
| 651 | `accepting ? "…"` (label del botón "Enviando" cuando `accepting=true` en OpenProposalRow) | reusar `matches.join.sending` |
| 761 | `busy ? "…"` en JoinRequestsPanel.matches | reusar `matches.join.sending` o nuevo `common.loading` |
| 924 | `placeholder="10:00"` en FormInput de hora inicio | **nuevo** `rivals.form.timePlaceholder` |
| 927 | `placeholder="12:00"` en FormInput de hora fin | **nuevo** `rivals.form.endTimePlaceholder` (o reutilizar el anterior) |
| 1058 | `"Sin rivales con estos filtros"` (EmptyRivals título) | reusar `rivals.empty.title` |
| 1061 | `"No encontramos a "{query}". Prueba con nombre o apellido."` | reusar `rivals.empty.query` |
| 1061 | `"Prueba con otro nivel o formato."` (sin query) | reusar `rivals.empty.hint` |
| 1071 | `Text ... "Buscar jugador por nombre"` (label visible de CandidateNameSearch) | reusar `rivals.search.label` |
| 1075 | `accessibilityLabel="Buscar jugador por nombre"` | reusar `rivals.search.label` |
| 1079 | `placeholder="Nombre o apellido"` | reusar `rivals.search.placeholder` |
| 1086 | `accessibilityLabel="Limpiar búsqueda"` | reusar `rivals.search.clear` |
| 1101 | `<PrimaryButton label="Reintentar"` (DiscoverLoadError) | reusar `common.retry` |
| 1156 | `formatLabel → "Singles" / "Dobles" / "Mixto"` (auxiliar) | reusar `onboarding.format.{singles,doubles,mixed}` |
| 1168 | `"Niveles {levels}"` en `formatAcceptedLevels` | **nuevo** `rivals.open.levels` (mejor que reusar `rivals.open.levels` que ya existe con `{levels}` — verificar que ya tiene ese placeholder en el dic) — ya EXISTE con placeholder {levels}. |
| 1230 | `"mi club"` (defaultPublishMessage fallback) | **nuevo** `rivals.publish.defaultMessage.club` |
| 1231 | `"Reservé la cancha {court} de {startTime} a {endTime} en {club}. ¿Alguien se anima?"` | **nuevo** `rivals.publish.defaultMessage` con placeholders |

### `app/(tabs)/matches.tsx`  (Partidos)
Hardcoded residual:
| Línea | String | Acción |
|---|---|---|
| 174 | `kicker="MATCH CONTROL"` (BroadcastHeader) | **nuevo** `matches.control.kicker` (o reusar `matches.dashboard.subtitle` no encaja; mejor clave propia) |
| 407 | `kicker="MATCH CONTROL"` (ConceptHero de MatchOpsHero) | reusar `matches.control.kicker` |
| 761 | `busy ? "…"` en JoinRequestsPanel | reusar `common.loading` o `matches.join.sending` |
| 99-104 | `stats: [{ label: t("matches.hero.todo"), ... }]` | OK |

### `app/(tabs)/liga.tsx`  (Ranking / Liga)
Hardcoded residual:
| Línea | String | Acción |
|---|---|---|
| 135 | `Icon name="trophy" size={36}` — sin texto | n/a |
| 410 | `centerLabel={\`#${you?.rank ?? "-"}\`}` | OK — número dinámico |
| 533 | `value={\`#${you?.rank ?? "-"}\`}` y `detail={\`${you?.points ?? 0} pts\`}` | OK — números. El sufijo `" pts"` sí es texto: **nuevo** `ranking.pointsSuffix` (usar también en línea 704 `" pts"`) |
| 704 | `{entry.points} pts` | reusar `ranking.pointsSuffix` con `value.replace(...)` |
| 649 | `<InfoChip ... value="Beta" />` (chip de "Beta" en estado del ranking competitivo) | **nuevo** `ranking.status.beta` |
| 815 | `"Club"` fallback en formato de día | reusar `matches.row.clubFallback` |
| 914 | `#${entry.rank} {entry.playerName}` | OK — patrón numérico, pero considerar `ranking.table.rankLine` con `{rank} {name}` si se quiere traducir el orden o el separador. |

### `app/(tabs)/profile.tsx`  (Perfil)
Hardcoded residual:
| Línea | String | Acción |
|---|---|---|
| 248 | `"MatchPoint Tennis · v${APP_VERSION}"` (footer web) | **nuevo** `profile.appVersion` con `{version}` |
| 264 | `"BETA ANDROID ABIERTA"` (kicker de AndroidBetaBanner) | **nuevo** `profile.androidBeta.kicker` |
| 265 | `"MatchPoint Tennis ya está lista para probarse en Android"` | **nuevo** `profile.androidBeta.title` |
| 266 | `"Solicita acceso y te añadiremos al grupo de testers. Después podrás instalarla desde Google Play."` | **nuevo** `profile.androidBeta.body` |
| 270 | `"Petición enviada"` (status sent) | **nuevo** `profile.androidBeta.sent` |
| 270 | `"Enviando..."` (status sending) | reusar `onboarding.saving` o **nuevo** `profile.androidBeta.sending` |
| 270 | `"Solicitar acceso a la beta"` (idle label) | **nuevo** `profile.androidBeta.cta` |
| 281 | `Alert.alert("No se pudo enviar", ...)` | **nuevo** `profile.androidBeta.alert.failed` |
| 285 | `"Ver en Google Play"` | **nuevo** `profile.androidBeta.googlePlay` |
| 466 | `"MatchPoint Tennis · v${APP_VERSION}"` (footer nativo) | reusar `profile.appVersion` |
| 750 | `" (tú)"` en MatchStarsRow — pero el código dice `match-room.tsx` línea 750 | ver abajo |
| 1027 | `label: "Top 50"` (badge Top 50) | **nuevo** `profile.badges.top50` |
| 954 | (en match-room.tsx) `"Cerrar"` (botón cerrar MatchRoomSheet) | reusar `common.cancel` o **nuevo** `matches.room.close` |

---

## Hallazgos en componentes compartidos

### `src/components/match-room.tsx`  (alto impacto — sala completa del partido)
Densidad alta de hardcoded; componente muy visible. Casi todo nuevo:
| Línea | String | Acción |
|---|---|---|
| 50 | `awaiting_result: { label: "Falta marcador" }` | **nuevo** `matches.status.awaitingResult` |
| 51 | `awaiting_validation: { label: "Por validar" }` | **nuevo** `matches.status.awaitingValidation` |
| 52 | `validated: { label: "Validado" }` | **nuevo** `matches.status.validated` |
| 53 | `disputed: { label: "En disputa" }` | **nuevo** `matches.status.disputed` |
| 57 | `formatLabel → "Singles" / "Dobles" / "Mixto"` | reusar `onboarding.format.{singles,doubles,mixed}` |
| 277 | `clubName ?? "Club"` | reusar `matches.row.clubFallback` |
| 281 | `"RESULTADO FINAL"` (jersey en ResultShareCard) | **nuevo** `matches.share.resultBadge` |
| 284 | `"VS"` (separador) | **nuevo** `matches.share.vs` (o dejarlo como sigla universal — confirmar con producto) |
| 289 | `"🏆 {winners} GANA"` | **nuevo** `matches.share.winnerLine` con `{names}` |
| 290 | `"Encuentra rival. Juega. Comparte."` (slogan share) | **nuevo** `matches.share.tagline` |
| 327 | `"SET {n}"` | **nuevo** `matches.share.setLabel` con `{n}` |
| 367 | `["Marcador", "Validación", "Cerrado"]` (StatusStepper) | **nuevo** `matches.stepper.{scoreboard,validation,closed}` |
| 577 | `"+ Agregar set"` (ResultEditor) | **nuevo** `matches.editor.addSet` |
| 584 | `label={busy ? "Enviando..." : "Enviar resultado"}` | **nuevo** `matches.editor.sending` / `matches.editor.submit` |
| 593 | `"El equipo rival deberá confirmar el marcador para que cuente en el ranking."` | **nuevo** `matches.editor.helper` |
| 636 | `isEdit ? "Tu reseña del partido" : "¿Te gustó el partido?"` | **nuevo** `matches.review.title` (con variante edit/new) o dos claves `matches.review.titleEdit` / `matches.review.titleNew` |
| 642 | `"Puntúa el nivel técnico de tu rival · 1 a 10"` | **nuevo** `matches.review.skillHint` |
| 645-649 | skill labels `["Servicio","Derecha","Revés","Volea","Consistencia"]` | reusar `onboarding.skill.{serve,forehand,backhand,volley,consistency}` |
| 662 | `placeholder="Deja un comentario para tu rival (máx. 180)"` | **nuevo** `matches.review.commentPlaceholder` |
| 680 | `busy ? "Publicando..." : isEdit ? "Actualizar reseña" : "Publicar reseña"` | **nuevo** `matches.review.sending` / `matches.review.update` / `matches.review.publish` |
| 685 | `"Una reseña por jugador · solo participantes del partido."` | **nuevo** `matches.review.disclaimer` |
| 726 | `"Aún no hay reseñas de este partido."` | **nuevo** `matches.review.empty` |
| 750 | `"{playerName} (tú)"` | reusar `ranking.youSuffix` |
| 756 | `"“{comment}”"` (entrecomillado) | dejar las comillas tipográficas como están — son universales |
| 799 | `Alert.alert("No se pudo completar", ...)` | **nuevo** `matches.error.generic` |
| 811 | `"SALA DEL PARTIDO"` (kicker header) | **nuevo** `matches.room.kicker` |
| 814 | `clubName ?? "Club"` | reusar `matches.row.clubFallback` |
| 845 | `sharing ? "Preparando imagen..." : "Compartir resultado"` | **nuevo** `matches.share.preparing` / `matches.share.cta` |
| 856 | `Alert.alert("No se pudo compartir", ...)` | **nuevo** `matches.share.error` |
| 862 | `"Imagen 4:5 lista para Instagram, WhatsApp y otras redes."` | **nuevo** `matches.share.format` |
| 873 | `"El rival disputó el marcador. Corrígelo y vuelve a enviarlo."` (DisputeBanner — texto pasado como prop pero escrito literal) | **nuevo** `matches.dispute.youMustCorrect` |
| 885 | `"El capitán ({captains}) registra el marcador. Te avisaremos para validarlo."` | **nuevo** `matches.waiting.captain` con `{captains}` |
| 891 | `"Marcador en disputa — el capitán que lo registró debe corregirlo."` | **nuevo** `matches.dispute.captainMustCorrect` |
| 898 | `"{name} registró este marcador. ¿Es correcto?"` | **nuevo** `matches.validation.prompt` con `{name}` |
| 901 | `busy === "validate" ? "Confirmando..." : "Confirmar resultado"` | **nuevo** `matches.validation.confirming` / `matches.validation.confirm` |
| 914 | `busy === "dispute" ? "Enviando..." : "No es correcto — disputar"` | **nuevo** `matches.dispute.sending` / `matches.dispute.cta` |
| 919 | `"Esperando que alguien del equipo rival confirme el marcador…"` | **nuevo** `matches.waiting.rival` |
| 929 | `"RESEÑAS DEL PARTIDO"` | **nuevo** `matches.review.kicker` |
| 953 | `"Cerrar"` (Pressable close) | **nuevo** `matches.room.close` o reusar `common.cancel` |
| 1027 | `"Registrar resultado"` | **nuevo** `matches.cta.report` |
| 1029 | `"Validar resultado"` | **nuevo** `matches.cta.validate` |
| 1031 | `"Calificar partido"` | **nuevo** `matches.cta.review` |
| 1050 | `clubName ?? "Club"` | reusar `matches.row.clubFallback` |
| 1098 | `youWon ? "Victoria" : a.side ? "Derrota" : "Cerrado"` | **nuevo** `matches.result.win` / `matches.result.loss` / `matches.result.closed` |
| 1111 | `room.reviews.length === 1 ? "reseña" : "reseñas"` | **nuevo** `matches.review.reviewCount.one` / `matches.review.reviewCount.many` con `{count}` |
| 1121 | `"Ver sala"` | **nuevo** `matches.room.viewRoom` |

### `src/components/player-reviews.tsx`
| Línea | String | Acción |
|---|---|---|
| 13 | `timeAgo → "hoy"` | **nuevo** `time.today` |
| 14 | `"ayer"` | **nuevo** `time.yesterday` |
| 15 | `` `hace ${days} días` `` | **nuevo** `time.daysAgo` con `{count}` |
| 16 | `` `hace ${n} sem` `` | **nuevo** `time.weeksAgo` con `{count}` |
| 17 | `` `hace ${n} mes` `` | **nuevo** `time.monthsAgo` con `{count}` |
| 51 | `"Notas de rivales"` | reusar `profile.reviews.title` |
| 54 | `"Aún sin reseñas de partidos."` | **nuevo** `profile.reviews.empty` |
| 55 | `` `${n} reseña(s) de partidos validados` `` | **nuevo** `profile.reviews.summary` con `{count}` (y plural) |
| 88-92 | skill labels | reusar `onboarding.skill.*` |

### `src/components/played-match-card.tsx`
| Línea | String | Acción |
|---|---|---|
| 34 | `clubName ?? "Club"` | reusar `matches.row.clubFallback` |
| 60 | `youWon ? "Victoria" : "Derrota"` | reusar `matches.result.win` / `matches.result.loss` |

### `src/components/coach-checkout.native.tsx`
| Línea | String | Acción |
|---|---|---|
| 25 | `Alert.alert("Anuncio publicado", ...)` | **nuevo** `coach.adPublished.title` / `coach.adPublished.body` con `{days}` |
| 27 | `Alert.alert("Pago pendiente", ...)` | **nuevo** `coach.paymentPending.title` / `coach.paymentPending.body` |
| 28 | `"La verificación sigue en curso."` | reusar `coach.paymentPending.body` |
| 38 | `"Google Play no está disponible en este momento."` | **nuevo** `coach.googlePlayUnavailable` |
| 42 | `Alert.alert("No se pudo abrir Google Play", ...)` | **nuevo** `coach.openGooglePlay.failed` |
| 42 | `"Inténtalo de nuevo."` | reusar `onboarding.error.retryFallback` |
| 51 | `"Anuncio listo para publicar"` | **nuevo** `coach.ready.title` |
| 52 | `"Pago único · sin renovación automática"` | **nuevo** `coach.ready.body` |
| 56 | `processing ? "Verificando…" : \`Publicar ${days} días\`` | **nuevo** `coach.processing` / `coach.publishDays` con `{days}` |
| 58 | `"Compra procesada por Google Play. El anuncio se activa tras validar el pago."` | **nuevo** `coach.disclaimer` |

### `src/components/league-checkout.native.tsx`
| Línea | String | Acción |
|---|---|---|
| 24 | `Alert.alert("Liga creada", "Ya puedes invitar a tus amigos.")` | **nuevo** `league.created.title` / `league.created.body` |
| 27 | `Alert.alert("Pago pendiente", ...)` | reusar `coach.paymentPending.*` |
| 35 | `"Google Play no está disponible."` | reusar `coach.googlePlayUnavailable` |
| 39 | `"No se pudo abrir Google Play"` | reusar `coach.openGooglePlay.failed` |
| 39 | `"Inténtalo de nuevo."` | reusar `onboarding.error.retryFallback` |
| (línea 42, todo el JSX inline) | `"Liga privada lista"` / `"Pago único · liga permanente"` / `"Verificando…"` / `` `Crear liga privada` `` | **nuevo** `league.ready.title` / `league.ready.body` / `league.processing` / `league.create` |

### `src/components/coach-card.tsx`
| Línea | String | Acción |
|---|---|---|
| 13 | `accessibilityLabel={\`Ver entrenador ${name}\`}` | **nuevo** `coach.a11y.viewCoach` con `{name}` |
| 39 | `ad.city || "Entrenamiento flexible"` | **nuevo** `coach.flexibleTraining` |
| 51 | `ad.priceNote || "Consulta disponibilidad"` | **nuevo** `coach.checkAvailability` |
| 53 | `"VER PERFIL"` | reusar `common.viewProfile` (a crear si no existe) o **nuevo** `coach.viewProfile` |

### `src/components/player-card.tsx`
| Línea | String | Acción |
|---|---|---|
| 40 | `candidate.sharedSlots[0] ?? "Horario flexible"` | **nuevo** `rivals.radar.flexible` (ya existe como `rivals.radar.flexible` — reusar) |
| 72 | `accessibilityLabel={\`${name}, perfil de muestra\`}` / `\`Ver perfil de ${name}\`` | **nuevo** `rivals.a11y.viewProfile` con `{name}` y variante demo |
| 142 | mismo flexible slot | reusar `rivals.radar.flexible` |
| 179 | mismo a11y | reusar `rivals.a11y.viewProfile` |
| 263 | `"MUESTRA"` | reusar `ranking.demoBadge` |
| 272 | `"Perfil ilustrativo · sin acciones disponibles"` | **nuevo** `rivals.demoNotice` |
| 300 | `accessibilityLabel={\`Ver perfil de ${name}\`}` | reusar `rivals.a11y.viewProfile` |
| 328 | `"Ver perfil"` | reusar `rivals.a11y.viewProfile` o **nuevo** `rivals.viewProfile` |
| 334 | `accessibilityLabel="Cómo llegar con Waze"` | **nuevo** `rivals.a11y.directionsWaze` (o reusar `common.directions` con sufijo) |
| 370 | `"Cómo llegar"` | reusar `common.directions` |
| 426 | `"match"` (badge score) | **nuevo** `rivals.match` |

### `src/components/top-players-preview.tsx`
| Línea | String | Acción |
|---|---|---|
| 23 | `` `Top ${divisionLabel}` `` | **nuevo** `rivals.topDivision` con `{division}` |
| 23 | `actionLabel="Ver liga"` | **nuevo** `rivals.viewLeague` (o reusar `ranking.fullStandings`) |
| 31 | `accessibilityLabel={\`Ver perfil de ${playerName}\`}` | reusar `rivals.a11y.viewProfile` |

### `src/components/profile-photo-uploader.tsx`
| Línea | String | Acción |
|---|---|---|
| 71 | `accessibilityLabel="Seleccionar foto de perfil"` | **nuevo** `profile.photo.a11y.select` |
| 89 | `"Añade tu foto"` | **nuevo** `profile.photo.empty` |
| 112 | `` `ESCANEANDO · ${progress}%` `` | **nuevo** `profile.photo.scanning` con `{progress}` |
| 127 | `scanning → "Optimizando tu perfil"` | **nuevo** `profile.photo.optimizing` |
| 127 | `complete → "Foto lista"` | **nuevo** `profile.photo.ready` |
| 127 | `idle → \`Foto de ${name || "jugador"}\`` | **nuevo** `profile.photo.caption` con `{name}` (reusar `home.playerFallback`) |
| 130 | `error → "No pudimos subirla. Toca para reintentar."` | **nuevo** `profile.photo.error` |
| 130 | `"Toca la imagen para cambiarla · JPG o PNG"` | **nuevo** `profile.photo.helper` |

### `src/components/auth-gate.tsx`  (loader y error de perfil)
| Línea | String | Acción |
|---|---|---|
| 50 | `"La conexión está tardando demasiado. Revisa internet y vuelve a intentarlo."` | reusar `onboarding.error.timeout` o **nuevo** `auth.profile.timeout` |
| 64 | `"No pudimos comprobar tu perfil."` | **nuevo** `auth.profile.failed` |
| 147 | `"No pudimos abrir tu perfil"` | **nuevo** `auth.profile.loadError.title` |
| 149 | `"Reintentar conexión"` | reusar `common.retry` |
| 161 | `["Creando tu jugador", "Preparando la pista", "Ajustando la red"]` | **nuevo** `auth.welcome.firstProfile.{creating,preparing,adjusting}` |
| 162 | `["Abriendo el club", "Preparando la pista", "Buscando tu partido"]` | **nuevo** `auth.welcome.returning.{opening,preparing,searching}` |
| 172 | `"Tu primera entrada merece una buena pista."` | **nuevo** `auth.welcome.firstProfile.tagline` |
| 172 | `"Un momento, estamos dejando todo listo."` | **nuevo** `auth.welcome.returning.tagline` |

### `src/components/status-badge.tsx`
| Línea | String | Acción |
|---|---|---|
| 14 | `proposed: "Pendiente"` | reusar `matches.filters.proposed` |
| 15 | `accepted: "Aceptado"` | **nuevo** `matches.statusBadge.accepted` |
| 16 | `declined: "Cancelado"` | **nuevo** `matches.statusBadge.declined` |

### `src/components/live-visuals.tsx` (feature cards de landing)
| Línea | String | Acción |
|---|---|---|
| 191 | `featureCards → title="Ranking beta"`, `body="Orden provisional de perfiles"`, `stat="Beta"` | **nuevo** `feature.ranking.title` / `body` / `stat` |
| 192 | `title="Rival Radar"`, `body="Encuentra rivales compatibles"`, `stat="86%"` | **nuevo** `feature.rivalRadar.{title,body,stat}` |
| 193 | `title="Match Control"`, `body="Publica y gestiona reservas"`, `stat="En pista"` | **nuevo** `feature.matchControl.{title,body,stat}` |
| 194 | `title="Validación rival"`, `body="Próxima fase del circuito"`, `stat="Próximamente"` | **nuevo** `feature.rivalValidation.{title,body,stat}` (reusar `ranking.comingSoon`) |

### `src/components/time-input.tsx`
| Línea | String | Acción |
|---|---|---|
| 26 | `placeholder = "18:00"` (default) | dejar el placeholder literal — es una máscara HH:MM universal |
| 57 | `accessibilityLabel="Hora"` | **nuevo** `common.a11y.time` |

### `src/components/date-field.tsx` y `date-field.native.tsx`
| Línea | String | Acción |
|---|---|---|
| 14 / 33 | `accessibilityLabel="Fecha de la reserva"` / `"Elegir fecha de la reserva"` | unificar en **nuevo** `rivals.form.a11y.date` (o `common.a11y.date`) |
| 20 | `placeholder="AAAA-MM-DD"` | dejar literal — es formato de input universal |

### `src/components/modal-sheet.tsx`
| Línea | String | Acción |
|---|---|---|
| 54 | `accessibilityLabel="Cerrar panel"` | **nuevo** `common.a11y.closeSheet` |

### `src/components/star-rating.tsx`
| Línea | String | Acción |
|---|---|---|
| 131 | `` `${star} estrellas` `` | **nuevo** `stars.a11y` con `{count}` |

### `src/components/avatar.tsx`
| Línea | String | Acción |
|---|---|---|
| 89 | `` `Foto de ${name}` `` | **nuevo** `avatar.a11y` con `{name}` |

### `src/components/brand-lockup.tsx`
| Línea | String | Acción |
|---|---|---|
| 24 | `accessibilityLabel="MatchPoint Tennis"` | marca — dejar literal |

### `src/components/section-title.tsx`, `section-header.tsx`, `skeleton.tsx`, `count-up.tsx`, `metric-stat.tsx`, `court-line.tsx`, `court-lines.tsx`, `court-pattern.tsx`, `court-rally.tsx`, `ball-bounce.tsx`, `tennis-ball.tsx`, `card.tsx`, `chip.tsx`, `icon.tsx`, `icons/*`, `división-badge.tsx`, `rank-badge.tsx`, `ranking-row.tsx`, `rating-bar.tsx`, `scoreboard.tsx`, `screen-hero.tsx`, `screen-shell.tsx`, `podium.tsx`, `search-candidates-cta.tsx`, `loading-view.tsx`, `grouped-list.tsx`, `hero-banner.tsx`, `concept-hero.tsx`, `web/*`, `purchase-provider*`, `podium.tsx`, `skill-radar.tsx`
— sin strings user-visible hardcoded (todos reciben props ya traducidas o son decorativos).

---

## Resumen cuantitativo

- **Componentes auditados**: 25 archivos en `src/components/` + 5 archivos en `app/(tabs)/` + el sub-archivo `app/(tabs)/_layout.tsx`.
- **Strings hardcoded encontrados**: ~95 user-visible.
- **Reutilizan claves existentes**: ~28 (ej. `rivals.open.levels`, `onboarding.format.*`, `common.retry`, `settings.theme.*`, `matches.filters.*`, `matches.row.*`, `rivals.empty.*`, `rivals.search.*`, `rivals.radar.flexible`, `ranking.demoBadge`, `onboarding.error.timeout`, `home.playerFallback`).
- **Claves nuevas a crear**: ~67 distribuidas en los espacios de nombres `a11y.*`, `time.*`, `common.*`, `matches.*`, `rivals.*`, `profile.*`, `coach.*`, `league.*`, `feature.*`, `auth.*`, `home.androidBeta` (mejor `profile.androidBeta.*`).

## Top 5 prioridades (mayor impacto por usuario)

1. **`match-room.tsx`** — sala completa del partido: estados, reseñas, validación, share card. Toda la fase beta competitiva vive aquí. ~40 strings nuevos.
2. **`profile.tsx`** — pantalla de perfil con AndroidBetaBanner y badges. ~12 strings nuevos.
3. **`index.tsx` (rivals tab)** — EmptyRivals, CandidateNameSearch, defaultPublishMessage, kicker del dashboard. ~10 strings nuevos.
4. **`coach-checkout.native.tsx` + `league-checkout.native.tsx`** — flujos de compra, copy repetido en ambos. ~14 strings nuevos.
5. **`player-card.tsx` + `player-reviews.tsx` + `top-players-preview.tsx` + `auth-gate.tsx`** — alto tráfico de lista y onboarding implícito. ~20 strings nuevos.

