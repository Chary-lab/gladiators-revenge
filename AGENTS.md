# Gladiators Revenge — agent notes

Godot 4.7 / GDScript arena survival, GL Compatibility, Web/HTML5 target. Code, comments and UI are Spanish. IP and names are original; code is MIT, art/audio is CC0.

## Repo reality

- The git repo is `D:\Orc Gladiators`. `D:\Opencode` is only the OpenCode runtime, not this project.
- `scenes/main.tscn` is just a `Node3D` root with `Arena.gd`. `scripts/game/Arena.gd` builds the map, safe zone, navmesh, player, camera, waves, HUD and shops **in code**. Edit scripts, not a scene tree.
- Composition root is `scripts/game/Arena.gd`; HUD is `scripts/ui/ArenaHUD.gd`; wave state is `scripts/game/WaveManager.gd`.
- `tests/inspect_crear_sala.gd` is a manual probe of the Cloudflare tunnel (needs network); `tests/inspect_lobby.gd` probes the Supabase lobby (lista de servidores tal como la ve el menú). Neither is part of the suite. The rest of `tests/` is: `smoke_test.gd`, `wave_sim.gd`, `net_smoke.gd` (client A) and `net_smoke_b.gd` (client B).

## Commands

Run from the repo root. `godot` resolves to the winget shim; if missing, use `C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot.exe`.

```powershell
godot --version
godot --headless --editor --quit           # import after new assets/scripts
godot --headless --script res://tests/smoke_test.gd
godot --headless --script res://tests/wave_sim.gd
godot --headless --script res://tests/balance_report.gd   # tabla de balance (no es prueba)
godot --headless --quit-after 600          # normal boot smoke run
godot --headless -- --servidor --puerto=9080 [--red-rapida]
godot -- --cliente=ws://127.0.0.1:9080
godot --headless --script res://tests/net_smoke.gd -- --cliente=ws://127.0.0.1:9080 --esperar=40
godot --headless --script res://tests/net_smoke_b.gd -- --cliente=ws://127.0.0.1:9080
godot --headless --script res://tests/inspect_crear_sala.gd   # sonda del túnel (red real)
godot -- --captura-combate                 # windowed screenshot to captura_combate.png
godot -- --captura-menu                    # lobby (fuerza el menú de red)
godot -- --captura-campeon                 # forja de campeones con vitrina 3D
godot -- --captura-apodo                   # modal de apodo
```

- Expected baseline: smoke **133/133**, wave sim **3/3**, net smoke A **11/11**, net smoke B **12/12**, clean 600-frame run.
- Net smoke B necesita a A **conectado a la vez**: arranca el servidor, lanza A con `--esperar=40` y 5 s después B. En solitario, B falla lobby, clases y revivir porque no hay compañero (no es una regresión).
- En `--headless` los fotogramas corren a miles por segundo: `await process_frame` no espera nada. Los tests esperan con `create_timer(0.01)` (`_esperar_hasta`) o `create_timer(segundos)`.
- Exit warnings about 2–4 resources still in use come from audio/SceneTree teardown and are known. Fail on `SCRIPT ERROR`, parse/compile errors or failed checks.
- `--script` mode does **not** register autoloads. `Sfx` is a static `RefCounted`; do not convert it to an autoload.
- There is no unit-test framework. Add checks inside `tests/smoke_test.gd` or create another `SceneTree` script and run it with `--headless --script`.
- Do not run smoke and wave sim concurrently; both instantiate the full arena.
- Captures are real-time: `--quit-after` can end the process before the capture timer. Use the capture command without it.

## Architecture invariants

