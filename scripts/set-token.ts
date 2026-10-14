// Carga a mano un token de Instagram en la cuenta ya conectada, sin pasar por
// el flujo OAuth de Settings. Para cuando Meta invalida el token (código 190:
// cambio de contraseña, cierre de sesiones por seguridad) y la reconexión por
// el dashboard no termina.
//
// Corre ADENTRO del contenedor web (lo lanza scripts/set-token.sh), donde
// existen el alias @/, el cliente de Prisma generado y el .env con
// ENCRYPTION_KEY. Lee el token de /tmp/ig-token.txt, que el wrapper borra al
// terminar.
//
// No crea cuentas: si el token pertenece a una cuenta que no está en la base,
// corta con error. Las campañas quedan intactas porque solo se actualiza el
// token de la fila existente.
import { readFileSync } from "node:fs";
import { prisma } from "@/lib/db/client";
import { encryptToken } from "@/lib/meta/oauth";
import {
  getUserInfo,
  subscribeInstagramAccountToWebhooks,
} from "@/lib/meta/client";

const TOKEN_FILE = "/tmp/ig-token.txt";
// Los tokens de larga duración de Instagram viven 60 días; el cron diario
// refresh-tokens los renueva antes de que venzan.
const SIXTY_DAYS_MS = 60 * 24 * 60 * 60 * 1000;

async function main() {
  const token = readFileSync(TOKEN_FILE, "utf8").trim();
  if (!token) throw new Error("El archivo del token está vacío.");

  const me = await getUserInfo(token);
  const instagramId = me.user_id ?? me.id;

  const existing = await prisma.instagramAccount.findUnique({
    where: { instagramId },
  });
  if (!existing) {
    throw new Error(
      `El token es de @${me.username} (${instagramId}) y esa cuenta no está en la base. Conectala desde Settings.`
    );
  }

  let webhookSubscribed = existing.webhookSubscribed;
  try {
    const result = await subscribeInstagramAccountToWebhooks(instagramId, token);
    webhookSubscribed = Boolean(result.success);
  } catch (error) {
    console.warn(
      "Aviso: no se pudo re-suscribir el webhook:",
      error instanceof Error ? error.message : error
    );
  }

  await prisma.instagramAccount.update({
    where: { id: existing.id },
    data: {
      accessToken: encryptToken(token),
      tokenExpiresAt: new Date(Date.now() + SIXTY_DAYS_MS),
      webhookSubscribed,
      username: me.username,
    },
  });

  console.log(
    `OK: token actualizado para @${me.username} (${instagramId}). Webhook ${
      webhookSubscribed ? "suscrito" : "NO suscrito"
    }. Vence en 60 días; el cron lo renueva.`
  );
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (error) => {
    console.error("ERROR:", error instanceof Error ? error.message : error);
    await prisma.$disconnect();
    process.exit(1);
  });
