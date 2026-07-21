import { Text, View } from "react-native";
import { Card } from "@/components/card";
import { ScreenShell } from "@/components/screen-shell";
import { colors, spacing, typography } from "@/theme";

const sections = [
  ["Datos que tratamos", "Cuenta y autenticación; perfil deportivo; foto; club y disponibilidad; ubicación aproximada cuando la solicitas; propuestas y reservas. Los resultados, reseñas y rankings solo se tratarán al habilitar esas funciones."],
  ["Finalidad", "Usamos estos datos para identificar tu perfil, encontrar rivales compatibles, cruzar horarios y organizar partidos. Cuando se habiliten las funciones competitivas, también servirán para validar resultados y calcular clasificaciones."],
  ["Ubicación", "La ubicación se solicita de forma contextual para ordenar jugadores cercanos y abrir rutas a clubes. No vendemos datos de localización ni los usamos para publicidad."],
  ["Proveedores", "Firebase de Google presta autenticación, base de datos y hosting. Google y Apple procesan el inicio de sesión cuando eliges esos proveedores."],
  ["Visibilidad", "Otros usuarios autenticados pueden ver tu nombre, foto, club, nivel, idiomas, disponibilidad, estadísticas y valoraciones deportivas necesarias para el funcionamiento de la comunidad."],
  ["Conservación y derechos", "Conservamos la información mientras tu cuenta esté activa. Puedes editarla, solicitar una copia o iniciar la eliminación de tu cuenta y datos asociados desde la sección Cuenta."],
  ["Responsable y contacto", "Responsable: Pedro Caparrós Torres. Para privacidad, soporte o ejercicio de derechos: support@puchica.uk."]
];

export default function PrivacyScreen() {
  return <ScreenShell bottomInset={32}><Card pad="lg"><Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>Política de privacidad</Text><Text selectable style={{ ...typography.footnote, color: colors.textTertiary }}>Versión de desarrollo · 10 de julio de 2026</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>MatchPoint Tennis es una aplicación para encontrar jugadores de tenis, organizar partidos y participar en rankings, equipos, ligas y torneos.</Text></Card>{sections.map(([title, body]) => <Card key={title}><Text selectable style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>{title}</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary, fontSize: 15, lineHeight: 22 }}>{body}</Text></Card>)}<View style={{ height: spacing.lg }} /></ScreenShell>;
}
