# Desplegar el servidor de salas

Con esto la web y el APK pueden **crear sala**: el navegador no puede abrir
puertos, así que le pide una sala al servicio y luego se conecta por WebSocket a
`wss://<host>/sala/<n>`.

Necesitás dos datos antes de empezar:

1. **`SUPABASE_SERVICE_KEY`** — Supabase → Project Settings → API → `service_role`.
   Solo la usa el servidor; nunca va al repo ni al cliente.
2. La URL pública del servicio (`https://<app>.fly.dev` o
   `https://<servicio>.onrender.com`).

El contenedor ya arranca el maestro de salas (`Dockerfile` → `--maestro`), con
`SALAS` procesos de partida dentro. Cada sala ocupa ~180 MB: 512 MB = 1 sala,
1 GB = 2.

## Opción A — Render (sin instalar nada)

1. Render → **New** → **Web Service** → conectá el repo
   `Chary-lab/gladiators-revenge`.
2. Runtime: **Docker**. Plan: **Free**.
3. En **Environment** cargá:
   - `SALAS` = `1`
   - `SUPABASE_SERVICE_KEY` = *(tu service_role)*
   - `SERVER_PUBLIC_URL` = `https://<tu-servicio>.onrender.com`
   - **No** definas `PORT`: Render lo inyecta y el contenedor lo respeta.
4. Health check path: `/` (el maestro responde `{"ok":true,...}`).
5. Deploy. El plan free se duerme a los 15 min sin uso; despierta en ~50 s.

También podés usar el `render.yaml` del repo: **New → Blueprint** y cargar el
secreto cuando lo pida.

## Opción B — Fly.io (con script)

```powershell
# 1) instalar flyctl una vez
iwr https://fly.io/install.ps1 -useb | iex

# 2) autenticarse (abre el navegador)
fly auth login

# 3) desplegar; el script crea la app, carga los secretos y hace el deploy
.\desplegar.ps1
```

El script lee la clave de `SUPABASE_SERVICE_KEY` si está en el entorno, o de
`%APPDATA%\Godot\app_userdata\Gladiators Revenge\supabase.local.cfg`, o te la
pide sin mostrarla. No la escribe en el repo.

## Apuntar la web al servicio

Dos formas:

- **Rápida, sin recompilar**: abrí la web con el parámetro
  `https://chary-lab.github.io/gladiators-revenge/?api=https://<tu-servicio>`
- **Permanente**: poné esa URL en `project.godot`:

  ```ini
  [red]
  api_url="https://<tu-servicio>"
  ```

  y hacé commit + push. GitHub Pages reconstruye la web en un par de minutos.

En escritorio el botón CREAR SALA sigue usando el túnel propio; la API solo se
usa en Web/APK (o si arrancás con `--api=https://<tu-servicio>`).

## Despliegue real (lo que quedó andando)

- App: **https://gladiators-revenge-server.fly.dev** (región `gru`, 1 máquina de
  1 GB, 2 salas).
- La web ya apunta ahí con `red/api_url` en `project.godot`, así que **CREAR SALA
  funciona sin parámetros**. Con `?api=` podés apuntar a otro servidor.
- La máquina se apaga sola cuando no hay uso (`auto_stop_machines = "stop"`):
  el primer pedido después de un rato tarda ~6 s en despertar.

Tres cosas que costaron y conviene no repetir:

1. `mad` (Madrid) está deprecada en Fly; el despliegue falla al crear la máquina.
   Región válida y cercana: `gru`.
2. La imagen necesita `RUN godot --headless --path /app --import`: sin importar
   el proyecto no existe `.godot/global_script_class_cache.cfg`, los `class_name`
   no se resuelven y el servidor no llega a abrir el puerto (Fly avisa "not
   listening on the expected address").
3. Los secretos se cargan con `fly secrets import` leyendo un archivo **sin BOM**
   y por stdin; el script ya lo hace y falla en voz alta si no puede.

## Comprobar que quedó bien

```powershell
# 1) el servicio responde
curl.exe https://<tu-servicio>/salud
# {"libres":1,"ocupadas":[],"ok":true,"reservadas":[],"salas":1}

# 2) entrega una sala en wss:// (no https://)
curl.exe -X POST https://<tu-servicio>/salas
# {"sala":1,"url":"wss://<tu-servicio>/sala/1"}

# 3) la sala se anuncia en el lobby (necesita la service key)
curl.exe "https://ntmxmaxaprmqmvhsxtmd.supabase.co/rest/v1/servidores?select=nombre,url,activo" ^
  -H "apikey: <anon>" -H "Authorization: Bearer <anon>"
```

En el juego: abrí la web con `?api=…`, pulsá **CREAR SALA** y deberías entrar con
el mensaje "Conectado como jugador 1". Al cerrar la pestaña la sala se libera y el
proceso se reinicia solo.

## Si algo falla

- **502 o el servicio no arranca en Render**: hay un `PORT` fijado a mano.
  Quitalo; Render inyecta el suyo.
- **El lobby no lista la sala**: falta `SUPABASE_SERVICE_KEY` en el servicio, o
  `SERVER_PUBLIC_URL` no es la URL pública correcta.
- **"No se pudo consultar Supabase" en la web**: revisá que el servicio tenga CORS
  (el maestro ya responde abierto) y que la web se abrió con `?api=`.
- **Una sola sala y "no hay salas libres"**: subí `SALAS` o esperá a que el grupo
  anterior salga (la reserva caduca a los 90 s).
