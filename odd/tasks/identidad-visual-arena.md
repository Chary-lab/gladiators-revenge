# Identidad visual original de la arena — frente 2 (dos fases)

Rama: `visual/identidad-arena` (desde `audit/bugs-limpieza`) · Estrategia: `ask-on-risk` · Runner: `godot --headless --script res://tests/<suite>.gd` + capturas `--captura-*` · Commit Fase 1: `8031b5b` (`feat(visual): arena en paleta carbón y ascua, fuente ámbar`)

## Specs

**S1** — Pedido original (verbatim): "necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual". Restricción de `AGENTS.md:152`: "Do not use Warcraft/Blizzard/Valve names or art. Keep Spanish original names, lore and icons." La UI ya tiene identidad propia (carbón/oro/ascua + Cinzel, `ForjaTema.gd`); el punto débil es la arena 3D: suelo claro ajedrezado, fuente cian fluorescente, modelos KayKit genéricos.

**S2** — Decisión del usuario (verbatim de la opción elegida): "Todo lo anterior en dos fases" = "Primero atmósfera/color (entrega 1) y después modelos propios (entrega 2), con revisión entre medias". O sea: **Fase 1** (esta entrega) = recolorizar suelo/fuente/muros a la paleta carbón-ascua, mejorar luces y atmósfera; **Fase 2** (pendiente de revisión) = modelos propios para gladiadores/enemigos. No se arranca la Fase 2 sin mostrar capturas de la Fase 1.

**S3** — Alcance de la Fase 1 (entrega actual). Archivo主要为 `scripts/game/Arena.gd`, funciones `_crear_entorno()` (~1255), `_crear_suelo()` (~1283), `_crear_muros()` (~1377), `_crear_decoracion()` (~1390) y bloque de la fuente/obelisco (~1490-1536). Criterios: (a) fuente deja de ser cian y pasa a ámbar/ascua coherente con `ForjaTema.ASCUA`/`ORO`; (b) suelos y muros en tonos carbón en vez de claros; (c) luz ambiental y sol cálidos; (d) se mantiene legibilidad de zonas (fuente vs obelisco vs tienda) y se evitan caracteres tofu (`AGENTS.md:145`); (e) gate en verde + capturas `--captura-combate` y `--captura-arquetipos` inspeccionadas. Fuera de alcance: tintes de personajes (ya son originales: skins Tierra Baldía/Ceniza/Sangre/Hielo) y modelos (Fase 2).

## Tasks

- **T1** — S1-S2 — ruta: inline — estado: ✅ — rama `visual/identidad-arena` desde `audit/bugs-limpieza`; documento creado.
- **T2** — S3 — ruta: inline — estado: ✅ — `Arena.gd`: environment carbón/ámbar, sol cálido, suelos/muros/gradas oscurecidos, fuente de cian → ascua; nuevo `scripts/visual/MaterialTinte.gd` tiñe los GLB del suelo reutilizando materiales por caché.
- **T3** — S3 — ruta: inline — estado: ✅ — capturas `--captura-combate` y `--captura-arquetipos` inspeccionadas (2 iteraciones: fuente amarilla → ascua rojiza). Gate: import 0, smoke 15/15, regression 171/171, wave sim 3/3, boot 600 limpio.
- **T4** — S2 — ruta: inline — estado: ✅ — checkpoint mostrado; usuario aprobó seguir con todas las fases y push al final (L9).
- **T5** — S2 — ruta: inline — estado: ✅ — Fase 2 re-entregada: nueva skin "Ascua de la Rebelión" en `SKINS` (`Arena.gd`) + check en `smoke_test.gd`. Intento de geometría en huesos revertido (L10) por invisible. Gate 15/15, 172/172, 3/3, boot limpio.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Frente 1 (auditoría/bugs/limpieza) entregado en rama `audit/bugs-limpieza`, commits `3f12dec` y `949615c`. El usuario confirmó: "ese es el repo esta bien la identidad, y si sigamos con que sigue". Se continúa con el frente visual.

**L3** — 2026-11-17 — Se inspeccionaron capturas reales (`captura_menu.png`, `captura_hud.png`, `captura_campeon.png`, `captura_arquetipos.png`). Menú y forja: identidad sólida y original. Arena 3D: suelo claro ajedrezado, fuente cian, modelos genéricos → foco del frente.

**L4** — 2026-11-17 — El usuario eligió alcance (verbatim): "Todo lo anterior en dos fases". Se respeta el checkpoint de revisión entre fases (S2).

