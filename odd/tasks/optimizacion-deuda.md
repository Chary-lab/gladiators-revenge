# Optimización y deuda — frente 4 (final, antes del push)

Rama: `visual/identidad-arena` (push al final, cuando todo esté listo) · Estrategia: `ask-on-risk` · Runner: `godot --headless --script res://tests/<suite>.gd`

## Specs

**S1** — Pedido original (verbatim): "vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso". Deuda conocida (`AGENTS.md:139`): `Arena.gd` (~2440), `ArenaHUD.gd` (~1623), `GladiatorController.gd` (~1425) son god objects.

**S2** — Restricción: cambios de BAJO riesgo y alto valor, verificables con los tests existentes, sin romper arquitectura/red/balance. Si no hay nada seguro, se dice honestamente y se cierra el frente sin cambios forzados.

## Tasks

- **T1** — S1-S2 — ruta: inline (mapeo delegado `gentle-ai-explore`, sesión `ses_e16a31da7ffeWm3Z7geoQRxY3i`) — estado: en curso — mapear extracciones seguras, coste por frame, red, presupuesto Web y tests de cobertura.
- **T2** — S1-S2 — ruta: inline — estado: pendiente — aplicar el cambio de mayor valor y menor riesgo del informe.
- **T3** — S1-S2 — ruta: inline — estado: pendiente — gate completo + assess RDD + docs.
- **T4** — estado: pendiente — push final (sólo cuando el usuario confirme "todo listo").

## Log

**L1** — 2026-11-17 — Frentes 1 (auditoría/bugs), 2 (visual) y 3 (jugabilidad/Legado) completos. Push diferido al final por decisión del usuario. Se abre frente 4 (optimización/deuda), el último.

---

Registro de entregas: T1 → ⏳ · T2 → [pendiente] · T3 → [pendiente] · T4 → [pendiente]
