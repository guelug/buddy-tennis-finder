"use strict";

/* ==========================================================================
   MatchPoint landing — i18n + interacciones
   ========================================================================== */

const APPLE_STORE_URL = "https://apps.apple.com/app/id6793740051";
const ALLOWED_INVITE_KEYS = new Set(["code", "inviteCode"]);
const REDUCED_MOTION = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const FINE_POINTER = window.matchMedia("(pointer: fine)").matches;

/* ------------------------------- I18N ---------------------------------- */
const I18N = {
  es: {
    "nav.how": "Cómo funciona",
    "nav.tour": "La app",
    "nav.leagues": "Ligas",
    "nav.about": "Nosotros",
    "nav.faq": "FAQ",
    "nav.cta": "Descargar",

    "hero.eyebrow": "Tu ciudad · Tu nivel · Tu próximo partido",
    "hero.title": "Deja de buscar rival.<br><span class=\"accent\">Empieza a jugar.</span>",
    "hero.lead": "MatchPoint conecta tenistas de tu nivel, organiza partidos con pista y convierte cada resultado validado en un ranking que sí refleja tu juego.",
    "hero.ios": "Descargar para iPhone",
    "hero.android": "Descargar para Android",
    "hero.availability": "Gratis · iPhone y Android · Sin permanencia",
    "hero.proof1": "✓ Rivales compatibles",
    "hero.proof2": "✓ Partidos con pista",
    "hero.proof3": "✓ Ranking validado",
    "hero.scroll": "Desliza",
    "float.cta": "Descargar gratis",

    "showcase.cap1": "Tu próximo partido, al abrir la app",
    "showcase.cap2": "Rivales de tu nivel, filtrados de verdad",
    "showcase.cap3": "Queda sin negociar por chat",
    "showcase.cap4": "Un ranking que se gana en pista",
    "showcase.cap5": "Tu juego, medido por tus rivales",

    "proof.city": "Tu ciudad es la siguiente",
    "proof.stat1": "% gratis, sin letra pequeña",
    "proof.stat2": "jugadores confirman cada resultado",
    "proof.stat3": "golpes que puntúan tus rivales",
    "proof.stat4": "toque para encontrar rival",

    "feat.eyebrow": "Todo el club en tu bolsillo",
    "feat.title": "Menos chats eternos.<br><span class=\"accent\">Más tiempo en pista.</span>",
    "feat.sub": "MatchPoint organiza la parte difícil para que tú solo tengas que elegir rival, pista y hora.",
    "feat.c1t": "Rivales compatibles",
    "feat.c1p": "Descubre tenistas cercanos por ciudad, nivel, disponibilidad y modalidad. Menos ruido, mejores partidos.",
    "feat.c2t": "Partidos abiertos",
    "feat.c2p": "¿Ya tienes pista? Publica la reserva y encuentra un rival compatible sin llenar grupos de mensajes.",
    "feat.c3t": "Resultado consensuado",
    "feat.c3p": "Un jugador reporta el marcador y el rival lo confirma. Tu ranking se construye con partidos reales.",
    "feat.c4t": "Clubes y entrenadores",
    "feat.c4p": "Guarda tus clubes habituales, descubre pistas y encuentra profesionales que entrenan cerca de ti.",
    "feat.c5t": "Tu Match Buddy",
    "feat.c5p": "Resuelve dudas, prepara partidos y descubre tu siguiente paso sin salir de la app.",
    "feat.c6t": "Tu ciudad primero",
    "feat.c6p": "Encuentra oportunidades relevantes para tu zona y mantén tu información personal bajo control.",

    "tour.eyebrow": "Un paseo por la app",
    "tour.title": "Así se juega<br><span class=\"accent\">un partido en MatchPoint.</span>",
    "tour.sub": "De abrir la app a subir en el ranking, en cinco pasos. Sin grupos de mensajes y sin discutir el resultado.",
    "tour.s1t": "Tu próximo partido, al abrir",
    "tour.s1p": "Nada más entrar ves qué tienes en la agenda, en qué club y a qué hora. Desde ahí llegas en un toque a buscar rival, reservar o mirar tu posición.",
    "tour.s2t": "Rivales de tu nivel, no de cualquiera",
    "tour.s2p": "Filtra por ciudad, nivel, edad y disponibilidad. Cada perfil llega con su valoración y sus notas técnicas, así sabes a qué vas antes de quedar.",
    "tour.s3t": "Queda sin negociar por chat",
    "tour.s3p": "Publica tu reserva o pide plaza en la de otro. La app se encarga de horarios, pista y confirmaciones; tú solo dices que sí.",
    "tour.s4t": "Un resultado que los dos firmáis",
    "tour.s4p": "Uno registra el marcador y el rival lo confirma. Solo entonces cuenta para la clasificación, así que el ranking refleja partidos de verdad.",
    "tour.s5t": "Tu juego, contado por quien te lo ha jugado",
    "tour.s5p": "Después del partido os puntuáis saque, derecha, revés, volea y consistencia. Con el tiempo tu perfil deja de ser lo que tú dices y pasa a ser lo que demuestras.",

    "league.boardLabel": "Liga pública · Individual",
    "league.w8": "8 victorias",
    "league.w7": "7 victorias",
    "league.w5": "5 victorias",
    "league.you": "Tú<br><small>5 victorias</small>",
    "league.pts": "pts",
    "league.eyebrow": "Competición que sí encaja contigo",
    "league.title": "Un ranking que<br><span class=\"accent\">se gana en pista.</span>",
    "league.lead": "Desde Novato hasta A. Te inscribes en tu división, juegas cuando ambos podéis y cada partido validado alimenta una clasificación transparente.",
    "league.st1": "Elige tu nivel y ciudad.",
    "league.st2": "Únete a la liga regional.",
    "league.st3": "Juega y registra el marcador.",
    "league.st4": "Tu rival valida y puntúas.",

    "vs.eyebrow": "El antes y el después",
    "vs.title": "El grupo de WhatsApp<br><span class=\"accent\">contra MatchPoint.</span>",
    "vs.oldT": "El caos de siempre",
    "vs.old1": "237 mensajes para quedar un martes",
    "vs.old2": "Rivales que no son de tu nivel",
    "vs.old3": "Resultados que nadie recuerda igual",
    "vs.old4": "Tu progreso, guardado en la nada",
    "vs.newT": "Con MatchPoint",
    "vs.new1": "Un toque: rival, pista y hora",
    "vs.new2": "Rivales filtrados por nivel real",
    "vs.new3": "Marcador confirmado por los dos",
    "vs.new4": "Un récord que crece partido a partido",

    "about.eyebrow": "Una necesidad real, convertida en producto",
    "about.title": "Hecha por tenistas,<br><span class=\"accent\">para jugar más.</span>",
    "about.lead": "MatchPoint no nació en una sala de reuniones. Nació de una dificultad muy concreta: encontrar rivales compatibles, organizar partidos y competir sin depender de grupos interminables.",
    "about.p1": "Cristian Gonzalez Salvatierra, cofundador, vivía esa necesidad en primera persona. Su experiencia, sus peticiones y el contacto directo con lo que necesita un jugador dieron origen a la idea y siguen guiando la evolución del producto.",
    "about.p2": "Pedro Caparrós, fundador y desarrollador, ha convertido esa visión en MatchPoint: diseño, usabilidad y desarrollo de la aplicación de principio a fin, transformando cada necesidad real en una experiencia sencilla y útil dentro y fuera de la pista.",
    "about.pedroRole": "Fundador y desarrollador",
    "about.pedroDesc": "Diseño, usabilidad y desarrollo, de la idea a la app.",
    "about.crisRole": "Cofundador",
    "about.crisDesc": "Origen de la idea, necesidades de jugador y visión de producto.",
    "about.quote": "“Construimos lo que de verdad echábamos en falta para poder jugar.”",

    "testers.eyebrow": "Gracias, equipo",
    "testers.title": "Construida con jugadores reales.",
    "testers.sub": "MatchPoint es mejor gracias a nuestros testers, que la han probado en pista y nos han llenado de sugerencias para pulir cada detalle:",
    "testers.more": "…y muchos más",

    "priv.eyebrow": "Juega con tranquilidad",
    "priv.title": "Tu juego es público.<br><span class=\"accent\">Tus datos, no.</span>",
    "priv.sub": "Solo te pedimos lo imprescindible para que puedas jugar, y usamos estadísticas anónimas para mantener la app rápida, estable y mejorando cada semana.",
    "priv.k1": "MÍNIMO",
    "priv.c1t": "Solo lo imprescindible",
    "priv.c1p": "Tu perfil de jugador, tu ciudad y tus partidos. Nada más. Lo justo para encontrarte rivales y llevar tu récord.",
    "priv.k2": "MEJORA",
    "priv.c2t": "Estadísticas anónimas",
    "priv.c2p": "Datos agregados y anónimos de uso nos ayudan a detectar fallos y mantener la app en forma. Nunca sabemos quién eres.",
    "priv.k3": "CONTROL",
    "priv.c3t": "Tú tienes el control",
    "priv.c3p": "Borra tu cuenta y tus datos desde la propia app, cuando quieras, sin escribir a soporte y sin esperas.",

    "price.eyebrow": "Sin letra pequeña",
    "price.title": "Gratis.<br><span class=\"accent\">De verdad.</span>",
    "price.sub": "Todo lo que necesitas para jugar más y mejor está incluido desde el primer día.",
    "price.plan": "Jugador",
    "price.forever": "/ para siempre",
    "price.f1": "Rivales compatibles por nivel y ciudad",
    "price.f2": "Partidos abiertos y reservas con pista",
    "price.f3": "Ranking validado entre jugadores",
    "price.f4": "Perfil técnico con valoraciones reales",
    "price.f5": "Ligas regionales por división",
    "price.cta": "Empezar ahora",

    "faq.eyebrow": "Antes de entrar en pista",
    "faq.title": "Lo que quieres saber.",
    "faq.sub": "Todo claro desde el primer partido.",
    "faq.q1": "¿Para quién es MatchPoint?",
    "faq.a1": "Para tenistas que quieren jugar más y organizarse mejor: desde quienes empiezan hasta quienes compiten por subir de nivel.",
    "faq.q2": "¿Cuánto cuesta?",
    "faq.a2": "Nada. MatchPoint es gratis: encontrar rivales, organizar partidos y competir en el ranking no cuestan un euro.",
    "faq.q3": "¿Cómo encuentro un rival?",
    "faq.a3": "Indica tu ciudad, nivel, modalidad y disponibilidad. MatchPoint te muestra perfiles y partidos compatibles para que elijas con quién jugar.",
    "faq.q4": "¿Quién valida el resultado?",
    "faq.a4": "El marcador lo confirma tu rival. Así el ranking se alimenta de partidos reales y no de puntos autoproclamados.",
    "faq.q5": "¿Tengo que pertenecer a un club?",
    "faq.a5": "No. Puedes descubrir jugadores de tu zona, guardar tus clubes habituales y organizar el partido que mejor encaje contigo.",
    "faq.q6": "¿Y si no hay jugadores en mi ciudad?",
    "faq.a6": "La comunidad crece cada semana. Invita a tus compañeros de pista con tu enlace y sé el primero de tu ciudad en abrir el ranking.",

    "cta.eyebrow": "Listo para jugar",
    "cta.title": "Empieza tu récord<br><span class=\"accent\">en la liga de tu ciudad.</span>",
    "cta.sub": "Cada partido cuenta. Encuentra rivales más diversos, juega tu primer partido esta semana y empieza a escribir tu nombre en el ranking.",
    "cta.ios": " iPhone",
    "cta.android": "▶ Android",
    "cta.note": "Gratis · Sin tarjeta · 2 minutos para crear tu perfil",

    "footer.copy": "© 2026 MatchPoint Tennis · Hecha por tenistas, para tenistas",
    "footer.privacy": "Privacidad",
    "footer.terms": "Términos",
    "footer.support": "Soporte",
    "footer.delete": "Eliminar cuenta"
  },
  en: {
      "nav.how": "How it works",
      "nav.tour": "The app",
      "nav.leagues": "Leagues",
      "nav.about": "About us",
      "nav.faq": "FAQ",
      "nav.cta": "Download",
      "hero.eyebrow": "Your city · Your level · Your next match",
      "hero.title": "Stop searching for an opponent.<br><span class=\"accent\">Start playing.</span>",
      "hero.lead": "MatchPoint connects tennis players at your level, organizes matches with a court, and turns every validated result into a ranking that truly reflects your game.",
      "hero.ios": "Download for iPhone",
      "hero.android": "Download for Android",
      "hero.availability": "Free · iPhone and Android · No commitment",
      "hero.proof1": "✓ Compatible opponents",
      "hero.proof2": "✓ Matches with a court",
      "hero.proof3": "✓ Validated ranking",
      "showcase.cap1": "Your next match, the moment you open the app",
      "showcase.cap2": "Opponents at your level, genuinely filtered",
      "showcase.cap3": "Arrange a match without negotiating in chat",
      "showcase.cap4": "A ranking you earn on court",
      "showcase.cap5": "Your game, measured by your opponents",
      "proof.city": "Your city is next",
      "proof.stat1": "% free, no fine print",
      "proof.stat2": "players confirm every result",
      "proof.stat3": "strokes your opponents rate",
      "proof.stat4": "tap to find an opponent",
      "feat.eyebrow": "The whole club in your pocket",
      "feat.title": "Fewer endless chats.<br><span class=\"accent\">More time on court.</span>",
      "feat.sub": "MatchPoint handles the hard part so all you have to do is choose your opponent, court, and time.",
      "feat.c1t": "Compatible opponents",
      "feat.c1p": "Discover nearby tennis players by city, level, availability, and format. Less noise, better matches.",
      "feat.c2t": "Open matches",
      "feat.c2p": "Already have a court? Publish your booking and find a compatible opponent without flooding group chats.",
      "feat.c3t": "Agreed result",
      "feat.c3p": "One player reports the score and the opponent confirms it. Your ranking is built on real matches.",
      "feat.c4t": "Clubs and coaches",
      "feat.c4p": "Save your regular clubs, discover courts, and find professionals training near you.",
      "feat.c5t": "Your Match Buddy",
      "feat.c5p": "Get answers, prepare for matches, and discover your next step without leaving the app.",
      "feat.c6t": "Your city first",
      "feat.c6p": "Find relevant opportunities in your area and keep your personal information under control.",
      "tour.eyebrow": "A tour of the app",
      "tour.title": "This is how you play<br><span class=\"accent\">a match on MatchPoint.</span>",
      "tour.sub": "From opening the app to climbing the rankings, in five steps. No group chats and no arguing over the score.",
      "tour.s1t": "Your next match, at a glance",
      "tour.s1p": "As soon as you open the app, you see what is on your schedule, which club it is at, and what time. From there, one tap takes you to find an opponent, book a court, or check your position.",
      "tour.s2t": "Opponents at your level—not just anyone",
      "tour.s2p": "Filter by city, level, age, and availability. Every profile comes with a rating and technical notes, so you know what to expect before you arrange a match.",
      "tour.s3t": "Arrange it without negotiating in chat",
      "tour.s3p": "Publish your booking or request a spot in someone else’s. The app handles schedules, court details, and confirmations; you just say yes.",
      "tour.s4t": "A result you both sign off on",
      "tour.s4p": "One player records the score and the opponent confirms it. Only then does it count toward the standings, so the ranking reflects real matches.",
      "tour.s5t": "Your game, told by the person who played you",
      "tour.s5p": "After the match, you rate each other’s serve, forehand, backhand, volley, and consistency. Over time, your profile stops being what you say and becomes what you prove.",
      "league.boardLabel": "Public league · Singles",
      "league.w8": "8 wins",
      "league.w7": "7 wins",
      "league.w5": "5 wins",
      "league.you": "You<br><small>5 wins</small>",
      "league.pts": "pts",
      "league.eyebrow": "Competition that fits you",
      "league.title": "A ranking you<br><span class=\"accent\">earn on court.</span>",
      "league.lead": "From Beginner to A. Sign up for your division, play when you’re both available, and every validated match feeds a transparent leaderboard.",
      "league.st1": "Choose your level and city.",
      "league.st2": "Join the regional league.",
      "league.st3": "Play and record the score.",
      "league.st4": "Your opponent validates it, and you earn points.",
      "vs.eyebrow": "Before and after",
      "vs.title": "The WhatsApp group<br><span class=\"accent\">versus MatchPoint.</span>",
      "vs.oldT": "The usual chaos",
      "vs.old1": "237 messages to arrange a Tuesday match",
      "vs.old2": "Opponents who aren’t at your level",
      "vs.old3": "Results nobody remembers the same way",
      "vs.old4": "Your progress, saved nowhere",
      "vs.newT": "With MatchPoint",
      "vs.new1": "One tap: opponent, court, and time",
      "vs.new2": "Opponents filtered by real skill level",
      "vs.new3": "Score confirmed by both players",
      "vs.new4": "A record that grows match by match",
      "about.eyebrow": "A real need, turned into a product",
      "about.title": "Made by tennis players,<br><span class=\"accent\">so you can play more.</span>",
      "about.lead": "MatchPoint wasn’t born in a meeting room. It came from a very specific challenge: finding compatible opponents, organizing matches, and competing without relying on endless group chats.",
      "about.p1": "Cristian Gonzalez Salvatierra, co-founder, experienced that need firsthand. His experience, requests, and direct contact with what players need gave rise to the idea and continue to guide the product’s evolution.",
      "about.p2": "Pedro Caparrós, founder and developer, turned that vision into MatchPoint: designing, refining usability, and developing the app from start to finish, transforming every real need into a simple, useful experience on and off the court.",
      "about.pedroRole": "Founder and developer",
      "about.pedroDesc": "Design, usability, and development—from idea to app.",
      "about.crisRole": "Co-founder",
      "about.crisDesc": "The idea’s origin, player needs, and product vision.",
      "about.quote": "“We built what we genuinely felt was missing so we could play.”",
      "testers.eyebrow": "Thanks, team",
      "testers.title": "Built with real players.",
      "testers.sub": "MatchPoint is better thanks to our testers, who tried it on court and shared suggestions to refine every detail:",
      "testers.more": "…and many more",
      "priv.eyebrow": "Play with peace of mind",
      "priv.title": "Your game is public.<br><span class=\"accent\">Your data isn’t.</span>",
      "priv.sub": "We only ask for what you need to play, and use anonymous statistics to keep the app fast, stable, and improving every week.",
      "priv.k1": "MINIMUM",
      "priv.c1t": "Only what’s essential",
      "priv.c1p": "Your player profile, your city, and your matches. Nothing more. Just enough to help you find opponents and keep your record.",
      "priv.k2": "IMPROVEMENT",
      "priv.c2t": "Anonymous statistics",
      "priv.c2p": "Aggregated, anonymous usage data helps us spot issues and keep the app in shape. We never know who you are.",
      "priv.k3": "CONTROL",
      "priv.c3t": "You’re in control",
      "priv.c3p": "Delete your account and data right from the app, whenever you want—no support ticket, no waiting.",
      "price.eyebrow": "No fine print",
      "price.title": "Free.<br><span class=\"accent\">For real.</span>",
      "price.sub": "Everything you need to play more and play better is included from day one.",
      "price.plan": "Player",
      "price.forever": "/ forever",
      "price.f1": "Compatible opponents by level and city",
      "price.f2": "Open matches and court bookings",
      "price.f3": "Player-validated ranking",
      "price.f4": "Technical profile with real ratings",
      "price.f5": "Regional leagues by division",
      "price.cta": "Start now",
      "faq.eyebrow": "Before you step on court",
      "faq.title": "What you want to know.",
      "faq.sub": "Everything clear from your first match.",
      "faq.q1": "Who is MatchPoint for?",
      "faq.a1": "For tennis players who want to play more and organize better—from beginners to those competing to move up a level.",
      "faq.q2": "How much does it cost?",
      "faq.a2": "Nothing. MatchPoint is free: finding opponents, organizing matches, and competing in the ranking don’t cost a thing.",
      "faq.q3": "How do I find an opponent?",
      "faq.a3": "Enter your city, level, format, and availability. MatchPoint shows you compatible profiles and matches so you can choose who to play.",
      "faq.q4": "Who validates the result?",
      "faq.a4": "Your opponent confirms the score. That way, the ranking is built on real matches—not self-awarded points.",
      "faq.q5": "Do I have to belong to a club?",
      "faq.a5": "No. Discover players in your area, save your regular clubs, and organize the match that fits you best.",
      "faq.q6": "What if there are no players in my city?",
      "faq.a6": "The community grows every week. Invite your tennis partners with your link and be the first in your city to open the ranking.",
      "cta.eyebrow": "Ready to play",
      "cta.title": "Start your record<br><span class=\"accent\">in your city’s league.</span>",
      "cta.sub": "Every match counts. Find a wider range of opponents, play your first match this week, and start writing your name into the rankings.",
      "cta.ios": "  iPhone",
      "cta.android": "▶ Android",
      "cta.note": "Free · No card · 2 minutes to create your profile",
      "footer.copy": "© 2026 MatchPoint Tennis · Made by tennis players, for tennis players",
      "footer.privacy": "Privacy",
      "footer.terms": "Terms",
      "footer.support": "Support",
      "footer.delete": "Delete account",
      "hero.scroll": "Scroll",
      "float.cta": "Download free"
  },
  ca: {
      "nav.how": "Com funciona",
      "nav.tour": "L’app",
      "nav.leagues": "Lligues",
      "nav.about": "Nosaltres",
      "nav.faq": "FAQ",
      "nav.cta": "Descarrega",
      "hero.eyebrow": "La teva ciutat · El teu nivell · El teu pròxim partit",
      "hero.title": "Deixa de buscar rival.<br><span class=\"accent\">Comença a jugar.</span>",
      "hero.lead": "MatchPoint connecta tennistes del teu nivell, organitza partits amb pista i converteix cada resultat validat en un rànquing que reflecteix de debò el teu joc.",
      "hero.ios": "Descarrega per a iPhone",
      "hero.android": "Descarrega per a Android",
      "hero.availability": "Gratis · iPhone i Android · Sense permanència",
      "hero.proof1": "✓ Rivals compatibles",
      "hero.proof2": "✓ Partits amb pista",
      "hero.proof3": "✓ Rànquing validat",
      "showcase.cap1": "El teu pròxim partit, en obrir l’app",
      "showcase.cap2": "Rivals del teu nivell, filtrats de debò",
      "showcase.cap3": "Concreta el partit sense negociar pel xat",
      "showcase.cap4": "Un rànquing que es guanya a la pista",
      "showcase.cap5": "El teu joc, mesurat pels teus rivals",
      "proof.city": "La teva ciutat és la següent",
      "proof.stat1": "% gratis, sense lletra petita",
      "proof.stat2": "jugadors confirmen cada resultat",
      "proof.stat3": "cops valorats pels teus rivals",
      "proof.stat4": "toc per trobar rival",
      "feat.eyebrow": "Tot el club a la butxaca",
      "feat.title": "Menys xats eterns.<br><span class=\"accent\">Més temps a la pista.</span>",
      "feat.sub": "MatchPoint organitza la part difícil perquè tu només hagis de triar rival, pista i hora.",
      "feat.c1t": "Rivals compatibles",
      "feat.c1p": "Descobreix tennistes propers per ciutat, nivell, disponibilitat i modalitat. Menys soroll, millors partits.",
      "feat.c2t": "Partits oberts",
      "feat.c2p": "Ja tens pista? Publica la reserva i troba un rival compatible sense omplir grups de missatges.",
      "feat.c3t": "Resultat consensuat",
      "feat.c3p": "Un jugador comunica el marcador i el rival el confirma. El teu rànquing es construeix amb partits reals.",
      "feat.c4t": "Clubs i entrenadors",
      "feat.c4p": "Desa els teus clubs habituals, descobreix pistes i troba professionals que entrenin a prop teu.",
      "feat.c5t": "El teu Match Buddy",
      "feat.c5p": "Resol dubtes, prepara partits i descobreix el teu pas següent sense sortir de l’app.",
      "feat.c6t": "La teva ciutat, primer",
      "feat.c6p": "Troba oportunitats rellevants per a la teva zona i mantén la teva informació personal sota control.",
      "tour.eyebrow": "Un recorregut per l’app",
      "tour.title": "Així es juga<br><span class=\"accent\">un partit a MatchPoint.</span>",
      "tour.sub": "D’obrir l’app a pujar en el rànquing, en cinc passos. Sense grups de missatges ni discutir el resultat.",
      "tour.s1t": "El teu pròxim partit, en obrir l’app",
      "tour.s1p": "Només entrar, veus què tens a l’agenda, a quin club és i a quina hora. Des d’allà, amb un sol toc pots buscar rival, reservar o consultar la teva posició.",
      "tour.s2t": "Rivals del teu nivell, no pas qualsevol",
      "tour.s2p": "Filtra per ciutat, nivell, edat i disponibilitat. Cada perfil inclou la seva valoració i les seves notes tècniques, perquè sàpigues què t’espera abans de quedar.",
      "tour.s3t": "Concreta-ho sense negociar pel xat",
      "tour.s3p": "Publica la teva reserva o demana plaça a la d’una altra persona. L’app s’encarrega dels horaris, la pista i les confirmacions; tu només has de dir que sí.",
      "tour.s4t": "Un resultat que signeu tots dos",
      "tour.s4p": "Un jugador registra el marcador i el rival el confirma. Només llavors compta per a la classificació, així que el rànquing reflecteix partits de debò.",
      "tour.s5t": "El teu joc, explicat per qui ha jugat contra tu",
      "tour.s5p": "Després del partit us valoreu el servei, la dreta, el revés, la volea i la consistència. Amb el temps, el teu perfil deixa de ser el que dius i passa a ser el que demostres.",
      "league.boardLabel": "Lliga pública · Individual",
      "league.w8": "8 victòries",
      "league.w7": "7 victòries",
      "league.w5": "5 victòries",
      "league.you": "Tu<br><small>5 victòries</small>",
      "league.pts": "pts",
      "league.eyebrow": "Competició que encaixa amb tu",
      "league.title": "Un rànquing que<br><span class=\"accent\">es guanya a la pista.</span>",
      "league.lead": "De Novell a A. T’inscrius a la teva divisió, jugues quan tots dos podeu i cada partit validat alimenta una classificació transparent.",
      "league.st1": "Tria el teu nivell i la teva ciutat.",
      "league.st2": "Uneix-te a la lliga regional.",
      "league.st3": "Juga i registra el marcador.",
      "league.st4": "El teu rival valida i tu sumes punts.",
      "vs.eyebrow": "L’abans i el després",
      "vs.title": "El grup de WhatsApp<br><span class=\"accent\">contra MatchPoint.</span>",
      "vs.oldT": "El caos de sempre",
      "vs.old1": "237 missatges per quedar un dimarts",
      "vs.old2": "Rivals que no són del teu nivell",
      "vs.old3": "Resultats que ningú recorda igual",
      "vs.old4": "El teu progrés, sense desar enlloc",
      "vs.newT": "Amb MatchPoint",
      "vs.new1": "Un toc: rival, pista i hora",
      "vs.new2": "Rivals filtrats pel nivell real",
      "vs.new3": "Marcador confirmat per tots dos",
      "vs.new4": "Un rècord que creix partit rere partit",
      "about.eyebrow": "Una necessitat real, convertida en producte",
      "about.title": "Feta per tennistes,<br><span class=\"accent\">per jugar més.</span>",
      "about.lead": "MatchPoint no va néixer en una sala de reunions. Va néixer d’una dificultat molt concreta: trobar rivals compatibles, organitzar partits i competir sense dependre de grups interminables.",
      "about.p1": "Cristian Gonzalez Salvatierra, cofundador, vivia aquesta necessitat en primera persona. La seva experiència, les seves peticions i el contacte directe amb allò que necessita un jugador van donar origen a la idea i continuen guiant l’evolució del producte.",
      "about.p2": "Pedro Caparrós, fundador i desenvolupador, ha convertit aquesta visió en MatchPoint: disseny, usabilitat i desenvolupament de l’aplicació de principi a fi, transformant cada necessitat real en una experiència senzilla i útil dins i fora de la pista.",
      "about.pedroRole": "Fundador i desenvolupador",
      "about.pedroDesc": "Disseny, usabilitat i desenvolupament, de la idea a l’app.",
      "about.crisRole": "Cofundador",
      "about.crisDesc": "Origen de la idea, necessitats del jugador i visió de producte.",
      "about.quote": "“Construïm allò que realment trobàvem a faltar per poder jugar.”",
      "testers.eyebrow": "Gràcies, equip",
      "testers.title": "Construïda amb jugadors reals.",
      "testers.sub": "MatchPoint és millor gràcies als nostres testers, que l’han provat a la pista i ens han fet arribar suggeriments per polir cada detall:",
      "testers.more": "…i molts més",
      "priv.eyebrow": "Juga amb tranquil·litat",
      "priv.title": "El teu joc és públic.<br><span class=\"accent\">Les teves dades, no.</span>",
      "priv.sub": "Només et demanem allò imprescindible perquè puguis jugar, i fem servir estadístiques anònimes per mantenir l’app ràpida i estable, i fer-la millorar cada setmana.",
      "priv.k1": "MÍNIM",
      "priv.c1t": "Només allò imprescindible",
      "priv.c1p": "El teu perfil de jugador, la teva ciutat i els teus partits. Res més. Just el necessari per trobar rivals i mantenir el teu rècord.",
      "priv.k2": "MILLORA",
      "priv.c2t": "Estadístiques anònimes",
      "priv.c2p": "Les dades d’ús agregades i anònimes ens ajuden a detectar errors i mantenir l’app en forma. Mai no sabem qui ets.",
      "priv.k3": "CONTROL",
      "priv.c3t": "Tu tens el control",
      "priv.c3p": "Esborra el teu compte i les teves dades des de la mateixa app, quan vulguis, sense escriure al suport ni esperar.",
      "price.eyebrow": "Sense lletra petita",
      "price.title": "Gratis.<br><span class=\"accent\">De debò.</span>",
      "price.sub": "Tot el que necessites per jugar més i millor està inclòs des del primer dia.",
      "price.plan": "Jugador",
      "price.forever": "/ per sempre",
      "price.f1": "Rivals compatibles per nivell i ciutat",
      "price.f2": "Partits oberts i reserves amb pista",
      "price.f3": "Rànquing validat entre jugadors",
      "price.f4": "Perfil tècnic amb valoracions reals",
      "price.f5": "Lligues regionals per divisió",
      "price.cta": "Comença ara",
      "faq.eyebrow": "Abans d’entrar a la pista",
      "faq.title": "El que vols saber.",
      "faq.sub": "Tot clar des del primer partit.",
      "faq.q1": "Per a qui és MatchPoint?",
      "faq.a1": "Per a tennistes que volen jugar més i organitzar-se millor: des dels qui tot just comencen fins als qui competeixen per pujar de nivell.",
      "faq.q2": "Quant costa?",
      "faq.a2": "Res. MatchPoint és gratis: trobar rivals, organitzar partits i competir al rànquing no et costa ni un euro.",
      "faq.q3": "Com trobo un rival?",
      "faq.a3": "Indica la teva ciutat, nivell, modalitat i disponibilitat. MatchPoint et mostra perfils i partits compatibles perquè triïs amb qui jugar.",
      "faq.q4": "Qui valida el resultat?",
      "faq.a4": "El teu rival confirma el marcador. Així, el rànquing s’alimenta de partits reals i no de punts autoproclamats.",
      "faq.q5": "He de pertànyer a un club?",
      "faq.a5": "No. Pots descobrir jugadors de la teva zona, desar els teus clubs habituals i organitzar el partit que encaixi millor amb tu.",
      "faq.q6": "I si no hi ha jugadors a la meva ciutat?",
      "faq.a6": "La comunitat creix cada setmana. Convida els teus companys de pista amb el teu enllaç i sigues el primer de la teva ciutat a obrir el rànquing.",
      "cta.eyebrow": "A punt per jugar",
      "cta.title": "Comença el teu rècord<br><span class=\"accent\">a la lliga de la teva ciutat.</span>",
      "cta.sub": "Cada partit compta. Troba rivals més diversos, juga el teu primer partit aquesta setmana i comença a escriure el teu nom al rànquing.",
      "cta.ios": "  iPhone",
      "cta.android": "▶ Android",
      "cta.note": "Gratis · Sense targeta · 2 minuts per crear el teu perfil",
      "footer.copy": "© 2026 MatchPoint Tennis · Feta per tennistes, per a tennistes",
      "footer.privacy": "Privacitat",
      "footer.terms": "Termes",
      "footer.support": "Suport",
      "footer.delete": "Eliminar el compte",
      "hero.scroll": "Fes scroll",
      "float.cta": "Baixa gratis"
  }
};