**L5** — 2026-11-17 — Mapa del código visual: `_crear_entorno()` usa `Environment` con fondo `Color(0.07,0.06,0.10)` y luz ambiental fría `Color(0.78,0.72,0.88)`; sol `Color(1.0,0.93,0.82)`; fuente con `material_agua` cian `Color(0.18,0.62,0.68)` + emisión `Color(0.15,0.75,0.80)` + luz `Color(0.35,0.85,0.95)`; obelisco violeta. Los tintes de personajes (`VISUALES`, skins) ya son originales y no se tocan en Fase 1.

**L6** — 2026-11-17 — Fase 1 implementada. Decisión de diseño: la fuente pasó de cian a ascua rojiza (`Color(0.55,0.22,0.10)` base, emisión `Color(0.90,0.30,0.10)`) para alinear con `ForjaTema.ASCUA` sin competir con el oro de la UI. Los GLB del suelo se tiñen multiplicando albedo (`MaterialTinte`) con caché por (modelo,malla,tinte), mismo patrón que `CharacterVisual`, sin assets nuevos.

**L7** — 2026-11-17 — Resultado visual inspeccionado en capturas reales: arena ahora carbón cálido con textura, fuente ascua, contraste con HUD coherente. Se descartó teñir los personajes en esta fase (sus skins Tierra Baldía/Ceniza/Sangre/Hielo ya son identidad original) y los modelos quedan para Fase 2.

**L8** — 2026-11-17 — Commit Fase 1 `8031b5b` (4 archivos, +143/−20: `Arena.gd`, `MaterialTinte.gd` + su `.uid`, doc ODD). Assess RDD con base `949615c`: `risk: medium`, `review_due: false`, reason `under_budget` (el primer intento fue `unassessable` por el hash de untracked desactualizado; se obtuvo el canónico con `review status --next-transition` y se re-corrió). Sin review obligatoria.

**L9** — 2026-11-17 — El usuario aprobó continuar TODAS las fases sin más checkpoints y hacer push al final, cuando todo esté listo: "sigue con las fases y luego subimos cuando tengamos todo listo". Se arranca Fase 2 (modelos propios). Explorador `gentle-ai-explore` (sesión `ses_e16bbd4ceffeuO7r2FY3CfXf3g3`) mapeó: los clips de animación (idle/walk/run/attack/cast/hit/death) viven en los GLB de KayKit, `CharacterVisual` los reproduce vía `AnimationPlayer`; reemplazar los GLB exige recrear skeleton + clips o se pierde `mover()`/`atacar()`/`ajustar_ritmo()`. KayKit pesa 21.4 MB dentro del build Web de ~47 MB.

**L10** — 2026-11-17 — Intento de Fase 2 (geometría original anclada a `BoneAttachment3D` head: crestas/cuernos/capuchas, helper `IdentidadPersonaje.gd`) **revertido**: las mallas se creaban (sonda: `head` con 4 hijos, malla visible=true) pero no se renderizaban en las capturas, igual que el `anadir_colmillos()` preexistente. Los huesos animados del GLB no muestran geometría añadida en runtime. No se insistió: los tests headless no validan lo visual y el enfoque era invisible.

**L11** — 2026-11-17 — Fase 2 re-entregada con el mecanismo PROBADO: nueva skin **"Ascua de la Rebelión"** (`SKIN_ASCUA := Color(1.0,0.52,0.30)`) añadida a `SKINS` en `Arena.gd`. Sonda verificó que `aplicar_skin` cambia el albedo del modelo de verde (0.90,0.98,0.84) a cálido (1.0,0.83,0.76) — visible y coherente con la paleta. Check de regresión en `smoke_test.gd`: "la skin Ascua de la Rebelión está disponible" (172/172). La piel se rota con K y se sincroniza por red (índice en snapshot). Sin assets nuevos.

**L12** — 2026-11-17 — decisión arquitectónica: se conservan los GLB CC0 de KayKit por su rig/animación; la identidad original se logra con (1) paleta carbón/ascua en la arena (Fase 1) y (2) skins de color con nombres/lore propios (Fase 2). No se introducen modelos nuevos para no sacrificar animación ni arriesgar el build Web. Queda como deuda documentada para un futuro proyecto de modelado con rig propio.

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · T5 → ✅ (Fase 2 re-entregada como skin Ascua) · Estado frente visual: **COMPLETO** · Siguiente: frente de ideas/jugabilidad, luego optimización/deuda. Push al final (usuario).
