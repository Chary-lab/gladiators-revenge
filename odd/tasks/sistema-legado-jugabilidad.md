# Sistema original de jugabilidad — frente 3

Rama: `visual/identidad-arena` (misma rama de trabajo; push al final) · Estrategia: `ask-on-risk` · Runner: `godot --headless --script res://tests/<suite>.gd`

## Specs

**S1** — Pedido original (verbatim): "vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso" y "necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad". El frente de ideas/jugabilidad debe aportar **originalidad con sello propio**, sin copiar WC3.

**S2** — Decisión del usuario (verbatim de la opción elegida): "Un sistema nuevo con sello propio (Recommended)" — "Añadir una mecánica transversal original (por ejemplo: 'Renegados' — oleadas de élite con招募 que cambian el ritmo, o un sistema de 'Legado' entre oleadas). Lo diseño acotado, con tests y docs, sin tocar el balance base."

**S3** — Restricciones de arquitectura (AGENTS.md): no tocar tablas de balance existentes (`BalanceOlas.PERFILES`, `ArenaEnemy.ARQUETIPOS`), no cambiar el formato de snapshots de red sin necesidad, mantener `GladiatorStats` como única fuente de escalado, y añadir checks en `smoke_test.gd`/`regression_test.gd`. El sistema debe ser observable de forma determinista en tests.

## Tasks

- **T1** — S1-S3 — ruta: inline (mapeo delegado `gentle-ai-explore`, sesión `ses_e16abe75affeYFQ12s8zYKbH2j`) — estado: en curso — mapear ciclo de oleada, hooks, red y tests; decidir el sistema concreto.
- **T2** — S2-S3 — ruta: inline — estado: pendiente — implementar el sistema (1 archivo nuevo + 2-3 enganches), sin tocar balance ni snapshots.
- **T3** — S2-S3 — ruta: inline — estado: pendiente — tests deterministas (RED→GREEN) + gate completo.
- **T4** — S1-S3 — ruta: inline — estado: pendiente — docs (README/AGENTS) y commit + assess RDD.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Frentes 1 (auditoría/bugs) y 2 (visual) completos en las ramas `audit/bugs-limpieza` y `visual/identidad-arena`. El usuario eligió para el frente 3 (verbatim): "Un sistema nuevo con sello propio (Recommended)".

**L3** — 2026-11-17 — Explorador mapeando el flujo de oleadas antes de decidir el sistema concreto, para elegir el que encaje con menor riesgo (sin tocar snapshots de red ni tablas de balance).

---

Registro de entregas: T1 → ⏳ · T2 → [pendiente] · T3 → [pendiente] · T4 → [pendiente]
