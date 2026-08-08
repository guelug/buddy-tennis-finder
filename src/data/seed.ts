import { Club, Player } from "../types";

export const countries = ["Guatemala", "El Salvador", "España"] as const;

export type Country = (typeof countries)[number];

/**
 * Países disponibles para SELECCIÓN en el onboarding. El lanzamiento inicial es
 * solo Guatemala; el resto de países (`countries`) permanece en el modelo de
 * datos para cuando abramos esos mercados. Para habilitar uno nuevo, añádelo
 * aquí y asegúrate de que tenga ciudades en `CITIES_BY_COUNTRY` y clubes.
 */
export const selectableCountries = ["Guatemala", "España"] as const satisfies readonly Country[];

/**
 * Comunidades / regiones dentro de cada país. Sirven para dos cosas: agrupar
 * las ciudades en el onboarding y permitir buscar rival en TODA la región en
 * vez de solo en el propio municipio.
 *
 * Eso último importa más de lo que parece: cada ciudad por separado parte la
 * comunidad en trozos diminutos, y en el área metropolitana de Barcelona la
 * gente se cruza media provincia para jugar. Con la región, quien vive en
 * Pallejà puede ver los partidos de Barcelona sin que su ciudad deje de ser
 * Pallejà.
 */
export const REGIONS_BY_COUNTRY: Record<Country, string[]> = {
  Guatemala: ["Guatemala"],
  "El Salvador": ["San Salvador"],
  España: ["Catalunya", "Aragón"]
};

/** Ciudades con pistas dadas de alta, agrupadas por región. */
export const CITIES_BY_REGION: Record<string, string[]> = {
  // Guatemala
  Guatemala: ["Ciudad de Guatemala"],
  "San Salvador": ["San Salvador"],
  // España · Catalunya (Barcelona y área metropolitana)
  Catalunya: ["Barcelona", "Castelldefels", "Pallejà"],
  // España · Aragón (Pirineo, Valle de Tena)
  Aragón: ["Formigal"]
};

/** Región a la que pertenece cada ciudad. */
export const REGION_BY_CITY: Record<string, string> = Object.entries(CITIES_BY_REGION)
  .reduce<Record<string, string>>((acc, [region, cities]) => {
    cities.forEach((city) => { acc[city] = region; });
    return acc;
  }, {});

export const CITIES_BY_COUNTRY: Record<Country, string[]> = {
  Guatemala: REGIONS_BY_COUNTRY.Guatemala.flatMap((r) => CITIES_BY_REGION[r] ?? []),
  "El Salvador": REGIONS_BY_COUNTRY["El Salvador"].flatMap((r) => CITIES_BY_REGION[r] ?? []),
  España: REGIONS_BY_COUNTRY["España"].flatMap((r) => CITIES_BY_REGION[r] ?? [])
};


/**
 * Ciudades a consultar al buscar rival. Con `wholeRegion` se abre a toda la
 * comunidad; si no, solo el municipio. Devuelve siempre al menos la ciudad
 * de origen para no dejar la consulta vacía.
 *
 * Se usa en consultas `where("city","in",...)`, que en Firestore admiten
 * hasta 30 valores: por eso se recorta, y de ahí que convenga no inflar una
 * región con municipios sin pistas.
 */
export function citiesForSearch(city: string | undefined, wholeRegion: boolean): string[] {
  if (!city) return [];
  if (!wholeRegion) return [city];
  const region = REGION_BY_CITY[city];
  const cities = region ? CITIES_BY_REGION[region] ?? [] : [];
  const unique = Array.from(new Set([city, ...cities]));
  return unique.slice(0, 30);
}

