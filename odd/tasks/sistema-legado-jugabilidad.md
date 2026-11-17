# Sistema original de jugabilidad — frente 3

Rama: `visual/identidad-arena` (misma rama de trabajo; push al final) · Estrategia: `ask-on-risk` · Runner: `godot --headless --script res://tests/<suite>.gd`

## Specs

**S1** — Pedido original (verbatim): "vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso" y "necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad". El frente de ideas/jugabilidad debe aportar **originalidad con sello propio**, sin copiar WC3.

**S2** — Decisión del usuario (verbatim de la opción elegida): "Un sistema nuevo con sello propio (Recommended)" — "Añadir una mecánica transversal original (por ejemplo: 'Renegados' — oleadas de élite con招募 que cambian el ritmo, o un sistema de 'Legado' entre oleadas). Lo diseño acotado, con tests y docs, sin tocar el balance base."

**S3** — Restricciones de arquitectura (AGENTS.md): no tocar tablas de balance existentes (`BalanceOlas.PERFILES`, `ArenaEnemy.ARQUETIPOS`), no cambiar el formato de snapshots de red sin necesidad, mantener `GladiatorStats` como única fuente de escalado, y añadir checks en `smoke_test.gd`/`regression_test.gd`. El sistema debe ser observable de forma determinista en tests.

## Tasks

- **T1** — S1-S3 — ruta: inline (mapeo delegado `gentle-ai-explore`, sesión `ses_e16abe75affeYFQ12s8zYKbH2j`) — estado: ✅ — mapa: `WaveManager.oleada_terminada`/`enemigo_abatido`, arena reparte oro en `_al_terminar_oleada`, snapshot trae `oleada`/`bajas`, Eventos es el puente seguro sin autoload. Decidido: "Legado de Renegados".
- **T2** — S2-S3 — ruta: inline — estado: ✅ — `scripts/game/Legado.gd` (puro, SIN snapshots): renombre determinista por oleada+bajas, 5 grados (Aspirante→Inmortal), `sincronizar(oleada,bajas)` para cliente. Enganches en `Arena.gd`: `legado`, `enemigo_abatido`→`_al_abatir_para_legado`, `_al_terminar_oleada`, `_aplicar_snapshot` (cliente), `_publicar_legado()` (anuncia sólo ascensos). Indicador en `ArenaHUD._ficha_jugador` + `establecer_legado()`. Sin tocar BalanceOlas/red daño.
- **T3** — S2-S3 — ruta: inline — estado: ✅ — RED→GREEN: 6 checks en `smoke_test.gd` (renombre, grados, determinismo, sincronía desde totales, HUD). Gate: import 0, smoke 15/15, regression 178/178, wave sim 3/3, boot limpio. Captura inspeccionada: "ASPIRANTE" visible en ascua junto a ABATIDOS.
- **T4** — S1-S3 — ruta: inline — estado: ✅ — commit `b997277` (6 archivos, +152/−5), assess RDD `medium/under_budget` sin review obligatoria. Doc ODD actualizado.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Frentes 1 (auditoría/bugs) y 2 (visual) completos en las ramas `audit/bugs-limpieza` y `visual/identidad-arena`. El usuario eligió para el frente 3 (verbatim): "Un sistema nuevo con sello propio (Recommended)".

**L3** — 2026-11-17 — Explorador mapeando el flujo de oleadas antes de decidir el sistema concreto, para elegir el que encaje con menor riesgo (sin tocar snapshots de red ni tablas de balance).

**L4** — 2026-11-17 — Explorador entregó el mapa. Decisión: "Legado de Renegados" — renombre cosmético/narrativo por jugador y partida, derivado de `oleada`/`bajas` (ya en snapshot). Sin claves nuevas en red, sin tocar `GladiatorStats`/`BalanceOlas`, sin buffs que afecten a otros jugadores (eso exigiría autoridad del servidor).

**L5** — 2026-11-17 — Implementación: `Legado.gd` con `renombre_por()`/`grado_por()` estáticos, 5 grados con títulos originales (Aspirante, Renegado, Veterano, Campeón de ceniza, Inmortal). El cliente usa `sincronizar(oleada,bajas)` del snapshot porque no corre WaveManager (`AGENTS.md:76`); el servidor usa los mismos totales. Así ambos calculan idéntico. `_publicar_legado` actualiza la ficha cada snapshot pero sólo emite mensaje en ascenso de grado (evita spam).

**L6** — 2026-11-17 — caption: el indicador de rango aparece en la barra superior junto a ABATIDOS, en color `ForjaTema.ASCUA`, con separador "·". Sin glyphs tofu (`AGENTS.md:145`).

**L7** — 2026-11-17 — Frente de jugabilidad COMPLETO. Commit `b997277`, assess `medium/under_budget`. Estado global: frentes 1 (auditoría), 2 (visual) y 3 (jugabilidad) entregados. Queda frente 4 (optimización/deuda) y entonces push final (el usuario lo autorizó cuando todo esté listo).

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · Estado frente jugabilidad: **COMPLETO**
