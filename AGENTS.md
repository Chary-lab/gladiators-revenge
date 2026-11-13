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
```

- Expected baseline: smoke **106/106**, wave sim **3/3**, net smoke A **11/11**, net smoke B **12/12**, clean 600-frame run.
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

- Only CC0 assets: KayKit 3D under `assets/kaykit/`, Kenney audio under `assets/audio/`. Keep license files with the assets and update `CREDITS.md` when adding any.
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
2. `godot --headless --script res://tests/smoke_test.gd` → 100/100
3. `godot --headless --script res://tests/wave_sim.gd` → 3/3
4. `godot --headless --quit-after 600` → no script/parse errors
5. UI change → `godot -- --captura-combate` and inspect `captura_combate.png`
6. Web change → export, serve, Edge console 0 errors. The Web menu must connect to a live `--servidor`.
7. Online change → run server + `net_smoke` + `net_smoke_b`; expect 11/11 and 12/12.

Commits use conventional Spanish messages (`feat(v2): …`, `feat(combate): …`) with no signatures. Do not commit generated builds, captures or `.godot/`.