let currentLang = "es";

function resolveInitialLang() {
  try {
    const saved = localStorage.getItem("mp-lang");
    if (saved && I18N[saved]) return saved;
  } catch (_) { /* storage bloqueado */ }
  const nav = (navigator.language || "es").toLowerCase();
  if (nav.startsWith("ca")) return "ca";
  if (nav.startsWith("en")) return "en";
  return "es";
}

function t(key) {
  return (I18N[currentLang] && I18N[currentLang][key]) || I18N.es[key] || key;
}

function applyLang(lang) {
  if (!I18N[lang]) lang = "es";
  currentLang = lang;
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    el.textContent = t(el.getAttribute("data-i18n"));
  });
  document.querySelectorAll("[data-i18n-html]").forEach((el) => {
    el.innerHTML = t(el.getAttribute("data-i18n-html"));
  });
  document.querySelectorAll(".lang-select button").forEach((btn) => {
    btn.classList.toggle("active", btn.getAttribute("data-lang") === lang);
  });
  try { localStorage.setItem("mp-lang", lang); } catch (_) {}
  updateShowcaseCaption();
}

document.querySelectorAll(".lang-select button").forEach((btn) => {
  btn.addEventListener("click", () => applyLang(btn.getAttribute("data-lang")));
});

/* --------------------------- Store links ------------------------------- */
document.querySelectorAll(".ios-link").forEach((link) => { link.href = APPLE_STORE_URL; });

