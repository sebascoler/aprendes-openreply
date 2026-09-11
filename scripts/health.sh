#!/usr/bin/env bash
# Muestra /api/health desde adentro del contenedor web (no depende del DNS ni de Traefik).
# status "ok" y worker.healthy true = todo bien. "degraded" = mirá qué check está en error.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose exec -T web node -e '
fetch("http://localhost:3000/api/health")
  .then(async (r) => { console.log("HTTP", r.status); console.log(JSON.stringify(await r.json(), null, 2)); process.exit(r.status === 200 ? 0 : 1); })
  .catch((e) => { console.error("La app no responde:", e.message); process.exit(1); });
'
