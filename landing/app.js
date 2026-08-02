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
    "nav.cta": "Compartir",
    "share.text": "Mira MatchPoint: encuentra rivales de tenis a tu nivel, juega partidos y sube en el ranking 🎾",
    "share.toast": "¡Enlace copiado!",

    "hero.eyebrow": "Tu ciudad · Tu nivel · Tu próximo partido",
    "hero.title": "Deja de buscar rival.<br><span class=\"accent\">Empieza a jugar.</span>",
    "hero.lead": "MatchPoint conecta tenistas de tu nivel, organiza partidos con pista y convierte cada resultado validado en un ranking que sí refleja tu juego.",
    "hero.ios": "Descargar para iPhone",
    "hero.android": "Descargar para Android",
    "hero.availability": "Gratis · iPhone y Android · Disponible en Ciudad de Guatemala y Barcelona · Más ciudades muy pronto",
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

    "testers.eyebrow": "Gracias, testers",
    "testers.title": "Testeada por miradas expertas.",
    "testers.sub": "MatchPoint ha crecido gracias a sus early alpha testers: personas de campos muy distintos que la han probado a fondo y nos han dado su opinión sincera. Cada uno la mira desde su oficio.",
    "t.david.role": "Programador",
    "t.david.note": "Programador: la testea con ojo técnico y caza lo que no cuadra en partidos y ranking.",
    "t.guillermo.role": "Marketing",
    "t.guillermo.note": "Del mundo del marketing: opina sobre cómo se percibe el producto y su mensaje.",
    "t.elizabeth.role": "Redactora profesional",
    "t.elizabeth.note": "Redactora profesional: la testea con sensibilidad para el lenguaje y la claridad.",
    "t.mafer.role": "Community manager",
    "t.mafer.note": "Community manager: la prueba pensando en cómo la vivirá la comunidad.",
    "t.rebeca.role": "Marketing leader · RRSS",
    "t.rebeca.note": "Líder de marketing en su empresa y experta en redes sociales: aporta su visión sobre propuesta de valor y alcance.",
    "t.evelin.role": "Gestión de comunidades",
    "t.evelin.note": "Gestiona comunidades: feedback cercano y sin filtro, de usuaria real.",
    "t.kimberly.role": "Diseñadora · Vídeo",
    "t.kimberly.note": "Diseñadora y editora de vídeo: la testea con criterio visual.",
    "t.elcin.role": "Economista · Project manager",
    "t.elcin.note": "Economista y project manager: ha liderado equipos en Chequia; la testea con visión de product owner.",
    "t.stanley.role": "Diseñador · Fotógrafo",
    "t.stanley.note": "Diseñador y fotógrafo: la ha testeado con ojo para el detalle visual.",
    "t.enrique.role": "Ingeniero",
    "t.enrique.note": "Ingeniero: la pone a prueba con mirada ingenieril sobre el rendimiento.",
    "t.kilian.role": "Mundo del tenis",
    "t.kilian.note": "Conoce el tenis por dentro: valida reglas, niveles y experiencia del jugador.",
    "t.arturo.role": "Proyectos europeos",
    "t.arturo.note": "Lidera proyectos europeos: aporta visión estratégica a largo plazo.",
    "t.ligia.role": "Modelo",
    "t.ligia.note": "Una mirada fresca desde fuera del sector tech y del tenis.",

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
      "nav.cta": "Share",
      "share.text": "Check out MatchPoint: find tennis rivals at your level, play matches and climb the ranking 🎾",
      "share.toast": "Link copied!",
      "hero.eyebrow": "Your city · Your level · Your next match",
      "hero.title": "Stop searching for an opponent.<br><span class=\"accent\">Start playing.</span>",
      "hero.lead": "MatchPoint connects tennis players at your level, organizes matches with a court, and turns every validated result into a ranking that truly reflects your game.",
      "hero.ios": "Download for iPhone",
      "hero.android": "Download for Android",
      "hero.availability": "Free · iPhone and Android · Available in Guatemala City and Barcelona · More cities coming soon",
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
      "testers.eyebrow": "Thanks, testers",
      "testers.title": "Tested by expert eyes.",
      "testers.sub": "MatchPoint grew thanks to its early alpha testers: people from very different fields who put it through its paces and gave us their honest opinion. Each one looks at it through their own craft.",
      "t.david.role": "Software developer",
      "t.david.note": "A developer: tests the app with a technical eye and hunts whatever doesn't add up in matches and ranking.",
      "t.guillermo.role": "Marketing",
      "t.guillermo.note": "From the marketing world: weighs in on how the product and its message are perceived.",
      "t.elizabeth.role": "Professional copywriter",
      "t.elizabeth.note": "A professional copywriter: tests it with a feel for language and clarity.",
      "t.mafer.role": "Community manager",
      "t.mafer.note": "Community manager: tries it thinking about how the community will live it.",
      "t.rebeca.role": "Marketing leader · Social media",
      "t.rebeca.note": "Marketing leader at her company and social media expert: brings her take on value proposition and reach.",
      "t.evelin.role": "Community management",
      "t.evelin.note": "Manages communities: close, unfiltered feedback from a real user.",
      "t.kimberly.role": "Designer · Video",
      "t.kimberly.note": "Designer and video editor: tests it with visual judgment.",
      "t.elcin.role": "Economist · Project manager",
      "t.elcin.note": "Economist and project manager: has led teams in Czechia; tests it with a product owner's vision.",
      "t.stanley.role": "Designer · Photographer",
      "t.stanley.note": "Designer and photographer: tested it with an eye for visual detail.",
      "t.enrique.role": "Engineer",
      "t.enrique.note": "An engineer: puts it through its paces with an engineer's eye on performance.",
      "t.kilian.role": "Tennis world",
      "t.kilian.note": "Knows tennis inside out: validates rules, levels, and the player experience.",
      "t.arturo.role": "European projects",
      "t.arturo.note": "Leads European projects: brings long-term strategic vision.",
      "t.ligia.role": "Model",
      "t.ligia.note": "A fresh perspective from outside both tech and tennis.",
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
      "nav.cta": "Comparteix",
      "share.text": "Mira MatchPoint: troba rivals de tennis al teu nivell, juga partits i puja al rànquing 🎾",
      "share.toast": "Enllaç copiat!",
      "hero.eyebrow": "La teva ciutat · El teu nivell · El teu pròxim partit",
      "hero.title": "Deixa de buscar rival.<br><span class=\"accent\">Comença a jugar.</span>",
      "hero.lead": "MatchPoint connecta tennistes del teu nivell, organitza partits amb pista i converteix cada resultat validat en un rànquing que reflecteix de debò el teu joc.",
      "hero.ios": "Descarrega per a iPhone",
      "hero.android": "Descarrega per a Android",
      "hero.availability": "Gratis · iPhone i Android · Disponible a Ciutat de Guatemala i Barcelona · Més ciutats molt aviat",
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
      "testers.eyebrow": "Gràcies, testers",
      "testers.title": "Testada per mirades expertes.",
      "testers.sub": "MatchPoint ha crescut gràcies als seus early alpha testers: persones de camps molt diferents que l’han provada a fons i ens han donat la seva opinió sincera. Cadascú la mira des del seu ofici.",
      "t.david.role": "Programador",
      "t.david.note": "Programador: la testeja amb ull tècnic i caça el que no quadra en partits i rànquing.",
      "t.guillermo.role": "Màrqueting",
      "t.guillermo.note": "Del món del màrqueting: opina sobre com es percep el producte i el seu missatge.",
      "t.elizabeth.role": "Redactora professional",
      "t.elizabeth.note": "Redactora professional: la testeja amb sensibilitat per al llenguatge i la claredat.",
      "t.mafer.role": "Community manager",
      "t.mafer.note": "Community manager: la prova pensant en com la viurà la comunitat.",
      "t.rebeca.role": "Líder de màrqueting · XXSS",
      "t.rebeca.note": "Líder de màrqueting a la seva empresa i experta en xarxes socials: aporta la seva visió sobre proposta de valor i abast.",
      "t.evelin.role": "Gestió de comunitats",
      "t.evelin.note": "Gestiona comunitats: feedback proper i sense filtre, d’usuària real.",
      "t.kimberly.role": "Dissenyadora · Vídeo",
      "t.kimberly.note": "Dissenyadora i editora de vídeo: la testeja amb criteri visual.",
      "t.elcin.role": "Economista · Project manager",
      "t.elcin.note": "Economista i project manager: ha liderat equips a Txèquia; la testeja amb visió de product owner.",
      "t.stanley.role": "Dissenyador · Fotògraf",
      "t.stanley.note": "Dissenyador i fotògraf: l’ha testada amb ull per al detall visual.",
      "t.enrique.role": "Enginyer",
      "t.enrique.note": "Enginyer: la posa a prova amb mirada enginyeril sobre el rendiment.",
      "t.kilian.role": "Món del tennis",
      "t.kilian.note": "Coneix el tennis per dins: valida regles, nivells i experiència del jugador.",
      "t.arturo.role": "Projectes europeus",
      "t.arturo.note": "Lidera projectes europeus: aporta visió estratègica a llarg termini.",
      "t.ligia.role": "Model",
      "t.ligia.note": "Una mirada fresca des de fora del sector tech i del tennis.",
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
  },
  ko: {
      "nav.how": "이용 방법",
      "nav.tour": "앱 둘러보기",
      "nav.leagues": "리그",
      "nav.about": "소개",
      "nav.faq": "자주 묻는 질문",
      "nav.cta": "공유하기",
      "share.text": "MatchPoint를 확인해 보세요: 같은 수준의 테니스 상대를 찾고, 시합을 즐기고, 랭킹을 올려보세요 🎾",
      "share.toast": "링크가 복사되었습니다!",
      "hero.eyebrow": "내 도시 · 내 실력 · 다음 시합",
      "hero.title": "상대를 찾는 건 그만.<br><span class=\"accent\">바로 플레이하세요.</span>",
      "hero.lead": "MatchPoint는 같은 실력의 테니스 선수들을 연결하고, 코트가 잡힌 시합을 주선하며, 검증된 모든 결과를 당신의 진짜 실력을 반영하는 랭킹으로 바꿔 줍니다.",
      "hero.ios": "iPhone으로 다운로드",
      "hero.android": "Android로 다운로드",
      "hero.availability": "무료 · iPhone 및 Android · 과테말라 시티와 바르셀로나에서 사용 가능 · 더 많은 도시 곧 오픈",
      "hero.proof1": "✓ 잘 맞는 상대",
      "hero.proof2": "✓ 코트가 잡힌 시합",
      "hero.proof3": "✓ 검증된 랭킹",
      "hero.scroll": "스크롤",
      "float.cta": "무료 다운로드",
      "showcase.cap1": "앱을 열면 바로 다음 시합",
      "showcase.cap2": "내 실력의 상대, 진짜로 필터링",
      "showcase.cap3": "채팅으로 협상 없이 약속",
      "showcase.cap4": "코트에서 쟁취하는 랭킹",
      "showcase.cap5": "내 플레이, 상대가 직접 평가",
      "proof.city": "다음은 당신의 도시",
      "proof.stat1": "% 무료, 숨은 조건 없이",
      "proof.stat2": "명의 선수가 모든 결과를 확인",
      "proof.stat3": "개의 스트로크를 상대가 평가",
      "proof.stat4": "번의 터치로 상대 찾기",
      "feat.eyebrow": "클럽 전체를 주머니에",
      "feat.title": "끝없는 단톡방은 그만.<br><span class=\"accent\">코트 위에서 더 많은 시간.</span>",
      "feat.sub": "MatchPoint가 어려운 부분을 정리해 드립니다. 당신은 상대, 코트, 시간만 고르면 됩니다.",
      "feat.c1t": "잘 맞는 상대",
      "feat.c1p": "도시, 실력, 가능 시간, 종목별로 가까운 테니스 선수를 만나보세요. 잡음은 줄이고, 시합의 질은 높이세요.",
      "feat.c2t": "열린 시합",
      "feat.c2p": "이미 코트를 잡으셨나요? 예약을 올리고 단톡방을 어수선하게 만들지 않고도 잘 맞는 상대를 찾아보세요.",
      "feat.c3t": "서로 확인하는 점수",
      "feat.c3p": "한 선수가 점수를 기록하면 상대가 확인합니다. 랭킹은 진짜 시합으로 쌓입니다.",
      "feat.c4t": "클럽과 코치",
      "feat.c4p": "자주 가는 클럽을 저장하고, 새로운 코트를 발견하고, 가까이에서 훈련하는 코치를 찾아보세요.",
      "feat.c5t": "내 Match Buddy",
      "feat.c5p": "앱 안에서 궁금증을 해결하고, 시합을 준비하고, 다음 단계를 발견하세요.",
      "feat.c6t": "내 도시 우선",
      "feat.c6p": "내 동네에서 알찬 기회를 찾고, 개인정보는 내 손 안에 두세요.",
      "tour.eyebrow": "앱 둘러보기",
      "tour.title": "MatchPoint에서의 시합,<br><span class=\"accent\">이렇게 진행됩니다.</span>",
      "tour.sub": "앱을 여는 순간부터 랭킹을 오르기까지, 다섯 단계면 됩니다. 단톡방도 없고, 점수 다툼도 없습니다.",
      "tour.s1t": "앱을 열면 바로 다음 시합",
      "tour.s1p": "들어서자마자 일정에 무엇이 있는지, 어느 클럽에서, 몇 시에 있는지 보입니다. 거기서 한 번의 터치로 상대 찾기, 예약, 내 순위 확인까지 이동할 수 있습니다.",
      "tour.s2t": "아무나가 아닌, 내 실력의 상대",
      "tour.s2p": "도시, 실력, 나이, 가능 시간으로 필터링하세요. 모든 프로필에는 평가와 기술 메모가 함께 제공되니, 만나기 전에 어떤 경기를 하게 될지 알 수 있습니다.",
      "tour.s3t": "채팅으로 협상 없이 약속",
      "tour.s3p": "내 예약을 올리거나 다른 사람의 예약에 자리를 요청하세요. 일정, 코트, 확인은 앱이 처리합니다. 당신은 \"좋아요\"만 말하면 됩니다.",
      "tour.s4t": "둘 다 서명하는 결과",
      "tour.s4p": "한 명이 점수를 기록하고 상대가 확인합니다. 그래야만 순위에 반영되니, 랭킹은 진짜 시합을 담습니다.",
      "tour.s5t": "내 게임, 나를 친 상대의 평가",
      "tour.s5p": "시합이 끝나면 서로의 서브, 포핸드, 백핸드, 발리, 일관성을 평가합니다. 시간이 지나면 프로필은 내가 말하는 것이 아니라 내가 증명하는 것이 됩니다.",
      "league.boardLabel": "공개 리그 · 단식",
      "league.w8": "8승",
      "league.w7": "7승",
      "league.w5": "5승",
      "league.you": "나<br><small>5승</small>",
      "league.pts": "점",
      "league.eyebrow": "당신에게 꼭 맞는 경기",
      "league.title": "코트 위에서 쟁취하는<br><span class=\"accent\">랭킹.</span>",
      "league.lead": "초보부터 A등급까지. 자신의 디비전에 가입해 둘 다 가능한 시간에 시합을 하고, 검증된 매 경기가 투명한 순위표를 채웁니다.",
      "league.st1": "실력과 도시를 선택하세요.",
      "league.st2": "지역 리그에 참여하세요.",
      "league.st3": "시합을 하고 점수를 기록하세요.",
      "league.st4": "상대가 확인하면 점수를 받습니다.",
      "vs.eyebrow": "전과 후",
      "vs.title": "WhatsApp 그룹<br><span class=\"accent\">vs MatchPoint.</span>",
      "vs.oldT": "늘 하던 그 혼돈",
      "vs.old1": "화요일에 한 번 잡으려면 237개의 메시지",
      "vs.old2": "내 실력이 아닌 상대들",
      "vs.old3": "점수를 아무도 똑같이 기억하지 못함",
      "vs.old4": "내 발전, 어디에도 기록되지 않음",
      "vs.newT": "MatchPoint와 함께라면",
      "vs.new1": "한 번의 터치: 상대, 코트, 시간",
      "vs.new2": "실제 실력으로 필터링된 상대",
      "vs.new3": "양쪽 모두 확인한 점수",
      "vs.new4": "시합마다 쌓이는 기록",
      "about.eyebrow": "진짜 필요에서 출발한 제품",
      "about.title": "테니스 플레이어가 만든,<br><span class=\"accent\">더 많이 치기 위한 앱.</span>",
      "about.lead": "MatchPoint는 회의실에서 태어나지 않았습니다. 잘 맞는 상대를 찾고, 시합을 조직하며, 끝없는 단톡방에 의존하지 않고 경쟁하는, 아주 구체적인 고민에서 출발했습니다.",
      "about.p1": "공동 창업자인 Cristian Gonzalez Salvatierra는 그 필요를 직접 겪었습니다. 그의 경험과 요청, 그리고 선수에게 진짜 필요한 것들과의 직접적인 만남이 아이디어의 시작이 되었고, 지금도 제품의 발전을 이끌고 있습니다.",
      "about.p2": "창업자이자 개발자인 Pedro Caparrós는 그 비전을 MatchPoint로 만들었습니다. 디자인, 사용성, 개발을 처음부터 끝까지 직접 진행하며, 코트 안팎에서 진짜 필요한 모든 것을 단순하고 유용한 경험으로 바꾸어 왔습니다.",
      "about.pedroRole": "창업자 및 개발자",
      "about.pedroDesc": "디자인, 사용성, 개발 — 아이디어부터 앱까지.",
      "about.crisRole": "공동 창업자",
      "about.crisDesc": "아이디어의 시작, 선수의 필요, 제품 비전.",
      "about.quote": "“우리가 정말로 더 치고 싶어서, 마땅히 없던 것을 만들었습니다.”",
      "testers.eyebrow": "테스터 여러분 감사합니다",
      "testers.title": "전문가들의 시선으로 테스트되었습니다.",
      "testers.sub": "MatchPoint는 다양한 분야의 얼리 알파 테스터 덕분에 성장해 왔습니다. 다양한 분들이 직접 써 보고 솔직한 의견을 주셨습니다. 각자 자기 직군의 눈으로 바라봅니다.",
      "t.david.role": "프로그래머",
      "t.david.note": "프로그래머: 기술적인 시선으로 테스트하며, 시합과 랭킹에서 어긋나는 부분을 잡아냅니다.",
      "t.guillermo.role": "마케팅",
      "t.guillermo.note": "마케팅 현장에서: 제품과 메시지가 어떻게 받아들여지는지에 대한 견해를 나눕니다.",
      "t.elizabeth.role": "전문 카피라이터",
      "t.elizabeth.note": "전문 카피라이터: 언어와 명확성에 대한 감각으로 테스트합니다.",
      "t.mafer.role": "커뮤니티 매니저",
      "t.mafer.note": "커뮤니티 매니저: 커뮤니티가 이 앱을 어떻게 경험할지를 떠올리며 테스트합니다.",
      "t.rebeca.role": "디지털 마케팅",
      "t.rebeca.note": "디지털 마케팅 전문가: 가치 제안과 도달 범위에 대한 시각을 더합니다.",
      "t.evelin.role": "커뮤니티 운영",
      "t.evelin.note": "커뮤니티 운영: 실제 사용자의 솔직하고 거침없는 피드백을 전합니다.",
      "t.kimberly.role": "디자이너 · 영상",
      "t.kimberly.note": "디자이너이자 영상 에디터: 시각적 기준으로 테스트합니다.",
      "t.elcin.role": "경제학자 · 프로젝트 매니저",
      "t.elcin.note": "경제학자이자 프로젝트 매니저: 체코에서 여러 팀을 이끌었으며, 프로덕트 오너의 시각으로 테스트해 주었어요.",
      "t.stanley.role": "디자이너 · 사진작가",
      "t.stanley.note": "디자이너이자 사진작가: 시각적 디테일에 대한 눈으로 테스트했습니다.",
      "t.enrique.role": "엔지니어",
      "t.enrique.note": "엔지니어: 성능에 대한 공학적 시선으로 검증합니다.",
      "t.kilian.role": "테니스 업계",
      "t.kilian.note": "테니스를 속속들이 아는 사람: 규칙, 레벨, 선수 경험을 검증합니다.",
      "t.arturo.role": "유럽 프로젝트",
      "t.arturo.note": "유럽 프로젝트를 이끄는 분: 장기적인 전략적 시각을 더합니다.",
      "t.ligia.role": "모델",
      "t.ligia.note": "테크와 테니스 모두 바깥에서 바라보는 신선한 시선.",
      "priv.eyebrow": "안심하고 플레이하세요",
      "priv.title": "당신의 경기는 공개됩니다.<br><span class=\"accent\">당신의 데이터는 공개되지 않습니다.</span>",
      "priv.sub": "플레이에 꼭 필요한 최소한만 요청하며, 익명 통계를 활용해 앱을 빠르고 안정적으로, 매주 개선합니다.",
      "priv.k1": "최소",
      "priv.c1t": "꼭 필요한 것만",
      "priv.c1p": "선수 프로필, 도시, 시합 기록. 그 이상 없습니다. 상대를 찾고 기록을 유지하는 데 필요한 만큼만요.",
      "priv.k2": "개선",
      "priv.c2t": "익명 통계",
      "priv.c2p": "익명으로 집계된 사용 데이터는 문제를 발견하고 앱을 건강하게 유지하는 데 도움이 됩니다. 우리는 당신이 누구인지 절대 알지 못합니다.",
      "priv.k3": "통제권",
      "priv.c3t": "통제권은 당신에게",
      "priv.c3p": "앱 안에서 직접 계정과 데이터를 삭제할 수 있습니다. 원할 때, 지원팀에 연락하거나 기다릴 필요 없이.",
      "price.eyebrow": "숨은 조건 없이",
      "price.title": "무료.<br><span class=\"accent\">진짜로.</span>",
      "price.sub": "더 많이, 더 잘 치는 데 필요한 모든 것이 첫날부터 포함되어 있습니다.",
      "price.plan": "플레이어",
      "price.forever": "/ 영원히",
      "price.f1": "실력과 도시별로 잘 맞는 상대",
      "price.f2": "열린 시합과 코트가 잡힌 예약",
      "price.f3": "선수들 사이에서 검증된 랭킹",
      "price.f4": "실제 평가가 담긴 기술 프로필",
      "price.f5": "디비전별 지역 리그",
      "price.cta": "지금 시작하기",
      "faq.eyebrow": "코트에 나서기 전에",
      "faq.title": "꼭 알아두고 싶은 것.",
      "faq.sub": "첫 시합부터 모든 것이 명확합니다.",
      "faq.q1": "MatchPoint는 누구를 위한 앱인가요?",
      "faq.a1": "더 많이 치고 더 잘 조직하고 싶은 테니스 선수들을 위한 앱입니다. 처음 시작하는 분부터 실력 향상을 위해 경쟁하는 분까지 모두를 위해.",
      "faq.q2": "얼마나 하나요?",
      "faq.a2": "한 푼도 없습니다. MatchPoint는 무료입니다. 상대 찾기, 시합 주선, 랭킹 경쟁까지 모두 무료입니다.",
      "faq.q3": "어떻게 상대를 찾나요?",
      "faq.a3": "도시, 실력, 종목, 가능 시간을 입력하세요. MatchPoint가 잘 맞는 프로필과 시합을 보여주니, 누구와 칠지 고를 수 있습니다.",
      "faq.q4": "누가 결과를 검증하나요?",
      "faq.a4": "상대가 점수를 확인합니다. 그래서 랭킹은 진짜 시합으로 채워지고, 스스로 매긴 점수는 반영되지 않습니다.",
      "faq.q5": "클럽에 가입해야 하나요?",
      "faq.a5": "아닙니다. 내 동네의 선수들을 발견하고, 자주 가는 클럽을 저장하고, 가장 잘 맞는 시합을 직접 주선할 수 있습니다.",
      "faq.q6": "내 도시에 선수가 없다면요?",
      "faq.a6": "커뮤니티는 매주 성장하고 있습니다. 링크로 같은 코트의 동료들을 초대하고, 내 도시에서 랭킹을 여는 첫 번째 사람이 되어 보세요.",
      "cta.eyebrow": "플레이할 준비 완료",
      "cta.title": "내 도시 리그에서<br><span class=\"accent\">나의 기록을 시작하세요.</span>",
      "cta.sub": "모든 시합이 의미 있습니다. 더 다양한 상대를 만나고, 이번 주에 첫 시합을 즐기며, 랭킹 위에 내 이름을 새기기 시작하세요.",
      "cta.ios": " iPhone",
      "cta.android": "▶ Android",
      "cta.note": "무료 · 카드 필요 없음 · 프로필 생성은 단 2분",
      "footer.copy": "© 2026 MatchPoint Tennis · 테니스 플레이어가, 테니스 플레이어를 위해 만들었습니다",
      "footer.privacy": "개인정보 처리방침",
      "footer.terms": "이용약관",
      "footer.support": "지원",
      "footer.delete": "계정 삭제"
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
  if (nav.startsWith("ko")) return "ko";
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

/* --------------------- Raqueta + luz que sigue al dedo ------------------- */
const racket = document.getElementById("racket");
const ambient = document.getElementById("touch-ambient");
const racketState = { x: -200, y: -200, tx: -200, ty: -200, angle: -20, visible: false };
let ambientTimer = null;

function pointTo(x, y) {
  racketState.tx = x;
  racketState.ty = y;
  if (!racketState.visible) {
    racketState.visible = true;
    document.body.classList.add("has-racket");
  }
  if (ambient) {
    ambient.style.setProperty("--ax", `${x}px`);
    ambient.style.setProperty("--ay", `${y}px`);
    ambient.classList.add("on");
    window.clearTimeout(ambientTimer);
    ambientTimer = window.setTimeout(() => ambient.classList.remove("on"), 1400);
  }
}

if (!REDUCED_MOTION) {
  if (FINE_POINTER) {
    document.addEventListener("mousemove", (e) => pointTo(e.clientX, e.clientY), { passive: true });
  }
  document.addEventListener("touchmove", (e) => {
    const t = e.touches[0];
    if (t) pointTo(t.clientX, t.clientY);
  }, { passive: true });
  document.addEventListener("touchend", () => {
    racketState.visible = false;
    document.body.classList.remove("has-racket");
  }, { passive: true });

  (function followRacket() {
    const px = racketState.x;
    racketState.x += (racketState.tx - racketState.x) * 0.2;
    racketState.y += (racketState.ty - racketState.y) * 0.2;
    const vx = racketState.x - px;
    const targetAngle = -20 + Math.max(-35, Math.min(35, vx * 2.4));
    racketState.angle += (targetAngle - racketState.angle) * 0.18;
    if (racket) {
      racket.style.transform = `translate(${racketState.x - 37}px, ${racketState.y - 37}px) rotate(${racketState.angle}deg)`;
    }
    requestAnimationFrame(followRacket);
  })();
}

/* ------------------------- Slider del tour ------------------------------- */
const tourTrack = document.getElementById("tour-track");
if (tourTrack) {
  const slides = Array.from(tourTrack.children);
  const dotsBox = document.getElementById("tour-dots");
  const currentSlide = () => Math.round(tourTrack.scrollLeft / tourTrack.clientWidth);
  const goTo = (i) => {
    const clamped = Math.max(0, Math.min(slides.length - 1, i));
    tourTrack.scrollTo({ left: clamped * tourTrack.clientWidth, behavior: "smooth" });
  };

  slides.forEach((_, i) => {
    const b = document.createElement("button");
    b.type = "button";
    b.setAttribute("aria-label", `Paso ${i + 1}`);
    if (i === 0) b.classList.add("active");
    b.addEventListener("click", () => goTo(i));
    dotsBox.appendChild(b);
  });
  document.getElementById("tour-prev").addEventListener("click", () => goTo(currentSlide() - 1));
  document.getElementById("tour-next").addEventListener("click", () => goTo(currentSlide() + 1));

  function paintSlides() {
    const center = tourTrack.scrollLeft + tourTrack.clientWidth / 2;
    let active = 0, best = Infinity;
    slides.forEach((s, i) => {
      const sc = s.offsetLeft + s.offsetWidth / 2;
      const d = Math.abs(center - sc);
      const ratio = Math.min(1, d / tourTrack.clientWidth);
      s.style.transform = `scale(${1 - ratio * 0.07})`;
      s.style.opacity = String(1 - ratio * 0.55);
      if (d < best) { best = d; active = i; }
    });
    Array.from(dotsBox.children).forEach((d, i) => d.classList.toggle("active", i === active));
  }
  let sTick = false;
  tourTrack.addEventListener("scroll", () => {
    if (!sTick) {
      sTick = true;
      requestAnimationFrame(() => { sTick = false; paintSlides(); });
    }
  }, { passive: true });
  window.addEventListener("resize", paintSlides);
  paintSlides();

  // Arrastre con ratón (en táctil el swipe es nativo)
  let dragX = 0, dragL = 0, dragging = false;
  tourTrack.addEventListener("pointerdown", (e) => {
    if (e.pointerType !== "mouse") return;
    dragging = true;
    dragX = e.clientX;
    dragL = tourTrack.scrollLeft;
    tourTrack.classList.add("dragging");
  });
  window.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    tourTrack.scrollLeft = dragL - (e.clientX - dragX);
  });
  window.addEventListener("pointerup", () => {
    if (!dragging) return;
    dragging = false;
    tourTrack.classList.remove("dragging");
    goTo(currentSlide());
  });
}