if (/Android/i.test(navigator.userAgent)) {
  document.querySelectorAll(".android-link").forEach((link) => {
    link.classList.remove("secondary");
  });
}

if (location.pathname === "/private-league") {
  const incoming = new URLSearchParams(location.search);
  const safeParams = new URLSearchParams();
  for (const [key, value] of incoming) {
    const normalized = value.trim();
    if (ALLOWED_INVITE_KEYS.has(key) && /^[A-Za-z0-9_-]{4,64}$/.test(normalized)) {
      safeParams.set(key, normalized);
    }
  }
  if ([...safeParams].length > 0) {
    const deepLink = `matchpoint://private-league?${safeParams.toString()}`;
    window.setTimeout(() => { location.assign(deepLink); }, 250);
  }
}

/* --------------------------- Navbar scroll ------------------------------ */
const nav = document.getElementById("nav");
const onScrollNav = () => nav.classList.toggle("scrolled", window.scrollY > 12);
window.addEventListener("scroll", onScrollNav, { passive: true });
onScrollNav();

/* --------------------- Showcase rotatorio (hero) ------------------------ */
const showcaseImgs = Array.from(document.querySelectorAll("#showcase img"));
const showcaseDots = document.getElementById("showcase-dots");
const showcaseCaption = document.getElementById("showcase-caption");
let showcaseIndex = 0;
let showcaseTimer = null;