export const clubs: Club[] = [
  // Guatemala · Ciudad de Guatemala
  {
    id: "club-alemán-gt",
    name: "Club Alemán",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "2a Avenida 9-00, Zona 15, Ciudad de Guatemala",
    latitude: 14.5914,
    longitude: -90.5133,
    courts: 6
  },
  {
    id: "club-hercules-gt",
    name: "Club Hércules",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "12 Calle 1-25, Zona 10, Ciudad de Guatemala",
    latitude: 14.6215,
    longitude: -90.5248,
    courts: 6
  },
  {
    id: "club-sporta-gt",
    name: "Sporta Cayalá",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Bulevar Rafael Landívar 10-05, Zona 16, Cayalá",
    latitude: 14.6106,
    longitude: -90.4847,
    courts: 5
  },
  {
    id: "federacion-zona-5-gt",
    name: "Federación Nacional de Tenis · Zona 5",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Calle Mateo Flores y 10a Avenida, Ciudad de los Deportes, Zona 5",
    latitude: 14.6284,
    longitude: -90.5187,
    courts: 6
  },
  {
    id: "federacion-zona-15-gt",
    name: "Federación Nacional de Tenis · Zona 15",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Zona 15, Ciudad de Guatemala",
    latitude: 14.5948,
    longitude: -90.4872,
    courts: 6
  },
  {
    id: "campo-marte-gt",
    name: "Campo Marte · Canchas públicas",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "15 Avenida y 32 Calle final, Zona 5",
    latitude: 14.6248,
    longitude: -90.5044,
    courts: 2
  },
  {
    id: "club-aurora-gt",
    name: "Club de Tenis Aurora",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Zona 5, Ciudad de Guatemala",
    latitude: 14.6267,
    longitude: -90.5162,
    courts: 4
  },
  {
    id: "club-delfines-gt",
    name: "Club Delfines",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Zona 14, Ciudad de Guatemala",
    latitude: 14.5762,
    longitude: -90.5114,
    courts: 4
  },
  {
    id: "club-la-villa-gt",
    name: "Club La Villa",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "20 Avenida 8-64, Zona 14",
    latitude: 14.5796,
    longitude: -90.5031,
    courts: 4
  },
  {
    id: "club-majadas-gt",
    name: "Club Majadas",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Zona 11, Ciudad de Guatemala",
    latitude: 14.6207,
    longitude: -90.5536,
    courts: 3
  },
  {
    id: "club-los-arcos-gt",
    name: "Club Deportivo Los Arcos",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "1a Calle, Zona 14, Ciudad de Guatemala",
    latitude: 14.5842,
    longitude: -90.5135,
    courts: 4
  },
  {
    id: "usac-tenis-gt",
    name: "USAC · Canchas de tenis",
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    address: "Campus Central USAC, Zona 12",
    latitude: 14.5869,
    longitude: -90.5525,
    courts: 4
  },
  // El Salvador · San Salvador
  {
    id: "club-cosmos-sv",
    name: "Club Cosmos",
    city: "San Salvador",
    country: "El Salvador",
    address: "Bulevar Los Próceres, San Salvador",
    latitude: 13.7081,
    longitude: -89.2159,
    courts: 4
  },
  {
    id: "estadio-nacional-sv",
    name: "Estadio Nacional · Canchas de tenis",
    city: "San Salvador",
    country: "El Salvador",
    address: "Avenida Las Naciones Unidas, San Salvador",
    latitude: 13.6914,
    longitude: -89.2227,
    courts: 4
  },
  {
    id: "olimpico-tenis-sv",
    name: "Complejo Olímpico de Tenis",
    city: "San Salvador",
    country: "El Salvador",
    address: "Bulevar Luis Poma, Antiguo Cuscatlán",
    latitude: 13.6728,
    longitude: -89.2486,
    courts: 6
  },
  // España · Barcelona
  {
    id: "rctb-1899-es",
    name: "Reial Club de Tennis Barcelona-1899",
    city: "Barcelona",
    country: "España",
    address: "Carrer de Bosch i Gimpera, 5-13, Les Corts, Barcelona",
    latitude: 41.3861,
    longitude: 2.1178,
    courts: 17
  },
  {
    id: "ct-barcino-es",
    name: "Club Tennis Barcino",
    city: "Barcelona",
    country: "España",
    address: "Carrer del Bosc, 5-11, Sarrià-Sant Gervasi, Barcelona",
    latitude: 41.4106,
    longitude: 2.1240,
    courts: 12
  },
  {
    id: "ct-vall-parc-es",
    name: "Club Tennis Vall Parc",
    city: "Barcelona",
    country: "España",
    address: "Carretera de l'Arrabassada, 97, Barcelona",
    latitude: 41.4180,
    longitude: 2.1290,
    courts: 12
  },
  {
    id: "can-caralleu-es",
    name: "Complex Esportiu Municipal Can Caralleu",
    city: "Barcelona",
    country: "España",
    address: "Carrer dels Esports, 2-8, Sarrià-Sant Gervasi, Barcelona",
    latitude: 41.4030,
    longitude: 2.1170,
    courts: 7
  },
  {
    id: "ct-pompeia-es",
    name: "Club Tennis Pompeia",
    city: "Barcelona",
    country: "España",
    address: "Carrer del Foc, 5, Montjuïc, Barcelona",
    latitude: 41.3600,
    longitude: 2.1450,
    courts: 6
  },
  // Área metropolitana de Barcelona. Cada club lleva su municipio real; para
  // que la gente de un pueblo no se quede sin rivales, la búsqueda permite
  // abrirse a toda la comunidad (ver REGIONS_BY_COUNTRY).
  {
    id: "ct-palleja-es",
    name: "Club de Tennis Pallejà",
    city: "Pallejà",
    country: "España",
    address: "Avinguda Onze de Setembre de 1714, 1, 08780 Pallejà",
    latitude: 41.4222,
    longitude: 1.9986,
    courts: 4
  },
  {
    id: "se-espiral-palleja-es",
    name: "S.E. L'Espiral — Tennis Pallejà",
    city: "Pallejà",
    country: "España",
    address: "Avinguda Fontpineda, 108, 08780 Pallejà",
    latitude: 41.4090,
    longitude: 1.9700,
    courts: 4
  },
  {
    id: "ct-andres-gimeno-es",
    name: "Club de Tennis Andrés Gimeno",
    city: "Castelldefels",
    country: "España",
    address: "Castelldefels, Baix Llobregat, Barcelona",
    latitude: 41.2800,
    longitude: 1.9770,
    courts: 12
  },
  {
    id: "ct-castelldefels-es",
    name: "Club Tennis Castelldefels",
    city: "Castelldefels",
    country: "España",
    address: "Castelldefels, Baix Llobregat, Barcelona",
    latitude: 41.2830,
    longitude: 1.9800,
    courts: 8
  },
  // España · Valle de Tena (Huesca). Mercado propio: está a más de 300 km de
  // Barcelona, así que aquí sí tiene sentido separarlo.
  {
    id: "escaladillo-sallent-es",
    name: "Complex Esportiu El Escaladillo",
    city: "Formigal",
    country: "España",
    address: "Paseo Fermín Arrudi s/n, Sallent de Gállego, Huesca",
    latitude: 42.7710,
    longitude: -0.3330,
    courts: 1
  },
  {
    id: "pistes-formigal-es",
    name: "Pistes de tennis de Formigal",
    city: "Formigal",
    country: "España",
    address: "Formigal, Sallent de Gállego, Huesca",
    latitude: 42.7800,
    longitude: -0.3900,
    courts: 2
  }
];

