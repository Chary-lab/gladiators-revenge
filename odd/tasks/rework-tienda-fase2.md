# Rework tienda fase 2 — ruta vertical, colores por categoría y undo

Rama: `main` (push al final) · Runner: `godot --headless --script res://tests/<suite>.gd` + capturas

## Specs

**S1** — Pedido del usuario (verbatim): "el arbol de contruccion no me convence en realidad, la estructura de la tienda aun la veo demaciado grande mucho espacios vacios que se puede ocupar mejor, los componenetes deberian ir antes y luego forja, consumibles deberia ser primero, y luego todos, clasificarlos tambien con colores, rojos consumibles, blancos complementos, epico morados recetas y legendarios los dorados amarrillo. aplica los colores de las tarjetas correctamente. tambien un boton de deshazer compra pero solo cuando la tienda esta abierta luego de la compra, si se sale de la tienda ya no puede volver a deshazer".

**S2** — Decisiones del usuario:
- Árbol → **ruta vertical clara** (pasos apilados, sin líneas que se cruzan, sin panel lateral repetido, ocupa mejor el espacio).
- Orden de pestañas: **CONSUMIBLES → COMPONENTES → FORJAR → TODOS**.
- Colores: **rojo=consumibles, blanco=componentes, morado=épico/recetas, dorado=legendarios**.
- Undo: **última compra**, botón visible sólo con la tienda abierta, se pierde al cerrar.

## Tasks

- **T1** — ✅ — mapeo completo (API de tests del árbol, flujo de compra y cierre).
- **T2** — ✅ — 4 pestañas en orden CONSUMIBLES→COMPONENTES→FORJAR→TODOS (constantes `PESTANA_*`, TODOS `3` muestra todo); colores por categoría en `_rareza_color` (rojo/blanco/morado/dorado); tarjetas 112×126 para ocupar mejor el espacio.
- **T3** — ✅ — BuildTreePanel: ruta vertical (ingredientes→objeto resaltado) con meta `&"en_ruta"` y flechas; se conservan 26 nodos y la API de tests.
- **T4** — ✅ — undo de última compra: `Arena.deshacer_compra`, botón visible sólo con tienda abierta, historial limpio al abrir/cerrar. 6 checks RED→GREEN.
- **T5** — ✅ — capturas inspeccionadas (tienda y árbol), gate 212/212, docs actualizados, commit + push.

## Log

**L1** — Pedido original del frente 2 (verbatim en S1). Se respeta la restricción de no arte Warcraft y la paleta propia del repo.

**L2** — 2026-11-17 — Inspeccioné `captura_tienda.png` y `captura_arbol.png`. Árbol: grafo de 5 columnas con líneas que se cruzan, ficha lateral repetida y espacio vacío abajo. Colores actuales desordenados: poción verde, pergamino morado, componente azul. Elegido: ruta vertical + colores por categoría + undo.

**L3** — 2026-11-17 — BUG corregido en commit `bd0b360`: la compra cobraba la forja por adelantado (Placa 110 + Núcleo 80 = 190 > 168 de oro → bloqueada) mientras la ficha decía 110. Según decisión del usuario, la compra cuesta sólo `item.precio`; la forja queda pendiente y se completa al ganar oro (`revisar_forjas_automaticas(jugador)`). 6 checks nuevos. Assess medium/under_budget. Pusheado.

**L4** — 2026-11-17 — Fase 2 completa. Undo se pierde al cerrar (pedido explícito). Ruta vertical reemplaza el grafo de líneas que se cruzaban. Colores de borde por categoría; el icono conserva su color semántico (maná azul) para distinguir pociones. Gate 212/212.

---

Registro de entregas: T1 → ✅ · T2 → ✅ · T3 → ✅ · T4 → ✅ · T5 → ✅ · Estado: **COMPLETO**