if (showcaseImgs.length && showcaseDots) {
  showcaseImgs.forEach((_, i) => {
    const dot = document.createElement("i");
    if (i === 0) dot.classList.add("active");
    showcaseDots.appendChild(dot);
  });
}

function updateShowcaseCaption() {
  if (!showcaseImgs.length || !showcaseCaption) return;
  const key = showcaseImgs[showcaseIndex].getAttribute("data-caption");
  showcaseCaption.style.opacity = "0";
  window.setTimeout(() => {
    showcaseCaption.textContent = t(key);
    showcaseCaption.style.opacity = "1";
  }, 200);
}

function stepShowcase() {
  showcaseImgs[showcaseIndex].classList.remove("active");
  showcaseDots.children[showcaseIndex].classList.remove("active");
  showcaseIndex = (showcaseIndex + 1) % showcaseImgs.length;
  showcaseImgs[showcaseIndex].classList.add("active");
  showcaseDots.children[showcaseIndex].classList.add("active");
  updateShowcaseCaption();
}

if (showcaseImgs.length > 1 && !REDUCED_MOTION) {
  showcaseTimer = window.setInterval(stepShowcase, 3400);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      window.clearInterval(showcaseTimer);
    } else {
      showcaseTimer = window.setInterval(stepShowcase, 3400);
    }
  });
}

