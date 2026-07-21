import { Linking, Text } from "react-native";
import { Card } from "@/components/card";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { colors, typography } from "@/theme";

export default function SupportScreen() {
  return <ScreenShell bottomInset={32}><Card pad="lg"><Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>Soporte</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Responsable: Pedro Caparrós Torres</Text><Text selectable style={{ ...typography.body, color: colors.textPrimary }}>support@puchica.uk</Text><PrimaryButton label="Contactar con soporte" onPress={() => Linking.openURL("mailto:support@puchica.uk?subject=Soporte%20MatchPoint%20Clubs")} /></Card><Card><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>Problemas con partidos</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Escríbenos indicando la fecha, el club y la reserva afectada. No incluyas contraseñas ni datos sensibles en el mensaje.</Text></Card><Card><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>Cuenta y privacidad</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Desde Perfil puedes editar tus datos, cerrar sesión y acceder a privacidad, términos y eliminación de cuenta.</Text></Card></ScreenShell>;
}
