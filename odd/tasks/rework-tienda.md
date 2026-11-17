# Rework de la tienda — más dinámica, interactiva y moderna

Rama: `main` (push al final) · Runner: `godot --headless --script res://tests/<suite>.gd` + `--captura-tienda`

## Specs

**S1** — Pedido del usuario (verbatim): "no me convece la tienda, tenemos que hacerle un tipo de rework que sea mas dinamico e facil de distinguir, de poder crear los items, que se interactivo y creativo, que sea facil de entender y facil de usar y moderno, algo asi como la tienda de lol o dota 2".

**S2** — Decisión del usuario (verbatim): "Rework completo con pestañas y forja visual (Recommended)" = "Rediseñar ShopPanel: pestañas COMPRAR/FORJAR/COMPONENTES, tarjetas con rareza glow y badges, barra de progreso de forja en vivo con 'FORJAR AHORA', y una ruta sugerida. Mantengo compatibilidad con tests."

**S3** — Restricciones (AGENTS.md): tienda es un modal 1120×560 sobre la arena (no pantalla completa — se descartó la opción LoL literal); una sola lista original sin pestañas (S2 la cambia a conciencia); tocar tarjeta selecciona, tocar otra vez compra; lógica de compra en Arena/InventoryComponent; sin glyphs tofu (◆✔✘); dirty flags y refresco en sitio (no reconstruir 26 tarjetas por compra); Botón ÁRBOL DE FORJA debe seguir abriendo BuildTreePanel.

## Tasks

- **T1** — S1-S3 — ruta: inline (mapeo delegado `gentle-ai-explore`, sesión `ses_e164ba681ffer6HkUo31l2br72`) — estado: ✅ — mapa: ShopPanel 1040 líneas, contrato de tests (`_cuadriculas`, `_ficha_*`, `_arbol_*`, `_cambiar_modo`, `_abrir_arbol`), forja hoy automática sin API directa.
- **T2** — S2-S3 — ruta: inline — estado: ✅ — rework aplicado: 3 pestañas (`TODOS`/`FORJAR`/`COMPONENTES`) en fila propia que sólo cambian visibilidad (las 26 tarjetas siguen en `_cuadriculas`); secciones por `item.tipo`; barra `BarraSegmentada` con `InventoryComponent.progreso_receta`; botón `FORJAR AHORA` que delega en `Arena.forjar_objeto()` (nueva API pública, sin economía en el panel). Chips con contraste corregido (texto `ORO_CLARO` sobre borde dorado).
- **T3** — S3 — ruta: inline — estado: ✅ — +7 checks (progreso_receta, forjar_objeto, 3 pestañas, filtrado sin borrar tarjetas, barra). 198/198.
- **T4** — S3 — ruta: inline — estado: ✅ — `--captura-tienda` inspeccionada en 4 iteraciones (arreglé desborde de CERRAR, doble COMPRAR y contraste del chip activo). Gate: import 0, smoke 15/15, regression 198/198, wave sim 3/3, boot limpio.
- **T5** — S1-S3 — ruta: inline — estado: ✅ — docs (AGENTS 81/84/43/184, README 35/260) actualizados. Commit `d76c55a` (7 archivos, +234/−42), assess `medium/under_budget` sin review. Push final.

## Log

**L1** — Pedido original (verbatim):
> "D:\Orc Gladiators" necesitamos que se paresca a orc gladiators revenge de warcraft 3 pero sin caer en la similitud, hay que tener originalidad, vamos a mejorar visual, errores, bugs, ideas, optimizar el codigo, y borrar cosas huerfanas sin uso

**L2** — 2026-11-17 — Inspeccioné `captura_tienda.png`: tienda funcional pero lista plana de 26 objetos, ficha lateral, "SOLO FORJA" pasivo sin progreso visual. Elegido rework completo con pestañas y forja visual. Se descartó tienda de pantalla completa estilo LoL literal porque tapa la arena (es modal entre oleadas).

**L3** — 2026-11-17 — Explorador mapeando el código antes de tocar nada. Prioridad: no romper los nombres que leen los tests (`_cuadriculas`, `_grid`, `_campo_busqueda`, `_boton_arbol`) y la API de compra/forja de Arena.

**L4** — 2026-11-17 — Decisión arquitectónica: el botón FORJAR no reimplementa economía. `Arena.forjar_objeto()` llama a la ya existente `revisar_forjas_automaticas()` (autoritativa, funciona en red) y devuelve si cambió el oro. El panel sólo muestra progreso y delega. `receta` es `Array[StringName]` (una entrada por unidad), no diccionario — corregido tras error de compilación.

**L5** — 2026-11-17 — Se aplicó la disciplina UI del skill `engineering-playbook`: contraste legible en chips activos (4.5:1), 44px+ de área táctil, sin glyphs tofu, sin *middle-dot meta* genérico. Paleta/tipografía propias del repo (ForjaTema/Cinzel). Las pestañas van en fila separada para no desbordar el modal 1120×560.

**L6** — 2026-11-17 — Rework COMPLETO y entregado. La tienda pasó de una lista plana a una experiencia con pestañas, progreso de forja visible y acción FORJAR, manteniendo el modal compacto y sin romper el contrato de tests (las 26 tarjetas siguen en `_cuadriculas`). Commit `d76c55a`, assess medium/under_budget.

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · T5 → ✅ · Estado: **COMPLETO**