/* ------------------------- Marquee infinito ----------------------------- */
const marqueeTrack = document.getElementById("marquee-track");
if (marqueeTrack) {
  // Duplicamos el contenido para que translateX(-50%) sea un bucle perfecto.
  marqueeTrack.innerHTML += marqueeTrack.innerHTML;
}

/* --------------------- Barra de progreso + CTA flotante ------------------ */
const scrollProgress = document.getElementById("scroll-progress");
const floatingCta = document.getElementById("floating-cta");
const finalCta = document.querySelector(".cta");
let ctaVisible = false;

if (finalCta) {
  new IntersectionObserver((entries) => {
    ctaVisible = entries[0].isIntersecting;
  }, { threshold: 0.15 }).observe(finalCta);
}

function onScrollChrome() {
  const max = document.documentElement.scrollHeight - window.innerHeight;
  if (scrollProgress && max > 0) {
    scrollProgress.style.width = `${Math.min(100, (window.scrollY / max) * 100)}%`;
  }
  if (floatingCta) {
    floatingCta.classList.toggle("show", window.scrollY > 650 && !ctaVisible);
  }
}
window.addEventListener("scroll", onScrollChrome, { passive: true });
onScrollChrome();

/* ------------------------- Parallax en el tour --------------------------- */
if (!REDUCED_MOTION) {
  const parallaxEls = Array.from(document.querySelectorAll(".tour-shot"));
  let ticking = false;
  function parallax() {
    ticking = false;
    const mid = window.innerHeight / 2;
    parallaxEls.forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.bottom < -100 || r.top > window.innerHeight + 100) return;
      const delta = (r.top + r.height / 2 - mid) * -0.055;
      el.style.transform = `translateY(${delta.toFixed(1)}px)`;
    });
  }
  window.addEventListener("scroll", () => {
    if (!ticking) { ticking = true; requestAnimationFrame(parallax); }
  }, { passive: true });
  parallax();
}

