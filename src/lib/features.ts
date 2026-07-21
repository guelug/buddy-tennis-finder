/**
 * Los pagos solo se muestran cuando Play products y Firebase Functions están
 * operativos. La bandera se incrusta al compilar; por defecto la experiencia
 * de rivales/partidos/ranking queda disponible sin ofrecer un checkout roto.
 */
export const PURCHASES_ENABLED = process.env.EXPO_PUBLIC_PURCHASES_ENABLED === "true";
