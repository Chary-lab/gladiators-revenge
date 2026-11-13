# Cooperativo online — implementación

El juego ya tiene un modo cooperativo online autoritativo para **hasta 3
jugadores** (una clase distinta por persona). El servidor ejecuta la arena; los
clientes solo envían intenciones y renderizan snapshots.

## Arquitectura

```
Cliente Web / APK ── WSS ──▶ Servidor Godot headless
        │                         │
        │  acciones (mover,       │  Arena completa: jugadores, oleadas,
        │  Q/W/E/R, objetos,      │  enemigos, jefe, estandarte, economía,
        │  tienda, talentos)      │  inventario y talentos
        ◀── snapshots binarios 15 Hz ─┘
```

- `scripts/net/NetCoop.gd` — `WebSocketPeer` (compatible con Web/APK): mensajes
  de control JSON y snapshots binarios con `var_to_bytes`.
- `scripts/game/Arena.gd` — modos `--servidor`, `--cliente=…` y partida local.
- `scripts/ui/MenuRed.gd` — menú de Web/APK: jugar solo o unirse por URL.
- `scripts/ui/TooltipRico.gd` — tooltip flotante con icono, BBCode y animación.
- `GladiatorController` tiene un modo espejo (`es_espejo`) que interpola la
  posición del servidor y reenvía los inputs.
- `ArenaEnemy`, `ArenaBossAI` y el estandarte se replican como proxies de solo
  lectura en el cliente.

## Reglas de la partida

- Una clase por jugador y partida. El servidor rechaza repetir clase y también
  rechaza cambiar de clase después de elegir.
- Al elegir campeón, los demás pedestales se apagan para ese jugador; las clases
  ocupadas se ocultan también para el resto.
- El servidor es la autoridad de daño, curación, oro, XP, oleadas y compras.
- La economía y los puntos de atributo son compartidos por el equipo; cada
  jugador mantiene su inventario, talentos y rangos de habilidad.
- Si un jugador muere y queda al menos un compañero vivo, entra en cuenta atrás
  de 10 s (≈4 s si un aliado está a menos de 4 m). Al revivir reaparece junto al
  aliado más cercano con el 60 % de vida y conserva nivel, talentos e inventario.
  Si todos caen, la partida termina.

## Registro de servidores en Supabase

El servidor puede anunciarse en Supabase para que Web/APK lo descubran sin
escribir la URL:

- Migración: [`../supabase/migrations/0001_coop.sql`](../supabase/migrations/0001_coop.sql).
- Servidor: `SUPABASE_SERVICE_KEY` + `SERVER_PUBLIC_URL` en variables de entorno.
  Hace `upsert` en `servidores` cada 20 s y guarda el resultado en `partidas`.
- Cliente: `supabase/url` + `supabase/anon_key` en `project.godot`; el menú
  lista los servidores activos y permite entrar con un clic.
- RLS: lectura pública de servidores activos y partidas; escritura solo con
  `service_role`. El cliente nunca conecta directamente a PostgreSQL.

Detalle: [`../supabase/README.md`](../supabase/README.md).

## Ejecutar en local

```powershell
# Servidor autoritativo
godot --headless -- --servidor --puerto=9080

# Cliente de escritorio
godot -- --cliente=ws://127.0.0.1:9080

# Servidor con oleadas rápidas para pruebas
godot --headless -- --servidor --puerto=9080 --red-rapida
```

En Web y APK aparece el menú inicial. También se puede entrar directo desde la
URL web:

```
https://tu-pagina/?servidor=wss://tu-servidor.example.com
```

El valor por defecto se configura en `project.godot` con
`red/servidor_url`.

## Crear sala desde el juego

En Web/APK (y en escritorio con `--menu-red`) el menú de red tiene tres acciones:
**JUGAR SOLO**, **CREAR SALA** y **UNIRSE A PARTIDA**. El botón **CREAR SALA**
hace todo sin que el host instale nada a mano:

1. Si falta, descarga `cloudflared` a `user://bin` (una sola vez, ~55 MB) y lo
   reutiliza en las siguientes partidas.
2. Abre un túnel HTTP rápido de Cloudflare contra `http://localhost:9080` y lee
   la URL `wss://…trycloudflare.com` de su registro.
3. Lanza un `godot --headless -- --servidor --puerto=9080 --publico=<url>` que se
   anuncia solo en Supabase (latido cada 20 s).
4. Mete al host como cliente por `ws://127.0.0.1:9080` (sin pasar por internet).

Los demás jugadores ven la sala en la lista del menú y entran con un clic. Al
terminar la partida, el botón **TERMINAR** (solo el host) cierra la escena, mata
el servidor y el túnel y borra la sala de Supabase: al salir del juego también se
apagan ambos procesos.

La clave de servicio que necesita el servidor para escribir en Supabase se toma
de `SUPABASE_SERVICE_KEY` o, si no existe, de `user://supabase.local.cfg` (texto
plano con la clave). El juego la pasa al servidor con `--clave-supabase=…`; nunca
se guarda en el repo, en `project.godot` ni en el cliente exportado.

`crear_sala.ps1` sigue disponible para hostear desde una consola sin abrir el
juego (útil en un equipo dedicado).

## Pruebas de red

```powershell
# Terminal 1
godot --headless -- --servidor --puerto=9080 --red-rapida

# Terminal 2 (jugador A)
godot --headless --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:9080 --esperar=12

# Terminal 3 (jugador B)
godot --headless --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:9080
```

Cubren conexión, snapshots, movimiento autoritativo, compra sincronizada, clase
única por jugador, clase única entre jugadores, enemigos y oleadas.

## Despliegue del servidor

El repo incluye `Dockerfile`, `fly.toml` y `render.yaml`.

### Fly.io

```powershell
fly launch --no-deploy
fly deploy
```

Fly termina TLS: los clientes usan `wss://<app>.fly.dev`.

### Render

Crea un **Web Service** con el `Dockerfile` del repo. Render inyecta `PORT` y el
contenedor arranca el servidor en ese puerto. Los clientes usan
`wss://<servicio>.onrender.com`.

### Docker genérico

```powershell
docker build -t gladiators-server .
docker run --rm -p 9080:9080 -e PORT=9080 gladiators-server
```

Sirve el servidor detrás de un proxy con TLS para que el navegador pueda usar
`wss://`; `ws://` solo funciona en local o en redes de confianza.

## Límites actuales

- Las invocaciones del Cetro (`SpiritSummon`) y los números de daño flotantes no
  se replican todavía; el daño se refleja en las barras de vida.
- Los efectos de habilidad se dibujan en los clientes, pero no aplican daño
  local: el servidor sigue siendo la autoridad.
- El servidor no persiste la partida: si el proceso se reinicia, empieza de
  nuevo. Tampoco hay reconexión a mitad de oleada.
- La tienda y los talentos se validan en servidor; las respuestas llegan con el
  siguiente snapshot (hasta 100 ms de latencia visual).
