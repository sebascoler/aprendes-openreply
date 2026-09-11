#!/usr/bin/env bash
# Construye la imagen desde el commit pinneado y levanta todo.
# Idempotente: se puede correr las veces que haga falta.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No hay .env. Corré scripts/init-env.sh primero." >&2; exit 1; }

if grep -q "=__COMPLETAR__" .env; then
  echo "Atención: quedan valores sin completar en .env:" >&2
  grep -n "=__COMPLETAR__" .env >&2
  echo "Sin RESEND_API_KEY no vas a poder iniciar sesión; sin los de Meta no vas a poder conectar Instagram." >&2
  echo "Sigo igual (Ctrl+C para cortar)..." >&2
  sleep 5
fi

docker compose build --pull web
docker compose up -d --remove-orphans

echo
echo "Esperando a que la app responda..."
for i in $(seq 1 30); do
  if docker compose ps --format '{{.Service}} {{.Health}}' | grep -q '^web healthy'; then
    break
  fi
  sleep 5
done

docker compose ps
echo
scripts/health.sh || true
