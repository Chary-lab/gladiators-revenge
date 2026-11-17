# Extraer ArenaMundo del god object Arena.gd — deuda técnica

Rama: `main` (desde `dd1b9a9`, tras el merge del PR #1) · Estrategia: `ask-on-risk` · Runner: `godot --headless --script res://tests/<suite>.gd`

## Specs

**S1** — Deuda documentada (`AGENTS.md:139`, `odd/tasks/optimizacion-deuda.md` L4): `Arena.gd` es un god object; el bloque de **construcción del mundo** es autocontenido (0 señales, 0 call sites externos) y puede extraerse a un nodo `ArenaMundo`.

**S2** — Pedido del usuario (verbatim): "pues hagamoslo" — autoriza ejecutar la extracción pendiente.

**S3** — Restricciones críticas (del mapeo de `ses_e16a31da7ffeWm3Z7geoQRxY3i`):
- El bloque toca `NavigationRegion3D`, colisiones y orden de `add_child` → **no hay tests que cubran la jerarquía del mundo**.
- Debe propagarse: `_puntos_spawn`, `_fuente`, `_obelisco` (usados en varias partes de Arena).
- `smoke_test.gd` lee getters de subsistemas (`escena.get("_oleadas")` etc.) y `SKINS` — mover eso rompería tests.
- **Orden de trabajo obligatorio**: primero añadir tests de jerarquía del mundo (RED), luego extraer (GREEN). Verificación: import → smoke → regression → wave sim → boot → capturas `--captura-combate`/`--captura-arquetipos`.

## Tasks

- **T1** — S1-S3 — ruta: inline — estado: ✅ — interfaz: `ArenaMundo.construir(padre, fuente, obelisco)` estático; `puntos_spawn: Array[Vector3]` público. `_fuente`/`_obelisco` siguen en Arena (los usa para interacción/curación/pistas) y se pasan al construir.
- **T2** — S3 — ruta: inline — estado: ✅ — 6 checks RED en `smoke_test.gd` (nodo Mundo, NavigationRegion3D, suelo colisión, 4 spawns, etiquetas FUENTE/TALENTOS, WorldEnvironment único). RED: 179 checks, 1 fallo (el nodo no existía).
- **T3** — S1-S3 — ruta: inline — estado: ✅ — `ArenaMundo.gd` creado con todo el bloque (entorno/suelo/muros/decoración/zona segura + utilitarios `_material`/`_crear_prop`/`_crear_caja_estatica`/`_instanciar_prop`/`_etiqueta_mundo`). `Arena._ready` usa `ArenaMundo.construir(self, _fuente, _obelisco)` y copia `puntos_spawn`. Recortadas 351 líneas de Arena.gd (2777→2426), cero referencias muertas.
- **T4** — S3 — ruta: inline — estado: ✅ — GREEN: 184/184 (178+6). Gate: import 0, smoke 15/15, regression 184/184, wave sim 3/3, boot limpio. Capturas `--captura-combate` y `--captura-arquetipos` inspeccionadas: **idénticas** a las del frente visual (sólo varía el azar del spawn de enemigos).
- **T5** — S1-S3 — ruta: inline — estado: ✅ — commit `00de5f9` (5 archivos, +452/−357; el amend añadió el `.uid`). Assess RDD con base `dd1b9a9`: `risk: medium`, `review_due: false`, reason `under_budget`, 810 líneas cambiadas. Sin verifier independiente: los 6 checks RED→GREEN cubren precisamente lo que el refactor podía romper (NavMesh/colisiones/spawns/etiquetas/luces), y las capturas son idénticas.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Los 4 frentes se completaron y mergearon a `main` (PR #1, merge commit `dd1b9a9`). Quedó documentada la deuda de extraer `ArenaMundo` con tests de jerarquía primero.

**L3** — 2026-11-17 — Usuario: "pues hagamoslo" → autoriza ejecutar la extracción. Se respeta la regla de tests-first del frente anterior (S3).

**L4** — 2026-11-17 — Se respetó el orden tests-first: los 6 checks de jerarquía se escribieron y vieron fallar (RED 179/1) ANTES de conectar el nodo. Así una regresión silenciosa de NavMesh/colisiones se vuelve visible. `ArenaMundo` es un `Node3D` hijo directo (nombre "Mundo"), sin señales ni dependencias de sistemas vivos.

**L5** — 2026-11-17 — Decisión: `_fuente`/`_obelisco` NO se movieron a ArenaMundo porque Arena los usa fuera del bloque (curación en 692/1223, interacción en 2100-2104/2281-2283, pistas). Se pasan por parámetro al construir. `_puntos_spawn` sí lo calcula ArenaMundo y Arena lo copia para `WaveManager.iniciar` (1625). Constantes ANCHO/LARGO/ALTO_MURO/BORDE_ARENA/CENTRO_ARENA se duplicaron en ArenaMundo (valores idénticos) para desacoplar — son datos dimensionales, no lógica.

**L6** — 2026-11-17 — Deuda saldada: `Arena.gd` pasó de 2777 a 2426 líneas (351 menos) y el mundo está aislado en `ArenaMundo.gd`. La deuda queda cerrada; si en el futuro se extraen más bloques del god object, se aplica el mismo patrón (tests de jerarquía primero).

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · T5 → ✅ · Estado: **COMPLETO** · Commit: `00de5f9` · Pendiente: push/PR (decisión del usuario).
