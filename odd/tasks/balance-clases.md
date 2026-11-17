# Balance de clases — atributos base y curva de velocidad

Rama: `main` · Runner: `godot --headless --script res://tests/<suite>.gd`

## Specs

**S1** — Pedido del usuario: "los campeones suben muy rapido [captura 2.20 golpes/s]" y "tambien deberiamos arreglar las estadisticas de cada campeon se supone que las clases son diferentes y tienen casi los mismos atributos".

**S2** — Decisiones del usuario: velocidad → "bajar a 0.015 y mantener tope 2.20"; atributos → "Perfil moderado" (Bastión 14/8/8, Filo 8/15/7, Cetro 7/8/15, Hoplita 12/11/7, Saeta 7/16/7, Prisionero 10/10/10). `VEL_ATAQUE_BASE` se dejó en 0.15 (sin subir a 0.25) para no meter un cambio no validado en partida.

## Tasks

- **T1** — ✅ — corregir `tests/balance_report.gd`: usaba fórmulas de enemigo falsas (`95+46L`, `11+4.6L`) vs reales (`66+24L`, `6+2L` en `ArenaEnemy.gd:160-163`) y sólo 4 clases. Ahora lee catálogo real y 6 clases. Commit `224e989`.
- **T2** — ✅ — RED→GREEN velocidad: `VEL_ATAQUE_POR_AGI` 0.05→0.015. Saeta L20 pasa de topado 2.20 a 2.00; la curva dura los 20 niveles. 2 checks nuevos (commit `d7620bf`).
- **T3** — ✅ — RED→GREEN atributos base: `ATRIBUTOS_BASE_POR_CLASE` aplicado en `configurar_clase()` sólo si nivel==1 y puntos_libres==0. 4 checks nuevos (commit `d7620bf`).
- **T4** — ✅ — gate: import 0, smoke 15/15, regression 190/190, wave sim 3/3, boot limpio. Assess `medium/under_budget`. Reporte de balance re-corrido y analizado.

## Log

**L1** — El reporte de balance mentía: el shim `godot` no imprimía su salida (había que usar el exe directo del winget) y además usaba constantes desactualizadas. Corregido en `224e989`; no se subió todavía.

**L2** — El tope de velocidad se alcanzaba en nivel 10-15 porque `VEL_ATAQUE_POR_AGI=0.05` con agilidades de 48-86. Con 0.015 ninguna clase topa; Saeta L20=2.00, Filo=1.71, Bastión=1.03.

**L3** — Todas las clases arrancaban 10/10/10; `configurar_clase()` sólo cambiaba la curva de crecimiento. Ahora cada clase tiene perfil inicial moderado (total 30), distinto desde el nivel 1. Prisionero se mantuvo neutro para no romper el check `VIDA_BASE + 10*VIDA_POR_FUERZA`.

**L4** — Efecto combinado: combate más pausado al inicio (TTK Saeta L1 de ~7s a ~10s) y progresión más larga. Se propuso subir `VEL_ATAQUE_BASE` a 0.25 si el playtest siente el inicio arrastrado; NO aplicado. Cetro sigue dependiendo de invocaciones no contadas por el reporte (validar en playtest).

---

Registro: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · Estado: **COMPLETO** · Commits: `224e989`, `d7620bf` (sin push) · Assess: medium/under_budget
