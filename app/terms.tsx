import { Text } from "react-native";
import { Card } from "@/components/card";
import { ScreenShell } from "@/components/screen-shell";
import { colors, typography } from "@/theme";

const terms = [
  ["Uso de la plataforma", "Debes proporcionar información veraz, respetar a otros jugadores y utilizar propuestas, equipos, ligas y torneos únicamente con fines deportivos legítimos."],
  ["Resultados y rankings", "Los resultados solo afectan clasificaciones cuando han sido validados. La administración puede corregir fraude, duplicados, suplantación o conducta abusiva."],
  ["Seguridad", "Cada jugador es responsable de evaluar dónde y con quién juega. La plataforma facilita el contacto y no sustituye las medidas personales de seguridad ni las normas de cada club."],
  ["Disponibilidad del servicio", "La versión actual se encuentra en fase de desarrollo y puede cambiar. Las condiciones comerciales y de monetización se comunicarán antes de activar cualquier pago."],
  ["Contacto", "Responsable: Pedro Caparrós Torres. Soporte y consultas legales: support@puchica.uk."]
];

export default function TermsScreen() {
  return <ScreenShell bottomInset={32}><Card pad="lg"><Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>Términos de uso</Text><Text selectable style={{ ...typography.footnote, color: colors.textTertiary }}>Última actualización: 10 de julio de 2026</Text></Card>{terms.map(([title, body]) => <Card key={title}><Text selectable style={{ ...typography.headline, color: colors.textPrimary, fontSize: 18 }}>{title}</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>{body}</Text></Card>)}</ScreenShell>;
}
