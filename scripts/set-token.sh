#!/usr/bin/env bash
# Carga a mano un token de Instagram generado en el panel de Meta, para cuando
# Meta invalidó el que había (código 190) y la reconexión desde Settings no
# funciona. No borra nada: solo actualiza el token de la cuenta existente, así
# que las campañas siguen tal cual.
#
# Dónde sacar el token: developers.facebook.com → tu app → Instagram →
# "Configuración de la API con inicio de sesión de Instagram" → paso
# "Generar tokens de acceso" → al lado de la cuenta, botón "Generar token".
# Es un token de larga duración (60 días); después el cron lo renueva solo.
set -euo pipefail
cd "$(dirname "$0")/.."

read -rsp "Pegá el token de Instagram y Enter (no se muestra al escribir): " TOKEN
echo
[ -n "${TOKEN}" ] || { echo "Token vacío." >&2; exit 1; }

docker compose cp scripts/set-token.ts web:/app/scripts/set-token.ts
printf '%s' "${TOKEN}" | docker compose exec -T web sh -c \
  'cat > /tmp/ig-token.txt && ./node_modules/.bin/tsx scripts/set-token.ts; rc=$?; rm -f /tmp/ig-token.txt; exit $rc'

echo
echo "Comprobá con: scripts/health.sh  y después un comentario de prueba desde otra cuenta."