/* ------------------------- Reveal on scroll ----------------------------- */
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add("visible");
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });

document.querySelectorAll(".reveal, .stagger").forEach((el) => revealObserver.observe(el));

/* --------------------------- Contadores --------------------------------- */
const counterObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    const el = entry.target;
    counterObserver.unobserve(el);
    const target = parseInt(el.getAttribute("data-count"), 10);
    if (REDUCED_MOTION) { el.textContent = String(target); return; }
    const start = performance.now();
    const dur = 1200;
    const tick = (now) => {
      const p = Math.min(1, (now - start) / dur);
      el.textContent = String(Math.round(target * (1 - Math.pow(1 - p, 3))));
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}, { threshold: 0.6 });

document.querySelectorAll("[data-count]").forEach((el) => counterObserver.observe(el));

/* --------------------- Tilt 3D en los dispositivos ---------------------- */
if (FINE_POINTER && !REDUCED_MOTION) {
  const stage = document.querySelector(".hero-stage");
  const iphone = document.getElementById("hero-iphone");
  const pixel = document.getElementById("hero-pixel");
  if (stage && iphone) {
    stage.addEventListener("mousemove", (e) => {
      const r = stage.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      iphone.style.transform = `rotateY(${x * 14}deg) rotateX(${-y * 10}deg) translateZ(10px)`;
      if (pixel) pixel.style.transform = `rotate(7deg) rotateY(${x * 9}deg) rotateX(${-y * 6}deg)`;
    });
    stage.addEventListener("mouseleave", () => {
      iphone.style.transform = "";
      if (pixel) pixel.style.transform = "";
    });
    iphone.style.transition = "transform .25s ease-out";
    if (pixel) pixel.style.transition = "transform .25s ease-out";
  }
}

