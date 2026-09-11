#!/usr/bin/env bash
# Dump comprimido de Postgres en ./backups. Conserva los últimos 14 días.
#
# Para que corra solo todas las noches, en el VPS:
#   (crontab -l 2>/dev/null; echo "15 3 * * * /opt/aprendes-openreply/scripts/backup.sh >> /var/log/openreply-backup.log 2>&1") | crontab -
#
# Restaurar (borra la base actual, cuidado):
#   gunzip -c backups/openreply-AAAA-MM-DD-HHMM.sql.gz | docker compose exec -T postgres psql -U openreply -d openreply
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p backups
stamp="$(date -u +%Y-%m-%d-%H%M)"
out="backups/openreply-${stamp}.sql.gz"

docker compose exec -T postgres pg_dump -U openreply --clean --if-exists openreply | gzip > "$out"
echo "Backup: $out ($(du -h "$out" | cut -f1))"

find backups -name 'openreply-*.sql.gz' -mtime +14 -delete
