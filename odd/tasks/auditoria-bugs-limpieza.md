# Auditoría, bugs y limpieza — frente 1 de la mejora integral de Gladiators Revenge

Rama: `audit/bugs-limpieza` · Estrategia de entrega: `ask-on-risk` (revisar al superar ~400 líneas autoradas) · Runner: `godot --headless --script res://tests/<suite>.gd` · Commit de trabajo: `3f12dec` (`fix(audio): efectos sonoros y limpieza de codigo y assets huerfanos`)

## Specs

**S1** — Alcance autorizado de este frente, según la elección del usuario: "Auditoría + bugs (Recommended)" — "Revisión estática del código, hallazgo de errores/bugs reales y detección correcta de código y assets huérfanos. Es el punto de partida concreto y de bajo riesgo." El pedido original incluye: "vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso". Criterios: (a) informe de auditoría con hallazgos evidenciados en `ruta:línea`; (b) bugs confirmados corregidos con prueba de regresión cuando exista expectativa ejecutable; (c) huérfanos confirmados eliminados sin romper referencias por UID/`class_name`/autoload; (d) gate completo en verde: smoke 15/15, regression 170/170, wave sim 3/3, boot 600 sin errores de script/parse. Fuera de alcance de este frente: mejoras visuales, ideas de jugabilidad y optimización de rendimiento (frentes posteriores).

**S2** — Restricción permanente del proyecto, citada textualmente del pedido: "necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad". `AGENTS.md` ya la refuerza: "Do not use Warcraft/Blizzard/Valve names or art. Keep Spanish original names, lore and icons." Ningún cambio de este frente puede introducir nombres, arte o/IP de terceros; no es un objetivo a implementar aquí, sólo una restricción a respetar.

**S3** — Hallazgo de entorno: "podemos instalar godot?". Resuelto: `GodotEngine.GodotEngine` 4.7.2 instalado vía winget; binario en `C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot.exe`, versión `4.7.2.stable.official.ed1daf0bf`. La ruta que documentaba `AGENTS.md` (`...\WinGet\Links\godot.exe`) ahora existe.

## Tasks

- **T1** — S1 — ruta: delegada (`gentle-ai-explore`, sesión `ses_e16d32b12ffeg1b1fnrmg3Y2VH`) — estado: **hecho** — informe entregado: 3 GLB huérfanos confirmados por UID, 2 bugs de audio, 1 helper muerto, bloque de pedestales inalcanzable, 1 scaffold (EventBus) decidido conservar.
- **T2** — S1 — ruta: inline — estado: **hecho** — RED→GREEN: `tests/smoke_test.gd` añade check "todo efecto emitido por el juego resuelve a un stream" (RED: 171 checks, 1 fallo → `escudo`, `venta`); `SfxPlayer.gd` añade `_venta`/`_escudo` sintetizados al `match` de `_crear_por_nombre` (GREEN: 171/171). Sin assets nuevos.
- **T3** — S1 — ruta: inline — estado: **hecho** — borrados 3 GLB + 3 texturas + 6 `.import` (12 archivos, 0 refs por UID/nombre); recortadas ~46 líneas inalcanzables de pedestales en `Arena.gd` y `_emitir_evento()` en `ArenaHUD.gd`. Conservado `ArmoryPedestal.gd` y `_pedestales` (el smoke los usa como invariante "la armería no deja pedestales").
- **T4** — S1 — ruta: inline — estado: **hecho** — gate: import 0, smoke 15/15, regression 171/171, wave sim 3/3, boot 600 sin `SCRIPT ERROR`/parse. Sin cambio de UI → sin captura.

## Log

**L1** — Pedido original del usuario (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — El usuario eligió el frente de arranque (verbatim): "Auditoría + bugs (Recommended)". Los demás frentes (identidad visual, ideas/jugabilidad, optimización/deuda) quedan en la cola, en ese orden, para entregas posteriores.

**L3** — 2026-11-17 — Entorno: Godot no estaba instalado; se instaló `GodotEngine.GodotEngine` 4.7.2 con `winget install --id GodotEngine.GodotEngine --version 4.7.2`. El usuario preguntó "podemos instalar godot?" y eso autorizó la instalación.

**L4** — 2026-11-17 — Baseline verificado en `main` antes de cualquier cambio: import `--headless --editor --quit` exitoso; smoke **15/15**; regression **170 comprobaciones, 0 fallos** (AGENTS.md decía 160, el número real es 170); wave sim **3/3**; boot 600 sin `SCRIPT ERROR`/parse errors. No hay bugs evidentes que salten en la suite.

**L5** — 2026-11-17 — Se creó la rama `audit/bugs-limpieza` desde `main` (estado limpio salvo `tools/mcp.sh` sin trackear, preexistente y ajeno a este frente). No hay `.atl/skill-registry.md` en el repo, así que no se pasaron skills de proyecto a los delegados.

**L6** — 2026-11-17 — T1 delegado al explorador de solo lectura `gentle-ai-explore` (sesión `ses_e16d32b12ffeg1b1fnrmg3Y2VH`). Resultado pendiente.

**L7** — 2026-11-17 — Decisión sobre `EventBus.pausa_solicitada`/`partida_iniciada`: NO se tocan. Se emiten sin suscriptor, pero `EventBus.gd` los declara como scaffold explícito de fases futuras y `AGENTS.md:82` prohíbe que `GameManager` maneje `Pausa` para no duplicar el contador. Cortarlos sería quitar API pública de un contrato que otros sistemas consumirán; no hay evidencia de fallo. Queda como follow-up documentado, no como bug corregido.

**L8** — 2026-11-17 — Decisión sobre `ArmoryPedestal.gd`: NO se borra el archivo ni el `class_name`. Aunque nunca se instancia, es un `class_name` registrado en el cache global y citado en `AGENTS.md`/`README.md` como parte del diseño. Se recortó sólo el código inalcanzable que operaba sobre `_pedestales` (siempre vacío); se conserva la declaración porque el smoke la lee como invariante.

**L9** — 2026-11-17 — Work-unit commit `3f12dec` (16 archivos, +26/−316). Git no tenía identidad configurada; se fijó `Chary-Lab <recargarcod@gmail.com>` **sólo a nivel local del repo**, igual a los commits existentes, para no inventar una identidad ajena. `tools/mcp.sh` sigue sin trackear (preexistente, ajeno a este frente).

**L10** — 2026-11-17 — Assess RDD (`gentle-ai review assess --base-ref 033242f --committed-only`): primer intento `unassessable` por los untracked (`odd/`, `tools/mcp.sh`); re-corro con `--untracked-scope=exclude` → **`risk: medium`, `review_due: false`, reason `under_budget`**, 16 paths / 342 líneas. Sin ítem de alto riesgo nombrado → no corresponde verifier independiente; el gate propio es la verificación aplicable.

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · Estado: **entregado** · Commit: `3f12dec` · Assess: medium/under_budget (sin review obligatoria)
