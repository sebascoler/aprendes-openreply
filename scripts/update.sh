#!/usr/bin/env bash
# Actualiza OpenReply a otro commit del repo upstream y redeploya.
#
#   scripts/update.sh                 -> reconstruye con el commit actual de .env
#   scripts/update.sh <sha-o-tag>     -> cambia OPENREPLY_REF en .env y reconstruye
#
# Antes de actualizar hace un backup de la base, porque el arranque corre
# `prisma migrate deploy` y una migración no se deshace sola.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "No hay .env." >&2; exit 1; }

if [ -d .git ]; then
  git pull --ff-only || echo "No pude hacer git pull de este repo de infra; sigo con lo que hay." >&2
fi

if [ "${1:-}" != "" ]; then
  sed -i "s|^OPENREPLY_REF=.*|OPENREPLY_REF=$1|" .env
  echo "OPENREPLY_REF -> $1"
fi

scripts/backup.sh
scripts/deploy.sh

# Limpia imágenes viejas de builds anteriores.
docker image prune -f >/dev/null || true
