#!/usr/bin/env bash
# Crea .env a partir de .env.example generando todos los secretos.
# Se corre una sola vez en el VPS. Si ya hay un .env, no lo pisa.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo "Ya existe .env. Si querés regenerarlo, borralo primero (perderías ENCRYPTION_KEY: las cuentas conectadas habría que reconectarlas)." >&2
  exit 1
fi

command -v openssl >/dev/null || { echo "Falta openssl (apt install openssl)" >&2; exit 1; }

gen()     { openssl rand -base64 32 | tr -d '\n=' | tr '+/' '-_'; }
gen_hex() { openssl rand -hex 32; }

PG_PASS="$(gen)"

cp .env.example .env
sed -i \
  -e "s|^POSTGRES_PASSWORD=__GENERAR__|POSTGRES_PASSWORD=${PG_PASS}|" \
  -e "s|__POSTGRES_PASSWORD__|${PG_PASS}|" \
  -e "s|^NEXTAUTH_SECRET=__GENERAR__|NEXTAUTH_SECRET=$(gen)|" \
  -e "s|^CRON_SECRET=__GENERAR__|CRON_SECRET=$(gen)|" \
  -e "s|^ENCRYPTION_KEY=__GENERAR_HEX__|ENCRYPTION_KEY=$(gen_hex)|" \
  -e "s|^WEBHOOK_VERIFY_TOKEN=__GENERAR__|WEBHOOK_VERIFY_TOKEN=$(gen)|" \
  .env
chmod 600 .env

echo ".env creado con los secretos generados."
echo
echo "Te queda completar a mano estas líneas (nano .env):"
grep -n "=__COMPLETAR__" .env || true
echo
echo "Cuando estén, corré: scripts/deploy.sh"
