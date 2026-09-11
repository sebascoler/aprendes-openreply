# La app de Meta, paso a paso

Esto es lo único de OpenReply que no se puede automatizar: requiere tu login de Facebook y de Instagram. Son unos 30 minutos si vas en orden. Cada paso existe porque saltarlo rompe algo después.

Vas a necesitar tener a mano:

- La URL pública: `https://envios.aprendes.ai` (ya desplegada y respondiendo).
- El valor de `WEBHOOK_VERIFY_TOKEN` del `.env` del VPS (`grep WEBHOOK_VERIFY_TOKEN /opt/aprendes-openreply/.env`).
- El teléfono con la app de Instagram de la cuenta de Aprendes.ai. Tiene que ser cuenta profesional (Empresa o Creador).

## 1. Crear la app

1. Entrá a [developers.facebook.com/apps](https://developers.facebook.com/apps) y tocá **Crear app**.
2. Tipo de app: **Empresa** (Business).
3. Email de contacto: uno que leas de verdad. Meta avisa ahí si la app queda restringida.
4. Cuando pida un **caso de uso**, filtrá por "Todos" y elegí **"Gestionar mensajes y contenido en Instagram"** (Manage messaging and content on Instagram).

No elijas "Autenticar con Facebook Login" ni "Crear y gestionar anuncios con la API de marketing". OpenReply usa Instagram Login. Si por error agregaste el de Marketing API, eliminalo: tiene requisitos de revisión propios y bloquea la publicación.

**Si la pantalla de casos de uso no apareció** (o no mostraba el de Instagram): la app quedó creada sin el producto Instagram, y sin ese producto no existen el App ID ni el App Secret de Instagram. Se agrega después, desde el panel de la app:

- Menú lateral → **Casos de uso** → **Personalizar** / **Agregar caso de uso** → "Gestionar mensajes y contenido en Instagram".
- O, en paneles más viejos, al final del menú lateral → **Agregar producto** → tarjeta **Instagram** → **Configurar**.

Al agregarlo aparece **Instagram** en el menú lateral, y adentro la pantalla **"Configuración de la API con inicio de sesión de Instagram"**, que es donde viven los pasos 2 a 5 de esta guía. Si el panel no deja agregar Instagram (app creada con un tipo incompatible), borrá la app y creá otra: en la pantalla de casos de uso hay un buscador o filtro "Todos" donde sí aparece.

## 2. Copiar los tres secretos al `.env`

Hay dos App ID y dos App Secret, y se confunden. El mapeo es este:

| Variable en `.env` | Dónde está en el panel de Meta |
| --- | --- |
| `INSTAGRAM_APP_ID` | Producto **Instagram** → "Configuración de la API con inicio de sesión de Instagram". En la cabecera de esa pantalla, campo "Identificador de la app de Instagram". Es un número tipo `2036...` |
| `INSTAGRAM_APP_SECRET` | Misma cabecera, campo "Clave secreta de la app de Instagram", botón **Mostrar** |
| `FACEBOOK_APP_SECRET` | **Configuración de la app → Básica → Clave secreta de la app**, botón Mostrar |

El App ID de Instagram no es el mismo número que el "Identificador de la app" de Facebook que aparece en Configuración básica. Usá el que está bajo el producto Instagram.

Cargalos directo en el VPS, sin pasarlos por chats ni notas:

```bash
nano /opt/aprendes-openreply/.env
# completar INSTAGRAM_APP_ID, INSTAGRAM_APP_SECRET, FACEBOOK_APP_SECRET
docker compose -f /opt/aprendes-openreply/docker-compose.yml up -d   # relee el .env
```

## 3. Agregar tu Instagram como tester y ACEPTAR la invitación

Este es el paso que todo el mundo se saltea y produce el error **"Insufficient Developer Role"** al conectar. Son dos mitades y las dos son obligatorias.

**Mitad 1, en Meta.** En el panel de la app: **Roles de la app → Roles**. En la sección **Instagram testers**, tocá agregar y escribí el nombre de usuario exacto de la cuenta de Instagram de Aprendes.ai. Enviá la invitación.

**Mitad 2, en Instagram.** Desde el teléfono, con esa cuenta:

1. Perfil → menú → **Configuración y actividad**.
2. **Apps y sitios web** (en versiones viejas: Permisos del sitio web → Apps y sitios web).
3. **Invitaciones de tester**.
4. Aceptar la invitación de tu app.

Hasta que no aceptes acá, la cuenta no es tester de verdad y el login va a seguir fallando. Si no ves la invitación, revisá que el usuario esté bien escrito y que la cuenta sea Empresa o Creador.

## 4. Registrar la redirect URI del login

En el producto Instagram: **Configurar el inicio de sesión para empresas de Instagram → Configuración del inicio de sesión para empresas**. En "URI de redireccionamiento de OAuth válidos" agregá exactamente:

```
https://envios.aprendes.ai/api/instagram/callback
```

Sin barra final. Si falta o está mal, conectar la cuenta falla con `redirect_uri mismatch`.

No hace falta la "URL para insertar" que Meta muestra ahí. OpenReply arma su propia URL de login.

## 5. Configurar el webhook

En el mismo producto Instagram, paso **Configurar webhooks**:

- URL de devolución de llamada: `https://envios.aprendes.ai/api/webhook`
- Token de verificación: el valor de `WEBHOOK_VERIFY_TOKEN` del `.env`
- **Verificar y guardar**. Tiene que pasar al instante, porque la app contesta el challenge de Meta. Si el botón está gris, hacé clic en el campo del token y pegalo de nuevo: editar la URL suele vaciarlo.
- Suscribite a los campos **`comments`** y **`messages`**.

Los dos importan. `comments` trae el comentario-a-DM. `messages` trae los DMs entrantes y las respuestas a historias, que es lo que usa la opción "responder también cuando alguien manda estas palabras por DM". Si suscribís solo `comments`, esa opción se ve activada pero nunca dispara.

Para probar sin un comentario real: al lado de `comments` tocá **Probar** y después **Enviar a mi servidor**. Son dos pasos; el primero solo muestra el payload de ejemplo. Después de enviar tiene que aparecer una fila en la tabla `WebhookEvent` (o el evento en el dashboard).

Si algún día cambia el dominio, actualizá esta URL. Un dominio que redirige con 307 hace que Meta deje de entregar webhooks en silencio.

## 6. Publicar la app

Los webhooks de comentarios reales solo llegan con la app en estado **Activa** (Live). En modo Desarrollo solo llega lo que mandás con el botón Probar. Es la causa número uno de "configuré todo y no pasa nada".

En el menú lateral, **Publicar**. Antes te va a exigir tres URLs. OpenReply ya sirve estas páginas en tu dominio:

| Campo | URL |
| --- | --- |
| Política de privacidad | `https://envios.aprendes.ai/privacy` |
| Condiciones del servicio | `https://envios.aprendes.ai/terms` |
| Instrucciones de eliminación de datos | `https://envios.aprendes.ai/data-deletion` |

Cargalas en **Configuración de la app → Básica** y publicá.

### Lo que la publicación NO hace

Publicar deja la app activa pero no amplía a quién aplican los permisos. La app queda con **Acceso estándar** a `instagram_business_basic`, `instagram_business_manage_comments` e `instagram_business_manage_messages`, y eso solo cubre cuentas de Instagram con un rol en la app (admins, developers, testers).

Para nuestro caso alcanza: la única cuenta que se conecta es la de Aprendes.ai, y ya es tester. Los que comentan **no necesitan nada**: solo tiene que tener rol la cuenta que recibe los comentarios y manda los DMs.

Si más adelante quisiéramos conectar una segunda cuenta que controlamos, se repite el paso 3 con esa cuenta. Solo si quisiéramos conectar cuentas de terceros haría falta App Review (screencast, justificación de permisos y verificación de la empresa). Hoy no.

## 7. Conectar y probar de punta a punta

1. Entrá a `https://envios.aprendes.ai`, pedí el magic link con `sebas@aprendes.ai` y abrilo desde el correo.
2. **Settings → Connect Instagram**. Tiene que aparecer la pantalla de consentimiento de Instagram y volver al dashboard con la cuenta conectada.
3. Verificá `https://envios.aprendes.ai/api/health`: `status: "ok"` y `worker.healthy: true`.
4. Creá una campaña sobre un post o reel con la palabra clave `TEST`.
5. **Desde otra cuenta de Instagram** comentá `TEST` en ese post. Tiene que ser otra cuenta: OpenReply ignora a propósito los comentarios de la cuenta conectada.
6. Tiene que llegar el DM y aparecer una fila `SENT` en **DM Logs**.

## Si algo falla

| Síntoma | Causa habitual |
| --- | --- |
| "Insufficient Developer Role" al conectar | No aceptaste la invitación de tester dentro de Instagram (paso 3, mitad 2). |
| `redirect_uri mismatch` | La redirect URI del paso 4 no coincide exactamente. |
| El botón Verificar del webhook falla | La app no responde en el dominio, o el token no coincide con `WEBHOOK_VERIFY_TOKEN`. Probá `https://envios.aprendes.ai/api/health` en el navegador. |
| El Test del webhook llega pero los comentarios reales no | La app está en modo Desarrollo. Publicala (paso 6). |
| Conecta bien pero todas las llamadas a `graph.instagram.com` dan `Unsupported request, code=100` | La cuenta que conectaste no tiene rol en la app. Repetí el paso 3 con esa cuenta. |
| `worker.healthy: false` en `/api/health` | El worker no corre o no llega a Redis. `docker compose logs worker` en el VPS. |
| Los DMs salían y un día dejaron de salir sin error | El token de Instagram expiró. Revisá que el contenedor `cron` esté corriendo: `docker compose logs cron`. |