/* ------------------------ Bola que sigue al ratón ----------------------- */
if (FINE_POINTER && !REDUCED_MOTION) {
  const cursorBall = document.querySelector(".cursor-ball");
  let cx = -100, cy = -100, tx = -100, ty = -100;
  document.addEventListener("mousemove", (e) => {
    tx = e.clientX - 13;
    ty = e.clientY - 13;
    document.body.classList.add("has-cursor");
  });
  (function follow() {
    cx += (tx - cx) * 0.18;
    cy += (ty - cy) * 0.18;
    cursorBall.style.transform = `translate(${cx}px, ${cy}px)`;
    requestAnimationFrame(follow);
  })();
}

/* ------------------- Spotlight en tarjetas ------------------------------ */
if (FINE_POINTER) {
  document.querySelectorAll(".card").forEach((card) => {
    card.addEventListener("mousemove", (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty("--mx", `${((e.clientX - r.left) / r.width) * 100}%`);
      card.style.setProperty("--my", `${((e.clientY - r.top) / r.height) * 100}%`);
    });
  });
}

/* ------------------------- Botones magnéticos --------------------------- */
if (FINE_POINTER && !REDUCED_MOTION) {
  document.querySelectorAll(".magnetic").forEach((btn) => {
    btn.addEventListener("mousemove", (e) => {
      const r = btn.getBoundingClientRect();
      const x = e.clientX - r.left - r.width / 2;
      const y = e.clientY - r.top - r.height / 2;
      btn.style.transform = `translate(${x * 0.14}px, ${y * 0.22}px)`;
    });
    btn.addEventListener("mouseleave", () => { btn.style.transform = ""; });
  });
}