/* ------------------- Pelota del CTA con física arcade -------------------- */
const ctaSection = document.querySelector(".cta");
const ctaBall = document.getElementById("cta-ball");
if (ctaSection && ctaBall && !REDUCED_MOTION) {
  const R = 19;
  let bx = 70, by = 50, vx = 2.4, vy = 1.8, rot = 0, running = false;

  new IntersectionObserver((entries) => {
    const vis = entries[0].isIntersecting;
    if (vis && !running) {
      running = true;
      requestAnimationFrame(stepBall);
    } else if (!vis) {
      running = false;
    }
  }, { threshold: 0.05 }).observe(ctaSection);

  function stepBall() {
    if (!running) return;
    const w = ctaSection.clientWidth;
    const h = ctaSection.clientHeight;
    const cRect = ctaSection.getBoundingClientRect();

    bx += vx;
    by += vy;

    // Rebote en los bordes de la tarjeta
    if (bx < 0) { bx = 0; vx = Math.abs(vx); }
    if (bx > w - R * 2) { bx = w - R * 2; vx = -Math.abs(vx); }
    if (by < 0) { by = 0; vy = Math.abs(vy); }
    if (by > h - R * 2) { by = h - R * 2; vy = -Math.abs(vy); }

    // Golpe de raqueta (cursor o dedo)
    if (racketState.visible) {
      const rx = racketState.x - cRect.left;
      const ry = racketState.y - cRect.top;
      const dx = (bx + R) - rx;
      const dy = (by + R) - ry;
      const dist = Math.hypot(dx, dy);
      if (dist < R + 46 && dist > 0.01) {
        const nx = dx / dist;
        const ny = dy / dist;
        const speed = Math.min(9, Math.hypot(vx, vy) + 1.7);
        vx = nx * speed;
        vy = ny * speed;
        bx = rx + nx * (R + 47) - R;
        by = ry + ny * (R + 47) - R;
      }
    }

    // Rozamiento suave para que no se acelere sin fin
    const sp = Math.hypot(vx, vy);
    if (sp > 3.2) { vx *= 0.995; vy *= 0.995; }

    rot += sp * 1.4;
    ctaBall.style.transform = `translate(${bx}px, ${by}px) rotate(${rot}deg)`;
    requestAnimationFrame(stepBall);
  }
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

/* ------------------------------ Share ------------------------------------ */
(function initShare() {
  const btn = document.getElementById("share-btn");
  if (!btn) return;
  const SHARE_URL = "https://tennisleagueapp.win";

  function toast(msg) {
    let el = document.querySelector(".share-toast");
    if (!el) {
      el = document.createElement("div");
      el.className = "share-toast";
      el.setAttribute("role", "status");
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add("visible");
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.remove("visible"), 2200);
  }

  btn.addEventListener("click", async () => {
    const text = t("share.text");
    // Compartir con imagen (Instagram y apps que aceptan archivos)
    try {
      const resp = await fetch("/share-card.png");
      if (resp.ok) {
        const blob = await resp.blob();
        const file = new File([blob], "matchpoint-tennis.png", { type: "image/png" });
        const payload = { files: [file], text: `${text} ${SHARE_URL}` };
        if (navigator.canShare && navigator.canShare(payload)) {
          await navigator.share(payload);
          return;
        }
      }
    } catch (e) {
      if (e && e.name === "AbortError") return;
    }
    // Compartir solo enlace (WhatsApp y resto)
    if (navigator.share) {
      try {
        await navigator.share({ title: "MatchPoint", text, url: SHARE_URL });
        return;
      } catch (e) {
        if (e && e.name === "AbortError") return;
      }
    }
    // Fallback: copiar enlace
    try {
      await navigator.clipboard.writeText(SHARE_URL);
    } catch (e) {
      const tmp = document.createElement("textarea");
      tmp.value = SHARE_URL;
      document.body.appendChild(tmp);
      tmp.select();
      document.execCommand("copy");
      tmp.remove();
    }
    toast(t("share.toast"));
  });
})();
applyLang(resolveInitialLang());
