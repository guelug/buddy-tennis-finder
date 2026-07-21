import { useState } from "react";
import { Alert, Linking, Text } from "react-native";
import { router } from "expo-router";
import { Card } from "@/components/card";
import { PrimaryButton } from "@/components/primary-button";
import { ScreenShell } from "@/components/screen-shell";
import { useAuth } from "@/lib/firebase-auth";
import { deleteCurrentAccountAndData } from "@/lib/account-deletion";
import { colors, typography } from "@/theme";

export default function DeleteAccountScreen() {
  const { user, isConfigured } = useAuth();
  const [busy, setBusy] = useState(false);

  const confirmDelete = () => Alert.alert(
    "¿Seguro que quieres eliminar tu cuenta?",
    "Se borrarán tu perfil, foto, horarios, puntuaciones, reseñas y partidos. No podrás recuperarlos.",
    [
      { text: "Conservar mi cuenta", style: "cancel" },
      { text: "Continuar", style: "destructive", onPress: confirmDeleteFinal }
    ]
  );

  const confirmDeleteFinal = () => Alert.alert(
    "Última confirmación",
    "Esta acción es permanente. Se eliminarán también tus puntuaciones y tu historial competitivo.",
    [
      { text: "Cancelar", style: "cancel" },
      { text: "Sí, eliminar definitivamente", style: "destructive", onPress: () => void performDelete() }
    ]
  );

  async function performDelete() {
    try {
      setBusy(true);
      await deleteCurrentAccountAndData();
      router.replace("/login");
    } catch (error) {
      Alert.alert("No se pudo eliminar", error instanceof Error ? error.message : "Contacta con soporte.");
    } finally {
      setBusy(false);
    }
  }

  return <ScreenShell bottomInset={32}><Card pad="lg"><Text selectable style={{ ...typography.title, color: colors.textPrimary, fontSize: 28 }}>Eliminación de cuenta</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Responsable: Pedro Caparrós Torres · support@puchica.uk</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Se eliminarán la identidad de Firebase, perfil, fotografía, disponibilidad y partidos asociados. La operación requiere haber iniciado sesión recientemente.</Text>{user && isConfigured ? <PrimaryButton label={busy ? "Eliminando..." : "Eliminar mi cuenta"} disabled={busy} variant="outline" onPress={confirmDelete} /> : <PrimaryButton label="Solicitar eliminación por correo" onPress={() => Linking.openURL("mailto:support@puchica.uk?subject=Eliminar%20cuenta%20MatchPoint%20Clubs")} />}</Card><Card><Text selectable style={{ ...typography.headline, color: colors.textPrimary }}>Alternativa de soporte</Text><Text selectable style={{ ...typography.body, color: colors.textSecondary }}>Si no puedes acceder a la cuenta, escribe desde el correo asociado a support@puchica.uk. Verificaremos la identidad antes de procesar la solicitud.</Text></Card></ScreenShell>;
}