/* ---------------- Canvas de fondo: pelotas a la deriva ------------------ */
if (!REDUCED_MOTION) {
  const canvas = document.getElementById("court-canvas");
  if (canvas) {
    const ctx = canvas.getContext("2d");
    let w, h, balls;
    const DPR = Math.min(2, window.devicePixelRatio || 1);

    function resize() {
      w = canvas.width = window.innerWidth * DPR;
      h = canvas.height = window.innerHeight * DPR;
      canvas.style.width = `${window.innerWidth}px`;
      canvas.style.height = `${window.innerHeight}px`;
    }

    function makeBalls() {
      const count = Math.min(14, Math.floor(window.innerWidth / 110));
      balls = Array.from({ length: count }, () => ({
        x: Math.random() * w,
        y: Math.random() * h,
        r: (2 + Math.random() * 3.4) * DPR,
        vx: (Math.random() - 0.5) * 0.22 * DPR,
        vy: (Math.random() - 0.5) * 0.22 * DPR,
        a: 0.14 + Math.random() * 0.22
      }));
    }

    function draw() {
      ctx.clearRect(0, 0, w, h);
      balls.forEach((b) => {
        b.x += b.vx; b.y += b.vy;
        if (b.x < -20) b.x = w + 20; if (b.x > w + 20) b.x = -20;
        if (b.y < -20) b.y = h + 20; if (b.y > h + 20) b.y = -20;
        ctx.beginPath();
        ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(200, 245, 66, ${b.a})`;
        ctx.fill();
      });
      requestAnimationFrame(draw);
    }

    resize(); makeBalls(); draw();
    window.addEventListener("resize", () => { resize(); makeBalls(); });
  }
}

/* ------------------------------ Init ------------------------------------ */
applyLang(resolveInitialLang());
