export type HomeCountryContent = {
  countryLabel: string;
  intro: string;
  stories: Array<{ tag: string; title: string; body: string }>;
  commerce: Array<{ name: string; detail: string; priceLabel: string }>;
};

const defaultContent: HomeCountryContent = {
  countryLabel: "tu país",
  intro: "Partidos, comunidad y novedades alrededor de tus pistas.",
  stories: [
    { tag: "AGENDA", title: "Eventos cerca de ti", body: "Próximamente: torneos y actividades verificados por MatchPoint." },
    { tag: "COMUNIDAD", title: "Jugadores y clubes", body: "Historias y convocatorias relevantes de tu comunidad local." }
  ],
  commerce: [
    { name: "Raquetas seleccionadas", detail: "Potencia, control y spin", priceLabel: "Próximamente" },
    { name: "Calzado para pista", detail: "Estabilidad y confort", priceLabel: "Próximamente" }
  ]
};

const contentByCountry: Record<string, HomeCountryContent> = {
  guatemala: {
    countryLabel: "Guatemala",
    intro: "Partidos, comunidad y todo lo que ocurre alrededor de las pistas de Guatemala.",
    stories: [
      { tag: "TORNEOS", title: "Agenda del tenis guatemalteco", body: "Próximamente: ligas, torneos y eventos confirmados por clubes y organizadores." },
      { tag: "COMUNIDAD", title: "Nuevos grupos cerca de ti", body: "Encuentra actividades y jugadores de tus clubes habituales." }
    ],
    commerce: [
      { name: "Raquetas seleccionadas", detail: "Opciones para cada nivel", priceLabel: "Tiendas de Guatemala" },
      { name: "Calzado para pista", detail: "Estabilidad y confort", priceLabel: "Tiendas de Guatemala" }
    ]
  }
};

export function getHomeCountryContent(country?: string | null): HomeCountryContent {
  const key = country?.trim().toLocaleLowerCase("es") ?? "";
  return contentByCountry[key] ?? { ...defaultContent, countryLabel: country || defaultContent.countryLabel };
}
