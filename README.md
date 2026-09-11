# aprendes-openreply

Despliegue de [OpenReply](https://github.com/diwenne/openreply) en el VPS de Aprendes.ai. OpenReply es un ManyChat open source: cuando alguien comenta una palabra clave en un post o reel de Instagram, recibe un DM automático por la API oficial de Meta. Corre en `https://reply.aprendes.ai`.

Este repo no tiene código de la app. Tiene lo necesario para correrla y operarla:

| Archivo | Qué es |
| --- | --- |
| `docker-compose.yml` | Los seis contenedores: web, worker, cron, postgres, redis, caddy. |
| `Caddyfile` | Proxy HTTPS con certificado automático de Let's Encrypt. |
| `.env.example` | Plantilla de configuración. `scripts/init-env.sh` la convierte en `.env` con secretos generados. |
| `scripts/` | Instalación, deploy, actualización, backup y health check. |
| `docs/meta-app.md` | Guía paso a paso de la app de Meta (la parte manual). |

La imagen se construye directo desde el repo upstream, pinneada al commit `OPENREPLY_REF` del `.env`. No hay fork que mantener.

## Cómo está armado

```
Instagram (Meta)  ──webhook──▶  caddy :443  ──▶  web :3000  (dashboard + /api/webhook)
                                                     │
                                          postgres ──┼── redis (cola BullMQ)
                                                     │
                                worker (manda los DMs, respeta rate limits)
                                cron   (refresca el token de Instagram cada día)
```

- **web**: Next.js. Recibe los webhooks de Meta, sirve el dashboard y encola los DMs. Al arrancar corre las migraciones de Prisma.
- **worker**: proceso siempre encendido que consume la cola y envía. Sin worker, los webhooks llegan pero ningún DM sale.
- **cron**: llama a `/api/cron/*` cada 5 minutos y una vez al día. El job diario `refresh-tokens` es el que importa: sin él, el token de Instagram expira a los 60 días y todo deja de funcionar sin ningún error.
- **postgres** y **redis**: solo accesibles desde la red interna de compose. Redis con persistencia y `noeviction`, que BullMQ exige.
- **caddy**: lo único con puertos al exterior (80 y 443).

Los tres contenedores de la app leen el mismo `.env`, así que `ENCRYPTION_KEY` es idéntica en web y worker por construcción. Si difirieran, el worker no podría descifrar el token de Instagram y todo envío fallaría.

## Instalación en el VPS

Requisitos: Ubuntu con Docker y Docker Compose v2, puertos 80 y 443 abiertos en el firewall de Hostinger, y el DNS de `reply.aprendes.ai` apuntando a la IP del VPS (registro A en Namecheap, TTL el mínimo).

```bash
# 0. Docker, si el VPS no lo trae
curl -fsSL https://get.docker.com | sh

# 1. Clonar este repo
sudo mkdir -p /opt && cd /opt
git clone git@github.com:sebascoler/aprendes-openreply.git
cd aprendes-openreply
chmod +x scripts/*.sh

# 2. Generar el .env con los secretos
scripts/init-env.sh

# 3. Completar a mano lo que el script te marca
nano .env
#   RESEND_API_KEY        -> la key de Resend (dominio envios.aprendes.ai ya verificado)
#   INSTAGRAM_APP_ID      -> de la app de Meta (ver docs/meta-app.md, paso 2)
#   INSTAGRAM_APP_SECRET
#   FACEBOOK_APP_SECRET

# 4. Construir y levantar
scripts/deploy.sh
```

El primer build tarda unos minutos (instala dependencias y compila Next.js). Cuando termina, `scripts/deploy.sh` muestra el estado de los contenedores y el `/api/health`.

Los valores de Meta se pueden completar después: la app arranca igual y solo falla al intentar conectar Instagram. Lo que sí hace falta desde el principio es `RESEND_API_KEY`, porque sin eso no llega el magic link para entrar.

Después de editar el `.env`, `docker compose up -d` relee los valores y reinicia lo que cambió.

## Después de instalar

1. Abrí `https://reply.aprendes.ai/api/health`. Tiene que dar `status: "ok"` con `worker.healthy: true`.
2. Entrá a `https://reply.aprendes.ai` con `sebas@aprendes.ai`. Solo los emails de `ALLOWED_EMAILS` pueden pedir magic link.
3. Seguí `docs/meta-app.md` para la app de Meta, conectar la cuenta y hacer la prueba de punta a punta.

## Operación

```bash
cd /opt/aprendes-openreply

docker compose ps                    # estado de los contenedores
docker compose logs -f web           # o worker, cron, caddy
scripts/health.sh                    # /api/health desde adentro del contenedor

scripts/backup.sh                    # dump de Postgres en ./backups (conserva 14 días)
scripts/update.sh                    # reconstruye con el mismo commit (tras git pull de este repo)
scripts/update.sh <sha>              # actualiza OpenReply a otro commit upstream
```

**Backup automático.** Una línea en el crontab del VPS:

```bash
(crontab -l 2>/dev/null; echo "15 3 * * * /opt/aprendes-openreply/scripts/backup.sh >> /var/log/openreply-backup.log 2>&1") | crontab -
```

**Restaurar un backup** (pisa la base actual):

```bash
gunzip -c backups/openreply-AAAA-MM-DD-HHMM.sql.gz | docker compose exec -T postgres psql -U openreply -d openreply
```

**Actualizar OpenReply.** Mirá el [historial upstream](https://github.com/diwenne/openreply/commits/main), elegí un commit y corré `scripts/update.sh <sha>`. El script hace backup antes, porque el arranque corre `prisma migrate deploy` y una migración no se deshace sola. Si algo sale mal: volvé a poner el commit anterior en `OPENREPLY_REF`, restaurá el backup y `scripts/deploy.sh`.

**Lo que no hay que perder.** El `.env` (sobre todo `ENCRYPTION_KEY`: si cambia, hay que reconectar Instagram) y el volumen `pgdata`. Redis se puede vaciar sin drama, solo pierde los DMs que estuvieran en cola en ese momento.

## Diagnóstico rápido

| Síntoma | Dónde mirar |
| --- | --- |
| La URL no carga o el certificado falla | `docker compose logs caddy`. Casi siempre es DNS que todavía no propagó o el puerto 80/443 cerrado en el firewall. |
| `worker.healthy: false` | `docker compose logs worker`. |
| El comentario llega (aparece en WebhookEvent) pero no sale el DM | DM Logs en el dashboard muestra el error de Meta. Lo habitual: la cuenta no aceptó la invitación de tester, o el que comentó tiene los DMs cerrados. |
| Los comentarios reales no llegan pero el botón Probar de Meta sí | La app de Meta está en modo Desarrollo. Ver `docs/meta-app.md`, paso 6. |
| Dejó de funcionar sin tocar nada, ~2 meses después de conectar | Token expirado: el contenedor `cron` no estaba corriendo. `docker compose logs cron`. Reconectar la cuenta en Settings lo arregla al instante. |

Las tablas `WebhookEvent`, `DmLog` y `OperationalEvent` de Postgres cuentan dónde se detuvo cada comentario:

```bash
docker compose exec postgres psql -U openreply -d openreply -c 'SELECT * FROM "DmLog" ORDER BY "createdAt" DESC LIMIT 10;'
```