export const currentPlayer: Player = {
  id: "me",
  name: "Ana Morales",
  age: 31,
  gender: "female",
  clubIds: ["club-alemán-gt", "club-hercules-gt"],
  city: "Ciudad de Guatemala",
  country: "Guatemala",
  latitude: 14.5914,
  longitude: -90.5133,
  level: "c",
  preferredFormats: ["singles", "mixed"],
  availability: [
    { day: "Martes", ranges: ["18:00-20:00"] },
    { day: "Jueves", ranges: ["18:00-21:00"] },
    { day: "Sábado", ranges: ["08:00-11:00"] }
  ],
  bio: "Juego 2 o 3 veces por semana. Busco partidos competitivos pero relajados.",
  rating: 4.7,
  responseRate: 94,
  languages: ["Español", "Inglés"],
  verified: true,
  profileComplete: true,
  skills: { consistency: 8.5, volley: 7.4, forehand: 8.2, backhand: 7.8, serve: 8.8 }
};

export const players: Player[] = [
  currentPlayer,
  {
    id: "p-1",
    name: "Carlos Rivera",
    age: 34,
    gender: "male",
    clubIds: ["club-hercules-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.6215,
    longitude: -90.5248,
    level: "c",
    preferredFormats: ["singles", "doubles"],
    availability: [
      { day: "Martes", ranges: ["18:00-20:00"] },
      { day: "Sábado", ranges: ["07:00-10:00"] }
    ],
    bio: "Prefiero singles entre semana y dobles los fines de semana.",
    rating: 4.8,
    responseRate: 91,
    languages: ["Español"]
  },
  {
    id: "p-2",
    name: "María Fernanda López",
    age: 29,
    gender: "female",
    clubIds: ["club-sporta-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.6106,
    longitude: -90.4847,
    level: "b",
    preferredFormats: ["singles", "mixed"],
    availability: [
      { day: "Jueves", ranges: ["19:00-21:00"] },
      { day: "Domingo", ranges: ["09:00-12:00"] }
    ],
    bio: "Entreno con regularidad y me gustan sets completos.",
    rating: 4.9,
    responseRate: 88,
    languages: ["Español", "Inglés"]
  },
  {
    id: "p-3",
    name: "Diego Castillo",
    age: 42,
    gender: "male",
    clubIds: ["ct-barcino-es"],
    city: "Barcelona",
    country: "España",
    latitude: 40.4237,
    longitude: -3.6693,
    level: "c",
    preferredFormats: ["doubles", "mixed"],
    availability: [
      { day: "Sábado", ranges: ["08:00-11:00"] },
      { day: "Domingo", ranges: ["08:00-10:00"] }
    ],
    bio: "Disponible para recibir jugadores en Barcelona.",
    rating: 4.5,
    responseRate: 80,
    languages: ["Español"]
  },
  {
    id: "p-4",
    name: "Sofía Arévalo",
    age: 25,
    gender: "female",
    clubIds: ["rctb-1899-es"],
    city: "Barcelona",
    country: "España",
    latitude: 41.4067,
    longitude: 2.1379,
    level: "novato",
    preferredFormats: ["singles", "doubles"],
    availability: [
      { day: "Jueves", ranges: ["18:00-20:00"] },
      { day: "Sábado", ranges: ["10:00-12:00"] }
    ],
    bio: "Estoy retomando tenis y busco rivales pacientes para mejorar.",
    rating: 4.6,
    responseRate: 97,
    languages: ["Español", "Francés"]
  },
  {
    id: "p-5",
    name: "Luis Mendoza",
    age: 38,
    gender: "male",
    clubIds: ["federacion-zona-5-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.6284,
    longitude: -90.5187,
    level: "d",
    preferredFormats: ["singles", "doubles"],
    availability: [{ day: "Miércoles", ranges: ["18:00-20:00"] }, { day: "Sábado", ranges: ["09:00-11:00"] }],
    bio: "Perfil ilustrativo para mostrar cómo se verá la comunidad.",
    rating: 4.2,
    responseRate: 0,
    languages: ["Español"]
  },
  {
    id: "p-6",
    name: "Valeria Paredes",
    age: 27,
    gender: "female",
    clubIds: ["federacion-zona-15-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.5948,
    longitude: -90.4872,
    level: "d",
    preferredFormats: ["singles", "mixed"],
    availability: [{ day: "Jueves", ranges: ["17:00-19:00"] }, { day: "Domingo", ranges: ["08:00-10:00"] }],
    bio: "Perfil ilustrativo para mostrar cómo se verá la comunidad.",
    rating: 4.3,
    responseRate: 0,
    languages: ["Español"]
  },
  {
    id: "p-7",
    name: "Javier Salazar",
    age: 35,
    gender: "male",
    clubIds: ["club-alemán-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.5914,
    longitude: -90.5133,
    level: "a",
    preferredFormats: ["singles"],
    availability: [{ day: "Martes", ranges: ["06:00-08:00"] }, { day: "Sábado", ranges: ["07:00-09:00"] }],
    bio: "Perfil ilustrativo para mostrar cómo se verá la comunidad.",
    rating: 4.9,
    responseRate: 0,
    languages: ["Español", "Inglés"]
  },
  {
    id: "p-8",
    name: "Elena Cabrera",
    age: 30,
    gender: "female",
    clubIds: ["club-sporta-gt"],
    city: "Ciudad de Guatemala",
    country: "Guatemala",
    latitude: 14.6106,
    longitude: -90.4847,
    level: "a",
    preferredFormats: ["singles", "doubles"],
    availability: [{ day: "Miércoles", ranges: ["19:00-21:00"] }, { day: "Domingo", ranges: ["09:00-11:00"] }],
    bio: "Perfil ilustrativo para mostrar cómo se verá la comunidad.",
    rating: 4.8,
    responseRate: 0,
    languages: ["Español"]
  }
];