- `scripts/core/GladiatorStats.gd` is the single source for damage/heal/shield scaling. New abilities and items must call its `escalar_dano`, `escalar_invocacion` or getters; do not hardcode final damage.
- Weapon stats use `aplicar_bonos_equipo`; inventory stats use `aplicar_bonos_inventario`. Both are dictionary bonuses summed by `_bono()`.
- `GladiatorController.gd` owns input, movement, autoattack, ability casting, level unlocks, ability ranks and talents.
- `WeaponItem.gd` owns the four-slot class kit and `_configurar_rangos()`: Q/W/E max rank 4, R max rank 3. Rank descriptions and numeric improvements must stay in sync.
- Progression: level 1 unlocks a random Q/W/E; levels 2–3 unlock the rest; R at 6. Every level-up grows the class stats automatically and upgrades one random unlocked ability; there are no manual skill points. XP curves live only in `scripts/core/CurvaNivel.gd` (`80+40L+6L²` per level, `80+55w+4w²` per wave).
- The chosen champion/class is permanent for the run. Choosing one disables the other armory pedestals (`ArmoryPedestal.desactivar()`), so the choice disappears for that player.
- Team contract: `gladiadores` = player, `aliados` = summons, `enemigos` = hostile, `banderas` = objectives. `SpiritSummon`/`SpiritBolt` must stay in `aliados` and must never join `enemigos`; enemy AI ignores allies.
- Item/recipe data lives in `scripts/items/ItemCatalog.gd`; inventory slots and auto-forge in `InventoryComponent.gd`. Purchases/forging are only allowed in the safe zone during preparation.
- Online co-op is server-authoritative: `scripts/net/NetCoop.gd` uses `WebSocketPeer` with JSON control messages and **15 Hz binary snapshots** (`var_to_bytes`; browser-compatible). Clients are render-only mirrors (`es_espejo`) and forward actions; never apply damage/purchases locally in client mode.
- The server must create `GameState` too (`_crear_estado_partida()` is called from both `_iniciar_local` and `_iniciar_servidor`). Without it the headless server throws `Invalid access to property 'oro' on Nil` on wave rewards and shop purchases, so gold and buying silently break in co-op.
- `_al_morir_jugador(caido)` receives the fallen body through `murio.connect(...bind(cuerpo))`: the `murio` signal fires **before** the controller copies `esta_muerto`, so reading the flag of the body that just died counts it as alive and the revive countdown never starts.
- Test-only actions (`debug_morir`, `debug_curar`, `debug_base`) run before the dead-player filter in `aplicar_accion_red` and only with `--red-rapida`. `debug_base` returns the gladiator to the fountain so the shop can be tested while waves are running.
- Revive: a dead player with a living teammate counts down 10 s (2.5× faster within 4 m) and revives next to the nearest ally at 60 % HP, keeping inventory/talents/level. All players dead still ends the run. Server action `debug_morir`/`debug_curar` only works with `--red-rapida` for tests.
- Sala de espera: `WaveManager.en_espera()` y `asegurar_preparacion(segundos)` mantienen la cuenta atrás de 30 s antes de la primera oleada; si alguien entra con menos de 8 s, `agregar_jugador_red` la alarga. `ArenaHUD.establecer_lobby(visible, segundos, jugadores, maximo, es_local)` dibuja el panel central (título, cuenta atrás grande y "N/3 gladiadores").
- El menú de red ya no pide URL a mano: lista de salas + JUGAR SOLO + CREAR SALA. Para entrar a una sala se pulsa su botón en la lista.
- Interfaz: `scripts/ui/ForjaTema.gd` es el sistema de diseño completo. Define la paleta (carbón, oro, ascua), `COLOR_RAREZA`/`NOMBRE_RAREZA` (común, raro, épico, legendario), la tipografía **Cinzel** (`assets/ui/Cinzel-variable.ttf`, SIL OFL; `fuente_titulo()`, `fuente_etiqueta()`) y `tema_global()`, que `Arena._ready` asigna a `get_tree().root.theme` para que todo `Control` lo herede. Piezas: `estilo_panel`, `estilo_ventana`, `estilo_tarjeta`, `BarraSegmentada`, `Emblema`, `AroRunas`, `VeloRadial`, `IconoStat`, `EsquinasOrnadas` (`ornar()`). Una pantalla nueva compone estas piezas; no define su propia paleta ni su propia fuente.
- Fondos: `scripts/ui/FondoForja.gd` dibuja degradado, resplandor de ascua, aros de arena y brasas (sin shaders, redibujo a 30 fps). Un `Control` hijo de un `CanvasLayer` **no** hereda el tamaño del viewport: `FondoForja` sincroniza su `size` en `_process` desde el padre; sin eso queda en 0x0 y la pantalla se ve transparente.
- Vitrina 3D: `scripts/ui/VitrinaCampeon.gd` (SubViewport propio, tres luces, giro de presentación) muestra al gladiador de cuerpo entero en el lobby y en la forja de campeones. No se construye en headless (`DisplayServer.get_name() == "headless"`), así que las pruebas no pagan el coste de instanciar GLB. La cámara se orienta con `look_at_from_position()`: `look_at()` antes de entrar al árbol falla con "Node not inside tree".
- Arranque local: `Arena._iniciar_local()` llama a `_pedir_apodo_y_campeon()` (no lo hace `_ready`, porque en Web/APK se entra por el lobby). Si `Perfil.apodo()` está vacío abre `NombreJugador` (CanvasLayer 62, campo `LineEdit`, 2–14 caracteres) y después la forja; el apodo se guarda en `user://perfil.cfg` y encabeza la ficha del HUD. `Perfil.normalizar()` filtra símbolos y conserva acentos.
- La elección de campeón **no existe en el mapa**: `_crear_armeria()` no crea pedestales ni etiquetas (sólo es un no-op) y `_al_elegir_campeon()` equipa el arma del catálogo directamente (`equipar_arma`), sin coste y sin segunda elección. Si se cierra la forja sin clase, no hay `VOLVER` ni Esc: la elección es obligatoria.
- Coop: el cliente no corre `WaveManager` (`set_process(false)` en `_iniciar_cliente()`), así que **nunca** leas `_oleadas.tiempo_preparacion()` en cliente: el snapshot trae `espera`, `prep` y `conectados`, y `_actualizar_lobby()` pinta la sala de espera con esos valores. Sin eso la cuenta atrás se quedaba clavada en 11 s y la partida parecía trabada. La capa táctil se crea también en `_iniciar_cliente()` (`_crear_controles_tactiles()`) y la forja se abre en `_al_recibir_bienvenida()`: en una sala el móvil entró con HUD de escritorio y sin joystick.
- La espera inicial son 30 s; `WaveManager.acortar_preparacion(segundos)` la recorta cuando ya hay campeón (local en `_al_elegir_campeon()`, en red cuando todos los conectados tienen clase, `equipar_clase_red()`). `asegurar_preparacion()` sólo alarga.
- En cliente `game_state` es `null`: la bolsa es `oro` (snapshot). `puede_comprar_para()` usa `game_state.oro` si existe y si no `oro`; sin ese corte, abrir la tienda mientras llega un snapshot lanzaba `Invalid access to property 'oro' on Nil`.
- HUD de combate: la barra superior es un solo `Panel` (`_barra_superior`) con oleada/cuenta atrás/enemigos, estandarte y la **ficha del jugador** (`_ficha_jugador`: apodo, `Nv`, `ABATIDOS`, oro). El oro cuenta hacia arriba con un `lerp` en `_process` y la ficha da un pulso al cambiar; las bajas dan un pulso en `_bajas_jugador`. `WaveManager` lleva `bajas` y emite `enemigo_abatido(total)`; `Arena._crear_hud()` lo conecta a `ArenaHUD.establecer_bajas()`. No hay panel de estadísticas ni "PUNTOS": el octavo comando abre la forja.
- Sala de espera: `ArenaHUD.establecer_lobby()` dibuja **sólo texto sin fondo** ("PREPÁRATE PARA LA SIGUIENTE OLEADA", cuenta atrás y "La oleada empieza en unos segundos"): nada de panel central tapando la arena.
- Lobby/forja: `MenuRed` monta el lobby atmosférico (campeón en vitrina, salas como tarjetas, estado de red arriba) y `SeleccionCampeon` la ficha RPG de tres zonas (riel de clases, vitrina, ficha con nivel/atributos/estadísticas/habilidades/equipo). Los perfiles de clase salen de `Arena._perfiles_campeon()`: cualquier campo nuevo (tinte, arma visual, xp_requerida, habilidades con `id`) se agrega ahí y la pantalla lo consume.
- HUD de combate: la barra superior es un solo `Panel` (`_barra_superior`) con oleada/cuenta atrás/enemigos, estandarte, oro/puntos y la lengüeta `_overlay` colgando abajo a la izquierda (deja libre la sala de espera, que arranca en x=268). Las ranuras del inventario usan el marco del color de rareza del objeto.
- Tienda: `ShopPanel` tiene filtros por categoría/rareza (`_filtro`, `_chips`, `_pasa_filtro`), tarjetas con franja de rareza y placa de estado (`_estado_carta`: xN, NUEVO, EN MOCHILA, FORJABLE). El filtro por defecto es `&"todo"`, así la cuadrícula muestra el catálogo completo y las pruebas que cuentan tarjetas siguen valiendo.
- HUD táctil: `TouchControls` dibuja una rueda con **INTERACTUAR en el centro** y Q/W/E/R alrededor (`CENTRO_RUEDA`, `RADIO_RUEDA`, `ANGULOS`), enfriamiento radial (`_velos`) y segundos (`_cd_textos`), pastilla de vida/maná con nivel, accesos MERCADER/TALENTOS/MOCHILA y mochila propia. `Arena._crear_controles_tactiles()` llama a `ArenaHUD.establecer_modo_tactil(true)`: en móvil se apaga la consola de escritorio (minimapa, retrato, ficha, inventario y parrilla QWER) y la pantalla queda despejada. El modo táctil sólo se activa con pantalla táctil o `--tactil`; el resto (menús, forja, tienda, HUD superior) es idéntico en Web y APK.
- Selección de campeón: `scripts/ui/SeleccionCampeon.gd` (CanvasLayer 55) se abre al empezar la partida local si no hay clase (`Arena._mostrar_seleccion_campeon`), recibe `_perfiles_campeon()` con vida/maná/daño/defensa calculados desde `GladiatorStats` y el arma de la clase, y al confirmar equipa por la misma vía que el pedestal (`pedestal.comprar`) o pide clase al servidor. `--captura-campeon` la fotografía.
- Táctil: `scripts/ui/TouchControls.gd` tiene joystick (base + perilla, emite `mover(direccion)`), Q/W/E/R y DETENER/INTERACTUAR. El gladiador usa `mover_tactil(direccion)` (movimiento directo, sin navegación) y en red el cliente manda la acción `mover` a ~8 Hz mientras se mantiene la dirección.
- Ajustes: `scripts/core/Ajustes.gd` (user://ajustes.cfg) guarda `volumen` y `escala_tactil`; `SettingsPanel` los edita desde el menú. `Arena._ready` los carga y aplica (bus Master y escala del joystick/botones).
- Actualizador: `scripts/net/Actualizador.gd` consulta el último release de GitHub y, si `tag_name` es mayor que `config/version`, el menú muestra "Nueva versión vX · tocar para descargar" (abre el release; no instala solo: eso requiere plugin nativo de Android).
- Fin de partida: `ArenaHUD.mostrar_final(texto, puede_reintentar)` abre un panel con DERROTA/VICTORIA, el detalle y los botones VOLVER A JUGAR / SALIR AL LOBBY (señales `reintentar` y `salir_lobby`). `Arena.volver_al_menu` (estática) fuerza el menú al recargar. (CanvasLayer 40) se crea desde `Arena._crear_controles_tactiles()` cuando `DisplayServer.is_touchscreen_available()` o con `--tactil`. Dibuja en coordenadas de diseño 1280x720: Q/W/E/R en 2x2 arriba de la consola, más DETENER e INTERACTUAR. Las habilidades se lanzan con `intentar_habilidad(slot, _punto_habilidad())`, que apunta al enemigo más cercano (o al frente si no hay). El movimiento sigue siendo "tocar el suelo" (el toque se traduce en clic izquierdo = atacar-moverse).
- UI: `TooltipRico` (CanvasLayer 60) renders rich hover cards for commands/abilities/items; `ShopPanel` uses visual cards with rarity/hover/detail. Keep both mouse-transparent and pause-process for the shop.
- One class per player and match: the server enforces `clases_ocupadas`/`clase_por_peer`; choosing disables the other pedestals for that player. Do not allow class changes after selection.
- `Arena` supports local, `--servidor` and `--cliente=…` modes. Server runs `Arena` + `WaveManager`; client builds world/UI and applies snapshots in `_aplicar_snapshot`.
- `Sfx.reproducir` is a no-op in headless to keep the server/tests silent; do not remove that guard.
- `Supabase` lee `supabase/url`, la anon key y `--clave-supabase` en `_init()`, no en `_ready`: `MenuRed` y `_iniciar_servidor` crean el nodo y lo usan en el mismo fotograma, así que con `_ready` la primera consulta del lobby (y el anuncio de la sala) fallaban en silencio.
- Web/APK start in `MenuRed` (Jugar solo / CREAR SALA / Unirse). Web can auto-join with `?servidor=wss://…`; desktop uses `--cliente=`. The **CREAR SALA** button (`scripts/net/CrearSala.gd`, desktop only) downloads `cloudflared` into `user://bin` on first use, opens a quick Cloudflare tunnel against `http://localhost:9080` (never `tcp://`: the browser needs the WebSocket upgrade over TLS), launches `godot --headless -- --servidor --publico=<wss url>` and joins the host through `ws://127.0.0.1:9080`. `Arena._exit_tree` and the TERMINAR button kill both processes.
- The server needs `SUPABASE_SERVICE_KEY` to announce the room; the game passes it as `--clave-supabase=…`, read from the env or from `user://supabase.local.cfg`. Never commit it, never put it in `project.godot` or the exported client.
- Server deployment: `Dockerfile`, `fly.toml`, `render.yaml`; TLS is terminated by the host, clients use `wss://`. El contenedor arranca `--maestro` (no `--servidor`): `scripts/net/MaestroSalas.gd` escucha en `PORT`, levanta `SALAS` procesos de sala en `puerto-base+n` y enruta `GET /sala/<n>` con proxy TCP puro (el handshake lo hace la sala). `POST /salas` reserva con caducidad de 90 s y `GET /salud` es el health check; `OPTIONS` responde CORS abierto.
- El `Dockerfile` importa el proyecto (`--import`) antes de arrancar: sin `.godot/global_script_class_cache.cfg` los `class_name` no existen, Arena.gd no compila y el contenedor no abre el puerto. Si tocás scripts y el deploy deja de escuchar, revisá ese paso.
- La sala se reinicia al desconectarse el último cliente, así el siguiente grupo empieza limpio. Cada sala es un proceso de ~180 MB: 512 MB = 1 sala.
- En Web/APK `CREAR SALA` usa `SalaRemota` (POST /salas) porque el navegador no puede abrir puertos; en escritorio sigue el túnel de `CrearSala`. La API se resuelve por `--api=`, `SALA_API`, `?api=` o `red/api_url`.
- `HTTPRequest` **no funciona en la build Web** (falla con código 0 sin llegar a la red): en `OS.has_feature("web")` hay que usar `JavaScriptBridge` + `fetch` (ver `Supabase._peticion_web` y `SalaRemota._crear_web`).
- Supabase is optional infrastructure: client uses `anon` key + RLS to list `servidores`; only the headless server uses `SUPABASE_SERVICE_KEY` from env. Never put the service key or the Postgres connection string in the client, `project.godot` or git. Migration: `supabase/migrations/0001_coop.sql`.

## UI / rendering gotchas

- `ArenaHUD.ALTO_CONSOLA` is **185 px** and the README matches. Console layout is five modules: square minimap, live portrait + HP/MP, merged gladiator card (combat + attributes), 2×3 inventory, 4×3 command/ability grid. Buttons are icon-only by design; key badges sit top-left and ability ranks show as gold pips.
- `IconStudio.gd` renders 64×64 `SubViewport` thumbnails with `UPDATE_ONCE` and caches them. `ItemModelFactory.gd` builds the original primitive models. In `--headless` they fall back to procedural icons, so smoke tests do not prove the visual result.
- This project uses **GL Compatibility**. Do not use screen-space AA (FXAA/TAA) or Forward+/Mobile-only features; `screen_space_aa` caused browser console errors. MSAA is fine.
- After UI changes, verify with a windowed `--captura-combate`; after export, verify in Edge with zero console errors.

## Assets / content rules

- Only CC0 art/audio: KayKit 3D under `assets/kaykit/`, Kenney audio under `assets/audio/`. The only exception is the interface font: Cinzel under `assets/ui/` (SIL OFL, license file alongside). Keep license files with the assets and update `CREDITS.md` when adding any.
- Do not use Warcraft/Blizzard/Valve names or art. Keep Spanish original names, lore and icons.
- Web budget is roughly 47 MB / 9 files today; keep the build comfortably below ~60 MB.

## Web build and browser check

```powershell
godot --headless --export-release "Web" "build/web/index.html"
Remove-Item build\web\*.import -ErrorAction SilentlyContinue
node "C:\Users\Administrator\.config\opencode\skills\web-test\scripts\serve.mjs" "D:\Orc Gladiators\build\web" 8137
playwright-cli.cmd open http://127.0.0.1:8137/ --browser msedge
```

- `file://` will not load the Web build; always use the static server.
- Use `playwright-cli.cmd`, not the blocked `.ps1`. For canvas clicks, `mousemove` + `mousedown`/`mouseup` is reliable; `click x y` can misinterpret the Y coordinate as a button.
- Export creates `build/web/*.import` files; remove them before serving/committing. `build/`, `captura*`, `.godot/` and `*.wasm` are ignored.
- `git push` may print “repository moved” on native stderr and return a non-zero PowerShell status even when the push worked. Verify with `git ls-remote origin refs/heads/main`, not `$LASTEXITCODE` alone.

## Verification gate

1. `godot --headless --editor --quit`
2. `godot --headless --script res://tests/smoke_test.gd` → 133/133
3. `godot --headless --script res://tests/wave_sim.gd` → 3/3
4. `godot --headless --quit-after 600` → no script/parse errors
5. UI change → `godot -- --captura-combate` and inspect `captura_combate.png`
6. Web change → export, serve, Edge console 0 errors. The Web menu must connect to a live `--servidor`.
7. Online change → run server + `net_smoke` + `net_smoke_b`; expect 11/11 and 12/12.

Commits use conventional Spanish messages (`feat(v2): …`, `feat(combate): …`) with no signatures. Do not commit generated builds, captures or `.godot/`.
